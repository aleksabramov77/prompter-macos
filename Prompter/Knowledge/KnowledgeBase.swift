import AppKit
import Foundation
import NaturalLanguage
import Observation
import PDFKit

/// База знаний о проекте: файлы пользователя → куски → локальные эмбеддинги → поиск по текущей реплике.
/// Всё хранится и считается на этом Mac.
@MainActor
@Observable
final class KnowledgeBase {
    private(set) var index = VectorIndex()
    private(set) var isIndexing = false
    private(set) var lastError: String?

    static let textExtensions: Set<String> = [
        "txt", "md", "markdown", "json", "csv", "yaml", "yml", "xml", "log",
        "swift", "ts", "tsx", "js", "py", "go", "java", "kt", "sql", "sh",
    ]
    static let richExtensions: Set<String> = ["rtf", "rtfd", "docx", "doc", "html", "htm", "odt"]
    static let maxFileSize = 5 * 1024 * 1024

    init() {
        if let saved = Storage.load(VectorIndex.self, from: Storage.knowledgeIndexURL) {
            index = saved
        }
    }

    func add(urls: [URL]) async {
        isIndexing = true
        lastError = nil
        defer { isIndexing = false }

        let files = urls.flatMap { Self.expand($0) }
        var failed: [String] = []
        for file in files {
            let chunks = await Task.detached(priority: .userInitiated) {
                Self.indexFile(file)
            }.value
            if let chunks, !chunks.isEmpty {
                index.replaceSource(file.path, with: chunks)
            } else {
                failed.append(file.lastPathComponent)
            }
        }
        if !failed.isEmpty {
            lastError = "Не удалось прочитать: " + failed.prefix(5).joined(separator: ", ") + (failed.count > 5 ? "…" : "")
        }
        save()
    }

    func remove(source: String) {
        index.removeSource(source)
        save()
    }

    func retrieve(_ query: String, topK: Int = 4) -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !index.chunks.isEmpty else { return [] }
        let vector = Embedder.vector(for: trimmed)
        return index.search(vector: vector, text: trimmed, topK: topK)
            .filter { $0.score > 0.2 }
            .map(\.chunk.text)
    }

    private func save() {
        do {
            try Storage.save(index, to: Storage.knowledgeIndexURL)
        } catch {
            lastError = "Не удалось сохранить базу знаний: \(error.localizedDescription)"
        }
    }

    // MARK: - Чтение файлов (вне главного потока)

    nonisolated private static func expand(_ url: URL) -> [URL] {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return [] }
        guard isDirectory.boolValue else { return isSupported(url) ? [url] : [] }
        let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )
        var result: [URL] = []
        while let next = enumerator?.nextObject() as? URL {
            if isSupported(next) { result.append(next) }
            if result.count >= 2000 { break }
        }
        return result
    }

    nonisolated private static func isSupported(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return textExtensions.contains(ext) || richExtensions.contains(ext) || ext == "pdf"
    }

    nonisolated private static func indexFile(_ url: URL) -> [IndexedChunk]? {
        guard let text = readText(url), !text.isEmpty else { return nil }
        let header = url.deletingPathExtension().lastPathComponent
        return TextChunker.chunks(of: text).map { chunk in
            IndexedChunk(source: url.path, text: chunk, vector: Embedder.vector(for: header + ". " + chunk))
        }
    }

    nonisolated private static func readText(_ url: URL) -> String? {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard size <= maxFileSize else { return nil }
        let ext = url.pathExtension.lowercased()
        if ext == "pdf" {
            return PDFDocument(url: url)?.string
        }
        if richExtensions.contains(ext) {
            return try? NSAttributedString(url: url, options: [:], documentAttributes: nil).string
        }
        return try? String(contentsOf: url, encoding: .utf8)
    }
}

/// Эмбеддинги предложений из NaturalLanguage: бесплатно и офлайн.
/// Язык выбирается по тексту, поэтому русские документы тоже индексируются;
/// разноязычные запрос и документ сводит вместе ключевая часть гибридного поиска.
enum Embedder {
    nonisolated static func vector(for text: String) -> [Float] {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        let language = recognizer.dominantLanguage ?? .english
        guard let embedding = NLEmbedding.sentenceEmbedding(for: language) ?? NLEmbedding.sentenceEmbedding(for: .english),
              let vector = embedding.vector(for: String(text.prefix(2000))) else { return [] }
        return vector.map(Float.init)
    }
}
