import AppKit
import Carbon
import Whisper2Core

final class HotkeyManager {
    private var currentRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var onTrigger: (() -> Void)?

    func register(hotkey: Hotkey?, onTrigger: @escaping () -> Void) {
        unregister()
        self.onTrigger = onTrigger
        guard let hk = hotkey, let mapping = HotkeyManager.mapToCarbon(hk) else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        InstallEventHandler(GetEventDispatcherTarget(), { (next, theEvent, userData) -> OSStatus in
            guard let userData = userData else { return noErr }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            manager.onTrigger?()
            return noErr
        }, 1, &eventType, selfPtr, &eventHandler)

        let hotKeyID = EventHotKeyID(signature: OSType(0x57534832), id: UInt32(1)) // 'WSH2'
        RegisterEventHotKey(mapping.keyCode, mapping.modifiers, hotKeyID, GetEventDispatcherTarget(), 0, &currentRef)
    }

    func unregister() {
        if let ref = currentRef { UnregisterEventHotKey(ref); currentRef = nil }
        if let handler = eventHandler { RemoveEventHandler(handler); eventHandler = nil }
        onTrigger = nil
    }

    deinit { unregister() }

    struct CarbonHotKey { let keyCode: UInt32; let modifiers: UInt32 }

    static func mapToCarbon(_ hk: Hotkey) -> CarbonHotKey? {
        let mods: UInt32 = (hk.cmd ? UInt32(cmdKey) : 0) |
                           (hk.ctrl ? UInt32(controlKey) : 0) |
                           (hk.alt ? UInt32(optionKey) : 0) |
                           (hk.shift ? UInt32(shiftKey) : 0)
        let keyCode: UInt32
        switch hk.key.lowercased() {
        case "space": keyCode = UInt32(kVK_Space)
        default:
            if hk.key.count == 1, let scalar = hk.key.uppercased().utf16.first {
                keyCode = UInt32(HotkeyManager.keyCodeForLetter(Character(UnicodeScalar(scalar)!)) ?? kVK_ANSI_A)
            } else {
                return nil
            }
        }
        return CarbonHotKey(keyCode: keyCode, modifiers: mods)
    }

    // Basic letter mapping A-Z using US ANSI constants. For digits or other keys, extend as needed.
    static func keyCodeForLetter(_ c: Character) -> Int? {
        switch c.uppercased() {
        case "A": return kVK_ANSI_A
        case "B": return kVK_ANSI_B
        case "C": return kVK_ANSI_C
        case "D": return kVK_ANSI_D
        case "E": return kVK_ANSI_E
        case "F": return kVK_ANSI_F
        case "G": return kVK_ANSI_G
        case "H": return kVK_ANSI_H
        case "I": return kVK_ANSI_I
        case "J": return kVK_ANSI_J
        case "K": return kVK_ANSI_K
        case "L": return kVK_ANSI_L
        case "M": return kVK_ANSI_M
        case "N": return kVK_ANSI_N
        case "O": return kVK_ANSI_O
        case "P": return kVK_ANSI_P
        case "Q": return kVK_ANSI_Q
        case "R": return kVK_ANSI_R
        case "S": return kVK_ANSI_S
        case "T": return kVK_ANSI_T
        case "U": return kVK_ANSI_U
        case "V": return kVK_ANSI_V
        case "W": return kVK_ANSI_W
        case "X": return kVK_ANSI_X
        case "Y": return kVK_ANSI_Y
        case "Z": return kVK_ANSI_Z
        default: return nil
        }
    }
}
