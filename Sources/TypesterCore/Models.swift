import Cocoa

let appVersion = "1.2.0"

enum ActivationMode: String, Codable, CaseIterable {
    case hotkey = "hotkey"
    case pressToSpeak = "pressToSpeak"
}

struct SupportedLanguage {
    let code: String
    let name: String
    let flag: String
    let isPopular: Bool

    init(code: String, name: String, flag: String, isPopular: Bool = false) {
        self.code = code
        self.name = name
        self.flag = flag
        self.isPopular = isPopular
    }
}

let supportedLanguages: [SupportedLanguage] = {
    let popular: [SupportedLanguage] = [
        SupportedLanguage(code: "en", name: "English", flag: "🇺🇸", isPopular: true),
        SupportedLanguage(code: "es", name: "Spanish", flag: "🇪🇸", isPopular: true),
        SupportedLanguage(code: "zh", name: "Chinese", flag: "🇨🇳", isPopular: true),
        SupportedLanguage(code: "fr", name: "French", flag: "🇫🇷", isPopular: true),
        SupportedLanguage(code: "de", name: "German", flag: "🇩🇪", isPopular: true),
        SupportedLanguage(code: "pt", name: "Portuguese", flag: "🇵🇹", isPopular: true),
    ]

    let others: [SupportedLanguage] = [
        SupportedLanguage(code: "af", name: "Afrikaans", flag: "🇿🇦"),
        SupportedLanguage(code: "sq", name: "Albanian", flag: "🇦🇱"),
        SupportedLanguage(code: "ar", name: "Arabic", flag: "🇸🇦"),
        SupportedLanguage(code: "az", name: "Azerbaijani", flag: "🇦🇿"),
        SupportedLanguage(code: "eu", name: "Basque", flag: "🇪🇸"),
        SupportedLanguage(code: "be", name: "Belarusian", flag: "🇧🇾"),
        SupportedLanguage(code: "bn", name: "Bengali", flag: "🇧🇩"),
        SupportedLanguage(code: "bs", name: "Bosnian", flag: "🇧🇦"),
        SupportedLanguage(code: "bg", name: "Bulgarian", flag: "🇧🇬"),
        SupportedLanguage(code: "ca", name: "Catalan", flag: "🇪🇸"),
        SupportedLanguage(code: "hr", name: "Croatian", flag: "🇭🇷"),
        SupportedLanguage(code: "cs", name: "Czech", flag: "🇨🇿"),
        SupportedLanguage(code: "da", name: "Danish", flag: "🇩🇰"),
        SupportedLanguage(code: "nl", name: "Dutch", flag: "🇳🇱"),
        SupportedLanguage(code: "et", name: "Estonian", flag: "🇪🇪"),
        SupportedLanguage(code: "fi", name: "Finnish", flag: "🇫🇮"),
        SupportedLanguage(code: "gl", name: "Galician", flag: "🇪🇸"),
        SupportedLanguage(code: "el", name: "Greek", flag: "🇬🇷"),
        SupportedLanguage(code: "gu", name: "Gujarati", flag: "🇮🇳"),
        SupportedLanguage(code: "he", name: "Hebrew", flag: "🇮🇱"),
        SupportedLanguage(code: "hi", name: "Hindi", flag: "🇮🇳"),
        SupportedLanguage(code: "hu", name: "Hungarian", flag: "🇭🇺"),
        SupportedLanguage(code: "id", name: "Indonesian", flag: "🇮🇩"),
        SupportedLanguage(code: "it", name: "Italian", flag: "🇮🇹"),
        SupportedLanguage(code: "ja", name: "Japanese", flag: "🇯🇵"),
        SupportedLanguage(code: "kn", name: "Kannada", flag: "🇮🇳"),
        SupportedLanguage(code: "kk", name: "Kazakh", flag: "🇰🇿"),
        SupportedLanguage(code: "ko", name: "Korean", flag: "🇰🇷"),
        SupportedLanguage(code: "lv", name: "Latvian", flag: "🇱🇻"),
        SupportedLanguage(code: "lt", name: "Lithuanian", flag: "🇱🇹"),
        SupportedLanguage(code: "mk", name: "Macedonian", flag: "🇲🇰"),
        SupportedLanguage(code: "ms", name: "Malay", flag: "🇲🇾"),
        SupportedLanguage(code: "ml", name: "Malayalam", flag: "🇮🇳"),
        SupportedLanguage(code: "mr", name: "Marathi", flag: "🇮🇳"),
        SupportedLanguage(code: "no", name: "Norwegian", flag: "🇳🇴"),
        SupportedLanguage(code: "fa", name: "Persian", flag: "🇮🇷"),
        SupportedLanguage(code: "pl", name: "Polish", flag: "🇵🇱"),
        SupportedLanguage(code: "pa", name: "Punjabi", flag: "🇮🇳"),
        SupportedLanguage(code: "ro", name: "Romanian", flag: "🇷🇴"),
        SupportedLanguage(code: "ru", name: "Russian", flag: "🇷🇺"),
        SupportedLanguage(code: "sr", name: "Serbian", flag: "🇷🇸"),
        SupportedLanguage(code: "sk", name: "Slovak", flag: "🇸🇰"),
        SupportedLanguage(code: "sl", name: "Slovenian", flag: "🇸🇮"),
        SupportedLanguage(code: "sw", name: "Swahili", flag: "🇰🇪"),
        SupportedLanguage(code: "sv", name: "Swedish", flag: "🇸🇪"),
        SupportedLanguage(code: "tl", name: "Tagalog", flag: "🇵🇭"),
        SupportedLanguage(code: "ta", name: "Tamil", flag: "🇱🇰"),
        SupportedLanguage(code: "te", name: "Telugu", flag: "🇮🇳"),
        SupportedLanguage(code: "th", name: "Thai", flag: "🇹🇭"),
        SupportedLanguage(code: "tr", name: "Turkish", flag: "🇹🇷"),
        SupportedLanguage(code: "uk", name: "Ukrainian", flag: "🇺🇦"),
        SupportedLanguage(code: "ur", name: "Urdu", flag: "🇵🇰"),
        SupportedLanguage(code: "vi", name: "Vietnamese", flag: "🇻🇳"),
        SupportedLanguage(code: "cy", name: "Welsh", flag: "🏴󠁧󠁢󠁷󠁬󠁳󠁿"),
    ]

    return popular + others
}()
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
