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
            case .auto: "Авто: локально + Claude"
            case .onDevice: "Только на устройстве"
            case .claude: "Только Claude"
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
    var projectBrief: String { didSet { defaults.set(projectBrief, forKey: "projectBrief") } }
    var glossaryText: String { didSet { defaults.set(glossaryText, forKey: "glossaryText") } }

    var apiKey: String {
        didSet { KeychainStore.write(apiKey, for: Self.apiKeyAccount) }
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
        apiKey = KeychainStore.read(Self.apiKeyAccount) ?? ""
    }

    /// Название языка по-английски для промпта: «English», «Russian».
    static func englishName(of identifier: String) -> String {
        let code = Locale(identifier: identifier).language.languageCode?.identifier ?? identifier
        return Locale(identifier: "en_US").localizedString(forLanguageCode: code) ?? identifier
    }
}
