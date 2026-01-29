import SwiftUI
import AVFoundation
import Carbon.HIToolbox
import AppKit

struct SettingsView: View {
    @ObservedObject private var settings = SettingsStore.shared
    @State private var sonioxKeyInput: String = ""
    @State private var deepgramKeyInput: String = ""
    @State private var showSonioxKey = false
    @State private var showDeepgramKey = false
    @State private var micPermissionGranted = false
    @State private var accessibilityGranted = false
    @State private var showingAddTerm = false

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    Toggle("Open at login", isOn: $settings.launchAtLogin)
                }

                Section("Speech-to-text provider") {
                    Picker("Provider", selection: $settings.sttProvider) {
                        ForEach(STTProviderType.allCases, id: \.self) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                }

                if settings.sttProvider == .soniox {
                    Section {
                        apiKeyField(
                            key: $sonioxKeyInput,
                            showKey: $showSonioxKey,
                            savedKey: settings.apiKey,
                            onSave: { settings.apiKey = $0 }
                        )
                    } header: {
                        HStack {
                            Text("Soniox API key")
                            Spacer()
                            Link("Get key", destination: URL(string: "https://soniox.com")!)
                                .font(.caption)
                        }
                    }
                } else {
                    Section {
                        apiKeyField(
                            key: $deepgramKeyInput,
                            showKey: $showDeepgramKey,
                            savedKey: settings.deepgramApiKey,
                            onSave: { settings.deepgramApiKey = $0 }
                        )
                    } header: {
                        HStack {
                            Text("Deepgram API key")
                            Spacer()
                            Link("Get key", destination: URL(string: "https://console.deepgram.com")!)
                                .font(.caption)
                        }
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

                if settings.sttProvider == .soniox {
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
        .frame(minHeight: 580)
        .sheet(isPresented: $showingAddTerm) {
            AddTermView { term in
                if !settings.dictionaryTerms.contains(term) {
                    settings.dictionaryTerms.append(term)
                }
            }
        }
        .onAppear {
            if let key = settings.apiKey {
                sonioxKeyInput = key
            }
            if let key = settings.deepgramApiKey {
                deepgramKeyInput = key
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

    @ViewBuilder
    private func apiKeyField(
        key: Binding<String>,
        showKey: Binding<Bool>,
        savedKey: String?,
        onSave: @escaping (String?) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ZStack {
                    if showKey.wrappedValue {
                        SingleLineTextField(text: key)
                    } else {
                        SecureField("", text: key)
                            .textFieldStyle(.plain)
                    }
                }

                Button {
                    showKey.wrappedValue.toggle()
                } label: {
                    Image(systemName: showKey.wrappedValue ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)

                if savedKey != nil && key.wrappedValue == savedKey {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            if key.wrappedValue != (savedKey ?? "") {
                HStack {
                    Spacer()
                    Button("Cancel") {
                        key.wrappedValue = savedKey ?? ""
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("Save") {
                        onSave(key.wrappedValue.isEmpty ? nil : key.wrappedValue)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
    }

    private var shortcutDescription: String {
        let keys = settings.shortcutKeys
        if keys.isTripleTap {
            return KeyboardUtils.formatTripleTapDisplay(modifier: keys.tapModifier ?? "command")
        }
        let modifiers = NSEvent.ModifierFlags(rawValue: keys.modifiers)
        return KeyboardUtils.formatShortcutDisplay(modifiers: modifiers, keyCode: keys.keyCode)
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
                        let keys = ShortcutKeys(modifiers: 0, keyCode: 0, isTripleTap: true, tapModifier: mod)
                        let display = KeyboardUtils.formatTripleTapDisplay(modifier: mod)
                        self.onShortcutRecorded?(keys, display)
                        return nil
                    }
                }
                return event
            }

            if event.type == .keyDown {
                let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                guard !modifiers.isEmpty else { return event }

                let keyCode = event.keyCode
                let displayString = KeyboardUtils.formatShortcutDisplay(modifiers: modifiers, keyCode: keyCode)
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

    deinit {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
