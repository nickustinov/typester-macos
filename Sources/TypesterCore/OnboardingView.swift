import SwiftUI
import AVFoundation

struct OnboardingView: View {
    @ObservedObject private var settings = SettingsStore.shared
    @State private var apiKeyInput = ""
    @State private var currentStep = 1
    @State private var micGranted = false
    @State private var accessibilityGranted = false
    @FocusState private var isApiKeyFocused: Bool

    var onComplete: () -> Void

    private var canContinue: Bool {
        switch currentStep {
        case 1: return !apiKeyInput.isEmpty
        case 2: return micGranted
        case 3: return accessibilityGranted
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

            if permissionsComplete {
                Divider()

                readyView
            }

            Spacer()

            Divider()

            // Footer
            HStack {
                Spacer()

                if permissionsComplete {
                    Button("Start using Typester") {
                        onComplete()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
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
        }
        .frame(width: 520, height: permissionsComplete ? 620 : 540)
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

    // MARK: - Ready view

    @ViewBuilder
    private var readyView: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 32, height: 32)

                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("You're all set!")
                    .font(.headline)

                Text("Hold the **Fn** key and speak — your words will appear wherever your cursor is. Release to stop.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
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
