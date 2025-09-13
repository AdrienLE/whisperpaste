import XCTest
@testable import WhisperpasteCore

final class ModelFilteringTests: XCTestCase {
    func testPartitionModelsDefaultsWhenEmpty() {
        let (trans, clean) = ModelFiltering.partition(models: [])
        XCTAssertTrue(trans.contains("whisper-1"))
        XCTAssertTrue(clean.contains("gpt-4o-mini"))
    }

    func testPartitionModelsSeparatesTranscriptionAndCleanup() {
        let models = ["gpt-4o", "gpt-4o-mini", "whisper-1", "some-transcribe-model", "gpt-realtime-preview"]
        let (trans, clean) = ModelFiltering.partition(models: models)
        XCTAssertTrue(trans.contains { $0.contains("whisper") || $0.contains("transcribe") })
        XCTAssertTrue(clean.allSatisfy { $0.hasPrefix("gpt-") })
        // Ensure excluded types do not appear in cleanup
        XCTAssertFalse(clean.contains(where: { $0.contains("realtime") }))
    }

    func testFilteredHidesPreviewAndTwoDigitSuffix() {
        let models = ["gpt-4o", "gpt-4o-preview", "gpt-4o-24", "gpt-4o-mini", "whisper-1", "gpt-4o-2024-08"]
        let filtered = ModelFiltering.filtered(models, includeAll: false)
        XCTAssertFalse(filtered.contains("gpt-4o-preview"))
        XCTAssertFalse(filtered.contains("gpt-4o-24"))
        // Model ending with -08 should be filtered out due to two-digit suffix
        XCTAssertFalse(filtered.contains("gpt-4o-2024-08"))
        XCTAssertTrue(filtered.contains("gpt-4o"))
        XCTAssertTrue(filtered.contains("gpt-4o-mini"))
        XCTAssertTrue(filtered.contains("whisper-1"))
    }

    func testFilteredIncludeAllKeepsEverything() {
        let models = ["gpt-4o-preview", "gpt-4o-24", "whisper-1"]
        let filtered = ModelFiltering.filtered(models, includeAll: true)
        XCTAssertEqual(Set(filtered), Set(models))
    }
}

