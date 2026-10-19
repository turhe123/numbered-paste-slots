import SwiftUI

/// The menu bar menu: ten slots to paste, a capture submenu, and app commands.
struct MenuContent: View {
    @ObservedObject var store: SlotStore
    let controller: AppController
    @Environment(\.openWindow) private var openWindow
    @AppStorage(Prefs.pasteMods) private var pasteMods = Prefs.defaultPaste

    var body: some View {
        ForEach(SlotIndex.all, id: \.self) { i in
            let slot = store.slots[i]
            let digit = SlotIndex.digit(i)
            Button {
                if slot.isEmpty { open("editor") } else { controller.paste(i, delay: 0.25) }
            } label: {
                Text("\(digit)   \(slot.title)")
                    .foregroundStyle(slot.isEmpty ? .secondary : .primary)
            }
            .keyboardShortcut(KeyEquivalent(Character(String(digit))),
                              modifiers: ModifierCombo.eventModifiers(pasteMods))
        }

        Divider()
        Menu("Capture Clipboard Into Slot") {
            ForEach(SlotIndex.all, id: \.self) { i in
                Button("Slot \(SlotIndex.digit(i)) — \(store.slots[i].title)") { controller.capture(i) }
            }
        }
        Button("Show Overview…") { controller.showOverview() }
        Button("Edit Slots…") { open("editor") }
        Button("Settings…") { open("settings") }
            .keyboardShortcut(",")
        Divider()
        Button("Support / Donate ❤️") { Support.openDonate() }
        Button("Quit NumberedPasteSlots") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    private func open(_ id: String) {
        openWindow(id: id)
        NSApp.activate(ignoringOtherApps: true)
    }
}

/// Grid of all ten slots shown in the overview panel; clicking a slot pastes it.
struct OverviewView: View {
    @ObservedObject var store: SlotStore
    let onPick: (Int) -> Void

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
            ForEach(SlotIndex.all, id: \.self) { i in
                Button { onPick(i) } label: {
                    VStack(spacing: 6) {
                        Text("\(SlotIndex.digit(i))").font(.title2.monospacedDigit().bold())
                        if let image = store.image(for: i) {
                            Image(nsImage: image).resizable().scaledToFit().frame(height: 36)
                        } else {
                            Text(store.slots[i].title).font(.caption).lineLimit(2)
                                .foregroundStyle(store.slots[i].isEmpty ? .tertiary : .secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 90)
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(store.slots[i].isEmpty)
            }
        }
        .padding(14)
        .frame(width: 560)
    }
}
