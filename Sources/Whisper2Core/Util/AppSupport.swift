import Foundation

public enum AppSupportPaths {
    // New brand folder; we keep backward compatibility with legacy folder
    public static let bundleIdentifier = "whisperpaste"

    public static func appSupportDirectory(base: URL? = nil) throws -> URL {
        if let base = base { return base }
        let fm = FileManager.default
        guard let root = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "AppSupportPaths", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to locate Application Support directory"])
        }
        let newDir = root.appendingPathComponent(bundleIdentifier, isDirectory: true)
        let legacyDir = root.appendingPathComponent("whisper2", isDirectory: true)
        // Prefer new dir; if it doesn't exist but legacy exists, keep using legacy to avoid data loss
        if fm.fileExists(atPath: newDir.path) {
            return newDir
        } else if fm.fileExists(atPath: legacyDir.path) {
            return legacyDir
        } else {
            try fm.createDirectory(at: newDir, withIntermediateDirectories: true)
            return newDir
        }
    }

    public static func settingsFile(base: URL? = nil) throws -> URL {
        try appSupportDirectory(base: base).appendingPathComponent("settings.json")
    }

    public static func historyFile(base: URL? = nil) throws -> URL {
        try appSupportDirectory(base: base).appendingPathComponent("history.json")
    }

    public static func audioDirectory(base: URL? = nil) throws -> URL {
        let dir = try appSupportDirectory(base: base).appendingPathComponent("audio", isDirectory: true)
        let fm = FileManager.default
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
}
