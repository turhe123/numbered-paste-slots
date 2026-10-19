import SwiftUI

/// App entry point: a menu-bar-only app with an editor window and a settings window.
@main
struct NumberedPasteSlotsApp: App {
    @StateObject private var controller = AppController.shared

    var body: some Scene {
        MenuBarExtra("NumberedPasteSlots", systemImage: "number.square") {
            MenuContent(store: controller.store, controller: controller)
        }

        Window("Edit Slots", id: "editor") {
            EditSlotsView(store: controller.store, controller: controller)
        }
        .defaultSize(width: 760, height: 720)

        Window("NumberedPasteSlots Settings", id: "settings") {
            SettingsView(controller: controller)
        }
        .windowResizability(.contentSize)
    }
}

/// Opens the donation page.
enum Support {
    static func openDonate() {
        NSWorkspace.shared.open(URL(string: "https://ko-fi.com/leodavidai")!)
    }
}
