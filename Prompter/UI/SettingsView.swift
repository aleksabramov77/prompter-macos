import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var settings = model.settings
        Form {
            Section("Языки") {
                Picker("Я говорю на", selection: $settings.speakingLocale) {
                    ForEach(AppSettings.speakingLocales, id: \.id) { Text($0.title).tag($0.id) }
                }
                Picker("Мой родной язык", selection: $settings.nativeLanguage) {
                    ForEach(AppSettings.nativeLanguages, id: \.id) { Text($0.title).tag($0.id) }
                }
            }
            .disabled(model.isRunning)

            Section("Подсказки") {
                Picker("Модель", selection: $settings.engine) {
                    ForEach(AppSettings.Engine.allCases) { Text($0.title).tag($0) }
                }
                LabeledContent("Apple Intelligence") {
                    Text(OnDeviceSuggester.unavailableReason ?? "Доступна, работает офлайн и бесплатно")
                        .foregroundStyle(OnDeviceSuggester.isAvailable ? Color.secondary : Color.orange)
                }
                VStack(alignment: .leading) {
                    Slider(value: $settings.pauseThreshold, in: 0.8...4, step: 0.2) {
                        Text("Пауза до подсказки")
                    }
                    Text(String(format: "%.1f с тишины после незаконченной фразы", settings.pauseThreshold))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Toggle("Скрывать окно подсказок от демонстрации экрана", isOn: $settings.hideFromScreenSharing)
            }

            Section {
                Picker("Провайдер", selection: $settings.cloudProvider) {
                    ForEach(AppSettings.CloudProvider.allCases) { Text($0.title).tag($0) }
                }
                switch settings.cloudProvider {
                case .openRouter:
                    KeyField(
                        placeholder: "Ключ OpenRouter (sk-or-…)",
                        stored: settings.openRouterKey,
                        save: { settings.openRouterKey = $0 }
                    )
                    Picker("Модель", selection: $settings.openRouterModel) {
                        ForEach(OpenRouterClient.models, id: \.id) { Text($0.title).tag($0.id) }
                        if !OpenRouterClient.models.contains(where: { $0.id == settings.openRouterModel }) {
                            Text(settings.openRouterModel).tag(settings.openRouterModel)
                        }
                    }
                    TextField("Или ID любой модели с openrouter.ai/models", text: $settings.openRouterModel)
                        .font(.body.monospaced())
                case .anthropic:
                    KeyField(
                        placeholder: "API-ключ Anthropic (sk-ant-…)",
                        stored: settings.apiKey,
                        save: { settings.apiKey = $0 }
                    )
                    Picker("Модель Claude", selection: $settings.claudeModel) {
                        ForEach(ClaudeClient.models, id: \.id) { Text($0.title).tag($0.id) }
                    }
                }
            } header: {
                Text("Облачная модель (PRO+)")
            } footer: {
                Text(cloudFooter(settings.cloudProvider))
            }
        }
        .formStyle(.grouped)
    }

    private func cloudFooter(_ provider: AppSettings.CloudProvider) -> String {
        let shared = "В облако уходят описание проекта, релевантные термины глоссария, найденные фрагменты документов и последние реплики разговора."
        switch provider {
        case .openRouter:
            return "Ключ: openrouter.ai → Keys → Create Key. Claude Haiku 5.5 стоит около $0.0005 за подсказку. " + shared
        case .anthropic:
            return "Ключ: console.anthropic.com → API Keys. При отказе модели включён серверный фолбэк (fallbacks: \"default\"). " + shared
        }
    }
}

/// Поле ключа: редактируем черновик и сохраняем в Связку ключей только по кнопке.
private struct KeyField: View {
    var placeholder: String
    var stored: String
    var save: (String) -> Void
    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                SecureField(placeholder, text: $draft)
                Button("Сохранить") {
                    save(draft.trimmingCharacters(in: .whitespacesAndNewlines))
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines) == stored)
            }
            Text(stored.isEmpty ? "Ключ не задан" : "Ключ сохранён в Связке ключей")
                .font(.caption)
                .foregroundStyle(stored.isEmpty ? Color.orange : Color.secondary)
        }
        .onAppear { draft = stored }
        .onChange(of: stored) { draft = stored }
    }
}
