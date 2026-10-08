import AppKit
import SwiftUI

/// Всё, что Суфлёр знает о проекте: описание, глоссарий и документы (RAG).
struct KnowledgeView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var settings = model.settings
        let knowledge = model.knowledge
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                section(
                    "О проекте и обо мне",
                    hint: "Пара абзацев: чем занимается проект, ваша роль, текущие задачи и проблемы. Подставляется в каждую подсказку."
                ) {
                    TextEditor(text: $settings.projectBrief)
                        .font(.body)
                        .frame(minHeight: 110)
                }

                section(
                    "Глоссарий",
                    hint: "По одному термину на строку: «выкатка = rollout», «дежурство — on-call». Суфлёр подскажет нужное слово, даже если вы скажете его по-русски."
                ) {
                    TextEditor(text: $settings.glossaryText)
                        .font(.body.monospaced())
                        .frame(minHeight: 130)
                }

                section(
                    "Документы проекта",
                    hint: "Тексты, Markdown, PDF, Word, код. Режутся на фрагменты и векторизуются на этом Mac; в подсказку попадают только фрагменты, близкие к текущему разговору."
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Button("Добавить файлы или папку…") { pickFiles() }
                                .disabled(knowledge.isIndexing)
                            if knowledge.isIndexing {
                                ProgressView().controlSize(.small)
                                Text("Индексирую…").foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("Фрагментов: \(knowledge.index.chunks.count)")
                                .foregroundStyle(.secondary)
                        }
                        if let error = knowledge.lastError {
                            Text(error).foregroundStyle(.orange).font(.callout)
                        }
                        ForEach(knowledge.index.sources, id: \.self) { source in
                            HStack {
                                Image(systemName: "doc.text")
                                Text(URL(fileURLWithPath: source).lastPathComponent)
                                    .help(source)
                                Text("\(knowledge.index.chunkCount(for: source))")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button {
                                    knowledge.remove(source: source)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                }

                Text("Документы и глоссарий используются локальной моделью частично (у неё маленький контекст), а Claude — полностью. В облако уходят только фрагменты, найденные для конкретной подсказки.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
        }
    }

    private func section<Content: View>(_ title: String, hint: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Text(hint).font(.callout).foregroundStyle(.secondary)
            content()
        }
    }

    private func pickFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.prompt = "Добавить"
        guard panel.runModal() == .OK else { return }
        let urls = panel.urls
        Task { await model.knowledge.add(urls: urls) }
    }
}
