import Foundation
import Testing
@testable import Prompter

struct LiveTranscriptTests {
    let now = Date(timeIntervalSince1970: 0)

    @Test func volatileIsReplacedAndClearedByFinal() {
        var transcript = LiveTranscript()
        transcript.apply(speaker: .me, text: "We need", isFinal: false, at: now)
        transcript.apply(speaker: .me, text: "We need to", isFinal: false, at: now)
        #expect(transcript.volatile[.me] == "We need to")
        #expect(transcript.lines.isEmpty)

        transcript.apply(speaker: .me, text: "We need to talk.", isFinal: true, at: now)
        #expect(transcript.volatile[.me] == nil)
        #expect(transcript.lines.map(\.text) == ["We need to talk."])
    }

    @Test func currentUtteranceStopsAtOtherSpeaker() {
        var transcript = LiveTranscript()
        transcript.apply(speaker: .me, text: "Old line.", isFinal: true, at: now)
        transcript.apply(speaker: .partner, text: "What about the release?", isFinal: true, at: now)
        transcript.apply(speaker: .me, text: "The release is", isFinal: true, at: now)
        transcript.apply(speaker: .me, text: "blocked by", isFinal: false, at: now)
        #expect(transcript.currentUtterance(of: .me) == "The release is blocked by")
        #expect(transcript.currentUtterance(of: .partner).isEmpty)
    }

    @Test func recentContextRendersSpeakersAndTrims() {
        var transcript = LiveTranscript()
        for index in 0..<50 {
            transcript.apply(speaker: index.isMultiple(of: 2) ? .me : .partner, text: "Line number \(index).", isFinal: true, at: now)
        }
        let context = transcript.recentContext(maxCharacters: 100)
        #expect(context.count <= 100)
        #expect(context.hasSuffix("Partner: Line number 49."))
        #expect(context.contains("Me: Line number 48."))
    }

    @Test func emptyFinalIsIgnored() {
        var transcript = LiveTranscript()
        transcript.apply(speaker: .partner, text: "  ", isFinal: true, at: now)
        #expect(transcript.lines.isEmpty)
    }

    @Test func tailDoesNotStartMidWord() {
        #expect(LiveTranscript.tail("alpha beta gamma", maxCharacters: 8) == "gamma")
        #expect(LiveTranscript.tail("short", maxCharacters: 10) == "short")
    }
}
