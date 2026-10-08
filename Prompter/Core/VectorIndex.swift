import Foundation

struct IndexedChunk: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    /// Путь или имя файла, из которого взят кусок.
    var source: String
    var text: String
    var vector: [Float]
}

/// Локальная векторная база знаний (RAG). Поиск гибридный: косинусная близость эмбеддингов
/// плюс доля совпавших слов — помогает, когда документ на русском, а речь на английском, и наоборот.
struct VectorIndex: Codable, Equatable, Sendable {
    var chunks: [IndexedChunk] = []

    var sources: [String] {
        var seen = Set<String>()
        return chunks.map(\.source).filter { seen.insert($0).inserted }
    }

    func chunkCount(for source: String) -> Int {
        chunks.filter { $0.source == source }.count
    }

    mutating func replaceSource(_ source: String, with newChunks: [IndexedChunk]) {
        removeSource(source)
        chunks.append(contentsOf: newChunks)
    }

    mutating func removeSource(_ source: String) {
        chunks.removeAll { $0.source == source }
    }

    func search(vector query: [Float], text queryText: String, topK: Int) -> [(chunk: IndexedChunk, score: Double)] {
        guard topK > 0 else { return [] }
        let queryWords = Set(Glossary.tokens(queryText).filter { $0.count >= 4 })
        let scored = chunks.map { chunk -> (chunk: IndexedChunk, score: Double) in
            let semantic = Self.cosine(query, chunk.vector)
            let keyword = Self.keywordScore(queryWords: queryWords, text: chunk.text)
            return (chunk, 0.75 * semantic + 0.25 * keyword)
        }
        return scored
            .filter { $0.score > 0 }
            .sorted { $0.score > $1.score }
            .prefix(topK)
            .map { $0 }
    }

    static func cosine(_ a: [Float], _ b: [Float]) -> Double {
        guard !a.isEmpty, a.count == b.count else { return 0 }
        var dot: Double = 0, normA: Double = 0, normB: Double = 0
        for i in a.indices {
            let x = Double(a[i]), y = Double(b[i])
            dot += x * y
            normA += x * x
            normB += y * y
        }
        guard normA > 0, normB > 0 else { return 0 }
        return dot / (normA.squareRoot() * normB.squareRoot())
    }

    static func keywordScore(queryWords: Set<String>, text: String) -> Double {
        guard !queryWords.isEmpty else { return 0 }
        let textWords = Set(Glossary.tokens(text))
        let hits = queryWords.filter { textWords.contains($0) }.count
        return Double(hits) / Double(queryWords.count)
    }
}
