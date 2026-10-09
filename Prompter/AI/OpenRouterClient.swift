import Foundation

/// Клиент OpenRouter (OpenAI-совместимый Chat Completions): один ключ — доступ к моделям разных провайдеров.
struct OpenRouterClient: ChatCompleting {
    var apiKey: String
    var model: String

    /// Быстрая и дешёвая модель, которой хватает для подсказок: ~$0.0005 за подсказку.
    static let defaultModel = "anthropic/claude-haiku-5.5"
    static let models: [(id: String, title: String)] = [
        ("anthropic/claude-haiku-5.5", "Claude Haiku 5.5 — быстро и дёшево (рекомендуется)"),
        ("anthropic/claude-sonnet-5.5", "Claude Sonnet 5.5 — умнее, в ~20 раз дороже"),
        ("openai/gpt-6-luna", "GPT-6 Luna — быстро и дёшево"),
        ("google/gemini-3.8-flash", "Gemini 3.8 Flash"),
    ]

    private static let endpoint = URL(string: "https://openrouter.ai/api/v1/chat/completions")!

    var displayName: String { "OpenRouter · \(model)" }

    func complete(system: String, user: String) async throws -> String {
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "authorization")
        // Необязательные заголовки атрибуции OpenRouter: так приложение видно в их статистике.
        request.setValue("https://github.com/aleksabramov77/prompter-macos", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("Prompter", forHTTPHeaderField: "X-Title")
        request.httpBody = try Self.requestBody(model: model, system: system, user: user)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        return try Self.parseResponse(data, status: status)
    }

    static func requestBody(model: String, system: String, user: String) throws -> Data {
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "temperature": 0.3,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user],
            ],
            // Подсказка нужна за секунды: просим модель не рассуждать долго (кто не умеет — игнорирует).
            "reasoning": ["effort": "low", "exclude": true],
        ]
        return try JSONSerialization.data(withJSONObject: body)
    }

    static func parseResponse(_ data: Data, status: Int) throws -> String {
        let decoded = try? JSONDecoder().decode(Response.self, from: data)
        if let message = decoded?.error?.message {
            throw PrompterError.message("OpenRouter \(status): \(message)")
        }
        guard status == 200 else {
            throw PrompterError.message("OpenRouter \(status): \(String(data: data, encoding: .utf8) ?? "")")
        }
        guard let content = decoded?.choices?.first?.message.content, !content.isEmpty else {
            throw PrompterError.message("OpenRouter вернул пустой ответ.")
        }
        return content
    }

    private struct Response: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable { var content: String? }
            var message: Message
        }

        struct APIError: Decodable { var message: String }

        var choices: [Choice]?
        var error: APIError?
    }
}
