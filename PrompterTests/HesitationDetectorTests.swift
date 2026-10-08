import Foundation
import Testing
@testable import Prompter

struct HesitationDetectorTests {
    let t0 = Date(timeIntervalSince1970: 1_000)

    @Test func pauseAfterUnfinishedSentenceTriggers() {
        var detector = HesitationDetector()
        detector.speechUpdated("We need to move the", at: t0)
        #expect(detector.check(now: t0.addingTimeInterval(1.0), isVoiceActive: false) == nil)
        #expect(detector.check(now: t0.addingTimeInterval(1.7), isVoiceActive: false) == .pause)
    }

    @Test func pauseAfterFinishedSentenceDoesNotTrigger() {
        var detector = HesitationDetector()
        detector.speechUpdated("We shipped it yesterday.", at: t0)
        #expect(detector.check(now: t0.addingTimeInterval(5), isVoiceActive: false) == nil)
    }

    @Test func noTriggerWhileStillMakingSound() {
        var detector = HesitationDetector()
        detector.speechUpdated("So the main problem is", at: t0)
        #expect(detector.check(now: t0.addingTimeInterval(3), isVoiceActive: true) == nil)
    }

    @Test func fillerTriggersQuickly() {
        var detector = HesitationDetector()
        detector.speechUpdated("The main issue is, um", at: t0)
        #expect(detector.check(now: t0.addingTimeInterval(0.6), isVoiceActive: true) == .filler)
    }

    @Test func russianFillerTriggers() {
        var detector = HesitationDetector()
        detector.speechUpdated("We should эээ", at: t0)
        #expect(detector.check(now: t0.addingTimeInterval(0.6), isVoiceActive: false) == .filler)
    }

    @Test func firesOncePerPauseAndRespectsCooldown() {
        var detector = HesitationDetector()
        detector.speechUpdated("I think that", at: t0)
        #expect(detector.check(now: t0.addingTimeInterval(2), isVoiceActive: false) == .pause)
        #expect(detector.check(now: t0.addingTimeInterval(3), isVoiceActive: false) == nil)

        // Новая незаконченная фраза, но кулдаун (4 с) ещё не прошёл.
        detector.speechUpdated("I think that we", at: t0.addingTimeInterval(3))
        #expect(detector.check(now: t0.addingTimeInterval(5), isVoiceActive: false) == nil)
        #expect(detector.check(now: t0.addingTimeInterval(6.5), isVoiceActive: false) == .pause)
    }

    @Test func emptyTextNeverTriggers() {
        var detector = HesitationDetector()
        detector.speechUpdated("   ", at: t0)
        #expect(detector.check(now: t0.addingTimeInterval(10), isVoiceActive: false) == nil)
    }

    @Test func manualTriggerStartsCooldown() {
        var detector = HesitationDetector()
        detector.speechUpdated("Let me", at: t0)
        detector.registerManualTrigger(at: t0.addingTimeInterval(0.5))
        #expect(detector.check(now: t0.addingTimeInterval(2), isVoiceActive: false) == nil)
    }

    @Test func sentenceAndFillerHelpers() {
        #expect(HesitationDetector.endsSentence("Done!"))
        #expect(HesitationDetector.endsSentence("Really?  "))
        #expect(!HesitationDetector.endsSentence("and then"))
        #expect(HesitationDetector.endsWithFiller("so, uh..."))
        #expect(!HesitationDetector.endsWithFiller("umbrella"))
    }
}
