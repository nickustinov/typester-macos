import Cocoa

let appVersion = "1.0.1"
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
