import Carbon

/// A system-wide shortcut. Fires when the key is released, so the fix starts after the press.
final class Hotkey {
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
        var released = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, me in
            Unmanaged<Hotkey>.fromOpaque(me!).takeUnretainedValue().action()
            return noErr
        }, 1, &released, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }

    /// False when another app already owns this shortcut.
    @discardableResult
    func register(keyCode: Int, modifiers: Int) -> Bool {
        unregister()
        let id = EventHotKeyID(signature: OSType(0x5361_3720), id: 1) // "Sa7 "
        return RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), id, GetApplicationEventTarget(), 0, &hotKey) == noErr
    }

    func unregister() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = nil
    }
}
