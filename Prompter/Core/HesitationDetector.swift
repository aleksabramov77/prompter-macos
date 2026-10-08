import Foundation

/// Решает, когда пользователь «завис» посреди фразы и пора подсказать.
///
/// Сигналы:
/// - пауза дольше `pauseThreshold` после незаконченной фразы (нет точки, вопроса, восклицания);
/// - фраза оканчивается словом-паразитом («uh», «um», «эээ»).
struct HesitationDetector {
    enum Trigger: Equatable {
        case pause
        case filler
        case manual
    }

    struct Config: Equatable {
        /// Сколько секунд тишины после незаконченной фразы считать «зависанием».
        var pauseThreshold: TimeInterval = 1.6
        /// Через сколько секунд после «паразита» подсказывать (чтобы не мигать на каждом «um»).
        var fillerDelay: TimeInterval = 0.5
        /// Минимальный интервал между автоматическими подсказками.
        var cooldown: TimeInterval = 4
    }

    static let fillers: Set<String> = [
        "uh", "uhm", "um", "umm", "er", "erm", "hmm", "mm", "ah", "eh",
        "э", "ээ", "эээ", "мм", "ммм", "эм", "ну",
    ]

    var config: Config

    private(set) var text = ""
    private(set) var lastChangeAt: Date?
    private var lastTriggerAt: Date?
    private var firedForCurrentText = false

    init(config: Config = Config()) {
        self.config = config
    }

    /// Новое состояние текущей реплики пользователя (финальный + промежуточный текст).
    mutating func speechUpdated(_ newText: String, at date: Date) {
        let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != text else { return }
        text = trimmed
        lastChangeAt = date
        firedForCurrentText = false
    }

    /// Вызывается по таймеру. Возвращает причину, если пора подсказать.
    /// `isVoiceActive` — пользователь сейчас издаёт звук (уровень микрофона выше порога).
    mutating func check(now: Date, isVoiceActive: Bool) -> Trigger? {
        guard !text.isEmpty, !firedForCurrentText, let changedAt = lastChangeAt else { return nil }
        if let last = lastTriggerAt, now.timeIntervalSince(last) < config.cooldown { return nil }

        let silence = now.timeIntervalSince(changedAt)
        let trigger: Trigger?
        if Self.endsWithFiller(text), silence >= config.fillerDelay {
            trigger = .filler
        } else if !isVoiceActive, silence >= config.pauseThreshold, !Self.endsSentence(text) {
            trigger = .pause
        } else {
            trigger = nil
        }

        if trigger != nil {
            firedForCurrentText = true
            lastTriggerAt = now
        }
        return trigger
    }

    /// Ручной запрос подсказки (горячая клавиша) тоже запускает кулдаун.
    mutating func registerManualTrigger(at date: Date) {
        lastTriggerAt = date
        firedForCurrentText = true
    }

    mutating func reset() {
        text = ""
        lastChangeAt = nil
        lastTriggerAt = nil
        firedForCurrentText = false
    }

    static func endsSentence(_ text: String) -> Bool {
        guard let last = text.trimmingCharacters(in: .whitespacesAndNewlines).last else { return false }
        return ".?!…".contains(last)
    }

    static func endsWithFiller(_ text: String) -> Bool {
        let words = text.lowercased()
            .components(separatedBy: CharacterSet.letters.inverted)
            .filter { !$0.isEmpty }
        guard let last = words.last else { return false }
        return fillers.contains(last)
    }
}
