import XCTest
@testable import Whisper2Core
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
}
