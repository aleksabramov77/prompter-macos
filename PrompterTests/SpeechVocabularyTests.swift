import Testing
@testable import Prompter

struct SpeechVocabularyTests {
    @Test func takesLatinSidesWithoutDuplicates() {
        let entries = Glossary.parse("""
        выкатка = rollout
        on-call = дежурство
        дедлайн = Deadline
        срок = deadline
        Kubernetes
        только русский = тоже русский
        """)
        #expect(SpeechVocabulary.contextualStrings(from: entries) == ["rollout", "on-call", "Deadline", "Kubernetes"])
    }

    @Test func respectsLimit() {
        let entries = (0..<10).map { GlossaryEntry(term: "term\($0)", translation: "") }
        #expect(SpeechVocabulary.contextualStrings(from: entries, limit: 3) == ["term0", "term1", "term2"])
    }

    @Test func latinDetection() {
        #expect(SpeechVocabulary.isLatin("CI/CD pipeline"))
        #expect(!SpeechVocabulary.isLatin("выкатка"))
        #expect(!SpeechVocabulary.isLatin("API шлюз"))
        #expect(!SpeechVocabulary.isLatin("2026"))
    }
}
