import Foundation

/// Личный глоссарий: термины проекта и их перевод. Хранится как простой текст,
/// по одной паре на строку: `дедлайн = deadline`, `deploy — выкатка`, `term<TAB>перевод`.
struct GlossaryEntry: Identifiable, Hashable, Sendable {
    var id: String { term + "\u{1F}" + translation }
    var term: String
    var translation: String

    var rendered: String { translation.isEmpty ? term : "\(term) = \(translation)" }
}

enum Glossary {
    private static let separators = [" = ", " — ", " – ", " - ", "\t", "="]

    static func parse(_ text: String) -> [GlossaryEntry] {
        var seen = Set<String>()
        var result: [GlossaryEntry] = []
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            var entry = GlossaryEntry(term: line, translation: "")
            for separator in separators {
                if let range = line.range(of: separator) {
                    let term = line[..<range.lowerBound].trimmingCharacters(in: .whitespaces)
                    let translation = line[range.upperBound...].trimmingCharacters(in: .whitespaces)
                    if !term.isEmpty {
                        entry = GlossaryEntry(term: term, translation: translation)
                        break
                    }
                }
            }
            if seen.insert(entry.id.lowercased()).inserted {
                result.append(entry)
            }
        }
        return result
    }

    /// Термины, слова которых встречаются в тексте, идут первыми; остальные добивают список до `limit`.
    static func relevant(_ entries: [GlossaryEntry], to text: String, limit: Int) -> [GlossaryEntry] {
        let words = Set(tokens(text))
        let scored = entries.enumerated().map { index, entry -> (Int, Int, GlossaryEntry) in
            let entryWords = tokens(entry.term + " " + entry.translation)
            let hits = entryWords.filter { words.contains($0) }.count
            return (hits, index, entry)
        }
        return scored
            .sorted { $0.0 != $1.0 ? $0.0 > $1.0 : $0.1 < $1.1 }
            .prefix(limit)
            .map(\.2)
    }

    static func tokens(_ text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 }
    }
}
