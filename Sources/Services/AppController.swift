import AppKit
import SwiftUI

/// Central coordinator: wires hotkeys to paste/capture actions, applies preferences and shows feedback.
@MainActor
final class AppController: ObservableObject {
    static let shared = AppController()

    let store = SlotStore()
    @Published private(set) var hotKeyFailures: [String] = []
    private var overviewPanel: NSPanel?
    private var defaults: UserDefaults { .standard }

    private init() {
        Prefs.registerDefaults()
        HotKeyManager.shared.onPress = { [weak self] id in
            Task { @MainActor in
                guard let self else { return }
                let index = Int(id % 10)
                if id < 10 { self.paste(index) } else { self.capture(index) }
            }
        }
        reloadHotKeys()
    }

    func reloadHotKeys() {
        hotKeyFailures = HotKeyManager.shared.register(pasteMods: defaults.integer(forKey: Prefs.pasteMods),
                                                       captureMods: defaults.integer(forKey: Prefs.captureMods))
    }

    // MARK: Actions

    /// Writes the slot to the pasteboard and, with Accessibility access, sends ⌘V to the frontmost app.
    func paste(_ index: Int, delay: TimeInterval = 0.05) {
        let slot = store.slots[index]
        let digit = SlotIndex.digit(index)
        guard !slot.isEmpty else { feedback("Slot \(digit) is empty", symbol: "tray"); return }
        let snapshot = defaults.bool(forKey: Prefs.restoreClipboard) ? PasteboardService.snapshot() : nil
        PasteboardService.write(slot, png: store.pngData(for: index))

        guard PasteboardService.isTrusted else {
            feedback("Copied slot \(digit) — press ⌘V", symbol: "doc.on.clipboard")
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            PasteboardService.postCommandV()
            self.feedback("Pasted slot \(digit)")
            if let snapshot {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { PasteboardService.restore(snapshot) }
            }
        }
    }

    /// Saves the current clipboard into a slot, asking before replacing unless disabled.
    func capture(_ index: Int) {
        let digit = SlotIndex.digit(index)
        let content = PasteboardService.read()
        switch content {
        case .nothing: feedback("Nothing to capture", symbol: "exclamationmark.triangle"); return
        case .tooLarge(let message): feedback(message, symbol: "exclamationmark.triangle"); return
        default: break
        }
        if !store.slots[index].isEmpty, defaults.bool(forKey: Prefs.confirmReplace), !confirmReplace(digit) { return }

        switch content {
        case let .text(text, rtf):
            store.setText(index, text: text, rtf: rtf)
        case let .image(data):
            if let error = store.setImage(index, data: data) {
                feedback(error, symbol: "exclamationmark.triangle"); return
            }
        default: return
        }
        feedback("Saved to slot \(digit)")
    }

    /// Copies a slot without pasting (editor copy button).
    func copy(_ index: Int) {
        PasteboardService.write(store.slots[index], png: store.pngData(for: index))
        feedback("Copied slot \(SlotIndex.digit(index))", symbol: "doc.on.clipboard")
    }

    private func confirmReplace(_ digit: Int) -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Replace slot \(digit)?"
        alert.informativeText = "Slot \(digit) already has content. Replace it with the current clipboard?"
        alert.addButton(withTitle: "Replace")
        alert.addButton(withTitle: "Cancel")
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = "Don't ask again"
        let confirmed = alert.runModal() == .alertFirstButtonReturn
        if confirmed, alert.suppressionButton?.state == .on { defaults.set(false, forKey: Prefs.confirmReplace) }
        return confirmed
    }

    private func feedback(_ message: String, symbol: String = "checkmark.circle.fill") {
        if defaults.bool(forKey: Prefs.playSound) { NSSound(named: "Tink")?.play() }
        if defaults.bool(forKey: Prefs.showHUD) { HUD.shared.show(message, symbol: symbol) }
    }

    // MARK: Overview

    /// Shows a non-activating panel with all ten slots; clicking one pastes into the still-frontmost app.
    func showOverview() {
        let panel = overviewPanel ?? NSPanel(contentRect: NSRect(x: 0, y: 0, width: 560, height: 260),
                                             styleMask: [.titled, .closable, .nonactivatingPanel, .utilityWindow],
                                             backing: .buffered, defer: false)
        panel.title = "Slots Overview"
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.contentView = NSHostingView(rootView: OverviewView(store: store) { [weak self, weak panel] index in
            panel?.orderOut(nil)
            self?.paste(index, delay: 0.15)
        })
        panel.center()
        panel.orderFrontRegardless()
        overviewPanel = panel
    }
}
