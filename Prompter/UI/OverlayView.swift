import SwiftUI

/// Содержимое плавающего окна: что сказал собеседник, что говорю я, облако слов и готовые фразы.
struct OverlayView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            partnerBlock
            myBlock
            Divider()
            suggestionsBlock
            Spacer(minLength: 0)
        }
        .padding(16)
        .padding(.top, 8)
        .frame(minWidth: 340, minHeight: 260, alignment: .topLeading)
        .background(.regularMaterial, in: .rect(cornerRadius: 14))
    }

    private var header: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(model.isRunning ? Color.green : Color.secondary)
                .frame(width: 8, height: 8)
            Text(model.isRunning ? "Слушаю" : "Пауза")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            if model.isSuggesting {
                ProgressView().controlSize(.small)
            }
            Button {
                model.requestSuggestions(trigger: .manual)
            } label: {
                Label("Подсказать", systemImage: "lightbulb")
            }
            .controlSize(.small)
            .help("Подсказать сейчас (⌥⌘Space)")
            .disabled(!model.isRunning)
        }
    }

    @ViewBuilder
    private var partnerBlock: some View {
        let volatile = model.transcript.volatile[.partner]
        let last = model.transcript.lastLine(of: .partner)
        if volatile != nil || last != nil {
            VStack(alignment: .leading, spacing: 4) {
                Text(volatile ?? last?.text ?? "")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                if volatile == nil, let last, let translation = model.partnerTranslations[last.id] {
                    Text(translation)
                        .font(.callout)
                        .foregroundStyle(.primary.opacity(0.8))
                        .lineLimit(3)
                }
            }
        }
    }

    @ViewBuilder
    private var myBlock: some View {
        let mine = model.transcript.currentUtterance(of: .me, maxCharacters: 160)
        if !mine.isEmpty {
            Text(mine + " …")
                .font(.title3)
                .lineLimit(2)
                .truncationMode(.head)
        }
    }

    @ViewBuilder
    private var suggestionsBlock: some View {
        if let error = model.suggestionError {
            Label(error, systemImage: "exclamationmark.triangle")
                .font(.callout)
                .foregroundStyle(.orange)
        }
        if model.suggestions.isEmpty {
            Text(model.isRunning
                 ? "Говорите. Когда запнётесь, здесь появятся слова и фразы."
                 : "Начните сессию в главном окне или в меню.")
                .font(.callout)
                .foregroundStyle(.secondary)
        } else {
            WordCloud(words: model.suggestions.words) { model.copyToClipboard($0) }
            VStack(alignment: .leading, spacing: 8) {
                ForEach(model.suggestions.phrases, id: \.self) { phrase in
                    Button {
                        model.copyToClipboard(phrase)
                    } label: {
                        Text("… " + phrase)
                            .font(.title3.weight(.medium))
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .help("Скопировать")
                }
            }
            if !model.suggestionSource.isEmpty {
                Text(model.suggestionSource)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

/// Облако слов: размер и насыщенность зависят от релевантности.
struct WordCloud: View {
    var words: [WeightedWord]
    var onTap: (String) -> Void

    var body: some View {
        FlowLayout(spacing: 10, lineSpacing: 6) {
            ForEach(words) { word in
                Button {
                    onTap(word.text)
                } label: {
                    Text(word.text)
                        .font(.system(size: 14 + 16 * word.score, weight: word.score > 0.7 ? .bold : .medium, design: .rounded))
                        .foregroundStyle(Color.accentColor.opacity(0.5 + 0.5 * word.score))
                }
                .buttonStyle(.plain)
            }
        }
        .animation(.easeOut(duration: 0.2), value: words)
    }
}

/// Раскладка «в строку с переносом».
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews: subviews, maxWidth: proposal.width ?? .infinity)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + lineSpacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(subviews: subviews, maxWidth: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                // Слова в строке выравниваем по базовой линии снизу.
                subviews[index].place(at: CGPoint(x: x, y: y + row.height - size.height), proposal: .unspecified)
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > maxWidth, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}
