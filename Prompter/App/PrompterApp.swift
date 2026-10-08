import SwiftUI

@main
struct PrompterApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        Window("Суфлёр", id: "main") {
            MainView()
                .environment(model)
                .frame(minWidth: 720, minHeight: 520)
        }
        .defaultSize(width: 860, height: 640)

        MenuBarExtra {
            MenuBarContent()
                .environment(model)
        } label: {
            Image(systemName: model.isRunning ? "waveform.circle.fill" : "waveform.circle")
        }
    }
}

struct MainView: View {
    var body: some View {
        TabView {
            Tab("Сессия", systemImage: "waveform") { SessionView() }
            Tab("Знания", systemImage: "books.vertical") { KnowledgeView() }
            Tab("История", systemImage: "clock.arrow.circlepath") { HistoryView() }
            Tab("Настройки", systemImage: "gearshape") { SettingsView() }
        }
    }
}

struct MenuBarContent: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button(model.isRunning ? "Остановить сессию" : "Начать сессию") { model.toggleSession() }
        Button("Подсказать сейчас") { model.requestSuggestions(trigger: .manual) }
            .disabled(!model.isRunning)
        Button("Окно подсказок") { model.toggleOverlay() }
        Divider()
        Button("Открыть Суфлёр") {
            openWindow(id: "main")
            NSApp.activate()
        }
        Button("Выйти") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
