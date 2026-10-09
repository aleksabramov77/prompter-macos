import Foundation

/// Минимальный клиент Claude Messages API поверх URLSession (официального Swift SDK нет).
struct ClaudeClient: ChatCompleting {
    var apiKey: String
    var model: String

    static let defaultModel = "claude-opus-5-5"
    static let models: [(id: String, title: String)] = [
        ("claude-opus-5-5", "Claude Opus 5.5 — лучшее качество"),
        ("claude-sonnet-5-5", "Claude Sonnet 5.5 — баланс"),
        ("claude-haiku-5-5", "Claude Haiku 5.5 — быстрее и дешевле"),
    ]

    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    /// Модели, которые принимают серверный фолбэк при отказе классификаторов безопасности.
    private static let fallbackModels: Set<String> = ["claude-opus-5-5", "claude-sonnet-5-5", "claude-opus-5", "claude-fable-5-1"]

    var displayName: String { model }

    func complete(system: String, user: String) async throws -> String {
        try await complete(system: system, user: user, maxTokens: 2048)
    }

    func complete(system: String, user: String, maxTokens: Int) async throws -> String {
        var body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "system": system,
            "messages": [["role": "user", "content": user]],
            // Подсказка нужна за секунды, глубокие рассуждения не нужны.
            "output_config": ["effort": "low"],
        ]
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        if Self.fallbackModels.contains(model) {
            body["fallbacks"] = "default"
            request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            let apiError = try? JSONDecoder().decode(ErrorEnvelope.self, from: data)
            let detail = apiError?.error.message ?? String(data: data, encoding: .utf8) ?? ""
            throw PrompterError.message("Claude API \(status): \(detail)")
        }

        let message = try JSONDecoder().decode(MessageResponse.self, from: data)
        if message.stopReason == "refusal" {
            throw PrompterError.message("Claude отказался отвечать на этот запрос.")
        }
        return message.content
            .filter { $0.type == "text" }
            .compactMap(\.text)
            .joined()
    }

    private struct MessageResponse: Decodable {
        struct Block: Decodable {
            var type: String
            var text: String?
        }

        var content: [Block]
        var stopReason: String?

        enum CodingKeys: String, CodingKey {
            case content
            case stopReason = "stop_reason"
        }
    }

    private struct ErrorEnvelope: Decodable {
        struct Detail: Decodable { var message: String }
        var error: Detail
    }
}
