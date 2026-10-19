import AppKit
import SwiftUI

/// Owns the ten slots and persists them: text and metadata as JSON, images as PNG files in Application Support.
@MainActor
final class SlotStore: ObservableObject {
    @Published private(set) var slots: [Slot] = Array(repeating: Slot(), count: 10)
    private var imageCache: [String: NSImage] = [:]
    let directory: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        directory = base.appendingPathComponent("NumberedPasteSlots", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        load()
    }

    private var jsonURL: URL { directory.appendingPathComponent("slots.json") }
    private func fileURL(_ name: String) -> URL { directory.appendingPathComponent(name) }

    // MARK: Persistence

    private func load() {
        guard let data = try? Data(contentsOf: jsonURL) else { return }
        do {
            let decoded = try JSONDecoder().decode([Slot].self, from: data)
            guard decoded.count == 10 else { throw CocoaError(.fileReadCorruptFile) }
            slots = decoded
            for i in SlotIndex.all where slots[i].kind == .image && image(for: i) == nil {
                slots[i] = Slot()  // missing or unreadable PNG
            }
        } catch {
            let backup = directory.appendingPathComponent("slots.corrupt-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.moveItem(at: jsonURL, to: backup)
            slots = Array(repeating: Slot(), count: 10)
            save()
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(slots)
            try data.write(to: jsonURL, options: .atomic)
        } catch {
            NSLog("NumberedPasteSlots: failed to save slots: \(error.localizedDescription)")
        }
    }

    // MARK: Mutations

    func setText(_ index: Int, text: String, rtf: Data?) {
        removeImageFile(index)
        slots[index].kind = text.isEmpty ? .empty : .text
        slots[index].text = text
        slots[index].rtf = rtf
        save()
    }

    /// Stores image data as PNG. Returns an error message on failure.
    @discardableResult
    func setImage(_ index: Int, data: Data) -> String? {
        guard data.count <= SlotIndex.maxImageBytes else { return "Image is larger than 5 MB" }
        guard let rep = NSBitmapImageRep(data: data), let png = rep.representation(using: .png, properties: [:]) else {
            return "Unsupported image data"
        }
        guard png.count <= SlotIndex.maxImageBytes else { return "Image is larger than 5 MB" }
        let name = "slot-\(UUID().uuidString).png"
        do { try png.write(to: fileURL(name), options: .atomic) } catch { return "Could not save image" }
        removeImageFile(index)
        slots[index].kind = .image
        slots[index].imageFile = name
        slots[index].text = ""
        slots[index].rtf = nil
        save()
        return nil
    }

    func clear(_ index: Int) {
        removeImageFile(index)
        slots[index] = Slot()
        save()
    }

    func swap(_ a: Int, _ b: Int) {
        guard a != b, slots.indices.contains(a), slots.indices.contains(b) else { return }
        slots.swapAt(a, b)
        save()
    }

    func image(for index: Int) -> NSImage? {
        guard let name = slots[index].imageFile else { return nil }
        if let cached = imageCache[name] { return cached }
        guard let img = NSImage(contentsOf: fileURL(name)) else { return nil }
        imageCache[name] = img
        return img
    }

    func pngData(for index: Int) -> Data? {
        guard let name = slots[index].imageFile else { return nil }
        return try? Data(contentsOf: fileURL(name))
    }

    private func removeImageFile(_ index: Int) {
        guard let name = slots[index].imageFile else { return }
        try? FileManager.default.removeItem(at: fileURL(name))
        imageCache[name] = nil
        slots[index].imageFile = nil
    }

    // MARK: Bindings for the editor

    func labelBinding(_ i: Int) -> Binding<String> {
        Binding(get: { self.slots[i].label }, set: { self.slots[i].label = $0; self.save() })
    }

    func plainTextBinding(_ i: Int) -> Binding<Bool> {
        Binding(get: { self.slots[i].plainTextOnly }, set: { self.slots[i].plainTextOnly = $0; self.save() })
    }

    /// Text edits drop captured formatting and are capped at 100 KB.
    func textBinding(_ i: Int) -> Binding<String> {
        Binding(get: { self.slots[i].text }, set: { newValue in
            guard newValue.utf8.count <= SlotIndex.maxTextBytes else { NSSound.beep(); return }
            self.setText(i, text: newValue, rtf: nil)
        })
    }
}
