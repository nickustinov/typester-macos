import Foundation

/// Soniox STT connection configuration.
struct SonioxConnectionConfig: STTConnectionConfig {
    var apiKey: String? { SettingsStore.shared.apiKey }

    func makeWebSocketRequest() -> URLRequest? {
        let url = URL(string: "wss://stt-rt.soniox.com/transcribe-websocket")!
        return URLRequest(url: url)
    }

    func parseResponse(_ json: [String: Any]) -> [STTParseResult] {
        var results: [STTParseResult] = []

        // Check for error response (invalid API key, etc.)
        if let error = json["error"] as? String {
            return [.error(error)]
        }

        if let tokens = json["tokens"] as? [[String: Any]] {
            for token in tokens {
                guard let tokenText = token["text"] as? String else { continue }

                if tokenText == "<end>" {
                    results.append(.endpoint)
                    continue
                }

                if tokenText == "<fin>" {
                    results.append(.finalized)
                    continue
                }

                let isFinal = token["is_final"] as? Bool ?? false
                if isFinal {
                    results.append(.transcript(text: tokenText, isFinal: true))
                }
            }
        }

        if let finished = json["finished"] as? Bool, finished {
            results.append(.finished)
        }

        return results
    }
}

/// Soniox speech-to-text client.
class SonioxClient: STTClientBase {
    override func makeConnectionConfig() -> STTConnectionConfig {
        SonioxConnectionConfig()
    }

    override func onWebSocketOpened() {
        sendConfiguration()
    }

    override func finalizeMessage() -> String {
        return "{\"type\":\"finalize\"}"
    }

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
        sendMessage(jsonString) { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let error = error {
                    Debug.log("Config send FAILED: \(error.localizedDescription)")
                    // Suppress timeout/cancellation errors - just disconnect silently
                    let nsError = error as NSError
                    if nsError.domain == NSURLErrorDomain &&
                       (nsError.code == NSURLErrorTimedOut ||
                        nsError.code == NSURLErrorCancelled ||
                        nsError.code == NSURLErrorNetworkConnectionLost) {
                        self.onDisconnected?()
                    } else {
                        self.onError?("Failed to send config: \(error.localizedDescription)")
                    }
                } else {
                    self.markConnectionReady()
                }
            }
        }
    }
}
