import Foundation
import Testing
@testable import Prompter

struct OpenRouterClientTests {
    @Test func requestBodyHasSystemAndUserMessages() throws {
        let data = try OpenRouterClient.requestBody(model: "anthropic/claude-haiku-5.5", system: "SYS", user: "USR")
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["model"] as? String == "anthropic/claude-haiku-5.5")
        let messages = try #require(json["messages"] as? [[String: String]])
        #expect(messages == [["role": "system", "content": "SYS"], ["role": "user", "content": "USR"]])
        #expect((json["reasoning"] as? [String: Any])?["effort"] as? String == "low")
    }

    @Test func parsesAssistantContent() throws {
        let data = Data(#"{"id":"gen-1","choices":[{"index":0,"message":{"role":"assistant","content":"{\"words\":[\"rollout\"]}"}}]}"#.utf8)
        #expect(try OpenRouterClient.parseResponse(data, status: 200) == #"{"words":["rollout"]}"#)
    }

    @Test func surfacesAPIErrorMessage() {
        let data = Data(#"{"error":{"code":401,"message":"No auth credentials found"}}"#.utf8)
        #expect(throws: PrompterError.self) { try OpenRouterClient.parseResponse(data, status: 401) }
        do {
            _ = try OpenRouterClient.parseResponse(data, status: 401)
        } catch {
            #expect(error.localizedDescription == "OpenRouter 401: No auth credentials found")
        }
    }

    @Test func emptyContentIsAnError() {
        let data = Data(#"{"choices":[{"message":{"role":"assistant","content":""}}]}"#.utf8)
        #expect(throws: PrompterError.self) { try OpenRouterClient.parseResponse(data, status: 200) }
    }
}
