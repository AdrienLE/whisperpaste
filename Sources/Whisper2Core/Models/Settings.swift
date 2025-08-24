import Foundation

public struct Settings: Codable, Equatable {
    public var openAIKey: String?
    public var transcriptionModel: String
    public var cleanupModel: String
    public var cleanupPrompt: String
    public var keepAudioFiles: Bool
    public var hotkey: String // simple placeholder, e.g., "ctrl+shift+space"

    public init(
        openAIKey: String? = nil,
        transcriptionModel: String = "whisper-1",
        cleanupModel: String = "gpt-4o-mini",
        cleanupPrompt: String = "Rewrite text for clarity and grammar.",
        keepAudioFiles: Bool = true,
        hotkey: String = "ctrl+shift+space"
    ) {
        self.openAIKey = openAIKey
        self.transcriptionModel = transcriptionModel
        self.cleanupModel = cleanupModel
        self.cleanupPrompt = cleanupPrompt
        self.keepAudioFiles = keepAudioFiles
        self.hotkey = hotkey
    }
}

public final class SettingsStore {
    private let fm = FileManager.default
    private let baseDir: URL?

    public init(baseDirectory: URL? = nil) {
        self.baseDir = baseDirectory
    }

    public func load() -> Settings {
        do {
            let url = try AppSupportPaths.settingsFile(base: baseDir)
            guard fm.fileExists(atPath: url.path) else { return Settings() }
            let data = try Data(contentsOf: url)
            let settings = try JSONDecoder().decode(Settings.self, from: data)
            return settings
        } catch {
            return Settings()
        }
    }

    public func save(_ settings: Settings) throws {
        let url = try AppSupportPaths.settingsFile(base: baseDir)
        let data = try JSONEncoder().encode(settings)
        try data.write(to: url, options: [.atomic])
    }
}
