import Foundation

class DeepgramClient: NSObject, STTProvider {
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()

    private var webSocketTask: URLSessionWebSocketTask?
    private var isConnectionReady = false
    private var isIntentionalDisconnect = false
    private var isConnecting = false
    private var audioBuffer: [Data] = []
    private var pendingFinalize = false
    private var connectStartTime: Date?

    var isConnected: Bool { isConnectionReady }

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

        guard let apiKey = SettingsStore.shared.deepgramApiKey, !apiKey.isEmpty else {
            Debug.log("connect() FAILED - no API key")
            onError?("Deepgram API key not configured")
            return
        }

        disconnect()
        isConnecting = true
        isConnectionReady = false
        isIntentionalDisconnect = false
        pendingFinalize = false

        Debug.log("Opening WebSocket connection...")
        connectStartTime = Date()

        // Build URL with parameters
        var urlComponents = URLComponents(string: "wss://api.deepgram.com/v1/listen")!
        urlComponents.queryItems = [
            URLQueryItem(name: "model", value: "nova-3"),
            URLQueryItem(name: "language", value: "multi"),
            URLQueryItem(name: "encoding", value: "linear16"),
            URLQueryItem(name: "sample_rate", value: "16000"),
            URLQueryItem(name: "channels", value: "1"),
            URLQueryItem(name: "punctuate", value: "true"),
            URLQueryItem(name: "interim_results", value: "false"),
            URLQueryItem(name: "endpointing", value: "100")
        ]

        var request = URLRequest(url: urlComponents.url!)
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")

        webSocketTask = Self.session.webSocketTask(with: request)
        webSocketTask?.resume()

        // Deepgram is ready once WebSocket opens - test with a receive
        receiveMessage()

        // Mark as ready after brief delay (WebSocket handshake)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self, self.isConnecting else { return }
            self.isConnecting = false
            self.isConnectionReady = true

            let elapsed = self.connectStartTime.map { Date().timeIntervalSince($0) } ?? 0
            Debug.log("Connected in \(String(format: "%.2f", elapsed))s, flushing \(self.audioBuffer.count) buffered chunks")

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
                self.sendCloseStream()
            }
        }
    }

    func disconnect() {
        Debug.log("disconnect() called, buffered chunks: \(audioBuffer.count)")
        isIntentionalDisconnect = true
        isConnecting = false
        audioBuffer.removeAll()
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        isConnectionReady = false
    }

    // MARK: - Audio streaming

    func sendAudio(_ data: Data) {
        if isConnectionReady {
            webSocketTask?.send(.data(data)) { _ in }
        } else {
            // Buffer audio while connecting
            audioBuffer.append(data)
        }
    }

    func sendFinalize() {
        Debug.log("sendFinalize() called, isConnected=\(isConnected), buffered=\(audioBuffer.count)")
        if isConnectionReady {
            sendCloseStream()
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

    private func sendCloseStream() {
        // Deepgram uses a CloseStream message to finalize
        let message = "{\"type\":\"CloseStream\"}"
        webSocketTask?.send(.string(message)) { [weak self] _ in
            // Give time for final transcripts before disconnecting
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.onFinalized?()
            }
        }
    }

    // MARK: - Receive

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
                if !self.isIntentionalDisconnect {
                    Debug.log("WebSocket receive FAILED: \(error.localizedDescription)")
                }
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

        // Check for error response
        if let error = json["error"] as? String {
            onError?(error)
            onDisconnected?()
            return
        }

        // Check for error in err_code/err_msg format
        if let errCode = json["err_code"] as? String {
            let errMsg = json["err_msg"] as? String ?? errCode
            onError?(errMsg)
            onDisconnected?()
            return
        }

        // Parse transcript
        if let channel = json["channel"] as? [String: Any],
           let alternatives = channel["alternatives"] as? [[String: Any]],
           let firstAlt = alternatives.first,
           let transcript = firstAlt["transcript"] as? String,
           !transcript.isEmpty {

            let isFinal = json["is_final"] as? Bool ?? false
            let speechFinal = json["speech_final"] as? Bool ?? false

            Debug.log("Transcript: '\(transcript)' isFinal=\(isFinal) speechFinal=\(speechFinal)")

            if isFinal {
                onTranscript?(transcript, true)
            }

            if speechFinal {
                onEndpoint?()
            }
        }
    }
}
