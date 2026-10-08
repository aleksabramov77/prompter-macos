import Foundation
import Translation

/// Перевод реплик собеседника на родной язык через встроенный переводчик macOS (офлайн).
@MainActor
final class SubtitleTranslator {
    private let session: TranslationSession

    private init(session: TranslationSession) {
        self.session = session
    }

    /// Возвращает переводчик или текст, почему перевод недоступен.
    static func make(from source: String, to target: String) async -> (translator: SubtitleTranslator?, problem: String?) {
        let sourceLanguage = Locale.Language(identifier: source)
        let targetLanguage = Locale.Language(identifier: target)
        if sourceLanguage.languageCode == targetLanguage.languageCode {
            return (nil, nil)
        }
        let status = await LanguageAvailability().status(from: sourceLanguage, to: targetLanguage)
        switch status {
        case .installed:
            return (SubtitleTranslator(session: TranslationSession(installedSource: sourceLanguage, target: targetLanguage)), nil)
        case .supported:
            return (nil, "Чтобы переводить собеседника, скачайте языки: Системные настройки → Основные → Язык и регион → Языки перевода.")
        default:
            return (nil, "Перевод для этой пары языков не поддерживается.")
        }
    }

    func translate(_ text: String) async -> String? {
        try? await session.translate(text).targetText
    }
}
