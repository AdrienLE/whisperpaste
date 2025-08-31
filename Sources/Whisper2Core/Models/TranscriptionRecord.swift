import Foundation

public struct TranscriptionRecord: Codable, Equatable, Identifiable {
    public let id: UUID
    public var createdAt: Date
    public var rawText: String
    public var cleanedText: String
    public var audioFilePath: String?
    public var previewText: String?
    public var source: String? // "openai" | "preview" | "error"

    public init(id: UUID = UUID(), createdAt: Date = Date(), rawText: String, cleanedText: String, audioFilePath: String? = nil, previewText: String? = nil, source: String? = nil) {
        self.id = id
        self.createdAt = createdAt
        self.rawText = rawText
        self.cleanedText = cleanedText
        self.audioFilePath = audioFilePath
        self.previewText = previewText
        self.source = source
    }
}

public final class HistoryStore {
    private let fm = FileManager.default
    private let baseDir: URL?

    public init(baseDirectory: URL? = nil) {
        self.baseDir = baseDirectory
    }

    public func load() -> [TranscriptionRecord] {
        do {
            let url = try AppSupportPaths.historyFile(base: baseDir)
            guard fm.fileExists(atPath: url.path) else { return [] }
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([TranscriptionRecord].self, from: data)
        } catch {
            return []
        }
    }

    public func save(_ items: [TranscriptionRecord]) throws {
        let url = try AppSupportPaths.historyFile(base: baseDir)
        let data = try JSONEncoder().encode(items)
        try data.write(to: url, options: [.atomic])
    }

    public func append(_ item: TranscriptionRecord) throws {
        var all = load()
        all.insert(item, at: 0)
        try save(all)
    }

    public func cleanMissingAudioReferences() throws {
        let all = load()
        let kept = all.filter { record in
            guard let path = record.audioFilePath else { return true }
            return fm.fileExists(atPath: path)
        }
        if kept.count != all.count {
            try save(kept)
        }
    }
}
