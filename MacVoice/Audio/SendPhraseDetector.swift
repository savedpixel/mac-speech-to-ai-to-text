import AVFoundation
import Speech
import os

final class SendPhraseDetector {
    private let logger = Logger(subsystem: "com.macvoice.app", category: "audio")

    private let settings: Settings
    private var recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var phraseDetectedTime: Date?
    private var silenceReadyFired = true  // true initially — don't beep before first speech
    private var lastRecognizedText = ""

    /// Fired when send phrase is detected AND silence threshold is met.
    var onSendConfirmed: (() -> Void)?
    /// Fired once when silence threshold is met before phrase — indicates it's safe to speak the send phrase.
    var onSilenceReady: (() -> Void)?

    init(settings: Settings) {
        self.settings = settings
        self.recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    private var lastWordCount = 0

    /// Begin monitoring for the send phrase. Call `appendBuffer(_:)` to feed audio.
    func startMonitoring() {
        let authStatus = SFSpeechRecognizer.authorizationStatus()
        logger.info("Speech auth status: \(String(describing: authStatus).replacingOccurrences(of: "SFSpeechRecognizerAuthorizationStatus.", with: ""), privacy: .public)")
        
        guard let recognizer else {
            logger.warning("Speech recognizer is nil")
            return
        }
        logger.info("Speech recognizer available: \(recognizer.isAvailable)")
        guard recognizer.isAvailable else {
            logger.warning("Speech recognizer not available")
            return
        }

        stopMonitoring()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = false
        recognitionRequest = request

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result {
                let text = result.bestTranscription.formattedString.lowercased()
                let words = text.split(separator: " ")
                self.logger.debug("Send detector heard: \"\(text)\"")

                // Rearm silence-ready beep when recognizer hears new words
                if words.count != self.lastWordCount {
                    self.lastWordCount = words.count
                    self.lastRecognizedText = text
                    self.silenceReadyFired = false
                }

                // Only check the LAST word(s) for the send phrase — not full accumulated text
                let recentText = words.suffix(3).joined(separator: " ")
                if self.matchesSendPhrase(recentText) && self.phraseDetectedTime == nil {
                    self.phraseDetectedTime = .now
                    self.logger.info("Send phrase detected, waiting for silence")
                }
            }

            if let error {
                self.logger.error("Speech recognition error: \(String(describing: error), privacy: .public)")
            }
        }

        logger.info("Send phrase monitoring started for: \"\(self.settings.sendPhrase)\"")
    }

    /// Call from the audio recorder's silence callback to check if send should be confirmed.
    func checkSilenceAfterPhrase(silenceDuration: TimeInterval) {
        // Phrase not yet detected — notify when silence threshold is met (ready to accept phrase)
        if phraseDetectedTime == nil {
            if silenceDuration >= settings.silenceThreshold && !silenceReadyFired {
                silenceReadyFired = true
                logger.info("Silence threshold met — send phrase ready")
                onSilenceReady?()
            }
            return
        }

        if silenceDuration >= settings.silenceThreshold {
            logger.info("Send confirmed — silence threshold met")
            onSendConfirmed?()
            reset()
        }
    }

    /// Feed audio buffers from the shared AudioRecorder.
    func appendBuffer(_ buffer: AVAudioPCMBuffer) {
        recognitionRequest?.append(buffer)
    }

    /// If the user continues speaking after the phrase, require a fresh phrase detection.
    func resetPendingConfirmationIfNeeded() {
        guard phraseDetectedTime != nil else { return }
        logger.info("Speech resumed after send phrase — resetting confirmation")
        phraseDetectedTime = nil
    }

    /// Match the send phrase flexibly — "ok" matches "okay", "OK", etc.
    private func matchesSendPhrase(_ text: String) -> Bool {
        let phrase = settings.sendPhrase.lowercased()
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: ".", with: "")
            .trimmingCharacters(in: .whitespaces)

        // Exact substring match
        if text.contains(phrase) { return true }

        // "ok" ↔ "okay" equivalence
        let normalized = text
            .replacingOccurrences(of: "okay", with: "ok")
        let normalizedPhrase = phrase
            .replacingOccurrences(of: "okay", with: "ok")

        if normalized.contains(normalizedPhrase) { return true }

        // Also check the reverse: user typed "ok" but recognizer says "okay"
        let text2 = text.replacingOccurrences(of: "ok", with: "okay")
        let phrase2 = phrase.replacingOccurrences(of: "ok", with: "okay")
        if text2.contains(phrase2) { return true }

        return false
    }

    func stopMonitoring() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        phraseDetectedTime = nil
        silenceReadyFired = true
        lastRecognizedText = ""
        lastWordCount = 0
        logger.debug("Send phrase monitoring stopped")
    }

    func reset() {
        phraseDetectedTime = nil
        silenceReadyFired = true
        lastRecognizedText = ""
        lastWordCount = 0
    }
}
