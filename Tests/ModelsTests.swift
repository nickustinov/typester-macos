import XCTest
@testable import TypesterCore

final class ModelsTests: XCTestCase {

    // MARK: - ShortcutKeys tests

    func testShortcutKeysCodable() throws {
        let original = ShortcutKeys(
            modifiers: 256,
            keyCode: 0,
            isTripleTap: false,
            tapModifier: nil
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ShortcutKeys.self, from: encoded)

        XCTAssertEqual(original, decoded)
    }

    func testShortcutKeysEquatable() {
        let keys1 = ShortcutKeys(modifiers: 256, keyCode: 1, isTripleTap: false, tapModifier: nil)
        let keys2 = ShortcutKeys(modifiers: 256, keyCode: 1, isTripleTap: false, tapModifier: nil)
        let keys3 = ShortcutKeys(modifiers: 512, keyCode: 1, isTripleTap: false, tapModifier: nil)

        XCTAssertEqual(keys1, keys2)
        XCTAssertNotEqual(keys1, keys3)
    }

    func testShortcutKeysDefaultTripleCmd() {
        let defaultKeys = ShortcutKeys.defaultTripleCmd

        XCTAssertEqual(defaultKeys.modifiers, 0)
        XCTAssertEqual(defaultKeys.keyCode, 0)
        XCTAssertTrue(defaultKeys.isTripleTap)
        XCTAssertEqual(defaultKeys.tapModifier, "command")
    }

    func testShortcutKeysTripleTapCodable() throws {
        let original = ShortcutKeys(
            modifiers: 0,
            keyCode: 0,
            isTripleTap: true,
            tapModifier: "option"
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ShortcutKeys.self, from: encoded)

        XCTAssertEqual(original, decoded)
        XCTAssertTrue(decoded.isTripleTap)
        XCTAssertEqual(decoded.tapModifier, "option")
    }

    // MARK: - ActivationMode tests

    func testActivationModeRawValues() {
        XCTAssertEqual(ActivationMode.hotkey.rawValue, "hotkey")
        XCTAssertEqual(ActivationMode.pressToSpeak.rawValue, "pressToSpeak")
    }

    func testActivationModeCodable() throws {
        let original = ActivationMode.pressToSpeak

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ActivationMode.self, from: encoded)

        XCTAssertEqual(original, decoded)
    }

    func testActivationModeAllCases() {
        let allCases = ActivationMode.allCases
        XCTAssertEqual(allCases.count, 2)
        XCTAssertTrue(allCases.contains(.hotkey))
        XCTAssertTrue(allCases.contains(.pressToSpeak))
    }

    // MARK: - SupportedLanguage tests

    func testSupportedLanguageInit() {
        let lang = SupportedLanguage(code: "en", name: "English", flag: "🇺🇸")
        XCTAssertEqual(lang.code, "en")
        XCTAssertEqual(lang.name, "English")
        XCTAssertEqual(lang.flag, "🇺🇸")
        XCTAssertFalse(lang.isPopular)
    }

    func testSupportedLanguageIsPopularDefault() {
        let lang = SupportedLanguage(code: "test", name: "Test", flag: "🏳️")
        XCTAssertFalse(lang.isPopular)

        let popularLang = SupportedLanguage(code: "en", name: "English", flag: "🇺🇸", isPopular: true)
        XCTAssertTrue(popularLang.isPopular)
    }

    func testSupportedLanguagesUniqueCodesExist() {
        let codes = supportedLanguages.map { $0.code }
        let uniqueCodes = Set(codes)
        XCTAssertEqual(codes.count, uniqueCodes.count, "Language codes should be unique")
    }

    func testSupportedLanguagesHasPopular() {
        let popularLanguages = supportedLanguages.filter { $0.isPopular }
        XCTAssertGreaterThan(popularLanguages.count, 0, "Should have at least one popular language")
    }

    // MARK: - PressToSpeakKey tests

    func testPressToSpeakKeyRawValues() {
        XCTAssertEqual(PressToSpeakKey.fn.rawValue, "fn")
        XCTAssertEqual(PressToSpeakKey.leftCommand.rawValue, "leftCommand")
        XCTAssertEqual(PressToSpeakKey.rightCommand.rawValue, "rightCommand")
        XCTAssertEqual(PressToSpeakKey.leftOption.rawValue, "leftOption")
        XCTAssertEqual(PressToSpeakKey.rightOption.rawValue, "rightOption")
    }

    func testPressToSpeakKeyDisplayName() {
        XCTAssertEqual(PressToSpeakKey.fn.displayName, "Fn")
        XCTAssertEqual(PressToSpeakKey.leftCommand.displayName, "Left ⌘")
        XCTAssertEqual(PressToSpeakKey.rightCommand.displayName, "Right ⌘")
        XCTAssertEqual(PressToSpeakKey.leftOption.displayName, "Left ⌥")
        XCTAssertEqual(PressToSpeakKey.rightOption.displayName, "Right ⌥")
    }

    func testPressToSpeakKeyCodable() throws {
        for key in PressToSpeakKey.allCases {
            let encoded = try JSONEncoder().encode(key)
            let decoded = try JSONDecoder().decode(PressToSpeakKey.self, from: encoded)
            XCTAssertEqual(key, decoded)
        }
    }

    func testPressToSpeakKeyAllCases() {
        let allCases = PressToSpeakKey.allCases
        XCTAssertEqual(allCases.count, 5)
    }

    // MARK: - STTProviderType tests

    func testSTTProviderTypeRawValues() {
        XCTAssertEqual(STTProviderType.soniox.rawValue, "soniox")
        XCTAssertEqual(STTProviderType.deepgram.rawValue, "deepgram")
    }

    func testSTTProviderTypeDisplayName() {
        XCTAssertEqual(STTProviderType.soniox.displayName, "Soniox")
        XCTAssertEqual(STTProviderType.deepgram.displayName, "Deepgram")
    }

    func testSTTProviderTypeCodable() throws {
        let original = STTProviderType.deepgram

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(STTProviderType.self, from: encoded)

        XCTAssertEqual(original, decoded)
    }

    func testSTTProviderTypeAllCases() {
        let allCases = STTProviderType.allCases
        XCTAssertEqual(allCases.count, 2)
        XCTAssertTrue(allCases.contains(.soniox))
        XCTAssertTrue(allCases.contains(.deepgram))
    }
}
