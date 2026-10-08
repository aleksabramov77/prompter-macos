import Foundation
import Testing
@testable import Prompter

struct SuggestionParserTests {
    @Test func parsesScoredJSONInsideFence() {
        let raw = """
        Here you go:
        ```json
        {"words":[{"text":"deadline","score":0.4},{"text":"release","score":0.9}],"phrases":["is blocked by the billing migration"]}
        ```
        """
        let result = SuggestionParser.parse(raw)
        #expect(result.words.map(\.text) == ["release", "deadline"])
        #expect(result.phrases == ["is blocked by the billing migration"])
    }

    @Test func plainStringWordsGetRankScores() {
        let result = SuggestionParser.parse(#"{"words":["first","second","third"],"phrases":[]}"#)
        #expect(result.words.map(\.text) == ["first", "second", "third"])
        #expect(result.words[0].score > result.words[2].score)
        #expect(result.words[0].score == 1)
    }

    @Test func clampsDedupesAndLimits() {
        let words = (0..<20).map { #"{"text":"w\#($0)","score":\#(Double($0) / 10)}"# }.joined(separator: ",")
        let raw = #"{"words":[\#(words),{"text":"W19","score":5}],"phrases":["a","A","b","c","d"]}"#
        let result = SuggestionParser.parse(raw)
        #expect(result.words.count == Suggestions.maxWords)
        #expect(result.words.allSatisfy { (0...1).contains($0.score) })
        #expect(result.phrases == ["a", "b", "c"])
    }

    @Test func fallsBackToBulletLines() {
        let result = SuggestionParser.parse("- we could postpone it\n• or ship it behind a flag\nnot a bullet")
        #expect(result.words.isEmpty)
        #expect(result.phrases == ["we could postpone it", "or ship it behind a flag"])
    }

    @Test func garbageGivesEmpty() {
        #expect(SuggestionParser.parse("sorry, no idea").isEmpty)
    }
}

struct PromptBuilderTests {
    func context(brief: String = "", glossary: [GlossaryEntry] = [], knowledge: [String] = []) -> PromptContext {
        PromptContext(
            speakingLanguage: "English",
            nativeLanguage: "Russian",
            unfinishedUtterance: "The main risk is",
            conversation: "Partner: What worries you?",
            projectBrief: brief,
            glossary: glossary,
            knowledge: knowledge
        )
    }

    @Test func includesOnlyNonEmptySections() {
        let prompt = PromptBuilder.userPrompt(context())
        #expect(!prompt.contains("<project_brief>"))
        #expect(!prompt.contains("<glossary>"))
        #expect(!prompt.contains("<project_knowledge>"))
        #expect(prompt.contains("<unfinished_utterance>\nThe main risk is\n</unfinished_utterance>"))
        #expect(prompt.contains("Partner: What worries you?"))
    }

    @Test func rendersKnowledgeAndGlossary() {
        let prompt = PromptBuilder.userPrompt(context(
            brief: "Payments team lead",
            glossary: [GlossaryEntry(term: "выкатка", translation: "rollout")],
            knowledge: ["Doc one", "Doc two"]
        ))
        #expect(prompt.contains("<project_brief>\nPayments team lead\n</project_brief>"))
        #expect(prompt.contains("выкатка = rollout"))
        #expect(prompt.contains("<document index=\"2\">\nDoc two\n</document>"))
    }

    @Test func systemPromptMentionsLanguagesAndJSON() {
        let system = PromptBuilder.systemPrompt(speakingLanguage: "English", nativeLanguage: "Russian")
        #expect(system.contains("native language is Russian"))
        #expect(system.contains("\"phrases\""))
    }

    @Test func compactPromptLimitsKnowledge() {
        let prompt = PromptBuilder.compactPrompt(context(knowledge: ["a", "b", "c"]))
        #expect(prompt.contains("index=\"2\""))
        #expect(!prompt.contains("index=\"3\""))
    }
}

struct SessionRecordTests {
    @Test func wordsToReviewOrderedByFrequency() {
        let date = Date(timeIntervalSince1970: 0)
        var session = SessionRecord(startedAt: date)
        session.stuck = [
            StuckMoment(date: date, utterance: "a", words: ["rollout", "deadline"], phrases: []),
            StuckMoment(date: date, utterance: "b", words: ["Deadline", "budget"], phrases: ["x"]),
        ]
        #expect(session.wordsToReview == ["deadline", "rollout", "budget"])
        let markdown = SessionExporter.markdown(session)
        #expect(markdown.contains("## Слова на повторение"))
        #expect(markdown.contains("- rollout"))
        #expect(markdown.contains("> b"))
    }
}
