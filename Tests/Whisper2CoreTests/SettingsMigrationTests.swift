import XCTest
@testable import Whisper2Core
import Foundation

final class SettingsMigrationTests: XCTestCase {

    func testDecodeOldSettingsPreservesKeyAndDefaults() throws {
        let base = try makeTempBase(function: #function)
        // Emulate an older settings.json without the new fields (transcriptionPrompt, useCleanup, showAllModels)
        let json: [String: Any] = [
            "openAIKey": "sk-old",
            "transcriptionModel": "whisper-1",
            "cleanupModel": "gpt-4o-mini",
            "cleanupPrompt": "Fix grammar",
            "keepAudioFiles": true,
            "hotkey": "ctrl+shift+space"
        ]
        let data = try JSONSerialization.data(withJSONObject: json, options: [])
        let settingsURL = try AppSupportPaths.settingsFile(base: base)
        try data.write(to: settingsURL)

        let store = SettingsStore(baseDirectory: base)
        let s = store.load()
        XCTAssertEqual(s.openAIKey, "sk-old")
        XCTAssertEqual(s.transcriptionModel, "whisper-1")
        XCTAssertEqual(s.cleanupModel, "gpt-4o-mini")
        XCTAssertEqual(s.cleanupPrompt, "Fix grammar")
        XCTAssertTrue(s.keepAudioFiles)
        XCTAssertEqual(s.hotkey, "ctrl+shift+space")
        // New fields should have sensible defaults
        XCTAssertEqual(s.transcriptionPrompt, "")
        XCTAssertTrue(s.useCleanup)
        XCTAssertFalse(s.showAllModels)
    }

    func testSettingsRoundtripWithNewFields() throws {
        let base = try makeTempBase(function: #function)
        let store = SettingsStore(baseDirectory: base)
        var s = Settings(
            openAIKey: "sk-new",
            transcriptionModel: "whisper-1",
            transcriptionPrompt: "Add punctuation only.",
            cleanupModel: "gpt-4o-mini",
            cleanupPrompt: "Rewrite for clarity.",
            useCleanup: false,
            keepAudioFiles: false,
            hotkey: "ctrl+alt+d",
            knownTranscriptionModels: ["whisper-1"],
            knownCleanupModels: ["gpt-4o-mini"],
            lastModelRefresh: Date(timeIntervalSince1970: 12345),
            showAllModels: true
        )
        try store.save(s)
        let loaded = store.load()
        XCTAssertEqual(loaded.openAIKey, s.openAIKey)
        XCTAssertEqual(loaded.transcriptionModel, s.transcriptionModel)
        XCTAssertEqual(loaded.transcriptionPrompt, s.transcriptionPrompt)
        XCTAssertEqual(loaded.cleanupModel, s.cleanupModel)
        XCTAssertEqual(loaded.cleanupPrompt, s.cleanupPrompt)
        XCTAssertEqual(loaded.useCleanup, s.useCleanup)
        XCTAssertEqual(loaded.keepAudioFiles, s.keepAudioFiles)
        XCTAssertEqual(loaded.hotkey, s.hotkey)
        XCTAssertEqual(loaded.showAllModels, s.showAllModels)
    }
}

