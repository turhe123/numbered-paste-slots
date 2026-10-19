import SwiftUI
import UniformTypeIdentifiers

/// The Edit Slots window: ten rows, reorderable by dragging a row's digit badge onto another row.
struct EditSlotsView: View {
    @ObservedObject var store: SlotStore
    let controller: AppController

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(SlotIndex.all, id: \.self) { i in
                    SlotRow(index: i, store: store, controller: controller)
                    if i < 9 { Divider() }
                }
            }
            .padding()
        }
        .frame(minWidth: 680, minHeight: 400)
    }
}

/// One editable slot: digit, label, text editor or image well, plain-text toggle, copy and clear.
struct SlotRow: View {
    let index: Int
    @ObservedObject var store: SlotStore
    let controller: AppController
    @State private var dropTargeted = false
    @State private var error: String?

    private var slot: Slot { store.slots[index] }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(SlotIndex.digit(index))")
                .font(.title2.monospacedDigit().bold())
                .frame(width: 34, height: 34)
                .background(Color.accentColor.opacity(0.18), in: RoundedRectangle(cornerRadius: 8))
                .draggable("npslot:\(index)")
                .help("Drag onto another row to swap")

            VStack(alignment: .leading, spacing: 6) {
                TextField("Label", text: store.labelBinding(index))
                Toggle("Plain text only", isOn: store.plainTextBinding(index))
                    .disabled(slot.kind == .image)
                if let error { Text(error).font(.caption).foregroundStyle(.red) }
            }
            .frame(width: 170)

            Group {
                if slot.kind == .image { imageWell } else { textArea }
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 6) {
                Button { controller.copy(index) } label: { Image(systemName: "doc.on.doc") }
                    .help("Copy to clipboard").disabled(slot.isEmpty)
                Button { store.clear(index); error = nil } label: { Image(systemName: "trash") }
                    .help("Clear slot").disabled(slot.isEmpty && slot.label.isEmpty)
                Button { chooseImage() } label: { Image(systemName: "photo") }
                    .help("Choose image…")
            }
        }
        .padding(6)
        .background(dropTargeted ? Color.accentColor.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 8))
        .dropDestination(for: String.self) { items, _ in
            guard let item = items.first, item.hasPrefix("npslot:"),
                  let from = Int(item.dropFirst("npslot:".count)) else { return false }
            store.swap(from, index)
            return true
        } isTargeted: { dropTargeted = $0 }
    }

    private var textArea: some View {
        TextEditor(text: store.textBinding(index))
            .font(.body)
            .frame(height: 64)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
            .overlay(alignment: .topLeading) {
                if slot.text.isEmpty {
                    Text("Empty — type text, or choose an image").foregroundStyle(.tertiary)
                        .padding(.horizontal, 6).padding(.vertical, 2).allowsHitTesting(false)
                }
            }
    }

    private var imageWell: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6).fill(.quaternary.opacity(0.4))
            if let image = store.image(for: index) {
                Image(nsImage: image).resizable().scaledToFit().padding(4)
            } else {
                Text("Drop an image").foregroundStyle(.secondary)
            }
        }
        .frame(height: 64)
        .onDrop(of: [.image, .fileURL], isTargeted: nil) { providers in handleImageDrop(providers) }
        .help("Drop an image here to replace it")
    }

    /// Accepts dropped image data or image files, validated via UTType conformance.
    private func handleImageDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                guard let data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                DispatchQueue.main.async { loadImageFile(url) }
            }
            return true
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                guard let data else { return }
                DispatchQueue.main.async { error = store.setImage(index, data: data) }
            }
            return true
        }
        return false
    }

    private func loadImageFile(_ url: URL) {
        guard let type = UTType(filenameExtension: url.pathExtension), type.conforms(to: .image) else {
            error = "Not an image file"; return
        }
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard size <= SlotIndex.maxImageBytes else { error = "Image is larger than 5 MB"; return }
        guard let data = try? Data(contentsOf: url) else { error = "Could not read file"; return }
        error = store.setImage(index, data: data)
    }

    private func chooseImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { loadImageFile(url) }
    }
}
