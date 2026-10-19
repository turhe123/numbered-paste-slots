import AppKit
import ApplicationServices

/// Reads, writes, snapshots and restores the general pasteboard, and synthesizes ⌘V.
enum PasteboardService {
    enum Content {
        case text(String, rtf: Data?)
        case image(Data)
        case nothing
        case tooLarge(String)
    }

    typealias Snapshot = [[NSPasteboard.PasteboardType: Data]]

    /// Current clipboard contents, preferring text and falling back to PNG or TIFF.
    static func read() -> Content {
        let pb = NSPasteboard.general
        if let string = pb.string(forType: .string), !string.isEmpty {
            guard string.utf8.count <= SlotIndex.maxTextBytes else { return .tooLarge("Text is larger than 100 KB") }
            return .text(string, rtf: pb.data(forType: .rtf))
        }
        if let data = pb.data(forType: .png) ?? pb.data(forType: .tiff) {
            guard data.count <= SlotIndex.maxImageBytes else { return .tooLarge("Image is larger than 5 MB") }
            return .image(data)
        }
        return .nothing
    }

    static func write(_ slot: Slot, png: Data?) {
        let pb = NSPasteboard.general
        pb.clearContents()
        switch slot.kind {
        case .empty: break
        case .text:
            if !slot.plainTextOnly, let rtf = slot.rtf { pb.setData(rtf, forType: .rtf) }
            pb.setString(slot.text, forType: .string)
        case .image:
            if let png {
                pb.setData(png, forType: .png)
                if let tiff = NSImage(data: png)?.tiffRepresentation { pb.setData(tiff, forType: .tiff) }
            }
        }
    }

    static func snapshot() -> Snapshot {
        (NSPasteboard.general.pasteboardItems ?? []).map { item in
            var dict: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types { dict[type] = item.data(forType: type) }
            return dict
        }
    }

    static func restore(_ snapshot: Snapshot) {
        let pb = NSPasteboard.general
        pb.clearContents()
        let items = snapshot.map { dict -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in dict { item.setData(data, forType: type) }
            return item
        }
        if !items.isEmpty { pb.writeObjects(items) }
    }

    /// Posts ⌘V to the frontmost app. Uses a private event source so held hotkey modifiers don't leak in.
    static func postCommandV() {
        let source = CGEventSource(stateID: .privateState)
        let vKey: CGKeyCode = 9
        let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Shows the system Accessibility prompt.
    static func requestAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
