import Foundation

/// Момент, когда пользователь «завис», и что ему подсказали. Из этих моментов
/// после созвона собирается список слов на повторение.
struct StuckMoment: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var date: Date
    var utterance: String
    var words: [String]
    var phrases: [String]
}

struct SessionRecord: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var startedAt: Date
    var endedAt: Date?
    var transcript: [TranscriptLine] = []
    var stuck: [StuckMoment] = []

    var title: String {
        startedAt.formatted(date: .abbreviated, time: .shortened)
    }

    /// Уникальные подсказанные слова по частоте — кандидаты на интервальное повторение.
    var wordsToReview: [String] {
        var counts: [String: Int] = [:]
        var firstSeen: [String: Int] = [:]
        var display: [String: String] = [:]
        var order = 0
        for moment in stuck {
            for word in moment.words.prefix(3) {
                let key = word.lowercased()
                counts[key, default: 0] += 1
                if firstSeen[key] == nil {
                    firstSeen[key] = order
                    display[key] = word
                    order += 1
                }
            }
        }
        return counts.keys
            .sorted { counts[$0]! != counts[$1]! ? counts[$0]! > counts[$1]! : firstSeen[$0]! < firstSeen[$1]! }
            .compactMap { display[$0] }
    }
}

enum SessionExporter {
    static func markdown(_ session: SessionRecord) -> String {
        var out = "# Сессия Суфлёра — \(session.title)\n\n"
        let review = session.wordsToReview
        if !review.isEmpty {
            out += "## Слова на повторение\n\n"
            out += review.map { "- \($0)" }.joined(separator: "\n") + "\n\n"
        }
        if !session.stuck.isEmpty {
            out += "## Где я запнулся\n\n"
            for moment in session.stuck {
                let time = moment.date.formatted(date: .omitted, time: .standard)
                out += "### \(time)\n\n> \(moment.utterance)\n\n"
                if !moment.words.isEmpty {
                    out += "Слова: " + moment.words.joined(separator: ", ") + "\n\n"
                }
                for phrase in moment.phrases {
                    out += "- \(phrase)\n"
                }
                out += "\n"
            }
        }
        if !session.transcript.isEmpty {
            out += "## Расшифровка\n\n"
            for line in session.transcript {
                let who = line.speaker == .me ? "Я" : "Собеседник"
                out += "**\(who):** \(line.text)\n\n"
            }
        }
        return out
    }
}
