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

    private var isComplete: Bool {
        settings.apiKey != nil && micGranted && accessibilityGranted
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
                    title: "Enter your Soniox API key",
                    description: "Typester uses Soniox for speech recognition. You pay Soniox directly for usage — no middleman, no subscription.",
                    isActive: currentStep == 1,
                    isComplete: settings.apiKey != nil
                ) {
                    apiKeyStepContent
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
                if currentStep > 1 && !isComplete {
                    Button("Back") {
                        withAnimation { currentStep -= 1 }
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                if isComplete {
                    Button("Start using Typester") {
                        onComplete()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else if canContinue && currentStep < 3 {
                    Button("Continue") {
                        if currentStep == 1 && !apiKeyInput.isEmpty {
                            settings.apiKey = apiKeyInput
                        }
                        withAnimation { currentStep += 1 }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(20)
        }
        .frame(width: 520, height: 540)
        .onAppear {
            checkPermissions()
            if let key = settings.apiKey {
                apiKeyInput = key
            }
            // Focus API key field after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isApiKeyFocused = true
            }
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
                Text(title)
                    .font(.headline)
                    .foregroundStyle(isActive || isComplete ? .primary : .secondary)

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

    // MARK: - Step content

    @ViewBuilder
    private var apiKeyStepContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                SecureField("Paste your Soniox API key", text: $apiKeyInput)
                    .textFieldStyle(.roundedBorder)
                    .focused($isApiKeyFocused)

                Link(destination: URL(string: "https://soniox.com")!) {
                    Text("Get key")
                }
            }
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

    private func checkPermissions() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        micGranted = status == .authorized
        accessibilityGranted = TextPaster.checkAccessibilityPermission()
    }
}
