import AppKit

final class PasteCapableSecureTextField: NSSecureTextField {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command), let chars = event.charactersIgnoringModifiers?.lowercased() {
            switch chars {
            case "v": NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self); return true
            case "x": NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: self); return true
            case "c": NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self); return true
            case "a": NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: self); return true
            default: break
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}

final class PasteCapableTextView: NSTextView {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command), let chars = event.charactersIgnoringModifiers?.lowercased() {
            switch chars {
            case "v": NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self); return true
            case "x": NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: self); return true
            case "c": NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self); return true
            case "a": NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: self); return true
            default: break
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}
