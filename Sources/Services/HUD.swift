import AppKit
import SwiftUI

/// A small, click-through floating panel that briefly confirms actions such as "Pasted slot 3".
@MainActor
final class HUD {
    static let shared = HUD()
    private var panel: NSPanel?
    private var hideWork: DispatchWorkItem?

    func show(_ message: String, symbol: String = "checkmark.circle.fill") {
        let view = HStack(spacing: 10) {
            Image(systemName: symbol).font(.title2)
            Text(message).font(.headline)
        }
        .padding(.horizontal, 22).padding(.vertical, 14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .fixedSize()

        let hosting = NSHostingView(rootView: view)
        let size = hosting.fittingSize
        let panel = self.panel ?? makePanel()
        panel.contentView = hosting
        if let screen = NSScreen.main?.visibleFrame {
            panel.setFrame(NSRect(x: screen.midX - size.width / 2, y: screen.minY + screen.height * 0.18,
                                  width: size.width, height: size.height), display: true)
        }
        panel.alphaValue = 1
        panel.orderFrontRegardless()
        self.panel = panel

        hideWork?.cancel()
        let work = DispatchWorkItem { [weak panel] in
            NSAnimationContext.runAnimationGroup({ $0.duration = 0.3; panel?.animator().alphaValue = 0 },
                                                 completionHandler: { panel?.orderOut(nil) })
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4, execute: work)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        return panel
    }
}
