import Foundation
import AVFoundation
import Speech
import Accelerate

// MARK: - SpeechRecognitionService
/// On-device speech recognition for pronunciation practice. Streams microphone
/// audio into SFSpeechRecognizer (en-US) and reports partial transcripts so the
/// UI can show live captions while the learner speaks.
@Observable
@MainActor
final class SpeechRecognitionService: NSObject {
    static let shared = SpeechRecognitionService()

    private(set) var isListening: Bool = false
    private(set) var transcript: String = ""
    private(set) var audioLevel: Float = 0.0

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    override private init() {
        super.init()
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        let micGranted = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        guard micGranted else { return false }

        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        return speechStatus == .authorized
    }

    // MARK: - Listening

    /// Starts streaming recognition. Partial results update `transcript`.
    func startListening() async throws {
        guard !isListening else { return }
        guard let recognizer, recognizer.isAvailable else {
            throw SpeechError.recognizerUnavailable
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let engine = AVAudioEngine()
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = false // server model is more accurate for accents
        }

        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            request.append(buffer)
            // Rough RMS level for the mic animation
            var level: Float = 0
            vDSP_vsq(buffer.floatChannelData![0], 1, buffer.floatChannelData![0], 1, vDSP_Length(buffer.frameLength))
            vDSP_sve(buffer.floatChannelData![0], 1, &level, vDSP_Length(buffer.frameLength))
            let rms = sqrtf(level / Float(buffer.frameLength))
            Task { @MainActor [weak self] in
                self?.audioLevel = min(1, rms * 24)
            }
        }

        engine.prepare()
        try engine.start()

        transcript = ""
        isListening = true
        audioEngine = engine
        recognitionRequest = request

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                }
                if error != nil || result?.isFinal == true {
                    self.isListening = false
                }
            }
        }
    }

    /// Stops listening and returns the best recognized text.
    @discardableResult
    func stopListening() async -> String {
        guard isListening else { return transcript }

        recognitionRequest?.endAudio()
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false
        audioLevel = 0

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return transcript
    }

    // MARK: - Errors

    enum SpeechError: LocalizedError {
        case recognizerUnavailable

        var errorDescription: String? {
            switch self {
            case .recognizerUnavailable:
                return "Trình nhận diện giọng nói chưa sẵn sàng. Kiểm tra kết nối mạng và thử lại."
            }
        }
    }
}
