import Foundation

/// Deepgram STT connection configuration.
struct DeepgramConnectionConfig: STTConnectionConfig {
    var apiKey: String? { SettingsStore.shared.deepgramApiKey }

    func makeWebSocketRequest() -> URLRequest? {
        guard let apiKey = apiKey else { return nil }

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
        return request
    }

    func parseResponse(_ json: [String: Any]) -> [STTParseResult] {
        // Check for error response
        if let error = json["error"] as? String {
            return [.error(error)]
        }

        // Check for error in err_code/err_msg format
        if let errCode = json["err_code"] as? String {
            let errMsg = json["err_msg"] as? String ?? errCode
            return [.error(errMsg)]
        }

        // Parse transcript
        if let channel = json["channel"] as? [String: Any],
           let alternatives = channel["alternatives"] as? [[String: Any]],
           let firstAlt = alternatives.first,
           let transcript = firstAlt["transcript"] as? String,
           !transcript.isEmpty {

            var results: [STTParseResult] = []

            let isFinal = json["is_final"] as? Bool ?? false
            let speechFinal = json["speech_final"] as? Bool ?? false

            Debug.log("Transcript: '\(transcript)' isFinal=\(isFinal) speechFinal=\(speechFinal)")

            if isFinal {
                results.append(.transcript(text: transcript, isFinal: true))
            }

            if speechFinal {
                results.append(.endpoint)
            }

            return results
        }

        return []
    }
}

/// Deepgram speech-to-text client.
class DeepgramClient: STTClientBase {
    override func makeConnectionConfig() -> STTConnectionConfig {
        DeepgramConnectionConfig()
    }

    override func onWebSocketOpened() {
        // Deepgram is ready after brief WebSocket handshake delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self, self.isConnecting else { return }
            self.markConnectionReady()
        }
    }

    override func finalizeMessage() -> String {
        return "{\"type\":\"CloseStream\"}"
    }

    override func onFinalizeMessageSent() {
        // Deepgram needs time for final transcripts before signaling finalized
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.onFinalized?()
        }
    }
}
