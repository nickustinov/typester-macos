import Cocoa
import SwiftUI
import Carbon.HIToolbox
import AVFoundation
import CoreAudio

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?

    private let audioRecorder = AudioRecorder()
    private let textPaster = TextPaster()
    private var sttProvider: STTProvider!

    private func createSTTProvider() -> STTProvider {
        switch SettingsStore.shared.sttProvider {
        case .soniox:
            return SonioxClient()
        case .deepgram:
            return DeepgramClient()
        }
    }

    private var isRecording = false
    private var accumulatedText = ""
    private var normalIcon: NSImage?
    private var recordingIcon: NSImage?

    // MARK: - App lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        sttProvider = createSTTProvider()
        setupIcons()
        setupStatusItem()
        setupHotkey()
        setupFnKeyMonitor()
        setupAudioPipeline()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsChanged),
            name: .settingsChanged,
            object: nil
        )

        // Show onboarding if not set up, otherwise start monitoring
        if SettingsStore.shared.apiKey == nil {
            showOnboarding()
        } else {
            updateMonitoringMode()
        }
    }

    @objc private func settingsChanged() {
        HotkeyManager.shared.registerHotkey()
        updateMonitoringMode()
        updateSTTProvider()
        rebuildMenu()
    }

    private func updateSTTProvider() {
        switch SettingsStore.shared.sttProvider {
        case .soniox:
            if sttProvider is SonioxClient { return }
        case .deepgram:
            if sttProvider is DeepgramClient { return }
        }

        // Disconnect old provider
        sttProvider.disconnect()

        // Setup new provider with same callbacks
        sttProvider = createSTTProvider()
        setupSTTCallbacks()
    }

    private func setupSTTCallbacks() {
        sttProvider.onConnected = {
            Debug.log("STT connected, buffered audio flushed")
        }

        sttProvider.onDisconnected = { [weak self] in
            guard let self = self, self.isRecording else { return }
            self.isRecording = false
            self.statusItem.button?.image = self.normalIcon
            self.rebuildMenu()
        }

        sttProvider.onTranscript = { [weak self] text, isFinal in
            if isFinal {
                self?.accumulatedText += text
            }
        }

        sttProvider.onEndpoint = { [weak self] in
            guard let self = self else { return }
            let text = self.accumulatedText.trimmingCharacters(in: .whitespaces)
            if !text.isEmpty {
                self.textPaster.paste(text + " ")
                self.accumulatedText = ""
            }
        }

        sttProvider.onFinalized = { [weak self] in
            guard let self = self else { return }
            let text = self.accumulatedText.trimmingCharacters(in: .whitespaces)
            if !text.isEmpty {
                self.textPaster.paste(text + " ")
                self.accumulatedText = ""
            }
            self.sttProvider.disconnect()
        }

        sttProvider.onError = { [weak self] error in
            guard let self = self else { return }
            self.isRecording = false
            self.statusItem.button?.image = self.normalIcon
            self.rebuildMenu()
            self.audioRecorder.stopRecording()
            self.showError(error)
        }
    }

    // MARK: - Icons

    private func setupIcons() {
        setAppIcon()
        normalIcon = loadMenuBarIcon()
        recordingIcon = createRecordingIcon()
    }

    private func setAppIcon() {
        // Try bundle Resources first (release build)
        if let bundlePath = Bundle.main.resourcePath {
            let path = bundlePath + "/AppIcon.icns"
            if let image = NSImage(contentsOfFile: path) {
                NSApp.applicationIconImage = image
                return
            }
        }

        // Try dev paths (swift run)
        var devPaths = [
            FileManager.default.currentDirectoryPath + "/Assets/AppIcon.icns",
            (ProcessInfo.processInfo.environment["PWD"] ?? "") + "/Assets/AppIcon.icns"
        ]

        // Also try relative to executable (for swift run from different directory)
        if let execPath = Bundle.main.executablePath {
            let url = URL(fileURLWithPath: execPath)
                .deletingLastPathComponent() // debug
                .deletingLastPathComponent() // arm64-apple-macosx
                .deletingLastPathComponent() // .build
            devPaths.append(url.path + "/Assets/AppIcon.icns")
        }

        for path in devPaths {
            if let image = NSImage(contentsOfFile: path) {
                NSApp.applicationIconImage = image
                return
            }
        }
    }

    private func loadMenuBarIcon() -> NSImage {
        // Try bundle Resources first (release build)
        if let bundlePath = Bundle.main.resourcePath {
            let path = bundlePath + "/MenuBarIcon.png"
            if let image = NSImage(contentsOfFile: path) {
                image.isTemplate = true
                image.size = NSSize(width: 18, height: 18)
                return image
            }
        }

        // Try dev paths (swift run)
        var devPaths = [
            FileManager.default.currentDirectoryPath + "/Assets/MenuBarIcon.png",
            (ProcessInfo.processInfo.environment["PWD"] ?? "") + "/Assets/MenuBarIcon.png"
        ]

        // Also try relative to executable (for swift run from different directory)
        if let execPath = Bundle.main.executablePath {
            let url = URL(fileURLWithPath: execPath)
                .deletingLastPathComponent() // debug
                .deletingLastPathComponent() // arm64-apple-macosx
                .deletingLastPathComponent() // .build
            devPaths.append(url.path + "/Assets/MenuBarIcon.png")
        }

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

        // Dictate/Stop item
        let title = isRecording ? "Stop" : "Dictate"
        let shortcut = shortcutDisplayString()
        let recordItem = NSMenuItem(
            title: title,
            action: #selector(toggleRecording),
            keyEquivalent: ""
        )

        let attributed = NSMutableAttributedString(string: "\(title)  \(shortcut)")
        let shortcutRange = NSRange(location: title.count + 2, length: shortcut.count)
        attributed.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: shortcutRange)
        recordItem.attributedTitle = attributed

        menu.addItem(recordItem)

        menu.addItem(.separator())

        // Microphone submenu
        let micMenu = NSMenu()
        let inputDevices = getInputDevices()
        let selectedMicID = SettingsStore.shared.selectedMicrophoneID

        let defaultMicItem = NSMenuItem(title: "System default", action: #selector(selectMicrophone(_:)), keyEquivalent: "")
        defaultMicItem.target = self
        defaultMicItem.representedObject = nil
        defaultMicItem.state = selectedMicID == nil ? .on : .off
        micMenu.addItem(defaultMicItem)

        if !inputDevices.isEmpty {
            micMenu.addItem(.separator())
        }

        for device in inputDevices {
            let item = NSMenuItem(title: device.name, action: #selector(selectMicrophone(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = NSNumber(value: device.id)
            item.state = selectedMicID == String(device.id) ? .on : .off
            micMenu.addItem(item)
        }

        let micMenuItem = NSMenuItem(title: "Microphone", action: nil, keyEquivalent: "")
        micMenuItem.submenu = micMenu
        menu.addItem(micMenuItem)

        // Languages submenu (only for Soniox - Deepgram uses auto-detect)
        if SettingsStore.shared.sttProvider == .soniox {
            let langMenu = NSMenu()
            let selectedLangs = Set(SettingsStore.shared.languageHints)

            // Sort: selected languages first, then popular, then rest alphabetically
            let sortedLanguages = supportedLanguages.sorted { a, b in
                let aSelected = selectedLangs.contains(a.code)
                let bSelected = selectedLangs.contains(b.code)
                if aSelected != bSelected { return aSelected }
                if a.isPopular != b.isPopular { return a.isPopular }
                return a.name < b.name
            }

            for lang in sortedLanguages {
                let item = NSMenuItem(
                    title: "\(lang.flag) \(lang.name)",
                    action: #selector(toggleLanguage(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = lang.code
                item.state = selectedLangs.contains(lang.code) ? .on : .off
                langMenu.addItem(item)
            }

            let langMenuItem = NSMenuItem(title: "Languages", action: nil, keyEquivalent: "")
            langMenuItem.submenu = langMenu
            menu.addItem(langMenuItem)
        }

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

    @objc private func selectMicrophone(_ sender: NSMenuItem) {
        if let deviceID = sender.representedObject as? NSNumber {
            SettingsStore.shared.selectedMicrophoneID = String(deviceID.uint32Value)
        } else {
            SettingsStore.shared.selectedMicrophoneID = nil
        }
        rebuildMenu()
    }

    @objc private func toggleLanguage(_ sender: NSMenuItem) {
        guard let code = sender.representedObject as? String else { return }
        var hints = SettingsStore.shared.languageHints

        if hints.contains(code) {
            hints.removeAll { $0 == code }
        } else {
            hints.append(code)
        }

        SettingsStore.shared.languageHints = hints
        rebuildMenu()
    }

    private struct AudioInputDevice {
        let id: AudioDeviceID
        let name: String
    }

    private func getInputDevices() -> [AudioInputDevice] {
        var devices: [AudioInputDevice] = []

        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize) == noErr else {
            return devices
        }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)

        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize, &deviceIDs) == noErr else {
            return devices
        }

        for deviceID in deviceIDs {
            // Check if device has input channels
            var inputAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreamConfiguration,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )

            var inputSize: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(deviceID, &inputAddress, 0, nil, &inputSize) == noErr, inputSize > 0 else {
                continue
            }

            let bufferListPointer = UnsafeMutableRawPointer.allocate(byteCount: Int(inputSize), alignment: MemoryLayout<AudioBufferList>.alignment)
            defer { bufferListPointer.deallocate() }

            guard AudioObjectGetPropertyData(deviceID, &inputAddress, 0, nil, &inputSize, bufferListPointer) == noErr else {
                continue
            }

            let bufferList = bufferListPointer.assumingMemoryBound(to: AudioBufferList.self).pointee
            guard bufferList.mNumberBuffers > 0 else { continue }

            // Get device name
            var nameAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceNameCFString,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )

            var name: Unmanaged<CFString>?
            var nameSize = UInt32(MemoryLayout<CFString?>.size)

            if AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, &name) == noErr,
               let deviceName = name?.takeUnretainedValue() as String? {
                // Check transport type to filter virtual devices
                var transportAddress = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyTransportType,
                    mScope: kAudioObjectPropertyScopeGlobal,
                    mElement: kAudioObjectPropertyElementMain
                )
                var transportType: UInt32 = 0
                var transportSize = UInt32(MemoryLayout<UInt32>.size)

                if AudioObjectGetPropertyData(deviceID, &transportAddress, 0, nil, &transportSize, &transportType) == noErr {
                    // Skip virtual and aggregate devices
                    if transportType == kAudioDeviceTransportTypeVirtual ||
                       transportType == kAudioDeviceTransportTypeAggregate {
                        continue
                    }
                }

                devices.append(AudioInputDevice(id: deviceID, name: deviceName))
            }
        }

        return devices
    }

    // MARK: - Hotkey

    private func setupHotkey() {
        HotkeyManager.shared.onHotkeyTriggered = { [weak self] in
            self?.toggleRecording()
        }
        HotkeyManager.shared.registerHotkey()
    }

    // MARK: - Fn key monitor

    private func setupFnKeyMonitor() {
        FnKeyMonitor.shared.onFnPressed = { [weak self] in
            guard SettingsStore.shared.activationMode == .pressToSpeak else { return }
            self?.startRecording()
        }

        FnKeyMonitor.shared.onFnReleased = { [weak self] in
            guard SettingsStore.shared.activationMode == .pressToSpeak else { return }
            self?.stopRecording()
        }
    }

    private func updateMonitoringMode() {
        switch SettingsStore.shared.activationMode {
        case .hotkey:
            FnKeyMonitor.shared.stop()
        case .pressToSpeak:
            setupFnKeyMonitor()
            FnKeyMonitor.shared.start()
        }
    }

    // MARK: - Audio pipeline

    private func setupAudioPipeline() {
        audioRecorder.onAudioBuffer = { [weak self] data in
            self?.sttProvider.sendAudio(data)
        }

        audioRecorder.onError = { [weak self] error in
            self?.stopRecording()
        }

        setupSTTCallbacks()
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Transcription failed"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "OK")

        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }
        NSApp.activate(ignoringOtherApps: true)

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openSettings()
        } else {
            // Reset to accessory policy if not opening settings
            NSApp.setActivationPolicy(.accessory)
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
        Debug.log("startRecording() called, isRecording=\(isRecording)")
        guard !isRecording else {
            Debug.log("startRecording() SKIPPED - already recording")
            return
        }

        let hasApiKey: Bool
        switch SettingsStore.shared.sttProvider {
        case .soniox:
            hasApiKey = SettingsStore.shared.apiKey != nil
        case .deepgram:
            hasApiKey = SettingsStore.shared.deepgramApiKey != nil
        }

        guard hasApiKey else {
            Debug.log("startRecording() SKIPPED - no API key for \(SettingsStore.shared.sttProvider)")
            openSettings()
            return
        }

        Debug.log("Starting recording...")
        isRecording = true
        statusItem.button?.image = recordingIcon
        accumulatedText = ""
        rebuildMenu()

        // Start audio immediately - it will buffer while WebSocket connects
        audioRecorder.startRecording()
        sttProvider.connect()
    }

    private func stopRecording() {
        Debug.log("stopRecording() called, isRecording=\(isRecording)")
        guard isRecording else {
            Debug.log("stopRecording() SKIPPED - not recording")
            return
        }

        Debug.log("Stopping recording...")
        isRecording = false
        statusItem.button?.image = normalIcon
        rebuildMenu()

        audioRecorder.stopRecording()

        // Small delay to let provider process last audio chunks before finalizing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            Debug.log("Sending finalize after delay")
            self?.sttProvider.sendFinalize()
        }
    }

    // MARK: - Shortcut display

    private func shortcutDisplayString() -> String {
        if SettingsStore.shared.activationMode == .pressToSpeak {
            return "Fn"
        }

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
            window.styleMask = [.titled, .closable, .resizable]
            window.minSize = NSSize(width: 580, height: 500)
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
        // Reset to accessory policy when settings/onboarding closes (menu bar app behavior)
        if NSApp.activationPolicy() == .regular {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    // MARK: - Onboarding

    private func showOnboarding() {
        if onboardingWindow == nil {
            let onboardingView = OnboardingView {
                self.onboardingWindow?.close()
                self.onboardingWindow = nil
                self.updateMonitoringMode()
            }
            let hostingController = NSHostingController(rootView: onboardingView)
            let window = NSWindow(contentViewController: hostingController)
            window.title = "Welcome to Typester"
            window.styleMask = [.titled, .closable]
            window.center()
            window.delegate = self
            onboardingWindow = window
        }

        setupMainMenu()

        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }

        // Set icon after activation policy change
        setAppIcon()

        onboardingWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
