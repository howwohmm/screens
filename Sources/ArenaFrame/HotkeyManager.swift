import Carbon
import AppKit

// MARK: - HotkeyManager
// Uses Carbon RegisterEventHotKey — no Accessibility permission required.

final class HotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let callback: () -> Void

    // Default: Cmd+Shift+A  (kVK_ANSI_A = 0x00)
    private let keyCode: UInt32
    private let modifiers: UInt32

    init(keyCode: UInt32 = UInt32(kVK_ANSI_A),
         modifiers: UInt32 = UInt32(cmdKey | shiftKey),
         callback: @escaping () -> Void) {
        self.keyCode   = keyCode
        self.modifiers = modifiers
        self.callback  = callback
    }

    func register() {
        let hotKeyID = EventHotKeyID(signature: OSType(0x4146524D), id: 1) // 'AFRM'

        // Install event handler
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))

        // We store the callback in a box so we can pass a pointer to C
        let box = Unmanaged.passRetained(CallbackBox(callback))

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                let box = Unmanaged<CallbackBox>.fromOpaque(userData!).takeUnretainedValue()
                DispatchQueue.main.async { box.callback() }
                return noErr
            },
            1, &spec,
            box.toOpaque(),
            &eventHandler
        )

        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    func unregister() {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref) }
        if let handler = eventHandler { RemoveEventHandler(handler) }
    }

    deinit { unregister() }
}

// MARK: - CallbackBox

private final class CallbackBox {
    let callback: () -> Void
    init(_ callback: @escaping () -> Void) { self.callback = callback }
    func toOpaque() -> UnsafeMutableRawPointer { Unmanaged.passUnretained(self).toOpaque() }
}
