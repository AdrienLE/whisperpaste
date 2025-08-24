import Foundation

public enum AppSupportPaths {
    public static let bundleIdentifier = "whisper2"

    public static func appSupportDirectory(base: URL? = nil) throws -> URL {
        if let base = base { return base }
        let fm = FileManager.default
        guard let root = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "AppSupportPaths", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to locate Application Support directory"])
        }
        let dir = root.appendingPathComponent(bundleIdentifier, isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
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
