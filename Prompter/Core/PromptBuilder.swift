import Foundation

/// Всё, что модель знает в момент подсказки.
struct PromptContext: Equatable, Sendable {
    /// Язык, на котором пользователь говорит (например, «English»).
    var speakingLanguage: String
    /// Родной язык пользователя (например, «Russian»).
    var nativeLanguage: String
    /// Недоговорённая реплика пользователя.
    var unfinishedUtterance: String
    /// Хвост разговора «Me: … / Partner: …».
    var conversation: String
    /// Короткое описание проекта и роли пользователя (из настроек).
    var projectBrief: String
    var glossary: [GlossaryEntry]
    /// Куски из базы знаний, найденные по текущей реплике.
    var knowledge: [String]
}

enum PromptBuilder {
    static func systemPrompt(speakingLanguage: String, nativeLanguage: String) -> String {
        """
        You are a live speaking prompter for a non-native \(speakingLanguage) speaker whose native language is \(nativeLanguage). \
        They are in a live work conversation, started a sentence and got stuck: they forgot a word or lost the thread. \
        Your hints appear on their screen and they glance at them while talking, so every hint must be short and instantly usable.

        Return ONLY a JSON object, no prose, in this shape:
        {"words":[{"text":"...","score":0.0}],"phrases":["..."]}

        - "words": up to 6 single words or short collocations (1-3 words) in \(speakingLanguage) most likely to come next in their unfinished sentence. \
        "score" is relevance from 0 to 1. If the utterance contains a \(nativeLanguage) word, the speaker forgot its \(speakingLanguage) equivalent: put that translation first.
        - "phrases": up to 3 natural, spoken continuations in \(speakingLanguage), at most 20 words each, that the speaker can read aloud as is. \
        They continue the unfinished sentence (do not repeat what was already said) and, when the project context is relevant, use its facts and terminology.
        - Prefer simple, common, spoken vocabulary over rare or bookish words. Never invent project facts that are not in the context.
        """
    }

    static func userPrompt(_ context: PromptContext) -> String {
        var sections: [String] = []
        let brief = context.projectBrief.trimmingCharacters(in: .whitespacesAndNewlines)
        if !brief.isEmpty {
            sections.append("<project_brief>\n\(brief)\n</project_brief>")
        }
        if !context.glossary.isEmpty {
            let lines = context.glossary.map(\.rendered).joined(separator: "\n")
            sections.append("<glossary>\n\(lines)\n</glossary>")
        }
        if !context.knowledge.isEmpty {
            let docs = context.knowledge.enumerated()
                .map { "<document index=\"\($0.offset + 1)\">\n\($0.element)\n</document>" }
                .joined(separator: "\n")
            sections.append("<project_knowledge>\n\(docs)\n</project_knowledge>")
        }
        let conversation = context.conversation.trimmingCharacters(in: .whitespacesAndNewlines)
        if !conversation.isEmpty {
            sections.append("<conversation>\n\(conversation)\n</conversation>")
        }
        sections.append("<unfinished_utterance>\n\(context.unfinishedUtterance)\n</unfinished_utterance>")
        sections.append("Suggest how the speaker should continue the unfinished utterance.")
        return sections.joined(separator: "\n\n")
    }

    /// Укороченный промпт для локальной модели: у неё маленькое окно контекста.
    static func compactPrompt(_ context: PromptContext) -> String {
        var trimmed = context
        trimmed.conversation = LiveTranscript.tail(context.conversation, maxCharacters: 700)
        trimmed.knowledge = context.knowledge.prefix(2).map { LiveTranscript.tail($0, maxCharacters: 500) }
        trimmed.glossary = Array(context.glossary.prefix(15))
        trimmed.projectBrief = LiveTranscript.tail(context.projectBrief, maxCharacters: 400)
        return userPrompt(trimmed)
    }
}
