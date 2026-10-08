import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Прошлые сессии: где я запнулся и какие слова стоит повторить.
struct HistoryView: View {
    @Environment(AppModel.self) private var model
    @State private var selection: SessionRecord.ID?

    var body: some View {
        NavigationSplitView {
            List(model.sessions, selection: $selection) { session in
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.title)
                    Text("Запинок: \(session.stuck.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .contextMenu {
                    Button("Удалить", role: .destructive) { model.delete(session) }
                }
            }
            .overlay {
                if model.sessions.isEmpty {
                    Text("Здесь появятся прошедшие сессии.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        } detail: {
            if let session = model.sessions.first(where: { $0.id == selection }) {
                SessionDetail(session: session)
            } else {
                Text("Выберите сессию").foregroundStyle(.secondary)
            }
        }
    }
}

private struct SessionDetail: View {
    @Environment(AppModel.self) private var model
    var session: SessionRecord

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(session.title).font(.title2.weight(.semibold))
                    Spacer()
                    Button("Скопировать Markdown") {
                        model.copyToClipboard(SessionExporter.markdown(session))
                    }
                    Button("Сохранить…") { export() }
                }

                if !session.wordsToReview.isEmpty {
                    Text("Слова на повторение").font(.headline)
                    FlowLayout(spacing: 8, lineSpacing: 6) {
                        ForEach(session.wordsToReview, id: \.self) { word in
                            Text(word)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(.quaternary, in: .capsule)
                        }
                    }
                }

                if !session.stuck.isEmpty {
                    Text("Где я запнулся").font(.headline)
                    ForEach(session.stuck) { moment in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(moment.utterance.isEmpty ? "(в начале фразы)" : moment.utterance)
                                .italic()
                            if !moment.words.isEmpty {
                                Text(moment.words.joined(separator: " · "))
                                    .foregroundStyle(Color.accentColor)
                            }
                            ForEach(moment.phrases, id: \.self) { phrase in
                                Text("… " + phrase).foregroundStyle(.secondary)
                            }
                        }
                        .textSelection(.enabled)
                        Divider()
                    }
                }

                if !session.transcript.isEmpty {
                    Text("Расшифровка").font(.headline)
                    ForEach(session.transcript) { line in
                        Text((line.speaker == .me ? "Я: " : "Собеседник: ") + line.text)
                            .textSelection(.enabled)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func export() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.nameFieldStringValue = "Суфлёр \(session.title).md"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? SessionExporter.markdown(session).write(to: url, atomically: true, encoding: .utf8)
    }
}
