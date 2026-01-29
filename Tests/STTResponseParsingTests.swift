import XCTest
@testable import TypesterCore

final class STTResponseParsingTests: XCTestCase {

    // MARK: - Soniox response parsing

    func testSonioxTranscript() {
        let config = SonioxConnectionConfig()
        let json: [String: Any] = [
            "tokens": [
                ["text": "Hello", "is_final": true]
            ]
        ]

        let results = config.parseResponse(json)

        XCTAssertEqual(results.count, 1)
        if case .transcript(let text, let isFinal) = results[0] {
            XCTAssertEqual(text, "Hello")
            XCTAssertTrue(isFinal)
        } else {
            XCTFail("Expected transcript result")
        }
    }

    func testSonioxMultipleTokens() {
        let config = SonioxConnectionConfig()
        let json: [String: Any] = [
            "tokens": [
                ["text": "Hello", "is_final": true],
                ["text": " ", "is_final": true],
                ["text": "world", "is_final": true]
            ]
        ]

        let results = config.parseResponse(json)

        XCTAssertEqual(results.count, 3)
    }

    func testSonioxEndpoint() {
        let config = SonioxConnectionConfig()
        let json: [String: Any] = [
            "tokens": [
                ["text": "<end>", "is_final": true]
            ]
        ]

        let results = config.parseResponse(json)

        XCTAssertEqual(results.count, 1)
        if case .endpoint = results[0] {
            // Pass
        } else {
            XCTFail("Expected endpoint result")
        }
    }

    func testSonioxFinalized() {
        let config = SonioxConnectionConfig()
        let json: [String: Any] = [
            "tokens": [
                ["text": "<fin>", "is_final": true]
            ]
        ]

        let results = config.parseResponse(json)

        XCTAssertEqual(results.count, 1)
        if case .finalized = results[0] {
            // Pass
        } else {
            XCTFail("Expected finalized result")
        }
    }

    func testSonioxError() {
        let config = SonioxConnectionConfig()
        let json: [String: Any] = [
            "error": "Invalid API key"
        ]

        let results = config.parseResponse(json)

        XCTAssertEqual(results.count, 1)
        if case .error(let message) = results[0] {
            XCTAssertEqual(message, "Invalid API key")
        } else {
            XCTFail("Expected error result")
        }
    }

    func testSonioxFinished() {
        let config = SonioxConnectionConfig()
        let json: [String: Any] = [
            "finished": true
        ]

        let results = config.parseResponse(json)

        XCTAssertEqual(results.count, 1)
        if case .finished = results[0] {
            // Pass
        } else {
            XCTFail("Expected finished result")
        }
    }

    func testSonioxNonFinalTokenIgnored() {
        let config = SonioxConnectionConfig()
        let json: [String: Any] = [
            "tokens": [
                ["text": "partial", "is_final": false]
            ]
        ]

        let results = config.parseResponse(json)

        XCTAssertEqual(results.count, 0, "Non-final tokens should be ignored")
    }

    // MARK: - Deepgram response parsing

    func testDeepgramTranscript() {
        let config = DeepgramConnectionConfig()
        let json: [String: Any] = [
            "channel": [
                "alternatives": [
                    ["transcript": "Hello world"]
                ]
            ],
            "is_final": true,
            "speech_final": false
        ]

        let results = config.parseResponse(json)

        XCTAssertEqual(results.count, 1)
        if case .transcript(let text, let isFinal) = results[0] {
            XCTAssertEqual(text, "Hello world")
            XCTAssertTrue(isFinal)
        } else {
            XCTFail("Expected transcript result")
        }
    }

    func testDeepgramEndpoint() {
        let config = DeepgramConnectionConfig()
        let json: [String: Any] = [
            "channel": [
                "alternatives": [
                    ["transcript": "Hello"]
                ]
            ],
            "is_final": true,
            "speech_final": true
        ]

        let results = config.parseResponse(json)

        XCTAssertEqual(results.count, 2)

        var hasTranscript = false
        var hasEndpoint = false

        for result in results {
            switch result {
            case .transcript:
                hasTranscript = true
            case .endpoint:
                hasEndpoint = true
            default:
                break
            }
        }

        XCTAssertTrue(hasTranscript)
        XCTAssertTrue(hasEndpoint)
    }

    func testDeepgramErrorWithErrorField() {
        let config = DeepgramConnectionConfig()
        let json: [String: Any] = [
            "error": "Connection failed"
        ]

        let results = config.parseResponse(json)

        XCTAssertEqual(results.count, 1)
        if case .error(let message) = results[0] {
            XCTAssertEqual(message, "Connection failed")
        } else {
            XCTFail("Expected error result")
        }
    }

    func testDeepgramErrorWithErrCodeErrMsg() {
        let config = DeepgramConnectionConfig()
        let json: [String: Any] = [
            "err_code": "INVALID_AUTH",
            "err_msg": "Invalid API key"
        ]

        let results = config.parseResponse(json)

        XCTAssertEqual(results.count, 1)
        if case .error(let message) = results[0] {
            XCTAssertEqual(message, "Invalid API key")
        } else {
            XCTFail("Expected error result")
        }
    }

    func testDeepgramErrorWithOnlyErrCode() {
        let config = DeepgramConnectionConfig()
        let json: [String: Any] = [
            "err_code": "INVALID_AUTH"
        ]

        let results = config.parseResponse(json)

        XCTAssertEqual(results.count, 1)
        if case .error(let message) = results[0] {
            XCTAssertEqual(message, "INVALID_AUTH")
        } else {
            XCTFail("Expected error result")
        }
    }

    func testDeepgramEmptyTranscriptIgnored() {
        let config = DeepgramConnectionConfig()
        let json: [String: Any] = [
            "channel": [
                "alternatives": [
                    ["transcript": ""]
                ]
            ],
            "is_final": true
        ]

        let results = config.parseResponse(json)

        XCTAssertEqual(results.count, 0, "Empty transcripts should be ignored")
    }

    func testDeepgramNonFinalIgnored() {
        let config = DeepgramConnectionConfig()
        let json: [String: Any] = [
            "channel": [
                "alternatives": [
                    ["transcript": "partial"]
                ]
            ],
            "is_final": false
        ]

        let results = config.parseResponse(json)

        XCTAssertEqual(results.count, 0, "Non-final results should be ignored")
    }
}
