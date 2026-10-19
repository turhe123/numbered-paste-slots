import Carbon

/// Registers the twenty global Carbon hotkeys (ten paste, ten capture) and forwards presses.
/// Hotkey ids 0–9 are paste slots, 10–19 are capture slots.
final class HotKeyManager {
    static let shared = HotKeyManager()

    var onPress: ((UInt32) -> Void)?
    private var refs: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?
    private let signature: OSType = 0x4E50_5354  // 'NPST'

    private init() {}

    private func installHandler() {
        guard handler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKey = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                           EventParamType(typeEventHotKeyID), nil,
                                           MemoryLayout<EventHotKeyID>.size, nil, &hotKey)
            if status == noErr {
                let id = hotKey.id
                DispatchQueue.main.async { HotKeyManager.shared.onPress?(id) }
            }
            return noErr
        }, 1, &spec, nil, &handler)
    }

    /// Re-registers all hotkeys. Returns human-readable descriptions of combinations that failed.
    func register(pasteMods: Int, captureMods: Int) -> [String] {
        installHandler()
        unregisterAll()
        var failures: [String] = []
        for (group, mods) in [(0, pasteMods), (1, captureMods)] {
            for i in SlotIndex.all {
                var ref: EventHotKeyRef?
                let id = EventHotKeyID(signature: signature, id: UInt32(group * 10 + i))
                let status = RegisterEventHotKey(SlotIndex.keyCodes[i], UInt32(mods), id,
                                                 GetApplicationEventTarget(), 0, &ref)
                if status == noErr, let ref {
                    refs.append(ref)
                } else {
                    failures.append("\(ModifierCombo.symbols(mods))\(SlotIndex.digit(i)) (error \(status))")
                }
            }
        }
        return failures
    }

    func unregisterAll() {
        refs.forEach { UnregisterEventHotKey($0) }
        refs.removeAll()
    }
}
