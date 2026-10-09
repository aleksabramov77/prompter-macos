import Foundation
import Observation

/// Настройки пользователя. Всё, кроме API-ключа, — в UserDefaults; ключ — в Связке ключей.
@MainActor
@Observable
final class AppSettings {
    enum Engine: String, CaseIterable, Identifiable {
        /// Локальная модель отвечает сразу, Claude уточняет, если есть ключ.
        case auto
        case onDevice
        case claude

        var id: String { rawValue }

        var title: String {
            switch self {
            case .auto: "Авто: локально + облако"
            case .onDevice: "Только на устройстве"
            case .claude: "Только облако"
            }
        }
    }

    /// Через кого ходим в облачную модель.
    enum CloudProvider: String, CaseIterable, Identifiable {
        case openRouter
        case anthropic

        var id: String { rawValue }

        var title: String {
            switch self {
            case .openRouter: "OpenRouter"
            case .anthropic: "Anthropic (Claude напрямую)"
            }
        }
    }

    static let speakingLocales: [(id: String, title: String)] = [
        ("en-US", "Английский (США)"),
        ("en-GB", "Английский (Великобритания)"),
        ("de-DE", "Немецкий"),
        ("fr-FR", "Французский"),
        ("es-ES", "Испанский"),
        ("it-IT", "Итальянский"),
        ("pt-BR", "Португальский (Бразилия)"),
    ]

    static let nativeLanguages: [(id: String, title: String)] = [
        ("ru", "Русский"),
        ("uk", "Украинский"),
        ("en", "Английский"),
        ("de", "Немецкий"),
        ("es", "Испанский"),
    ]

    private static let apiKeyAccount = "claude-api-key"
    private static let openRouterKeyAccount = "openrouter-api-key"
    private let defaults = UserDefaults.standard

    var speakingLocale: String { didSet { defaults.set(speakingLocale, forKey: "speakingLocale") } }
    var nativeLanguage: String { didSet { defaults.set(nativeLanguage, forKey: "nativeLanguage") } }
    var listenToPartner: Bool { didSet { defaults.set(listenToPartner, forKey: "listenToPartner") } }
    var translatePartner: Bool { didSet { defaults.set(translatePartner, forKey: "translatePartner") } }
    var autoSuggest: Bool { didSet { defaults.set(autoSuggest, forKey: "autoSuggest") } }
    var pauseThreshold: Double { didSet { defaults.set(pauseThreshold, forKey: "pauseThreshold") } }
    var hideFromScreenSharing: Bool { didSet { defaults.set(hideFromScreenSharing, forKey: "hideFromScreenSharing") } }
    var engine: Engine { didSet { defaults.set(engine.rawValue, forKey: "engine") } }
    var claudeModel: String { didSet { defaults.set(claudeModel, forKey: "claudeModel") } }
    var cloudProvider: CloudProvider { didSet { defaults.set(cloudProvider.rawValue, forKey: "cloudProvider") } }
    var openRouterModel: String { didSet { defaults.set(openRouterModel, forKey: "openRouterModel") } }
    var projectBrief: String { didSet { defaults.set(projectBrief, forKey: "projectBrief") } }
    var glossaryText: String { didSet { defaults.set(glossaryText, forKey: "glossaryText") } }

    var apiKey: String {
        didSet { KeychainStore.write(apiKey, for: Self.apiKeyAccount) }
    }

    var openRouterKey: String {
        didSet { KeychainStore.write(openRouterKey, for: Self.openRouterKeyAccount) }
    }

    init() {
        defaults.register(defaults: [
            "speakingLocale": "en-US",
            "nativeLanguage": "ru",
            "listenToPartner": true,
            "translatePartner": true,
            "autoSuggest": true,
            "pauseThreshold": 1.6,
            "hideFromScreenSharing": true,
            "engine": Engine.auto.rawValue,
            "claudeModel": ClaudeClient.defaultModel,
            "cloudProvider": CloudProvider.openRouter.rawValue,
            "openRouterModel": OpenRouterClient.defaultModel,
            "projectBrief": "",
            "glossaryText": "",
        ])
        speakingLocale = defaults.string(forKey: "speakingLocale") ?? "en-US"
        nativeLanguage = defaults.string(forKey: "nativeLanguage") ?? "ru"
        listenToPartner = defaults.bool(forKey: "listenToPartner")
        translatePartner = defaults.bool(forKey: "translatePartner")
        autoSuggest = defaults.bool(forKey: "autoSuggest")
        pauseThreshold = defaults.double(forKey: "pauseThreshold")
        hideFromScreenSharing = defaults.bool(forKey: "hideFromScreenSharing")
        engine = Engine(rawValue: defaults.string(forKey: "engine") ?? "") ?? .auto
        claudeModel = defaults.string(forKey: "claudeModel") ?? ClaudeClient.defaultModel
        projectBrief = defaults.string(forKey: "projectBrief") ?? ""
        glossaryText = defaults.string(forKey: "glossaryText") ?? ""
        cloudProvider = CloudProvider(rawValue: defaults.string(forKey: "cloudProvider") ?? "") ?? .openRouter
        openRouterModel = defaults.string(forKey: "openRouterModel") ?? OpenRouterClient.defaultModel
        apiKey = KeychainStore.read(Self.apiKeyAccount) ?? ""
        openRouterKey = KeychainStore.read(Self.openRouterKeyAccount) ?? ""
    }

    /// Облачная модель по выбранному провайдеру или nil, если для него нет ключа.
    func cloudClient() -> (any ChatCompleting)? {
        switch cloudProvider {
        case .openRouter:
            let key = openRouterKey.trimmingCharacters(in: .whitespacesAndNewlines)
            let model = openRouterModel.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { return nil }
            return OpenRouterClient(apiKey: key, model: model.isEmpty ? OpenRouterClient.defaultModel : model)
        case .anthropic:
            let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { return nil }
            return ClaudeClient(apiKey: key, model: claudeModel)
        }
    }

    /// Название языка по-английски для промпта: «English», «Russian».
    static func englishName(of identifier: String) -> String {
        let code = Locale(identifier: identifier).language.languageCode?.identifier ?? identifier
        return Locale(identifier: "en_US").localizedString(forLanguageCode: code) ?? identifier
    }
}
