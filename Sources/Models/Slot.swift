import Carbon
import SwiftUI

/// One of the ten paste slots: text (optionally with rich formatting) or an image, plus a label.
struct Slot: Codable, Equatable {
    enum Kind: String, Codable { case empty, text, image }

    var kind: Kind = .empty
    var label: String = ""
    var text: String = ""
    /// Original RTF captured from the pasteboard; dropped when the text is edited.
    var rtf: Data?
    /// File name (inside the store directory) of the PNG for image slots.
    var imageFile: String?
    var plainTextOnly: Bool = false

    var isEmpty: Bool { kind == .empty }

    /// Label, or a 30-character single-line preview of the contents.
    var title: String {
        if !label.isEmpty { return label }
        switch kind {
        case .empty: return "Empty"
        case .image: return "Image"
        case .text:
            let flat = text.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
            return flat.count > 30 ? String(flat.prefix(30)) + "…" : flat
        }
    }
}

/// Size limits and index/digit helpers shared across the app.
enum SlotIndex {
    static let all = Array(0..<10)
    static let maxTextBytes = 100 * 1024
    static let maxImageBytes = 5 * 1024 * 1024
    /// Slot index 0...9 maps to digit keys 1...9, 0.
    static func digit(_ index: Int) -> Int { (index + 1) % 10 }
    /// Virtual key codes of the top digit row — layout independent.
    static let keyCodes: [UInt32] = [18, 19, 20, 21, 23, 22, 26, 28, 25, 29]
}

/// UserDefaults keys and defaults for every preference.
enum Prefs {
    static let pasteMods = "pasteModifiers"
    static let captureMods = "captureModifiers"
    static let playSound = "playSound"
    static let showHUD = "showHUD"
    static let restoreClipboard = "restoreClipboard"
    static let confirmReplace = "confirmReplace"
    static let defaultPaste = controlKey | optionKey
    static let defaultCapture = controlKey | optionKey | shiftKey

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            pasteMods: defaultPaste, captureMods: defaultCapture, playSound: true,
            showHUD: true, restoreClipboard: false, confirmReplace: true,
        ])
    }
}

/// Selectable modifier combinations, stored as Carbon modifier masks.
enum ModifierCombo {
    static let presets: [Int] = [
        controlKey | optionKey, controlKey | cmdKey, optionKey | cmdKey, controlKey | shiftKey,
        optionKey | shiftKey, shiftKey | cmdKey, controlKey | optionKey | shiftKey,
        controlKey | optionKey | cmdKey, controlKey | shiftKey | cmdKey,
    ]

    static func symbols(_ mask: Int) -> String {
        var s = ""
        if mask & controlKey != 0 { s += "⌃" }
        if mask & optionKey != 0 { s += "⌥" }
        if mask & shiftKey != 0 { s += "⇧" }
        if mask & cmdKey != 0 { s += "⌘" }
        return s
    }

    static func eventModifiers(_ mask: Int) -> SwiftUI.EventModifiers {
        var m: SwiftUI.EventModifiers = []
        if mask & controlKey != 0 { m.insert(.control) }
        if mask & optionKey != 0 { m.insert(.option) }
        if mask & shiftKey != 0 { m.insert(.shift) }
        if mask & cmdKey != 0 { m.insert(.command) }
        return m
    }

    /// Known macOS system shortcuts that collide with some digit combinations.
    static func systemConflict(_ mask: Int) -> String? {
        if mask == shiftKey | cmdKey { return "⇧⌘3/4/5/6 are used by macOS for screenshots." }
        if mask == controlKey | shiftKey | cmdKey { return "⌃⇧⌘3/4 are used by macOS for screenshots to the clipboard." }
        return nil
    }
}
