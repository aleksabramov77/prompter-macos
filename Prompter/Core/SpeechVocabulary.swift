import Foundation

/// Слова, которые подсказываем распознавателю речи, чтобы он узнавал термины проекта на слух
/// (имена, названия сервисов, жаргон), а не коверкал их.
enum SpeechVocabulary {
    /// Стороны глоссария, написанные латиницей (язык речи), без дублей и не больше `limit`.
    static func contextualStrings(from entries: [GlossaryEntry], limit: Int = 100) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for entry in entries {
            for side in [entry.term, entry.translation] {
                let text = side.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty, isLatin(text), seen.insert(text.lowercased()).inserted else { continue }
                result.append(text)
                if result.count == limit { return result }
            }
        }
        return result
    }

    /// Есть латинские буквы и нет кириллицы.
    static func isLatin(_ text: String) -> Bool {
        var hasLatin = false
        for scalar in text.unicodeScalars {
            if (0x0400...0x04FF).contains(scalar.value) { return false }
            if ("a"..."z").contains(Character(scalar).lowercased().first ?? " ") { hasLatin = true }
        }
        return hasLatin
    }
}
