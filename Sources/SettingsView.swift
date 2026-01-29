import SwiftUI
import AVFoundation
import Carbon.HIToolbox
import AppKit

struct SettingsView: View {
    @ObservedObject private var settings = SettingsStore.shared
    @State private var apiKeyInput: String = ""
    @State private var showApiKey = false
    @State private var micPermissionGranted = false
    @State private var accessibilityGranted = false
    @State private var showingAddTerm = false

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    Toggle("Open at login", isOn: $settings.launchAtLogin)
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            ZStack {
                                if showApiKey {
                                    SingleLineTextField(text: $apiKeyInput)
                                } else {
                                    SecureField("", text: $apiKeyInput)
                                        .textFieldStyle(.plain)
                                }
                            }

                            Button {
                                showApiKey.toggle()
                            } label: {
                                Image(systemName: showApiKey ? "eye.slash" : "eye")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.borderless)

                            if settings.apiKey != nil && apiKeyInput == settings.apiKey {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }

                        if apiKeyInput != (settings.apiKey ?? "") {
                            HStack {
                                Spacer()
                                Button("Cancel") {
                                    apiKeyInput = settings.apiKey ?? ""
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)

                                Button("Save") {
                                    settings.apiKey = apiKeyInput.isEmpty ? nil : apiKeyInput
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Soniox API key")
                        Spacer()
                        Link("Get key at soniox.com", destination: URL(string: "https://soniox.com")!)
                            .font(.caption)
                    }
                }

                Section("Activation") {
                    Picker("Mode", selection: $settings.activationMode) {
                        Text("Hotkey (toggle)").tag(ActivationMode.hotkey)
                        Text("Fn key (hold to speak)").tag(ActivationMode.pressToSpeak)
                    }
                    .pickerStyle(.radioGroup)

                    if settings.activationMode == .hotkey {
                        ShortcutRecorderView(
                            shortcut: Binding(
                                get: { shortcutDescription },
                                set: { _ in }
                            ),
                            shortcutKeys: Binding(
                                get: { settings.shortcutKeys },
                                set: { if let keys = $0 { settings.shortcutKeys = keys } }
                            )
                        )
                    }
                }

                Section("Permissions") {
                    HStack {
                        Circle()
                            .fill(micPermissionGranted ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)

                        Text("Microphone")

                        Spacer()

                        if micPermissionGranted {
                            Text("Granted").foregroundStyle(.secondary)
                        } else {
                            Button("Request") {
                                requestMicPermission()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }

                    HStack {
                        Circle()
                            .fill(accessibilityGranted ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)

                        Text("Accessibility")

                        Spacer()

                        if accessibilityGranted {
                            Text("Granted").foregroundStyle(.secondary)
                        } else {
                            Button("Open Settings") {
                                TextPaster.openAccessibilitySettings()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }

                Section {
                    ForEach(settings.dictionaryTerms, id: \.self) { term in
                        HStack {
                            Text(term)
                                .lineLimit(1)

                            Spacer()

                            Button {
                                settings.dictionaryTerms.removeAll { $0 == term }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                } header: {
                    HStack {
                        Text("Dictionary")
                        Spacer()
                        Button {
                            showingAddTerm = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16))
                        }
                        .buttonStyle(.borderless)
                    }
                } footer: {
                    Text("Add domain-specific words, names, or technical terms to improve recognition accuracy.")
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Text("Typester \(appVersion)")
                    .foregroundStyle(.secondary)
                Text("·")
                    .foregroundStyle(.tertiary)
                Link("GitHub", destination: URL(string: githubURL)!)
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
            .padding(.vertical, 10)
        }
        .frame(width: 500)
        .frame(minHeight: 500)
        .sheet(isPresented: $showingAddTerm) {
            AddTermView { term in
                if !settings.dictionaryTerms.contains(term) {
                    settings.dictionaryTerms.append(term)
                }
            }
        }
        .onAppear {
            if let key = settings.apiKey {
                apiKeyInput = key
            }
            checkPermissions()
            settings.syncLaunchAtLoginStatus()
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            checkPermissions()
        }
    }

    private func checkPermissions() {
        checkMicPermission()
        accessibilityGranted = TextPaster.checkAccessibilityPermission()
    }

    private var shortcutDescription: String {
        let keys = settings.shortcutKeys
        if keys.isTripleTap {
            switch keys.tapModifier {
            case "command": return "⌘⌘⌘"
            case "option": return "⌥⌥⌥"
            case "control": return "⌃⌃⌃"
            case "shift": return "⇧⇧⇧"
            default: return "⌘⌘⌘"
            }
        }
        return shortcutDisplayString(keys: keys)
    }

    private func shortcutDisplayString(keys: ShortcutKeys) -> String {
        var result = ""
        let modifiers = NSEvent.ModifierFlags(rawValue: keys.modifiers)
        if modifiers.contains(.control) { result += "⌃" }
        if modifiers.contains(.option) { result += "⌥" }
        if modifiers.contains(.shift) { result += "⇧" }
        if modifiers.contains(.command) { result += "⌘" }
        result += keyCodeToString(keys.keyCode)
        return result
    }

    private func keyCodeToString(_ keyCode: UInt16) -> String {
        switch Int(keyCode) {
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Space: return "Space"
        case kVK_Delete: return "⌫"
        case kVK_Escape: return "⎋"
        default: return "?"
        }
    }

    private func checkMicPermission() {
        micPermissionGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    private func requestMicPermission() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                micPermissionGranted = granted
            }
        }
    }
}

private struct SingleLineTextField: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.isBezeled = false
        textField.drawsBackground = false
        textField.isEditable = true
        textField.isSelectable = true
        textField.focusRingType = .none
        if let cell = textField.cell as? NSTextFieldCell {
            cell.usesSingleLineMode = true
            cell.isScrollable = true
            cell.lineBreakMode = .byTruncatingHead
        }
        textField.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        textField.delegate = context.coordinator
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        private let parent: SingleLineTextField

        init(_ parent: SingleLineTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            parent.text = textField.stringValue
        }
    }
}

// MARK: - Add term view

struct AddTermView: View {
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var term: String = ""

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading) {
                TextField("Word or phrase", text: $term)
                    .textFieldStyle(.roundedBorder)
            }
            .padding()

            Divider()

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add") {
                    let trimmed = term.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty {
                        onSave(trimmed)
                    }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(term.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .frame(width: 300, height: 120)
    }
}

// MARK: - Shortcut recorder

struct ShortcutRecorderView: View {
    @Binding var shortcut: String
    @Binding var shortcutKeys: ShortcutKeys?
    @State private var isRecording = false

