import XCTest
@testable import Whisper2Core

final class HotkeyTests: XCTestCase {
    func testParseSimple() {
        let hk = Hotkey.parse("ctrl+shift+space")
        XCTAssertNotNil(hk)
        XCTAssertEqual(hk?.ctrl, true)
        XCTAssertEqual(hk?.shift, true)
        XCTAssertEqual(hk?.alt, false)
        XCTAssertEqual(hk?.cmd, false)
        XCTAssertEqual(hk?.key, "space")
        XCTAssertEqual(hk?.description, "ctrl+shift+space")
    }

    func testParseLetterUppercaseNormalized() {
        let hk = Hotkey.parse("cmd+Alt+s")
        XCTAssertEqual(hk?.cmd, true)
        XCTAssertEqual(hk?.alt, true)
        XCTAssertEqual(hk?.key, "S")
        XCTAssertEqual(hk?.description, "alt+cmd+S")
    }

    func testInvalid() {
        XCTAssertNil(Hotkey.parse("ctrl+shift"))
        XCTAssertNil(Hotkey.parse(""))
    }
}

