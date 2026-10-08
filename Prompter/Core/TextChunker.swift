import Foundation

/// Режет документы на куски для векторного поиска: по абзацам, длинные абзацы — по предложениям,
/// с небольшим перекрытием, чтобы мысль на стыке не терялась.
enum TextChunker {
    static func chunks(of text: String, targetSize: Int = 700, overlap: Int = 120) -> [String] {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        let paragraphs = normalized
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var pieces: [String] = []
        for paragraph in paragraphs {
            if paragraph.count > targetSize {
                pieces.append(contentsOf: splitLong(paragraph, targetSize: targetSize))
            } else {
                pieces.append(paragraph)
            }
        }

        var chunks: [String] = []
        var current = ""
        for piece in pieces {
            if current.isEmpty {
                current = piece
            } else if current.count + 1 + piece.count <= targetSize {
                current += "\n" + piece
            } else {
                chunks.append(current)
                let carry = overlapTail(of: current, length: overlap)
                current = carry.isEmpty ? piece : carry + " " + piece
            }
        }
        if !current.isEmpty {
            chunks.append(current)
        }
        return chunks
    }

    /// Длинный абзац: собираем предложения в куски до `targetSize`; одно огромное предложение режем по словам.
    private static func splitLong(_ paragraph: String, targetSize: Int) -> [String] {
        var sentences: [String] = []
        paragraph.enumerateSubstrings(in: paragraph.startIndex..., options: .bySentences) { sentence, _, _, _ in
            if let sentence = sentence?.trimmingCharacters(in: .whitespacesAndNewlines), !sentence.isEmpty {
                sentences.append(sentence)
            }
        }
        if sentences.isEmpty { sentences = [paragraph] }

        var result: [String] = []
        var current = ""
        for sentence in sentences.flatMap({ $0.count > targetSize ? splitByWords($0, targetSize: targetSize) : [$0] }) {
            if current.isEmpty {
                current = sentence
            } else if current.count + 1 + sentence.count <= targetSize {
                current += " " + sentence
            } else {
                result.append(current)
                current = sentence
            }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    private static func splitByWords(_ text: String, targetSize: Int) -> [String] {
        var result: [String] = []
        var current = ""
        for word in text.split(separator: " ") {
            if !current.isEmpty, current.count + 1 + word.count > targetSize {
                result.append(current)
                current = ""
            }
            current += current.isEmpty ? String(word) : " " + word
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    private static func overlapTail(of text: String, length: Int) -> String {
        guard length > 0, text.count > length else { return "" }
        return LiveTranscript.tail(text, maxCharacters: length)
    }
}
