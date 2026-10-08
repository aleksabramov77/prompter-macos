import Foundation

struct WeightedWord: Identifiable, Equatable, Codable, Sendable {
    var id: String { text.lowercased() }
    var text: String
    /// Релевантность 0…1 — от неё зависит размер слова в облаке.
    var score: Double
}

struct Suggestions: Equatable, Codable, Sendable {
    var words: [WeightedWord] = []
    var phrases: [String] = []

    var isEmpty: Bool { words.isEmpty && phrases.isEmpty }

    static let maxWords = 8
    static let maxPhrases = 3

    /// Убирает дубли и пустые элементы, ограничивает количество, нормализует оценки.
    func normalized() -> Suggestions {
        var seen = Set<String>()
        let cleanWords = words
            .map { WeightedWord(text: $0.text.trimmingCharacters(in: .whitespacesAndNewlines), score: min(max($0.score, 0), 1)) }
            .filter { !$0.text.isEmpty && seen.insert($0.id).inserted }
            .sorted { $0.score > $1.score }
            .prefix(Self.maxWords)
        var seenPhrases = Set<String>()
        let cleanPhrases = phrases
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seenPhrases.insert($0.lowercased()).inserted }
            .prefix(Self.maxPhrases)
        return Suggestions(words: Array(cleanWords), phrases: Array(cleanPhrases))
    }

    /// Слова в порядке релевантности без оценок → оценки по рангу (первое — 1.0).
    static func ranked(words: [String], phrases: [String]) -> Suggestions {
        let count = max(words.count, 1)
        let weighted = words.enumerated().map { index, word in
            WeightedWord(text: word, score: 1.0 - Double(index) / Double(count) * 0.7)
        }
        return Suggestions(words: weighted, phrases: phrases).normalized()
    }
}

/// Разбирает ответ облачной модели. Ожидается JSON
/// `{"words":[{"text":"…","score":0.9}],"phrases":["…"]}`, но модель может обернуть его в ```json
/// или добавить текст вокруг; в крайнем случае берём строки-маркеры как фразы.
enum SuggestionParser {
    private struct Payload: Decodable {
        struct Word: Decodable {
            var text: String
            var score: Double?

            init(from decoder: Decoder) throws {
                if let single = try? decoder.singleValueContainer(), let plain = try? single.decode(String.self) {
                    text = plain
                    score = nil
                    return
                }
                let container = try decoder.container(keyedBy: CodingKeys.self)
                text = try container.decode(String.self, forKey: .text)
                score = try container.decodeIfPresent(Double.self, forKey: .score)
            }

            enum CodingKeys: String, CodingKey { case text, score }
        }

        var words: [Word]?
        var phrases: [String]?
    }

    static func parse(_ raw: String) -> Suggestions {
        if let json = extractJSONObject(from: raw),
           let data = json.data(using: .utf8),
           let payload = try? JSONDecoder().decode(Payload.self, from: data) {
            let words = payload.words ?? []
            let hasScores = words.contains { $0.score != nil }
            if hasScores {
                let weighted = words.map { WeightedWord(text: $0.text, score: $0.score ?? 0.5) }
                return Suggestions(words: weighted, phrases: payload.phrases ?? []).normalized()
            }
            return Suggestions.ranked(words: words.map(\.text), phrases: payload.phrases ?? [])
        }

        let bullets = raw.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("-") || $0.hasPrefix("•") || $0.hasPrefix("*") }
            .map { String($0.dropFirst()).trimmingCharacters(in: .whitespaces) }
        return Suggestions(words: [], phrases: bullets).normalized()
    }

    static func extractJSONObject(from text: String) -> String? {
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"), start < end else { return nil }
        return String(text[start...end])
    }
}
