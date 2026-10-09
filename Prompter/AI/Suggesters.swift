import Foundation
import FoundationModels

protocol Suggester: Sendable {
    var name: String { get }
    func suggest(_ context: PromptContext) async throws -> Suggestions
}

/// Бесплатная локальная модель Apple Intelligence: быстрые слова без сети.
struct OnDeviceSuggester: Suggester {
    var name: String { "Apple Intelligence (на устройстве)" }

    @Generable
    struct Output {
        @Guide(description: "Single words or 1-3 word collocations most likely to come next, most relevant first", .maximumCount(6))
        var words: [String]
        @Guide(description: "Short spoken continuations of the unfinished sentence, at most 20 words each", .maximumCount(3))
        var phrases: [String]
    }

    static var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    static var unavailableReason: String? {
        switch SystemLanguageModel.default.availability {
        case .available:
            return nil
        case .unavailable(.deviceNotEligible):
            return "Этот Mac не поддерживает Apple Intelligence."
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Включите Apple Intelligence в Системных настройках."
        case .unavailable(.modelNotReady):
            return "Модель Apple Intelligence не загружена. Если в System Settings нет раздела «Apple Intelligence & Siri», в вашем регионе она недоступна — используйте облачную модель."
        case .unavailable:
            return "Локальная модель недоступна."
        }
    }

    func suggest(_ context: PromptContext) async throws -> Suggestions {
        let session = LanguageModelSession(
            instructions: PromptBuilder.systemPrompt(
                speakingLanguage: context.speakingLanguage,
                nativeLanguage: context.nativeLanguage
            )
        )
        let response = try await session.respond(
            to: PromptBuilder.compactPrompt(context),
            generating: Output.self,
            options: GenerationOptions(temperature: 0.3)
        )
        return Suggestions.ranked(words: response.content.words, phrases: response.content.phrases)
    }
}

/// Облачная модель, которой отдаём системный и пользовательский промпт целиком.
protocol ChatCompleting: Sendable {
    var displayName: String { get }
    func complete(system: String, user: String) async throws -> String
}

/// Облачная модель (Claude напрямую или через OpenRouter) с полным контекстом проекта (RAG):
/// точнее локальной, но нужен ключ и сеть.
struct CloudSuggester: Suggester {
    var client: any ChatCompleting

    var name: String { client.displayName }

    func suggest(_ context: PromptContext) async throws -> Suggestions {
        let raw = try await client.complete(
            system: PromptBuilder.systemPrompt(
                speakingLanguage: context.speakingLanguage,
                nativeLanguage: context.nativeLanguage
            ),
            user: PromptBuilder.userPrompt(context)
        )
        let parsed = SuggestionParser.parse(raw)
        if parsed.isEmpty {
            throw PrompterError.message("Модель вернула ответ в неожиданном формате.")
        }
        return parsed
    }
}
