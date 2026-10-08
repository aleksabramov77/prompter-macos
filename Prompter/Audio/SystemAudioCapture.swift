@preconcurrency import AVFoundation
import CoreMedia
@preconcurrency import ScreenCaptureKit

/// Звук собеседника: всё, что играет на Mac (Zoom, Meet, Teams, браузер), через ScreenCaptureKit.
/// Требует разрешения «Запись экрана и системного звука». Видео не нужно, поэтому кадр 2×2 и 1 fps.
final class SystemAudioCapture: NSObject, SCStreamOutput, SCStreamDelegate {
    private var stream: SCStream?
    private let audioQueue = DispatchQueue(label: "Prompter.SystemAudio")
    private let videoQueue = DispatchQueue(label: "Prompter.SystemVideo")

    /// Вызывается на `audioQueue`.
    var onBuffer: ((AVAudioPCMBuffer) -> Void)?
    var onLevel: ((Float) -> Void)?
    /// Поток остановился сам (например, отозвали разрешение).
    var onStop: ((Error?) -> Void)?

    func start() async throws {
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch {
            throw PrompterError.message(
                "Нет доступа к системному звуку. Разрешите Суфлёру «Запись экрана и системного звука» в Системных настройках → Конфиденциальность и безопасность, затем перезапустите приложение."
            )
        }
        guard let display = content.displays.first else {
            throw PrompterError.message("Не найден ни один дисплей для захвата звука.")
        }

        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        config.sampleRate = 48_000
        config.channelCount = 1
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        config.queueDepth = 3

        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: audioQueue)
        // Без экранного выхода ScreenCaptureKit засоряет лог «stream output NOT found».
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: videoQueue)
        try await stream.startCapture()
        self.stream = stream
    }

    func stop() async {
        guard let stream else { return }
        self.stream = nil
        try? await stream.stopCapture()
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio, sampleBuffer.isValid, let buffer = sampleBuffer.makePCMBuffer() else { return }
        onLevel?(AudioLevel.decibels(of: buffer))
        onBuffer?(buffer)
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        self.stream = nil
        onStop?(error)
    }
}

extension CMSampleBuffer {
    /// Копирует аудио из CMSampleBuffer в AVAudioPCMBuffer того же формата.
    func makePCMBuffer() -> AVAudioPCMBuffer? {
        guard let description = formatDescription else { return nil }
        let format = AVAudioFormat(cmAudioFormatDescription: description)
        let frames = AVAudioFrameCount(numSamples)
        guard frames > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return nil }
        buffer.frameLength = frames
        let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(
            self, at: 0, frameCount: Int32(frames), into: buffer.mutableAudioBufferList
        )
        return status == noErr ? buffer : nil
    }
}
