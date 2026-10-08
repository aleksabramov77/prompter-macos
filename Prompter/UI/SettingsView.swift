import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var keyDraft = ""
    @State private var keySaved = false

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
                HStack {
                    SecureField("API-ключ (sk-ant-…)", text: $keyDraft)
                    Button("Сохранить") {
                        settings.apiKey = keyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        keySaved = true
                    }
                    .disabled(keyDraft == settings.apiKey)
                }
                if keySaved || !settings.apiKey.isEmpty {
                    Text(settings.apiKey.isEmpty ? "Ключ удалён" : "Ключ сохранён в Связке ключей")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Picker("Модель Claude", selection: $settings.claudeModel) {
                    ForEach(ClaudeClient.models, id: \.id) { Text($0.title).tag($0.id) }
                }
            } header: {
                Text("Claude (PRO+)")
            } footer: {
                Text("Ключ берётся на console.anthropic.com. Claude получает описание проекта, глоссарий, найденные фрагменты документов и последние реплики разговора. При отказе модели включён серверный фолбэк (fallbacks: \"default\").")
            }
        }
        .formStyle(.grouped)
        .onAppear { keyDraft = model.settings.apiKey }
    }
}
