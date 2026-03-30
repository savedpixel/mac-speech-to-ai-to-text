import AVFoundation
import Speech
import os

final class WakePhraseListener: NSObject, SFSpeechRecognizerDelegate {
    private let logger = Logger(subsystem: "com.macvoice.app", category: "input")

    private let settings: Settings
    private let onWakePhrase: () -> Void

    private var audioEngine: AVAudioEngine?
    private var recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private(set) var isListening = false
    private var shouldBeListening = false
    private var isPaused = false
    private var pendingRestartWorkItem: DispatchWorkItem?
    private var restartBackoff: TimeInterval = 1.0
    private static let maxBackoff: TimeInterval = 60.0

    /// Normalized forms of the wake phrase to match against — built from settings
    private var wakePhraseVariants: [String] {
        let phrase = settings.wakePhrase.lowercased().trimmingCharacters(in: .whitespaces)
        guard !phrase.isEmpty else { return [] }
        var variants = [phrase]
        // Add comma-separated variant (e.g. "ok voice" → "ok, voice")
        let words = phrase.split(separator: " ")
        if words.count >= 2 {
            let commaVariant = words[0] + ", " + words.dropFirst().joined(separator: " ")
            variants.append(commaVariant)
        }
        // If starts with "ok", also add "okay" variant and vice versa
        if phrase.hasPrefix("ok ") {
            variants.append("okay" + phrase.dropFirst(2))
            variants.append("okay," + phrase.dropFirst(2))
        } else if phrase.hasPrefix("okay ") {
            variants.append("ok" + phrase.dropFirst(4))
            variants.append("ok," + phrase.dropFirst(4))
        }
        return variants
    }

    init(settings: Settings, onWakePhrase: @escaping () -> Void) {
        self.settings = settings
        self.onWakePhrase = onWakePhrase
        super.init()
        let rec = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        rec?.delegate = self
        self.recognizer = rec
    }

    // MARK: - SFSpeechRecognizerDelegate

    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        logger.info("Speech recognizer availability changed: \(available)")
        if available && shouldBeListening && !isPaused && !isListening {
            restartBackoff = 1.0
            beginListening()
        } else if !available {
            tearDownAudio()
        }
    }

    /// Temporarily pause listening (e.g. during recording). Call `resumeListening()` to restart.
    func pauseListening() {
        isPaused = true
        pendingRestartWorkItem?.cancel()
        pendingRestartWorkItem = nil
        tearDownAudio()
        logger.info("Wake phrase listener paused")
    }

    /// Resume listening after a pause.
    func resumeListening() {
        guard isPaused else { return }
        isPaused = false
        if shouldBeListening {
            logger.info("Wake phrase listener resuming")
            beginListening()
        }
    }

    func startListening() {
        shouldBeListening = true
        restartBackoff = 1.0

        guard settings.wakePhraseEnabled else {
            logger.debug("Wake phrase disabled in settings")
            return
        }

        guard let recognizer else {
            logger.warning("Speech recognizer could not be created")
            return
        }

        guard recognizer.isAvailable else {
            logger.info("Speech recognizer not yet available — waiting for availability callback")
            return
        }

        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard let self else { return }
            switch status {
            case .authorized:
                DispatchQueue.main.async {
                    self.beginListening()
                }
            default:
                self.logger.warning("Speech recognition not authorized (status: \(status.rawValue))")
            }
        }
    }

    private func beginListening() {
        guard shouldBeListening, !isPaused else { return }

        guard let recognizer, recognizer.isAvailable else {
            logger.info("Recognizer unavailable, deferring to availability callback")
            return
        }

        tearDownAudio()

        let engine = AVAudioEngine()
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = false
        request.taskHint = .search  // short utterance — better for wake phrase

        if #available(macOS 13, *), recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        let inputNode = engine.inputNode
        
        if !settings.selectedMicrophoneID.isEmpty {
            inputNode.applyPreferredInputDevice(uid: settings.selectedMicrophoneID)
        }
        
        let format = inputNode.outputFormat(forBus: 0)

        guard format.sampleRate > 0 else {
            logger.error("Audio input format has 0 sample rate — no mic available?")
            return
        }

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            logger.error("Wake phrase audio engine failed to start: \(error.localizedDescription)")
            scheduleRestart()
            return
        }

        audioEngine = engine
        recognitionRequest = request

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result {
                self.restartBackoff = 1.0
                let text = result.bestTranscription.formattedString.lowercased()
                self.logger.debug("Wake listener heard: \"\(text)\"")

                if self.containsWakePhrase(in: text) {
                    self.logger.info("Wake phrase detected!")
                    self.tearDownAudio()
                    DispatchQueue.main.async {
                        self.onWakePhrase()
                    }
                    // Restart after pipeline has time to claim the mic
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                        self?.beginListening()
                    }
                    return
                }
            }

            if let error {
                let nsError = error as NSError
                // Error 216 = "kAFAssistantErrorDomain request finished" — normal timeout, not a real error
                // Error 1110 = "no speech detected" — also normal
                if nsError.code == 216 || nsError.code == 1110 || nsError.domain == "kAFAssistantErrorDomain" {
                    self.logger.debug("Recognition session ended normally, restarting...")
                } else if nsError.code == 201 {
                    // 201 = recognition service not available — let delegate handle restart
                    self.logger.warning("Speech recognition service unavailable (201), waiting for availability")
                    self.restartBackoff = min(self.restartBackoff * 2, Self.maxBackoff)
                } else {
                    self.logger.error("Speech recognition error: \(error.localizedDescription) (code: \(nsError.code))")
                }
                self.tearDownAudio()
                self.scheduleRestart()
                return
            }

            if result?.isFinal ?? false {
                self.logger.debug("Recognition result is final, restarting...")
                self.tearDownAudio()
                self.scheduleRestart()
            }
        }

        isListening = true
        logger.info("Wake phrase listener started")
    }

    private func containsWakePhrase(in text: String) -> Bool {
        // Normalize: remove punctuation, collapse whitespace
        let normalized = text
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "!", with: "")
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        for variant in wakePhraseVariants {
            if normalized.contains(variant) { return true }
        }
        return false
    }

    private func scheduleRestart() {
        guard shouldBeListening, !isPaused else { return }
        pendingRestartWorkItem?.cancel()
        let delay = restartBackoff
        let work = DispatchWorkItem { [weak self] in
            self?.beginListening()
        }
        pendingRestartWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    func stopListening() {
        shouldBeListening = false
        isPaused = false
        pendingRestartWorkItem?.cancel()
        pendingRestartWorkItem = nil
        tearDownAudio()
        logger.info("Wake phrase listener stopped")
    }

    private func tearDownAudio() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        if let engine = audioEngine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        audioEngine = nil
        isListening = false
    }
}
