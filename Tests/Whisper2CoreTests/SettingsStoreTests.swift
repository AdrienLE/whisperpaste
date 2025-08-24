import XCTest
@testable import Whisper2Core
import Foundation

final class SettingsStoreTests: XCTestCase {
    func testSaveAndLoadSettings() throws {
        let base = try makeTempBase()
        let store = SettingsStore(baseDirectory: base)
        var s = Settings(openAIKey: "sk-test", transcriptionModel: "whisper-1", cleanupModel: "gpt-4o-mini", cleanupPrompt: "Fix grammar", keepAudioFiles: false, hotkey: "ctrl+alt+d")
        try store.save(s)

        let loaded = store.load()
        XCTAssertEqual(loaded.openAIKey, s.openAIKey)
        XCTAssertEqual(loaded.transcriptionModel, s.transcriptionModel)
        XCTAssertEqual(loaded.cleanupModel, s.cleanupModel)
        XCTAssertEqual(loaded.cleanupPrompt, s.cleanupPrompt)
        XCTAssertEqual(loaded.keepAudioFiles, s.keepAudioFiles)
        XCTAssertEqual(loaded.hotkey, s.hotkey)
    }
}

// MARK: - Helpers
func makeTempBase(function: String = #function) throws -> URL {
    let fm = FileManager.default
    let base = URL(fileURLWithPath: fm.currentDirectoryPath)
        .appendingPathComponent(".tmp-tests", isDirectory: true)
        .appendingPathComponent(function.replacingOccurrences(of: " ", with: "_"), isDirectory: true)
    try? fm.removeItem(at: base)
    try fm.createDirectory(at: base, withIntermediateDirectories: true)
    return base
}
