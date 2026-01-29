import Cocoa

let appVersion = "1.1.0"

enum ActivationMode: String, Codable, CaseIterable {
    case hotkey = "hotkey"
    case pressToSpeak = "pressToSpeak"
}
let githubURL = "https://github.com/nickustinov/typester-macos"

struct ShortcutKeys: Codable, Equatable {
    var modifiers: UInt
    var keyCode: UInt16
    var isTripleTap: Bool
    var tapModifier: String?

    static let defaultTripleCmd = ShortcutKeys(
        modifiers: 0,
        keyCode: 0,
        isTripleTap: true,
        tapModifier: "command"
    )
}
