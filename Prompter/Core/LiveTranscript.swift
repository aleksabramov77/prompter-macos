import Foundation

enum Speaker: String, Codable, Sendable {
    case me
    case partner

    var label: String {
        switch self {
        case .me: "Me"
        case .partner: "Partner"
        }
    }
}

struct TranscriptLine: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var speaker: Speaker
    var text: String
    var date: Date
}

/// Расшифровка разговора: финальные строки обоих собеседников плюс промежуточный (volatile) текст,
/// который распознаватель ещё может переписать.
struct LiveTranscript: Equatable {
    private(set) var lines: [TranscriptLine] = []
    private(set) var volatile: [Speaker: String] = [:]

    mutating func apply(speaker: Speaker, text: String, isFinal: Bool, at date: Date) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if isFinal {
            volatile[speaker] = nil
            if !trimmed.isEmpty {
                lines.append(TranscriptLine(speaker: speaker, text: trimmed, date: date))
            }
        } else {
            volatile[speaker] = trimmed.isEmpty ? nil : trimmed
        }
    }

    mutating func clear() {
        lines = []
        volatile = [:]
    }

    /// Текущая реплика собеседника: его финальные строки после последней реплики другого собеседника
    /// плюс промежуточный текст. Обрезается до `maxCharacters` с конца.
    func currentUtterance(of speaker: Speaker, maxCharacters: Int = 400) -> String {
        var parts: [String] = []
        for line in lines.reversed() {
            guard line.speaker == speaker else { break }
            parts.insert(line.text, at: 0)
        }
        if let pending = volatile[speaker] {
            parts.append(pending)
        }
        return Self.tail(parts.joined(separator: " "), maxCharacters: maxCharacters)
    }

    /// Последняя финальная строка собеседника.
    func lastLine(of speaker: Speaker) -> TranscriptLine? {
        lines.last { $0.speaker == speaker }
    }

    /// Хвост разговора в виде «Me: …\nPartner: …» для промпта.
    func recentContext(maxCharacters: Int = 2000) -> String {
        var rendered: [String] = []
        var total = 0
        var all = lines.map { "\($0.speaker.label): \($0.text)" }
        for speaker in [Speaker.partner, .me] {
            if let pending = volatile[speaker] {
                all.append("\(speaker.label): \(pending)")
            }
        }
        for entry in all.reversed() {
            total += entry.count + 1
            if total > maxCharacters, !rendered.isEmpty { break }
            rendered.insert(entry, at: 0)
        }
        return rendered.joined(separator: "\n")
    }

    static func tail(_ text: String, maxCharacters: Int) -> String {
        guard text.count > maxCharacters else { return text }
        let cut = text.suffix(maxCharacters)
        // Не начинаем с обрывка слова.
        if let space = cut.firstIndex(of: " ") {
            return String(cut[cut.index(after: space)...])
        }
        return String(cut)
    }
}
