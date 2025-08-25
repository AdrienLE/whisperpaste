import Foundation

public struct Hotkey: Equatable, Codable {
    public var cmd: Bool
    public var ctrl: Bool
    public var alt: Bool
    public var shift: Bool
    public var key: String // normalized uppercase letter, number, or special e.g. "space"

    public init(cmd: Bool = false, ctrl: Bool = false, alt: Bool = false, shift: Bool = false, key: String) {
        self.cmd = cmd; self.ctrl = ctrl; self.alt = alt; self.shift = shift; self.key = Hotkey.normalizeKey(key)
    }

    public var description: String {
        var parts: [String] = []
        if ctrl { parts.append("ctrl") }
        if alt { parts.append("alt") }
        if shift { parts.append("shift") }
        if cmd { parts.append("cmd") }
        parts.append(key)
        return parts.joined(separator: "+")
    }

    public static func parse(_ string: String) -> Hotkey? {
        let tokens = string.split(separator: "+").map { String($0).trimmingCharacters(in: .whitespaces).lowercased() }
        guard !tokens.isEmpty else { return nil }
        var cmd = false, ctrl = false, alt = false, shift = false
        var key: String?
        for t in tokens {
            switch t {
            case "cmd", "command": cmd = true
            case "ctrl", "control": ctrl = true
            case "alt", "option": alt = true
            case "shift": shift = true
            default: key = t
            }
        }
        guard let k = key else { return nil }
        return Hotkey(cmd: cmd, ctrl: ctrl, alt: alt, shift: shift, key: k)
    }

    private static func normalizeKey(_ k: String) -> String {
        let map: [String: String] = [" ": "space", "space": "space"]
        if let m = map[k.lowercased()] { return m }
        if k.count == 1 { return k.uppercased() }
        return k.lowercased()
    }
}

