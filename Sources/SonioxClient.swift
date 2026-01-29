import Foundation

class SonioxClient: NSObject, STTProvider {
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()

    private var webSocketTask: URLSessionWebSocketTask?
    private var isConfigSent = false
    private var isIntentionalDisconnect = false
    private var isConnecting = false
    private var audioBuffer: [Data] = []
    private var pendingFinalize = false
    private var connectStartTime: Date?

    var isConnected: Bool { isConfigSent }

    // MARK: - Callbacks

    var onTranscript: ((String, Bool) -> Void)?
    var onEndpoint: (() -> Void)?
    var onFinalized: (() -> Void)?
    var onError: ((String) -> Void)?
    var onConnected: (() -> Void)?
    var onDisconnected: (() -> Void)?

    // MARK: - Connection

    func connect() {
        Debug.log("connect() called, isConnecting=\(isConnecting)")
        guard !isConnecting else {
            Debug.log("connect() SKIPPED - already connecting")
            return
        }

        guard let apiKey = SettingsStore.shared.apiKey, !apiKey.isEmpty else {
            Debug.log("connect() FAILED - no API key")
            onError?("API key not configured")
            return
        }

        disconnect()
        isConnecting = true
        isConfigSent = false
        isIntentionalDisconnect = false
        pendingFinalize = false

        Debug.log("Opening WebSocket connection...")
        connectStartTime = Date()
        let url = URL(string: "wss://stt-rt.soniox.com/transcribe-websocket")!
        webSocketTask = Self.session.webSocketTask(with: url)
        webSocketTask?.resume()

        sendConfiguration()
        receiveMessage()
    }

    func disconnect() {
        Debug.log("disconnect() called, buffered chunks: \(audioBuffer.count)")
        isIntentionalDisconnect = true
        isConnecting = false
        audioBuffer.removeAll()
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        isConfigSent = false
    }

    // MARK: - Audio streaming

    func sendAudio(_ data: Data) {
        if isConfigSent {
            webSocketTask?.send(.data(data)) { _ in }
        } else {
            // Buffer audio while connecting
            audioBuffer.append(data)
        }
    }

    func sendFinalize() {
        Debug.log("sendFinalize() called, isConnected=\(isConnected), buffered=\(audioBuffer.count)")
        if isConnected {
            let message = "{\"type\":\"finalize\"}"
            webSocketTask?.send(.string(message)) { _ in }
        } else if audioBuffer.isEmpty {
            // No audio buffered, just disconnect
            Debug.log("No audio buffered, disconnecting")
            disconnect()
            onFinalized?()
        } else {
            // Audio buffered but not connected yet - wait for connection
            Debug.log("Waiting for connection to send \(audioBuffer.count) buffered chunks")
            pendingFinalize = true
        }
    }

    // MARK: - Private

    private func sendConfiguration() {
        guard let apiKey = SettingsStore.shared.apiKey else { return }

        var config: [String: Any] = [
            "api_key": apiKey,
            "model": "stt-rt-preview",
            "audio_format": "pcm_s16le",
            "sample_rate": 16000,
            "num_channels": 1,
            "enable_endpoint_detection": true
        ]

        let languageHints = SettingsStore.shared.languageHints
        if !languageHints.isEmpty {
            config["language_hints"] = languageHints
        }

        let dictionaryTerms = SettingsStore.shared.dictionaryTerms
        if !dictionaryTerms.isEmpty {
            config["context"] = ["terms": dictionaryTerms]
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: config),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            onError?("Failed to create config")
            return
        }

        Debug.log("Sending config to Soniox...")
        webSocketTask?.send(.string(jsonString)) { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isConnecting = false
                if let error = error {
                    // Don't show error if we intentionally disconnected
                    if !self.isIntentionalDisconnect {
                        Debug.log("Config send FAILED: \(error.localizedDescription)")
                        self.onError?("Failed to send config: \(error.localizedDescription)")
                    } else {
                        Debug.log("Config send cancelled (intentional disconnect)")
                    }
                } else {
                    let elapsed = self.connectStartTime.map { Date().timeIntervalSince($0) } ?? 0
                    Debug.log("Config sent OK in \(String(format: "%.2f", elapsed))s, flushing \(self.audioBuffer.count) buffered chunks")
                    self.isConfigSent = true
                    // Flush buffered audio
                    for chunk in self.audioBuffer {
                        self.webSocketTask?.send(.data(chunk)) { _ in }
                    }
                    self.audioBuffer.removeAll()
                    self.onConnected?()

                    // If finalize was requested while connecting, send it now
                    if self.pendingFinalize {
                        Debug.log("Sending pending finalize")
                        self.pendingFinalize = false
                        let message = "{\"type\":\"finalize\"}"
                        self.webSocketTask?.send(.string(message)) { _ in }
                    }
                }
            }
        }
    }

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                DispatchQueue.main.async {
                    self.handleMessage(message)
                }
                self.receiveMessage()

            case .failure(let error):
                Debug.log("WebSocket receive FAILED: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.onDisconnected?()
                }
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            parseResponse(text)
        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                parseResponse(text)
            }
        @unknown default:
            break
        }
    }

    private func parseResponse(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        // Check for error response (invalid API key, etc.)
        if let error = json["error"] as? String {
            onError?(error)
            onDisconnected?()
            return
        }

        if let tokens = json["tokens"] as? [[String: Any]] {
            for token in tokens {
                guard let tokenText = token["text"] as? String else { continue }

                if tokenText == "<end>" {
                    onEndpoint?()
                    continue
                }

                if tokenText == "<fin>" {
                    onFinalized?()
                    continue
                }

                let isFinal = token["is_final"] as? Bool ?? false
                if isFinal {
                    onTranscript?(tokenText, true)
                }
            }
        }

        if let finished = json["finished"] as? Bool, finished {
            onDisconnected?()
        }
    }
}
