import Foundation

class SonioxClient: NSObject {
    private var webSocketTask: URLSessionWebSocketTask?
    private var isConfigSent = false
    private var isIntentionalDisconnect = false

    // MARK: - Callbacks

    var onTranscript: ((String, Bool) -> Void)?
    var onEndpoint: (() -> Void)?
    var onError: ((String) -> Void)?
    var onConnected: (() -> Void)?
    var onDisconnected: (() -> Void)?

    // MARK: - Connection

    func connect() {
        guard let apiKey = SettingsStore.shared.apiKey, !apiKey.isEmpty else {
            onError?("API key not configured")
            return
        }

        disconnect()
        isConfigSent = false
        isIntentionalDisconnect = false

        let url = URL(string: "wss://stt-rt.soniox.com/transcribe-websocket")!
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()

        sendConfiguration()
        receiveMessage()
    }

    func disconnect() {
        isIntentionalDisconnect = true
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        isConfigSent = false
    }

    // MARK: - Audio streaming

    func sendAudio(_ data: Data) {
        guard isConfigSent else { return }
        webSocketTask?.send(.data(data)) { _ in }
    }

    func finishAudio() {
        webSocketTask?.send(.data(Data())) { _ in }
    }

    // MARK: - Private

    private func sendConfiguration() {
        guard let apiKey = SettingsStore.shared.apiKey else { return }

        let config: [String: Any] = [
            "api_key": apiKey,
            "model": "stt-rt-preview",
            "audio_format": "pcm_s16le",
            "sample_rate": 16000,
            "num_channels": 1,
            "language_hints": ["en"],
            "enable_endpoint_detection": true
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: config),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            onError?("Failed to create config")
            return
        }

        webSocketTask?.send(.string(jsonString)) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.onError?("Failed to send config: \(error.localizedDescription)")
                } else {
                    self?.isConfigSent = true
                    self?.onConnected?()
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
                DispatchQueue.main.async {
                    // Don't report error if we intentionally disconnected
                    if !self.isIntentionalDisconnect {
                        self.onError?("Connection error: \(error.localizedDescription)")
                    }
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

                let isFinal = token["is_final"] as? Bool ?? false
                onTranscript?(tokenText, isFinal)
            }
        }

        if let finished = json["finished"] as? Bool, finished {
            onDisconnected?()
        }
    }
}
