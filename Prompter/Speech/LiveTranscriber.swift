@preconcurrency import AVFoundation
import Speech

/// Потоковое распознавание речи одного канала (я или собеседник) на устройстве через SpeechAnalyzer.
/// Буферы приходят с аудиопотока, конвертируются в формат анализатора и уходят в AsyncStream.
final class LiveTranscriber: @unchecked Sendable {
    struct Update: Sendable {
        var text: String
        var isFinal: Bool
    }

    private var analyzer: SpeechAnalyzer?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?

    // Используются только на аудиопотоке после старта.
    private var analyzerFormat: AVAudioFormat?
    private var converter: AVAudioConverter?

    /// Проверяет язык и при необходимости скачивает модель распознавания (один раз, затем работает офлайн).
    static func prepare(locale: Locale) async throws -> Locale {
        guard SpeechTranscriber.isAvailable else {
            throw PrompterError.message("Распознавание речи на этом Mac недоступно.")
        }
        guard let supported = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
            throw PrompterError.message("Язык \(locale.identifier) не поддерживается распознаванием речи.")
        }
        let probe = SpeechTranscriber(locale: supported, preset: .progressiveTranscription)
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [probe]) {
            try await request.downloadAndInstall()
        }
        return supported
    }

    /// `vocabulary` — термины, которые распознаватель должен узнавать на слух (из глоссария).
    func start(locale: Locale, vocabulary: [String] = [], onUpdate: @escaping @Sendable (Update) -> Void) async throws {
        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults, .fastResults],
            attributeOptions: []
        )
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        if !vocabulary.isEmpty {
            let context = AnalysisContext()
            context.contextualStrings[.general] = vocabulary
            try await analyzer.setContext(context)
        }
        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            throw PrompterError.message("Не удалось подобрать аудиоформат для распознавания.")
        }
        analyzerFormat = format

        let (stream, continuation) = AsyncStream.makeStream(of: AnalyzerInput.self, bufferingPolicy: .bufferingNewest(64))
        inputContinuation = continuation
        self.analyzer = analyzer

        resultsTask = Task {
            do {
                for try await result in transcriber.results {
                    onUpdate(Update(text: String(result.text.characters), isFinal: result.isFinal))
                }
            } catch {
                // Поток результатов завершается ошибкой при отмене — это штатно.
            }
        }
        try await analyzer.start(inputSequence: stream)
    }

    /// Вызывается с аудиопотока.
    func append(_ buffer: AVAudioPCMBuffer) {
        guard let continuation = inputContinuation, let target = analyzerFormat else { return }
        guard let converted = convert(buffer, to: target) else { return }
        continuation.yield(AnalyzerInput(buffer: converted))
    }

    func stop() async {
        inputContinuation?.finish()
        inputContinuation = nil
        if let analyzer {
            try? await analyzer.finalizeAndFinishThroughEndOfInput()
        }
        analyzer = nil
        resultsTask?.cancel()
        resultsTask = nil
        converter = nil
    }

    private func convert(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        if buffer.format == format { return buffer }
        if converter == nil || converter?.inputFormat != buffer.format {
            converter = AVAudioConverter(from: buffer.format, to: format)
        }
        guard let converter else { return nil }

        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 16
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }

        var consumed = false
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, inputStatus in
            if consumed {
                inputStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            inputStatus.pointee = .haveData
            return buffer
        }
        guard status != .error, error == nil, output.frameLength > 0 else { return nil }
        return output
    }
}
