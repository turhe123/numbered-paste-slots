import Combine
import ServiceManagement
import SwiftUI

/// Preferences: hotkey modifiers (with conflict checks), feedback, Accessibility status and launch at login.
struct SettingsView: View {
    @ObservedObject var controller: AppController
    @AppStorage(Prefs.pasteMods) private var pasteMods = Prefs.defaultPaste
    @AppStorage(Prefs.captureMods) private var captureMods = Prefs.defaultCapture
    @AppStorage(Prefs.playSound) private var playSound = true
    @AppStorage(Prefs.showHUD) private var showHUD = true
    @AppStorage(Prefs.restoreClipboard) private var restoreClipboard = false
    @AppStorage(Prefs.confirmReplace) private var confirmReplace = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var trusted = PasteboardService.isTrusted
    @State private var message: String?
    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        Form {
            Section("Hotkeys") {
                modifierPicker("Paste modifiers", selection: $pasteMods, other: captureMods)
                modifierPicker("Capture modifiers", selection: $captureMods, other: pasteMods)
                ForEach([pasteMods, captureMods], id: \.self) { mask in
                    if let conflict = ModifierCombo.systemConflict(mask) { warning(conflict) }
                }
                if !controller.hotKeyFailures.isEmpty {
                    warning("Already in use by the system or another app: "
                            + controller.hotKeyFailures.joined(separator: ", "))
                }
                if let message { warning(message) }
            }

            Section("Behavior") {
                Toggle("Play feedback sound", isOn: $playSound)
                Toggle("Show HUD", isOn: $showHUD)
                Toggle("Restore previous clipboard after pasting", isOn: $restoreClipboard)
                Toggle("Ask before replacing a filled slot", isOn: $confirmReplace)
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
            }

            Section("Accessibility") {
                if trusted {
                    Label("Accessibility access granted — slots paste directly.", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                } else {
                    Text("To paste into other apps, NumberedPasteSlots sends ⌘V on your behalf, which needs "
                         + "Accessibility access. Without it, slots are copied and you press ⌘V yourself.")
                        .font(.callout).foregroundStyle(.secondary)
                    HStack {
                        Button("Grant Access…") { PasteboardService.requestAccessibility() }
                        Button("Open System Settings") { PasteboardService.openAccessibilitySettings() }
                    }
                }
            }

            Section {
                HStack {
                    Text("NumberedPasteSlots is free and open source.").foregroundStyle(.secondary)
                    Spacer()
                    Button("Support / Donate ❤️") { Support.openDonate() }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .fixedSize(horizontal: false, vertical: true)
        .onReceive(timer) { _ in trusted = PasteboardService.isTrusted }
    }

    private func modifierPicker(_ title: String, selection: Binding<Int>, other: Int) -> some View {
        Picker(title, selection: Binding(get: { selection.wrappedValue }, set: { newValue in
            guard newValue != other else {
                message = "Paste and capture modifiers must be different."
                return
            }
            message = nil
            selection.wrappedValue = newValue
            controller.reloadHotKeys()
        })) {
            ForEach(ModifierCombo.presets, id: \.self) { mask in
                Text("\(ModifierCombo.symbols(mask)) + 1…0").tag(mask)
            }
        }
    }

    private func warning(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .font(.callout).foregroundStyle(.orange)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            message = "Launch at login failed: \(error.localizedDescription)"
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