    var body: some View {
        HStack {
            Text("Shortcut")

            Spacer()

            Button {
                isRecording.toggle()
            } label: {
                if isRecording {
                    Text("Press keys...")
                        .foregroundStyle(.orange)
                } else if shortcut.isEmpty {
                    Text("Click to record")
                        .foregroundStyle(.secondary)
                } else {
                    Text(shortcut)
                        .font(.system(.body, design: .monospaced))
                }
            }
            .buttonStyle(.bordered)
            .background(
                ShortcutRecorderHelper(
                    isRecording: $isRecording,
                    shortcut: $shortcut,
                    shortcutKeys: $shortcutKeys
                )
            )

            if !shortcut.isEmpty {
                Button {
                    shortcut = ""
                    shortcutKeys = .defaultTripleCmd
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
        }
    }
}

struct ShortcutRecorderHelper: NSViewRepresentable {
    @Binding var isRecording: Bool
    @Binding var shortcut: String
    @Binding var shortcutKeys: ShortcutKeys?

    func makeNSView(context: Context) -> NSView {
        let view = ShortcutRecorderNSView()
        view.onShortcutRecorded = { keys, displayString in
            shortcut = displayString
            shortcutKeys = keys
            isRecording = false
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let view = nsView as? ShortcutRecorderNSView {
            view.isRecording = isRecording
        }
    }
}

class ShortcutRecorderNSView: NSView {
    var isRecording = false
    var onShortcutRecorded: ((ShortcutKeys, String) -> Void)?

    private var monitor: Any?
    private var tripleTapTimestamps: [Date] = []

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        setupMonitor()
    }

    private func setupMonitor() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self = self, self.isRecording else { return event }

            if event.type == .flagsChanged {
                let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                var modifier: String?

                if flags == .option { modifier = "option" }
                else if flags == .control { modifier = "control" }
                else if flags == .shift { modifier = "shift" }
                else if flags == .command { modifier = "command" }

                if let mod = modifier {
                    let now = Date()
                    self.tripleTapTimestamps.append(now)
                    self.tripleTapTimestamps = self.tripleTapTimestamps.filter { now.timeIntervalSince($0) < 0.5 }

                    if self.tripleTapTimestamps.count >= 3 {
                        self.tripleTapTimestamps.removeAll()
                        let symbol: String
                        switch mod {
                        case "option": symbol = "⌥"
                        case "control": symbol = "⌃"
                        case "shift": symbol = "⇧"
                        case "command": symbol = "⌘"
                        default: symbol = "?"
                        }
                        let keys = ShortcutKeys(modifiers: 0, keyCode: 0, isTripleTap: true, tapModifier: mod)
                        self.onShortcutRecorded?(keys, "\(symbol)\(symbol)\(symbol)")
                        return nil
                    }
                }
                return event
            }

            if event.type == .keyDown {
                let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                guard !modifiers.isEmpty else { return event }

                let keyCode = event.keyCode
                let displayString = self.shortcutDisplayString(keyCode: keyCode, modifiers: modifiers)
                let keys = ShortcutKeys(
                    modifiers: modifiers.rawValue,
                    keyCode: keyCode,
                    isTripleTap: false,
                    tapModifier: nil
                )
                self.onShortcutRecorded?(keys, displayString)
                return nil
            }

            return event
        }
    }

    private func shortcutDisplayString(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> String {
        var result = ""

        if modifiers.contains(.control) { result += "⌃" }
        if modifiers.contains(.option) { result += "⌥" }
        if modifiers.contains(.shift) { result += "⇧" }
        if modifiers.contains(.command) { result += "⌘" }

        result += keyCodeToString(keyCode)

        return result
    }

    private func keyCodeToString(_ keyCode: UInt16) -> String {
        switch Int(keyCode) {
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Space: return "Space"
        case kVK_Delete: return "⌫"
        case kVK_Escape: return "⎋"
        case kVK_ForwardDelete: return "⌦"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_Home: return "↖"
        case kVK_End: return "↘"
        case kVK_PageUp: return "⇞"
        case kVK_PageDown: return "⇟"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        default:
            if let char = keyCodeToCharacter(keyCode) {
                return char.uppercased()
            }
            return "?"
        }
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

    deinit {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
