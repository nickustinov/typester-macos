import SwiftUI
import AVFoundation

struct OnboardingView: View {
    @ObservedObject private var settings = SettingsStore.shared
    @State private var apiKeyInput = ""
    @State private var currentStep = 1
    @State private var micGranted = false
    @State private var accessibilityGranted = false
    @State private var tryItText = ""
    @State private var isTrying = false
    @FocusState private var isApiKeyFocused: Bool

    private let audioRecorder = AudioRecorder()
    @State private var sttProvider: STTProvider?

    var onComplete: () -> Void

    private var canContinue: Bool {
        switch currentStep {
        case 1: return !apiKeyInput.isEmpty
        case 2: return micGranted
        case 3: return accessibilityGranted
        case 4: return true
        default: return true
        }
    }

    private var hasApiKey: Bool {
        switch settings.sttProvider {
        case .soniox: return settings.apiKey != nil
        case .deepgram: return settings.deepgramApiKey != nil
        }
    }

    private var permissionsComplete: Bool {
        hasApiKey && micGranted && accessibilityGranted
    }

    var body: some View {
        VStack(spacing: 0) {
            if currentStep < 4 {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "waveform")
                        .font(.system(size: 48))
                        .foregroundStyle(.blue)

                    Text("Welcome to Typester")
                        .font(.title.bold())

                    Text("Dictate text anywhere on your Mac")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 32)
                .padding(.bottom, 24)

                Divider()

                // Steps
                VStack(spacing: 0) {
                    stepView(
                        number: 1,
                        title: "Enter your API key",
                        titleLink: settings.sttProvider == .deepgram
                            ? ("Get key", URL(string: "https://console.deepgram.com")!)
                            : ("Get key", URL(string: "https://soniox.com")!),
                        description: "You pay the provider directly for usage — no middleman, no subscription.",
                        isActive: currentStep == 1,
                        isComplete: hasApiKey
                    ) {
                        providerAndApiKeyContent
                    }

                    Divider().padding(.leading, 56)

                    stepView(
                        number: 2,
                        title: "Grant microphone access",
                        description: "Typester needs to hear you speak to transcribe your voice to text.",
                        isActive: currentStep == 2,
                        isComplete: micGranted
                    ) {
                        microphoneStepContent
                    }

                    Divider().padding(.leading, 56)

                    stepView(
                        number: 3,
                        title: "Grant accessibility access",
                        description: "Typester needs this to type text into other apps by simulating keyboard input.",
                        isActive: currentStep == 3,
                        isComplete: accessibilityGranted
                    ) {
                        accessibilityStepContent
                    }
                }
                .padding(.vertical, 8)

                Spacer()

                Divider()

                // Footer
                HStack {
                    Spacer()

                    if permissionsComplete {
                        Button("Next") {
                            withAnimation { currentStep = 4 }
                        }
                        .buttonStyle(.borderedProminent)
                    } else if canContinue && currentStep < 3 {
                        Button("Continue") {
                            if currentStep == 1 && !apiKeyInput.isEmpty {
                                switch settings.sttProvider {
                                case .soniox:
                                    settings.apiKey = apiKeyInput
                                case .deepgram:
                                    settings.deepgramApiKey = apiKeyInput
                                }
                            }
                            withAnimation { currentStep += 1 }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(20)
            } else {
                // How to use screen
                howToUseView
            }
        }
        .frame(width: 520, height: 540)
        .onAppear {
            checkPermissions()
            loadApiKeyForProvider()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isApiKeyFocused = true
            }
        }
        .onChange(of: settings.sttProvider) { _ in
            loadApiKeyForProvider()
        }
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
            checkPermissions()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            checkPermissions()
        }
    }

    // MARK: - Step view

    @ViewBuilder
    private func stepView<Content: View>(
        number: Int,
        title: String,
        titleLink: (String, URL)? = nil,
        description: String,
        isActive: Bool,
        isComplete: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .top, spacing: 16) {
            // Step indicator
            ZStack {
                Circle()
                    .fill(isComplete ? Color.green : (isActive ? Color.blue : Color.secondary.opacity(0.3)))
                    .frame(width: 32, height: 32)

                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Text("\(number)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isActive ? .white : .secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(isActive || isComplete ? .primary : .secondary)

                    if let (linkText, linkURL) = titleLink {
                        Spacer()
                        Link(linkText, destination: linkURL)
                            .font(.callout)
                    }
                }

                Text(description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if isActive && !isComplete {
                    content()
                        .padding(.top, 8)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .onTapGesture {
            if number <= currentStep || (number == currentStep + 1 && canContinue) {
                withAnimation { currentStep = number }
            }
        }
    }

    // MARK: - How to use

    @ViewBuilder
    private var howToUseView: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                // Fn key mockup
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(white: 0.15))
                        .frame(width: 80, height: 80)
                        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)

                    RoundedRectangle(cornerRadius: 10)
                        .fill(LinearGradient(
                            colors: [Color(white: 0.25), Color(white: 0.18)],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .frame(width: 72, height: 72)

                    Text("fn")
                        .font(.system(size: 28, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                }

                VStack(spacing: 12) {
                    Text("Hold Fn to dictate")
                        .font(.title2.bold())

                    Text("Press and hold the Fn key, speak, then release.\nYour words will appear wherever your cursor is.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Try it area
                VStack(spacing: 8) {
                    Text(tryItText.isEmpty ? "Give it a try..." : tryItText)
                        .font(.title3)
                        .foregroundStyle(tryItText.isEmpty ? .tertiary : .primary)
                        .multilineTextAlignment(.center)
                        .frame(minHeight: 60)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.primary.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isTrying ? Color.blue : Color.clear, lineWidth: 2)
                        )
                }
                .padding(.top, 16)
            }
            .padding(.horizontal, 40)

            Spacer()

            Divider()

            HStack {
                Spacer()

                Button("Start using Typester") {
                    stopTryIt()
                    onComplete()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(20)
        }
        .onAppear {
            setupTryIt()
        }
    }

    private func setupTryIt() {
        // Create provider based on current selection
        let provider: STTProvider = settings.sttProvider == .deepgram ? DeepgramClient() : SonioxClient()
        sttProvider = provider

        audioRecorder.onAudioBuffer = { data in
            provider.sendAudio(data)
        }

        provider.onTranscript = { text, isFinal in
            DispatchQueue.main.async {
                if isFinal {
                    tryItText += text
                }
            }
        }

        FnKeyMonitor.shared.onFnPressed = {
            DispatchQueue.main.async {
                isTrying = true
                tryItText = ""
            }
            provider.connect()
        }

        FnKeyMonitor.shared.onFnReleased = { [audioRecorder] in
            audioRecorder.stopRecording()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                provider.sendFinalize()
            }
            DispatchQueue.main.async {
                isTrying = false
            }
        }

        provider.onConnected = { [audioRecorder] in
            audioRecorder.startRecording()
        }

        provider.onFinalized = {
            provider.disconnect()
        }

        FnKeyMonitor.shared.start()
    }

    private func stopTryIt() {
        FnKeyMonitor.shared.stop()
        audioRecorder.stopRecording()
        sttProvider?.disconnect()
    }

    // MARK: - Step content

    @ViewBuilder
    private var providerAndApiKeyContent: some View {
        HStack(spacing: 8) {
            Picker("Provider", selection: $settings.sttProvider) {
                ForEach(STTProviderType.allCases, id: \.self) { provider in
                    Text(provider.displayName).tag(provider)
                }
            }
            .labelsHidden()
            .fixedSize()

            SecureField("Paste your API key", text: $apiKeyInput)
                .textFieldStyle(.roundedBorder)
                .focused($isApiKeyFocused)
        }
    }

    @ViewBuilder
    private var microphoneStepContent: some View {
        Button("Request microphone access") {
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    micGranted = granted
                    if granted && currentStep == 2 {
                        withAnimation { currentStep = 3 }
                    }
                }
            }
        }
        .buttonStyle(.bordered)
    }

    @ViewBuilder
    private var accessibilityStepContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button("Open System Settings") {
                TextPaster.openAccessibilitySettings()
            }
            .buttonStyle(.bordered)

            Text("Find Typester in the list and enable it, then come back here.")
                .font(.callout)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Helpers

    private func loadApiKeyForProvider() {
        switch settings.sttProvider {
        case .soniox:
            apiKeyInput = settings.apiKey ?? ""
        case .deepgram:
            apiKeyInput = settings.deepgramApiKey ?? ""
        }
    }

    private func checkPermissions() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        micGranted = status == .authorized
        accessibilityGranted = TextPaster.checkAccessibilityPermission()
    }
}
