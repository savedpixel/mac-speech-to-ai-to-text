import AVFoundation
import Speech
import os

final class InsertPhraseListener: NSObject, SFSpeechRecognizerDelegate {
    private let logger = Logger(subsystem: "com.macvoice.app", category: "input")

    private let settings: Settings
    var onInsert: () -> Void

    private var audioEngine: AVAudioEngine?
    private var recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private(set) var isListening = false

    /// Normalized phrase variants to match against.
    private var insertPhraseVariants: [String] {
        let phrase = settings.insertPhrase.lowercased().trimmingCharacters(in: .whitespaces)
        guard !phrase.isEmpty else { return [] }
        var variants = [phrase]
        let noPunc = phrase
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: ".", with: "")
        if noPunc != phrase { variants.append(noPunc) }
        for v in Array(variants) {
            if v.hasPrefix("ok ") {
                variants.append("okay" + v.dropFirst(2))
            } else if v.hasPrefix("okay ") {
                variants.append("ok" + v.dropFirst(4))
            }
        }
        return variants
    }

    init(settings: Settings, onInsert: @escaping () -> Void) {
        self.settings = settings
        self.onInsert = onInsert
        super.init()
        let rec = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        rec?.delegate = self
        self.recognizer = rec
    }

    // MARK: - SFSpeechRecognizerDelegate

    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if !available { stopListening() }
    }

    // MARK: - Public

    func startListening() {
        guard !isListening, settings.insertPhraseEnabled else { return }
        guard let recognizer, recognizer.isAvailable else {
            logger.warning("Insert phrase listener: speech recognizer unavailable")
            return
        }
        beginListening()
    }

    func stopListening() {
        guard isListening else { return }
        tearDownAudio()
        logger.info("Insert phrase listener stopped")
    }

    // MARK: - Private

    private func beginListening() {
        let engine = AVAudioEngine()
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true

        let inputNode = engine.inputNode
        
        if !settings.selectedMicrophoneID.isEmpty {
            inputNode.applyPreferredInputDevice(uid: settings.selectedMicrophoneID)
        }
        
        let format = inputNode.outputFormat(forBus: 0)

        recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let transcribed = result.bestTranscription.formattedString.lowercased()
                for variant in self.insertPhraseVariants {
                    if transcribed.contains(variant) {
                        self.logger.info("Insert phrase detected: '\(transcribed)'")
                        DispatchQueue.main.async { self.onInsert() }
                        self.stopListening()
                        return
                    }
                }
            }
            if let error {
                self.logger.warning("Insert phrase recognition error: \(error.localizedDescription)")
                self.tearDownAudio()
            }
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak request] buffer, _ in
            request?.append(buffer)
        }

        do {
            try engine.start()
            audioEngine = engine
            recognitionRequest = request
            isListening = true
            logger.info("Insert phrase listener started — listening for '\(self.settings.insertPhrase)'")
        } catch {
            logger.error("Insert phrase listener failed to start: \(error.localizedDescription)")
            tearDownAudio()
        }
    }

    private func tearDownAudio() {
        recognitionTask?.cancel()
        recognitionTask = nil
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        isListening = false
    }
}
