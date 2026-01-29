import Cocoa
import ServiceManagement
import Security

extension Notification.Name {
    static let settingsChanged = Notification.Name("settingsChanged")
}

class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @Published var launchAtLogin: Bool = false {
        didSet {
            if launchAtLogin {
                try? SMAppService.mainApp.register()
            } else {
                try? SMAppService.mainApp.unregister()
            }
        }
    }

    @Published var shortcutKeys: ShortcutKeys = .defaultTripleCmd {
        didSet {
            saveShortcutKeys()
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    @Published var activationMode: ActivationMode = .pressToSpeak {
        didSet {
            saveActivationMode()
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    @Published var languageHints: [String] = [] {
        didSet {
            saveLanguageHints()
        }
    }

    @Published var selectedMicrophoneID: String? = nil {
        didSet {
            saveSelectedMicrophone()
        }
    }

    @Published var dictionaryTerms: [String] = [] {
        didSet {
            saveDictionaryTerms()
        }
    }

    private let shortcutKeysKey = "shortcutKeys"
    private let activationModeKey = "activationMode"
    private let languageHintsKey = "languageHints"
    private let selectedMicrophoneKey = "selectedMicrophone"
    private let dictionaryTermsKey = "dictionaryTerms"
    private let keychainService = "com.typester.api"
    private let keychainAccount = "soniox-api-key"

    private init() {
        loadShortcutKeys()
        loadActivationMode()
        loadLanguageHints()
        loadSelectedMicrophone()
        loadDictionaryTerms()
        syncLaunchAtLoginStatus()
    }

    func syncLaunchAtLoginStatus() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    // MARK: - Shortcut keys (UserDefaults)

    private func loadShortcutKeys() {
        guard let data = UserDefaults.standard.data(forKey: shortcutKeysKey),
              let keys = try? JSONDecoder().decode(ShortcutKeys.self, from: data) else {
            return
        }
        shortcutKeys = keys
    }

    private func saveShortcutKeys() {
        guard let data = try? JSONEncoder().encode(shortcutKeys) else { return }
        UserDefaults.standard.set(data, forKey: shortcutKeysKey)
    }

    private func loadActivationMode() {
        guard let rawValue = UserDefaults.standard.string(forKey: activationModeKey),
              let mode = ActivationMode(rawValue: rawValue) else {
            return
        }
        activationMode = mode
    }

    private func saveActivationMode() {
        UserDefaults.standard.set(activationMode.rawValue, forKey: activationModeKey)
    }

    private func loadLanguageHints() {
        if let hints = UserDefaults.standard.stringArray(forKey: languageHintsKey) {
            languageHints = hints
        }
    }

    private func saveLanguageHints() {
        UserDefaults.standard.set(languageHints, forKey: languageHintsKey)
    }

    private func loadSelectedMicrophone() {
        selectedMicrophoneID = UserDefaults.standard.string(forKey: selectedMicrophoneKey)
    }

    private func saveSelectedMicrophone() {
        UserDefaults.standard.set(selectedMicrophoneID, forKey: selectedMicrophoneKey)
    }

    private func loadDictionaryTerms() {
        if let terms = UserDefaults.standard.stringArray(forKey: dictionaryTermsKey) {
            dictionaryTerms = terms
        }
    }

    private func saveDictionaryTerms() {
        UserDefaults.standard.set(dictionaryTerms, forKey: dictionaryTermsKey)
    }

    // MARK: - API key (Keychain)

    var apiKey: String? {
        get { getKeychainItem() }
        set {
            if let value = newValue {
                setKeychainItem(value)
            } else {
                deleteKeychainItem()
            }
            objectWillChange.send()
        }
    }

    private func getKeychainItem() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }

    private func setKeychainItem(_ value: String) {
        deleteKeychainItem()

        guard let data = value.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        SecItemAdd(query as CFDictionary, nil)
    }

    private func deleteKeychainItem() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]

        SecItemDelete(query as CFDictionary)
    }
}
