import AppKit
import Foundation
import Observation

/// Координатор: аудио → распознавание → детектор «зависания» → подсказчики → окно подсказок.
@MainActor
@Observable
final class AppModel {
    enum Status: Equatable {
        case idle
        case starting(String)
        case running
        case failed(String)
    }

    let settings = AppSettings()
    let knowledge = KnowledgeBase()

    private(set) var status: Status = .idle
    private(set) var transcript = LiveTranscript()
    private(set) var partnerTranslations: [UUID: String] = [:]
    private(set) var suggestions = Suggestions()
    private(set) var suggestionSource = ""
    private(set) var isSuggesting = false
    private(set) var suggestionError: String?
    /// Предупреждения, при которых сессия продолжается (нет звука собеседника, нет перевода).
    private(set) var warnings: [String] = []
    private(set) var micLevel: Float = -160
    private(set) var partnerLevel: Float = -160
    private(set) var sessions: [SessionRecord] = []

    var isRunning: Bool { status == .running }

    private let microphone = MicrophoneCapture()
    private let systemAudio = SystemAudioCapture()
    private let myTranscriber = LiveTranscriber()
    private let partnerTranscriber = LiveTranscriber()
    private let overlay = OverlayPanelController()
    private var detector = HesitationDetector()
    private var translator: SubtitleTranslator?
    private var currentSession: SessionRecord?
    private var ticker: Task<Void, Never>?
    private var suggestionTask: Task<Void, Never>?
    private var lastVoiceAt = Date.distantPast
    private var hotKey: GlobalHotKey?

    init() {
        loadSessions()
        hotKey = GlobalHotKey { [weak self] in
            self?.hotKeyPressed()
        }
    }

    // MARK: - Сессия

    func toggleSession() {
        Task {
            if isRunning { await stop() } else { await start() }
        }
    }

    func start() async {
        switch status {
        case .starting, .running: return
        case .idle, .failed: break
        }
        warnings = []
        status = .starting("Запрашиваю доступ к микрофону…")
        guard await MicrophoneCapture.requestAccess() else {
            status = .failed("Нет доступа к микрофону. Разрешите его в Системных настройках → Конфиденциальность и безопасность → Микрофон.")
            return
        }

        do {
            status = .starting("Готовлю распознавание речи (в первый раз скачивается модель)…")
            let locale = try await LiveTranscriber.prepare(locale: Locale(identifier: settings.speakingLocale))

            transcript.clear()
            partnerTranslations = [:]
            suggestions = Suggestions()
            suggestionError = nil
            detector = HesitationDetector(config: .init(pauseThreshold: settings.pauseThreshold))
            currentSession = SessionRecord(startedAt: .now)
            let vocabulary = SpeechVocabulary.contextualStrings(from: Glossary.parse(settings.glossaryText))

            try await myTranscriber.start(locale: locale, vocabulary: vocabulary) { [weak self] update in
                Task { @MainActor in self?.handle(update, from: .me) }
            }
            let myTranscriber = myTranscriber
            microphone.onBuffer = { myTranscriber.append($0) }
            microphone.onLevel = { [weak self] level in
                Task { @MainActor in self?.updateLevel(level, of: .me) }
            }
            try microphone.start()

            if settings.listenToPartner {
                status = .starting("Подключаю звук собеседника…")
                await startPartnerAudio(locale: locale, vocabulary: vocabulary)
            }

            if settings.translatePartner, settings.listenToPartner {
                let result = await SubtitleTranslator.make(from: settings.speakingLocale, to: settings.nativeLanguage)
                translator = result.translator
                if let problem = result.problem { warnings.append(problem) }
            }

            if activeSuggesters().isEmpty {
                warnings.append("Подсказки недоступны: добавьте ключ OpenRouter или Claude во вкладке «Настройки».")
            }

            status = .running
            startTicker()
            overlay.show(model: self)
        } catch {
            await stopCapture()
            status = .failed(error.localizedDescription)
        }
    }

    func stop() async {
        guard isRunning else { return }
        await stopCapture()
        if var session = currentSession {
            session.endedAt = .now
            session.transcript = transcript.lines
            if !session.transcript.isEmpty || !session.stuck.isEmpty {
                save(session)
                sessions.insert(session, at: 0)
            }
        }
        currentSession = nil
        status = .idle
    }

    private func startPartnerAudio(locale: Locale, vocabulary: [String]) async {
        do {
            try await partnerTranscriber.start(locale: locale, vocabulary: vocabulary) { [weak self] update in
                Task { @MainActor in self?.handle(update, from: .partner) }
            }
            let partnerTranscriber = partnerTranscriber
            systemAudio.onBuffer = { partnerTranscriber.append($0) }
            systemAudio.onLevel = { [weak self] level in
                Task { @MainActor in self?.updateLevel(level, of: .partner) }
            }
            systemAudio.onStop = { [weak self] _ in
                Task { @MainActor in self?.warnings.append("Захват звука собеседника остановился.") }
            }
            try await systemAudio.start()
        } catch {
            await partnerTranscriber.stop()
            warnings.append(error.localizedDescription + " Пока работаю только с микрофоном.")
        }
    }

    private func stopCapture() async {
        ticker?.cancel()
        ticker = nil
        suggestionTask?.cancel()
        suggestionTask = nil
        isSuggesting = false
        microphone.stop()
        await systemAudio.stop()
        await myTranscriber.stop()
        await partnerTranscriber.stop()
        translator = nil
        micLevel = -160
        partnerLevel = -160
    }

    // MARK: - Речь

