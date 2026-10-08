import Foundation
import Testing
@testable import Prompter

struct TextChunkerTests {
    @Test func shortTextIsSingleChunk() {
        #expect(TextChunker.chunks(of: "Hello world.") == ["Hello world."])
    }

    @Test func emptyTextHasNoChunks() {
        #expect(TextChunker.chunks(of: "\n\n  \n").isEmpty)
    }

    @Test func paragraphsAreGroupedUpToTargetSize() {
        let paragraph = String(repeating: "word ", count: 30).trimmingCharacters(in: .whitespaces) // 149 символов
        let text = Array(repeating: paragraph, count: 10).joined(separator: "\n\n")
        let chunks = TextChunker.chunks(of: text, targetSize: 400, overlap: 0)
        #expect(chunks.count > 1)
        #expect(chunks.allSatisfy { $0.count <= 400 })
        #expect(chunks.joined(separator: "\n").components(separatedBy: "word").count - 1 == 300)
    }

    @Test func longParagraphIsSplitBySentences() {
        let sentence = "The deployment pipeline failed because of a missing secret."
        let text = Array(repeating: sentence, count: 40).joined(separator: " ")
        let chunks = TextChunker.chunks(of: text, targetSize: 300, overlap: 0)
        #expect(chunks.count >= 8)
        #expect(chunks.allSatisfy { $0.count <= 300 })
    }

    @Test func overlapCarriesTailIntoNextChunk() {
        let first = String(repeating: "alpha ", count: 40).trimmingCharacters(in: .whitespaces)
        let second = String(repeating: "beta ", count: 40).trimmingCharacters(in: .whitespaces)
        let chunks = TextChunker.chunks(of: first + "\n\n" + second, targetSize: 300, overlap: 30)
        #expect(chunks.count == 2)
        #expect(chunks[1].hasPrefix("alpha"))
        #expect(chunks[1].hasSuffix("beta"))
    }

    @Test func giantSentenceIsSplitByWords() {
        let text = String(repeating: "x", count: 50) + " " + Array(repeating: "token", count: 200).joined(separator: " ")
        let chunks = TextChunker.chunks(of: text, targetSize: 200, overlap: 0)
        #expect(chunks.allSatisfy { $0.count <= 200 })
    }
}

struct VectorIndexTests {
    @Test func cosineBasics() {
        #expect(abs(VectorIndex.cosine([1, 0], [1, 0]) - 1) < 1e-9)
        #expect(abs(VectorIndex.cosine([1, 0], [0, 1])) < 1e-9)
        #expect(VectorIndex.cosine([1, 0], [1, 0, 0]) == 0)
        #expect(VectorIndex.cosine([], []) == 0)
    }

    @Test func searchRanksBySimilarityAndKeywords() {
        var index = VectorIndex()
        index.replaceSource("a.md", with: [
            IndexedChunk(source: "a.md", text: "Billing service migration to Postgres", vector: [1, 0, 0]),
            IndexedChunk(source: "a.md", text: "Team offsite in March", vector: [0, 1, 0]),
        ])
        index.replaceSource("b.md", with: [
            IndexedChunk(source: "b.md", text: "Postgres replication lag alerts", vector: [0.7, 0.7, 0]),
        ])
        let results = index.search(vector: [1, 0, 0], text: "the postgres migration", topK: 2)
        #expect(results.map(\.chunk.text) == ["Billing service migration to Postgres", "Postgres replication lag alerts"])
    }

    @Test func replaceAndRemoveSource() {
        var index = VectorIndex()
        index.replaceSource("a", with: [IndexedChunk(source: "a", text: "one", vector: [1])])
        index.replaceSource("a", with: [IndexedChunk(source: "a", text: "two", vector: [1])])
        index.replaceSource("b", with: [IndexedChunk(source: "b", text: "three", vector: [1])])
        #expect(index.sources == ["a", "b"])
        #expect(index.chunks.map(\.text) == ["two", "three"])
        index.removeSource("a")
        #expect(index.sources == ["b"])
    }

    @Test func keywordOnlyMatchWorksWithoutVectors() {
        var index = VectorIndex()
        index.replaceSource("ru.md", with: [IndexedChunk(source: "ru.md", text: "Kubernetes кластер падает ночью", vector: [])])
        let results = index.search(vector: [1, 0], text: "kubernetes cluster", topK: 3)
        #expect(results.count == 1)
    }

    @Test func roundTripsThroughJSON() throws {
        var index = VectorIndex()
        index.replaceSource("a", with: [IndexedChunk(source: "a", text: "x", vector: [0.5, -1])])
        let data = try JSONEncoder().encode(index)
        #expect(try JSONDecoder().decode(VectorIndex.self, from: data) == index)
    }
}

struct GlossaryTests {
    @Test func parsesSeparatorsAndSkipsComments() {
        let text = """
        # мой глоссарий
        дедлайн = deadline
        выкатка — rollout
        on-call\tдежурство
        standalone

        дедлайн = deadline
        """
        let entries = Glossary.parse(text)
        #expect(entries.map(\.term) == ["дедлайн", "выкатка", "on-call", "standalone"])
        #expect(entries.map(\.translation) == ["deadline", "rollout", "дежурство", ""])
    }

    @Test func hyphenatedTermIsNotSplit() {
        let entries = Glossary.parse("on-call = дежурство")
        #expect(entries.first?.term == "on-call")
    }

    @Test func relevantEntriesComeFirst() {
        let entries = Glossary.parse("alpha = один\nrollout = выкатка\nbeta = два")
        let relevant = Glossary.relevant(entries, to: "the rollout is late", limit: 2)
        #expect(relevant.map(\.term) == ["rollout", "alpha"])
    }
}
