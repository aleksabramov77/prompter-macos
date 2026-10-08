import AppKit
import SwiftUI

/// Плавающее окно подсказок поверх всех окон и рабочих столов. Не забирает фокус у созвона.
@MainActor
final class OverlayPanelController {
    private var panel: NSPanel?

    var isVisible: Bool { panel?.isVisible ?? false }

    func show(model: AppModel) {
        let panel = panel ?? makePanel(model: model)
        self.panel = panel
        // Пытаемся скрыть окно от демонстрации экрана. Некоторые программы захвата это игнорируют,
        // поэтому перед важным созвоном стоит проверить в своём Zoom/Meet.
        panel.sharingType = model.settings.hideFromScreenSharing ? .none : .readOnly
        panel.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func toggle(model: AppModel) {
        isVisible ? hide() : show(model: model)
    }

    private func makePanel(model: AppModel) -> NSPanel {
        let size = NSSize(width: 460, height: 420)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel, .fullSizeContentView, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = "Суфлёр"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.contentView = NSHostingView(rootView: OverlayView().environment(model))
        panel.setFrameAutosaveName("PrompterOverlay")
        if !panel.setFrameUsingName("PrompterOverlay"), let screen = NSScreen.main {
            let visible = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: visible.maxX - size.width - 24, y: visible.maxY - size.height - 24))
        }
        return panel
    }
}