    private func handle(_ update: LiveTranscriber.Update, from speaker: Speaker) {
        let now = Date.now
        transcript.apply(speaker: speaker, text: update.text, isFinal: update.isFinal, at: now)
        detector.speechUpdated(transcript.currentUtterance(of: .me), at: now)

        if update.isFinal, speaker == .partner, let translator, let line = transcript.lastLine(of: .partner) {
            Task {
                if let translated = await translator.translate(line.text) {
                    partnerTranslations[line.id] = translated
                }
            }
        }
    }

    private func updateLevel(_ level: Float, of speaker: Speaker) {
        switch speaker {
        case .me:
            micLevel = level
            if level > AudioLevel.voiceThreshold { lastVoiceAt = .now }
        case .partner:
            partnerLevel = level
        }
    }

    private func startTicker() {
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                self?.tick()
            }
        }
    }

    private func tick() {
        guard isRunning, settings.autoSuggest else { return }
        let now = Date.now
        let voiceActive = now.timeIntervalSince(lastVoiceAt) < 0.4
        if let trigger = detector.check(now: now, isVoiceActive: voiceActive) {
            requestSuggestions(trigger: trigger)
        }
    }

    // MARK: - Подсказки

    private func hotKeyPressed() {
        if !overlay.isVisible { overlay.show(model: self) }
        requestSuggestions(trigger: .manual)
    }

    func requestSuggestions(trigger: HesitationDetector.Trigger) {
        guard isRunning else {
            suggestionError = "Сначала начните сессию."
            return
        }
        if trigger == .manual { detector.registerManualTrigger(at: .now) }

        let engines = activeSuggesters()
        guard !engines.isEmpty else {
            suggestionError = "Нет доступной модели: добавьте ключ OpenRouter или Claude во вкладке «Настройки»."
            return
        }

        let utterance = transcript.currentUtterance(of: .me)
        let context = makeContext(utterance: utterance)
        let momentID = UUID()

        suggestionTask?.cancel()
        isSuggesting = true
        suggestionError = nil
        suggestionTask = Task {
            // Модели опрашиваются параллельно: что пришло первым — показываем сразу,
            // более сильная модель (меньший ранг) заменяет ответ, когда догонит.
            var bestRank = Int.max
            var errors: [String] = []
            await withTaskGroup(of: (Int, String, Result<Suggestions, Error>).self) { group in
                for (rank, engine) in engines.enumerated() {
                    group.addTask {
                        do {
                            return (rank, engine.name, .success(try await engine.suggest(context)))
                        } catch {
                            return (rank, engine.name, .failure(error))
                        }
                    }
                }
                for await (rank, name, result) in group {
                    guard !Task.isCancelled else { break }
                    switch result {
                    case .success(let found) where rank < bestRank && !found.isEmpty:
                        bestRank = rank
                        show(found, from: name, utterance: utterance, momentID: momentID)
                    case .failure(let error):
                        errors.append("\(name): \(error.localizedDescription)")
                    default:
                        break
                    }
                }
            }
            guard !Task.isCancelled else { return }
            if bestRank == .max {
                suggestionError = errors.first ?? "Модель не предложила вариантов."
            }
            isSuggesting = false
        }
    }

    private func show(_ found: Suggestions, from source: String, utterance: String, momentID: UUID) {
        suggestions = found
        suggestionSource = source
        let moment = StuckMoment(
            id: momentID,
            date: .now,
            utterance: utterance,
            words: found.words.map(\.text),
            phrases: found.phrases
        )
        if let index = currentSession?.stuck.firstIndex(where: { $0.id == momentID }) {
            currentSession?.stuck[index] = moment
        } else {
            currentSession?.stuck.append(moment)
        }
    }

    private func activeSuggesters() -> [any Suggester] {
        var result: [any Suggester] = []
        let cloud = settings.cloudClient().map { CloudSuggester(client: $0) }
        switch settings.engine {
        case .claude:
            if let cloud { result.append(cloud) }
        case .onDevice:
            if OnDeviceSuggester.isAvailable { result.append(OnDeviceSuggester()) }
        case .auto:
            if let cloud { result.append(cloud) }
            if OnDeviceSuggester.isAvailable { result.append(OnDeviceSuggester()) }
        }
        return result
    }

    private func makeContext(utterance: String) -> PromptContext {
        let partnerLine = transcript.lastLine(of: .partner)?.text ?? ""
        let query = partnerLine + " " + utterance
        return PromptContext(
            speakingLanguage: AppSettings.englishName(of: settings.speakingLocale),
            nativeLanguage: AppSettings.englishName(of: settings.nativeLanguage),
            unfinishedUtterance: utterance.isEmpty ? "(the speaker has not started the sentence yet)" : utterance,
            conversation: transcript.recentContext(),
            projectBrief: settings.projectBrief,
            glossary: Glossary.relevant(Glossary.parse(settings.glossaryText), to: query, limit: 40),
            knowledge: knowledge.retrieve(query)
        )
    }

    // MARK: - Окно подсказок

    func showOverlay() {
        overlay.show(model: self)
    }

    func toggleOverlay() {
        overlay.toggle(model: self)
    }

    func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    // MARK: - История

    private func loadSessions() {
        let files = (try? FileManager.default.contentsOfDirectory(at: Storage.sessionsDirectory, includingPropertiesForKeys: nil)) ?? []
        sessions = files
            .filter { $0.pathExtension == "json" }
            .compactMap { Storage.load(SessionRecord.self, from: $0) }
            .sorted { $0.startedAt > $1.startedAt }
    }

    private func save(_ session: SessionRecord) {
        let url = Storage.sessionsDirectory.appendingPathComponent("\(session.id.uuidString).json")
        try? Storage.save(session, to: url)
    }

    func delete(_ session: SessionRecord) {
        sessions.removeAll { $0.id == session.id }
        let url = Storage.sessionsDirectory.appendingPathComponent("\(session.id.uuidString).json")
        try? FileManager.default.removeItem(at: url)
    }
}
