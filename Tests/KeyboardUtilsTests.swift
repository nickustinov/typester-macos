import XCTest
import Carbon.HIToolbox
import AppKit
@testable import TypesterCore

final class KeyboardUtilsTests: XCTestCase {

    // MARK: - keyCodeToString tests for special keys

    func testKeyCodeToStringReturn() {
        XCTAssertEqual(KeyboardUtils.keyCodeToString(UInt16(kVK_Return)), "↩")
    }

    func testKeyCodeToStringTab() {
        XCTAssertEqual(KeyboardUtils.keyCodeToString(UInt16(kVK_Tab)), "⇥")
    }

    func testKeyCodeToStringSpace() {
        XCTAssertEqual(KeyboardUtils.keyCodeToString(UInt16(kVK_Space)), "Space")
    }

    func testKeyCodeToStringDelete() {
        XCTAssertEqual(KeyboardUtils.keyCodeToString(UInt16(kVK_Delete)), "⌫")
    }

    func testKeyCodeToStringEscape() {
        XCTAssertEqual(KeyboardUtils.keyCodeToString(UInt16(kVK_Escape)), "⎋")
    }

    func testKeyCodeToStringForwardDelete() {
        XCTAssertEqual(KeyboardUtils.keyCodeToString(UInt16(kVK_ForwardDelete)), "⌦")
    }

    // MARK: - Arrow keys

    func testKeyCodeToStringLeftArrow() {
        XCTAssertEqual(KeyboardUtils.keyCodeToString(UInt16(kVK_LeftArrow)), "←")
    }

    func testKeyCodeToStringRightArrow() {
        XCTAssertEqual(KeyboardUtils.keyCodeToString(UInt16(kVK_RightArrow)), "→")
    }

    func testKeyCodeToStringUpArrow() {
        XCTAssertEqual(KeyboardUtils.keyCodeToString(UInt16(kVK_UpArrow)), "↑")
    }

    func testKeyCodeToStringDownArrow() {
        XCTAssertEqual(KeyboardUtils.keyCodeToString(UInt16(kVK_DownArrow)), "↓")
    }

    // MARK: - Navigation keys

    func testKeyCodeToStringHome() {
        XCTAssertEqual(KeyboardUtils.keyCodeToString(UInt16(kVK_Home)), "↖")
    }

    func testKeyCodeToStringEnd() {
        XCTAssertEqual(KeyboardUtils.keyCodeToString(UInt16(kVK_End)), "↘")
    }

    func testKeyCodeToStringPageUp() {
        XCTAssertEqual(KeyboardUtils.keyCodeToString(UInt16(kVK_PageUp)), "⇞")
    }

    func testKeyCodeToStringPageDown() {
        XCTAssertEqual(KeyboardUtils.keyCodeToString(UInt16(kVK_PageDown)), "⇟")
    }

    // MARK: - Function keys

    func testKeyCodeToStringFunctionKeys() {
        XCTAssertEqual(KeyboardUtils.keyCodeToString(UInt16(kVK_F1)), "F1")
        XCTAssertEqual(KeyboardUtils.keyCodeToString(UInt16(kVK_F2)), "F2")
        XCTAssertEqual(KeyboardUtils.keyCodeToString(UInt16(kVK_F3)), "F3")
        XCTAssertEqual(KeyboardUtils.keyCodeToString(UInt16(kVK_F4)), "F4")
        XCTAssertEqual(KeyboardUtils.keyCodeToString(UInt16(kVK_F5)), "F5")
        XCTAssertEqual(KeyboardUtils.keyCodeToString(UInt16(kVK_F6)), "F6")
        XCTAssertEqual(KeyboardUtils.keyCodeToString(UInt16(kVK_F7)), "F7")
        XCTAssertEqual(KeyboardUtils.keyCodeToString(UInt16(kVK_F8)), "F8")
        XCTAssertEqual(KeyboardUtils.keyCodeToString(UInt16(kVK_F9)), "F9")
        XCTAssertEqual(KeyboardUtils.keyCodeToString(UInt16(kVK_F10)), "F10")
        XCTAssertEqual(KeyboardUtils.keyCodeToString(UInt16(kVK_F11)), "F11")
        XCTAssertEqual(KeyboardUtils.keyCodeToString(UInt16(kVK_F12)), "F12")
    }

    // MARK: - formatShortcutDisplay tests

    func testFormatShortcutDisplayCommandOnly() {
        let modifiers = NSEvent.ModifierFlags.command
        let display = KeyboardUtils.formatShortcutDisplay(modifiers: modifiers, keyCode: UInt16(kVK_Return))
        XCTAssertTrue(display.contains("⌘"))
        XCTAssertTrue(display.contains("↩"))
    }

    func testFormatShortcutDisplayModifierOrder() {
        // Modifiers should be in order: ⌃⌥⇧⌘
        let modifiers: NSEvent.ModifierFlags = [.control, .option, .shift, .command]
        let display = KeyboardUtils.formatShortcutDisplay(modifiers: modifiers, keyCode: UInt16(kVK_Space))

        // Check order by finding indices
        let controlIndex = display.firstIndex(of: "⌃")!
        let optionIndex = display.firstIndex(of: "⌥")!
        let shiftIndex = display.firstIndex(of: "⇧")!
        let commandIndex = display.firstIndex(of: "⌘")!

        XCTAssertLessThan(controlIndex, optionIndex)
        XCTAssertLessThan(optionIndex, shiftIndex)
        XCTAssertLessThan(shiftIndex, commandIndex)
    }

    func testFormatShortcutDisplayControlOption() {
        let modifiers: NSEvent.ModifierFlags = [.control, .option]
        let display = KeyboardUtils.formatShortcutDisplay(modifiers: modifiers, keyCode: UInt16(kVK_Tab))

        XCTAssertTrue(display.hasPrefix("⌃⌥"))
        XCTAssertTrue(display.contains("⇥"))
    }

    func testFormatShortcutDisplayShiftCommand() {
        let modifiers: NSEvent.ModifierFlags = [.shift, .command]
        let display = KeyboardUtils.formatShortcutDisplay(modifiers: modifiers, keyCode: UInt16(kVK_Delete))

        XCTAssertTrue(display.contains("⇧"))
        XCTAssertTrue(display.contains("⌘"))
        XCTAssertTrue(display.contains("⌫"))
    }

    // MARK: - formatTripleTapDisplay tests

    func testFormatTripleTapDisplayCommand() {
        XCTAssertEqual(KeyboardUtils.formatTripleTapDisplay(modifier: "command"), "⌘⌘⌘")
    }

    func testFormatTripleTapDisplayOption() {
        XCTAssertEqual(KeyboardUtils.formatTripleTapDisplay(modifier: "option"), "⌥⌥⌥")
    }

    func testFormatTripleTapDisplayControl() {
        XCTAssertEqual(KeyboardUtils.formatTripleTapDisplay(modifier: "control"), "⌃⌃⌃")
    }

    func testFormatTripleTapDisplayShift() {
        XCTAssertEqual(KeyboardUtils.formatTripleTapDisplay(modifier: "shift"), "⇧⇧⇧")
    }

    func testFormatTripleTapDisplayUnknownReturnsEmpty() {
        XCTAssertEqual(KeyboardUtils.formatTripleTapDisplay(modifier: "unknown"), "")
    }
}
