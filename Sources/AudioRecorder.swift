import AVFoundation
import Cocoa

class AudioRecorder {
    private var audioEngine: AVAudioEngine?
    private var isRecording = false

    // MARK: - Callbacks

    var onAudioBuffer: ((Data) -> Void)?
    var onError: ((String) -> Void)?

    // MARK: - Permission

    func requestPermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }

    // MARK: - Recording

    func startRecording() {
        guard !isRecording else { return }

        requestPermission { [weak self] granted in
            guard granted else {
                self?.onError?("Microphone permission denied")
                return
            }
            self?.setupAndStart()
        }
    }

    func stopRecording() {
        guard isRecording else { return }

        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        isRecording = false
    }

    // MARK: - Private

    private func setupAndStart() {
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else { return }

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Target format: 16kHz mono PCM (Soniox requirement)
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16000,
            channels: 1,
            interleaved: true
        ) else {
            onError?("Failed to create target audio format")
            return
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            onError?("Failed to create audio converter")
            return
        }

        let inputBufferSize: AVAudioFrameCount = 4096
        let outputBufferSize = AVAudioFrameCount(Double(inputBufferSize) * (16000.0 / inputFormat.sampleRate))

        inputNode.installTap(onBus: 0, bufferSize: inputBufferSize, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }

            guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputBufferSize) else {
                return
            }

            var error: NSError?
            let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }

            converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)

            if error != nil { return }

            if let channelData = outputBuffer.int16ChannelData {
                let frameLength = Int(outputBuffer.frameLength)
                let data = Data(bytes: channelData[0], count: frameLength * 2)
                self.onAudioBuffer?(data)
            }
        }

        do {
            try audioEngine.start()
            isRecording = true
        } catch {
            onError?("Failed to start audio engine: \(error.localizedDescription)")
        }
    }
}
