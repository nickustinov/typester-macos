import Cocoa
import SwiftUI
import Carbon.HIToolbox

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?

    private let audioRecorder = AudioRecorder()
    private let sonioxClient = SonioxClient()
    private let textPaster = TextPaster()

    private var isRecording = false
    private var accumulatedText = ""
    private var normalIcon: NSImage?
    private var recordingIcon: NSImage?

    // MARK: - App lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupIcons()
        setupStatusItem()
        setupHotkey()
        setupAudioPipeline()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsChanged),
            name: .settingsChanged,
            object: nil
        )
    }

    @objc private func settingsChanged() {
        HotkeyManager.shared.registerHotkey()
        rebuildMenu()
    }

    // MARK: - Icons

    private func setupIcons() {
        setAppIcon()
        normalIcon = loadMenuBarIcon()
        recordingIcon = createRecordingIcon()
    }

    private func setAppIcon() {
        let devPaths = [
            FileManager.default.currentDirectoryPath + "/Assets/AppIcon.icns",
            (ProcessInfo.processInfo.environment["PWD"] ?? "") + "/Assets/AppIcon.icns"
        ]

        for path in devPaths {
            if let image = NSImage(contentsOfFile: path) {
                NSApp.applicationIconImage = image
                return
            }
        }
    }

    private func loadMenuBarIcon() -> NSImage {
        let devPaths = [
            FileManager.default.currentDirectoryPath + "/Assets/MenuBarIcon.png",
            (ProcessInfo.processInfo.environment["PWD"] ?? "") + "/Assets/MenuBarIcon.png"
        ]

        for path in devPaths {
            if let image = NSImage(contentsOfFile: path) {
                image.isTemplate = true
                image.size = NSSize(width: 18, height: 18)
                return image
            }
        }

        // Fallback: simple mic shape
        return createFallbackIcon()
    }

    private func createRecordingIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.systemRed.setFill()
            let circle = NSBezierPath(ovalIn: rect.insetBy(dx: 3, dy: 3))
            circle.fill()
            return true
        }
        image.isTemplate = false
        return image
    }

    private func createFallbackIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { _ in
            let path = NSBezierPath()
            path.move(to: NSPoint(x: 9, y: 4))
            path.line(to: NSPoint(x: 9, y: 14))
            path.move(to: NSPoint(x: 5, y: 10))
            path.appendArc(withCenter: NSPoint(x: 9, y: 10), radius: 4, startAngle: 180, endAngle: 0, clockwise: true)
            path.lineWidth = 1.5
            path.lineCapStyle = .round
            NSColor.black.setStroke()
            path.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }

    // MARK: - Status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = normalIcon
        }

        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let title = isRecording ? "Stop" : "Dictate"
        let shortcut = shortcutDisplayString()
        let recordItem = NSMenuItem(
            title: title,
            action: #selector(toggleRecording),
            keyEquivalent: ""
        )

        if !shortcut.isEmpty {
            let attributed = NSMutableAttributedString(string: "\(title)  \(shortcut)")
            let shortcutRange = NSRange(location: title.count + 2, length: shortcut.count)
            attributed.addAttribute(NSAttributedString.Key.foregroundColor, value: NSColor.tertiaryLabelColor, range: shortcutRange)
            recordItem.attributedTitle = attributed
        }

        menu.addItem(recordItem)

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(
            title: "Settings...",
            action: #selector(openSettings),
            keyEquivalent: ""
        ))

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(
            title: "Quit Typester",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: ""
        ))

        statusItem.menu = menu
    }

    // MARK: - Hotkey

    private func setupHotkey() {
        HotkeyManager.shared.onHotkeyTriggered = { [weak self] in
            self?.toggleRecording()
        }
        HotkeyManager.shared.registerHotkey()
    }

    // MARK: - Audio pipeline

    private func setupAudioPipeline() {
        audioRecorder.onAudioBuffer = { [weak self] data in
            self?.sonioxClient.sendAudio(data)
        }

        audioRecorder.onError = { [weak self] error in
            self?.stopRecording()
        }

        sonioxClient.onConnected = { [weak self] in
            self?.audioRecorder.startRecording()
        }

        sonioxClient.onDisconnected = { [weak self] in
            self?.stopRecording()
        }

        sonioxClient.onTranscript = { [weak self] text, isFinal in
            if isFinal {
                self?.accumulatedText += text
            }
        }

        sonioxClient.onEndpoint = { [weak self] in
            guard let self = self else { return }
            let text = self.accumulatedText.trimmingCharacters(in: .whitespaces)
            if !text.isEmpty {
                self.textPaster.paste(text + " ")
                self.accumulatedText = ""
            }
        }

        sonioxClient.onError = { [weak self] error in
            self?.stopRecording()
        }
    }

    // MARK: - Recording control

    @objc func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        guard !isRecording else { return }
        guard SettingsStore.shared.apiKey != nil else {
            openSettings()
            return
        }

        isRecording = true
        statusItem.button?.image = recordingIcon
        accumulatedText = ""
        rebuildMenu()

        sonioxClient.connect()
    }

    private func stopRecording() {
        guard isRecording else { return }

        isRecording = false
        statusItem.button?.image = normalIcon
        rebuildMenu()

        audioRecorder.stopRecording()
        sonioxClient.finishAudio()
        sonioxClient.disconnect()

        // Paste any remaining accumulated text
        let text = accumulatedText.trimmingCharacters(in: .whitespaces)
        if !text.isEmpty {
            textPaster.paste(text)
        }
        accumulatedText = ""
    }

    // MARK: - Shortcut display

    private func shortcutDisplayString() -> String {
        let keys = SettingsStore.shared.shortcutKeys
        if keys.isTripleTap {
            switch keys.tapModifier {
            case "command": return "⌘⌘⌘"
            case "option": return "⌥⌥⌥"
            case "control": return "⌃⌃⌃"
            case "shift": return "⇧⇧⇧"
            default: return ""
            }
        }

        // Regular keyboard shortcut
        var result = ""
        let modifiers = NSEvent.ModifierFlags(rawValue: keys.modifiers)
        if modifiers.contains(.control) { result += "⌃" }
        if modifiers.contains(.option) { result += "⌥" }
        if modifiers.contains(.shift) { result += "⇧" }
        if modifiers.contains(.command) { result += "⌘" }

        if let char = keyCodeToCharacter(keys.keyCode) {
            result += char.uppercased()
        }

        return result
    }

    private func keyCodeToCharacter(_ keyCode: UInt16) -> String? {
        let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        guard let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }
        let dataRef = unsafeBitCast(layoutData, to: CFData.self)
        let keyboardLayout = unsafeBitCast(CFDataGetBytePtr(dataRef), to: UnsafePointer<UCKeyboardLayout>.self)

        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length: Int = 0

        let result = UCKeyTranslate(
            keyboardLayout,
            keyCode,
            UInt16(kUCKeyActionDown),
            0,
            UInt32(LMGetKbdType()),
            OptionBits(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            chars.count,
            &length,
            &chars
        )

        guard result == noErr && length > 0 else { return nil }
        return String(utf16CodeUnits: chars, count: length)
    }

    // MARK: - Settings

    @objc private func openSettings() {
        if settingsWindow == nil {
            let hostingController = NSHostingController(rootView: SettingsView())
            let window = NSWindow(contentViewController: hostingController)
            window.title = "Settings"
            window.styleMask = [.titled, .closable]
            window.center()
            window.setFrameAutosaveName("SettingsWindow")
            window.delegate = self
            settingsWindow = window
        }

        setupMainMenu()

        // Menu bar apps need .regular policy for text input to work
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }

        settingsWindow?.level = .floating
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.settingsWindow?.level = .normal
        }
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // App menu
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "Quit Typester", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // Edit menu (enables Cmd+C, Cmd+V, Cmd+A, etc.)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        let editMenuItem = NSMenuItem()
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
    }

    func windowWillClose(_ notification: Notification) {
        // Reset to accessory policy when settings closes (menu bar app behavior)
        if NSApp.activationPolicy() == .regular {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
