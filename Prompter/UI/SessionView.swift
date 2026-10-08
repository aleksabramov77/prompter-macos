import SwiftUI

struct SessionView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var settings = model.settings
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                Button {
                    model.toggleSession()
                } label: {
                    Label(model.isRunning ? "Остановить" : "Начать сессию",
                          systemImage: model.isRunning ? "stop.fill" : "mic.fill")
                        .frame(minWidth: 160)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .tint(model.isRunning ? .red : .accentColor)
                .disabled(isStarting)

                Button("Окно подсказок") { model.toggleOverlay() }
                    .controlSize(.large)

                statusText
            }

            HStack(spacing: 24) {
                Toggle("Слушать собеседника", isOn: $settings.listenToPartner)
                Toggle("Переводить собеседника", isOn: $settings.translatePartner)
                    .disabled(!settings.listenToPartner)
                Toggle("Подсказывать автоматически", isOn: $settings.autoSuggest)
            }
            .disabled(model.isRunning)

            if model.isRunning {
                HStack(spacing: 24) {
                    LevelMeter(title: "Я", level: model.micLevel)
                    if settings.listenToPartner {
                        LevelMeter(title: "Собеседник", level: model.partnerLevel)
                    }
                }
            }

            ForEach(model.warnings, id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .font(.callout)
            }

            GroupBox("Расшифровка") {
                TranscriptList(transcript: model.transcript, translations: model.partnerTranslations)
                    .frame(maxWidth: .infinity, minHeight: 200, maxHeight: .infinity)
            }

            Text("Совет: в наушниках Суфлёр не путает ваш голос с голосом собеседника. Горячая клавиша ⌥⌘Space — подсказать сейчас.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
    }

    private var isStarting: Bool {
        if case .starting = model.status { return true }
        return false
    }

    @ViewBuilder
    private var statusText: some View {
        switch model.status {
        case .idle:
            Text("Готов к работе").foregroundStyle(.secondary)
        case .starting(let message):
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text(message).foregroundStyle(.secondary)
            }
        case .running:
            Text("Идёт сессия").foregroundStyle(.green)
        case .failed(let message):
            Text(message).foregroundStyle(.red).lineLimit(3)
        }
    }
}

struct LevelMeter: View {
    var title: String
    var level: Float

    var body: some View {
        HStack(spacing: 8) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            ProgressView(value: Double(max(0, min(1, (level + 60) / 60))))
                .frame(width: 120)
        }
    }
}

struct TranscriptList: View {
    var transcript: LiveTranscript
    var translations: [UUID: String]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(transcript.lines) { line in
                        row(speaker: line.speaker, text: line.text, translation: translations[line.id])
                    }
                    ForEach([Speaker.partner, .me], id: \.self) { speaker in
                        if let pending = transcript.volatile[speaker] {
                            row(speaker: speaker, text: pending, translation: nil)
                                .opacity(0.6)
                        }
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: transcript) {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }

    private func row(speaker: Speaker, text: String, translation: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(speaker == .me ? "Я" : "Собеседник")
                .font(.caption.weight(.semibold))
                .foregroundStyle(speaker == .me ? Color.accentColor : .secondary)
            Text(text).textSelection(.enabled)
            if let translation {
                Text(translation).foregroundStyle(.secondary).textSelection(.enabled)
            }
        }
    }
}
