import XCTest
@testable import WhisperpasteCore
import Foundation

final class HistoryStoreTests: XCTestCase {
    func testAppendAndLoad() throws {
        let base = try makeTempBase(function: #function)
        let store = HistoryStore(baseDirectory: base)
        let rec = TranscriptionRecord(rawText: "raw", cleanedText: "clean")
        try store.append(rec)
        let all = store.load()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.rawText, "raw")
    }

    func testCleanMissingAudioReferences() throws {
        let base = try makeTempBase(function: #function)
        let store = HistoryStore(baseDirectory: base)
        // existing file
        let audioDir = try AppSupportPaths.audioDirectory(base: base)
        let goodPath = audioDir.appendingPathComponent("good.caf").path
        FileManager.default.createFile(atPath: goodPath, contents: Data(), attributes: nil)

        let good = TranscriptionRecord(rawText: "raw1", cleanedText: "c1", audioFilePath: goodPath)
        let missing = TranscriptionRecord(rawText: "raw2", cleanedText: "c2", audioFilePath: audioDir.appendingPathComponent("missing.caf").path)
        try store.append(good)
        try store.append(missing)

        try store.cleanMissingAudioReferences()
        let after = store.load()
        XCTAssertEqual(after.count, 1)
        XCTAssertEqual(after.first?.audioFilePath, goodPath)
    }

    func testClearAllRemovesHistory() throws {
        let base = try makeTempBase(function: #function)
        let store = HistoryStore(baseDirectory: base)
        try store.append(TranscriptionRecord(rawText: "a", cleanedText: "a"))
        try store.append(TranscriptionRecord(rawText: "b", cleanedText: "b"))
        XCTAssertEqual(store.load().count, 2)
        try store.clearAll()
        XCTAssertEqual(store.load().count, 0)
    }

    func testClearAllAudioReferencesDeletesFilesWhenRequested() throws {
        let base = try makeTempBase(function: #function)
        let store = HistoryStore(baseDirectory: base)
        let audioDir = try AppSupportPaths.audioDirectory(base: base)
        let p1 = audioDir.appendingPathComponent("one.m4a").path
        let p2 = audioDir.appendingPathComponent("two.m4a").path
        FileManager.default.createFile(atPath: p1, contents: Data(), attributes: nil)
        FileManager.default.createFile(atPath: p2, contents: Data(), attributes: nil)
        try store.append(TranscriptionRecord(rawText: "a", cleanedText: "a", audioFilePath: p1))
        try store.append(TranscriptionRecord(rawText: "b", cleanedText: "b", audioFilePath: p2))
        try store.clearAllAudioReferences(deleteFiles: true)
        let after = store.load()
        XCTAssertEqual(after.count, 2)
        XCTAssertNil(after[0].audioFilePath)
        XCTAssertNil(after[1].audioFilePath)
        XCTAssertFalse(FileManager.default.fileExists(atPath: p1))
        XCTAssertFalse(FileManager.default.fileExists(atPath: p2))
    }

    func testClearAllAudioReferencesKeepsFilesWhenDisabled() throws {
        let base = try makeTempBase(function: #function)
        let store = HistoryStore(baseDirectory: base)
        let audioDir = try AppSupportPaths.audioDirectory(base: base)
        let p = audioDir.appendingPathComponent("keep.m4a").path
        FileManager.default.createFile(atPath: p, contents: Data(), attributes: nil)
        try store.append(TranscriptionRecord(rawText: "a", cleanedText: "a", audioFilePath: p))
        try store.clearAllAudioReferences(deleteFiles: false)
        let after = store.load()
        XCTAssertNil(after.first?.audioFilePath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: p))
    }
}
