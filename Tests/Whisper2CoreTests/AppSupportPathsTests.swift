import XCTest
@testable import Whisper2Core
import Foundation

final class AppSupportPathsTests: XCTestCase {
    func testAudioDirectoryCreationUnderBase() throws {
        let base = try makeTempBase(function: #function)
        let dir = try AppSupportPaths.audioDirectory(base: base)
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDir)
        XCTAssertTrue(exists)
        XCTAssertTrue(isDir.boolValue)
    }
}
