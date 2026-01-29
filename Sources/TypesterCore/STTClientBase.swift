import Foundation

/// Result of parsing an STT response message.
enum STTParseResult {
    case transcript(text: String, isFinal: Bool)
    case endpoint
    case finalized
    case error(String)
    case finished
    case none
}

/// Protocol for STT client configuration - each provider implements this.
protocol STTConnectionConfig {
    var apiKey: String? { get }
    func makeWebSocketRequest() -> URLRequest?
    func parseResponse(_ json: [String: Any]) -> [STTParseResult]
}

/// Base class for speech-to-text WebSocket clients.
/// Handles connection lifecycle, audio buffering, and message routing.
class STTClientBase: NSObject, STTProvider {
    static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()

    var webSocketTask: URLSessionWebSocketTask?
    var isConnecting = false
    var audioBuffer: [Data] = []
    var pendingFinalize = false
    var connectStartTime: Date?

    private var isIntentionalDisconnect = false
    private var connectionReady = false

    var isConnected: Bool { connectionReady }

    // MARK: - Callbacks (STTProvider protocol)

    var onTranscript: ((String, Bool) -> Void)?
    var onEndpoint: (() -> Void)?
    var onFinalized: (() -> Void)?
    var onError: ((String) -> Void)?
    var onConnected: (() -> Void)?
    var onDisconnected: (() -> Void)?

    // MARK: - Abstract hooks (subclasses override)

    /// Returns the connection config for this client.
    func makeConnectionConfig() -> STTConnectionConfig {
        fatalError("Subclass must override makeConnectionConfig()")
    }

    /// Called when WebSocket connection opens. Subclass can send config messages here.
    func onWebSocketOpened() {
        // Default: mark as ready immediately
        markConnectionReady()
    }

    /// Called after sending finalize message. Subclass can delay finalized callback.
    func onFinalizeMessageSent() {
        // Default: no special handling
    }

    /// Returns the finalize message to send (JSON string).
    func finalizeMessage() -> String {
        return "{\"type\":\"finalize\"}"
    }

    // MARK: - Connection (STTProvider protocol)

    func connect() {
        Debug.log("connect() called, isConnecting=\(isConnecting)")
        guard !isConnecting else {
            Debug.log("connect() SKIPPED - already connecting")
            return
        }

        let config = makeConnectionConfig()
        guard let apiKey = config.apiKey, !apiKey.isEmpty else {
            Debug.log("connect() FAILED - no API key")
            onError?("API key not configured")
            return
        }

        guard let request = config.makeWebSocketRequest() else {
            Debug.log("connect() FAILED - could not create request")
            onError?("Failed to create connection request")
            return
        }

        disconnect()
        isConnecting = true
        connectionReady = false
        isIntentionalDisconnect = false
        pendingFinalize = false

        Debug.log("Opening WebSocket connection...")
        connectStartTime = Date()
        webSocketTask = Self.session.webSocketTask(with: request)
        webSocketTask?.resume()

        onWebSocketOpened()
        receiveMessage()
    }

    func disconnect() {
        Debug.log("disconnect() called, buffered chunks: \(audioBuffer.count)")
        isIntentionalDisconnect = true
        isConnecting = false
        audioBuffer.removeAll()
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        connectionReady = false
    }

    // MARK: - Audio streaming (STTProvider protocol)

    func sendAudio(_ data: Data) {
        if connectionReady {
            webSocketTask?.send(.data(data)) { _ in }
        } else {
            audioBuffer.append(data)
        }
    }

    func sendFinalize() {
        Debug.log("sendFinalize() called, isConnected=\(isConnected), buffered=\(audioBuffer.count)")
        if connectionReady {
            sendFinalizeMessage()
        } else if audioBuffer.isEmpty {
            Debug.log("No audio buffered, disconnecting")
            disconnect()
            onFinalized?()
        } else {
            Debug.log("Waiting for connection to send \(audioBuffer.count) buffered chunks")
            pendingFinalize = true
        }
    }

    // MARK: - Internal helpers

    /// Marks the connection as ready and flushes buffered audio.
    func markConnectionReady() {
        isConnecting = false
        connectionReady = true

        let elapsed = connectStartTime.map { Date().timeIntervalSince($0) } ?? 0
        Debug.log("Connected in \(String(format: "%.2f", elapsed))s, flushing \(audioBuffer.count) buffered chunks")

        for chunk in audioBuffer {
            webSocketTask?.send(.data(chunk)) { _ in }
        }
        audioBuffer.removeAll()
        onConnected?()

        if pendingFinalize {
            Debug.log("Sending pending finalize")
            pendingFinalize = false
            sendFinalizeMessage()
        }
    }

    /// Sends a message on the WebSocket.
    func sendMessage(_ text: String, completion: ((Error?) -> Void)? = nil) {
        webSocketTask?.send(.string(text)) { error in
            completion?(error)
        }
    }

    private func sendFinalizeMessage() {
        let message = finalizeMessage()
        webSocketTask?.send(.string(message)) { [weak self] _ in
            self?.onFinalizeMessageSent()
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
        let text: String?
        switch message {
        case .string(let str):
            text = str
        case .data(let data):
            text = String(data: data, encoding: .utf8)
        @unknown default:
            text = nil
        }

        guard let text = text,
              let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        let config = makeConnectionConfig()
        let results = config.parseResponse(json)

        for result in results {
            switch result {
            case .transcript(let text, let isFinal):
                onTranscript?(text, isFinal)
            case .endpoint:
                onEndpoint?()
            case .finalized:
                onFinalized?()
            case .error(let message):
                onError?(message)
                onDisconnected?()
            case .finished:
                onDisconnected?()
            case .none:
                break
            }
        }
    }
}
