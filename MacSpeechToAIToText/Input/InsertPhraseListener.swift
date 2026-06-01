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
    private let speechAppendQueue = DispatchQueue(label: "com.macvoice.insertPhrase.speechAppend")
    private var shouldRestartAfterRecognitionEnd = false
    private var pendingRestartWorkItem: DispatchWorkItem?
    private var staleListeningWorkItem: DispatchWorkItem?
    private var voiceFallbackWorkItem: DispatchWorkItem?
    private var restartBackoff: TimeInterval = 0.4
    private var appendedAudioBufferCount = 0
    private var firstAudioBufferAt: Date = .distantPast
    private var voiceActivityStartedAt: Date?
    private var lastVoiceActivityAt: Date = .distantPast
    private var lastPartialAt: Date = .distantPast
    private var listeningStartedAt: Date = .distantPast
    private var hasTriggeredInsert = false
    private static let maxBackoff: TimeInterval = 5.0
    private static let noAudioBufferTimeout: TimeInterval = 2.5
    private static let staleListeningTimeout: TimeInterval = 6.0
    private static let listenerHealthCheckInterval: TimeInterval = 2.5
    private static let voiceActivityThresholdDB: Float = -42.0
    private static let voiceActivityMinimumDuration: TimeInterval = 0.12
    private static let voiceActivitySilenceDelay: TimeInterval = 0.55

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
            if v == "ok" {
                variants.append("okay")
            } else if v == "okay" {
                variants.append("ok")
            } else if v.hasPrefix("ok ") {
                variants.append("okay" + v.dropFirst(2))
            } else if v.hasPrefix("okay ") {
                variants.append("ok" + v.dropFirst(4))
            }
        }
        if phrase == "insert" {
            variants.append(contentsOf: [
                "insect",     // common Speech framework misrecognition
                "in set",
                "insert it",
                "and insert",
                "ok insert",
                "okay insert"
            ])
        }
        return Array(Set(variants))
    }

    init(settings: Settings, onInsert: @escaping () -> Void) {
        self.settings = settings
        self.onInsert = onInsert
        super.init()
        self.recognizer = makeRecognizer()
    }

    private func makeRecognizer() -> SFSpeechRecognizer? {
        let rec = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        rec?.delegate = self
        return rec
    }

    // MARK: - SFSpeechRecognizerDelegate

    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if !available { stopListening() }
    }

    // MARK: - Public

    func startListening() {
        guard !isListening, settings.insertPhraseEnabled else {
            DiagnosticLogger.shared.write("insert", "Start skipped isListening=\(isListening) enabled=\(settings.insertPhraseEnabled)")
            return
        }
        recognizer = makeRecognizer()
        guard let recognizer, recognizer.isAvailable else {
            logger.warning("Insert phrase listener: speech recognizer unavailable")
            DiagnosticLogger.shared.write("insert", "Start failed speech recognizer unavailable")
            return
        }
        let supportsOnDevice: Bool
        if #available(macOS 13, *) {
            supportsOnDevice = recognizer.supportsOnDeviceRecognition
        } else {
            supportsOnDevice = false
        }
        DiagnosticLogger.shared.write("insert", "Start requested phrase=\(settings.insertPhrase) variants=\(insertPhraseVariants.joined(separator: "|")) auth=\(SFSpeechRecognizer.authorizationStatus().rawValue) recognizerAvailable=\(recognizer.isAvailable) supportsOnDevice=\(supportsOnDevice)")

        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            beginListening()
        case .notDetermined:
            SFSpeechRecognizer.requestAuthorization { [weak self] status in
                guard let self else { return }
                DispatchQueue.main.async {
                    if status == .authorized {
                        self.beginListening()
                    } else {
                        self.logger.warning("Insert phrase speech recognition not authorized (status: \(status.rawValue, privacy: .public))")
                        DiagnosticLogger.shared.write("insert", "Authorization denied status=\(status.rawValue)")
                    }
                }
            }
        default:
            logger.warning("Insert phrase speech recognition not authorized")
            DiagnosticLogger.shared.write("insert", "Start failed authorization status=\(SFSpeechRecognizer.authorizationStatus().rawValue)")
        }
    }

    func stopListening() {
        shouldRestartAfterRecognitionEnd = false
        pendingRestartWorkItem?.cancel()
        pendingRestartWorkItem = nil
        staleListeningWorkItem?.cancel()
        staleListeningWorkItem = nil
        voiceFallbackWorkItem?.cancel()
        voiceFallbackWorkItem = nil
        guard isListening || audioEngine != nil || recognitionTask != nil else { return }
        tearDownAudio()
        logger.info("Insert phrase listener stopped")
        DiagnosticLogger.shared.write("insert", "Stopped")
    }

    // MARK: - Private

    private func beginListening() {
        pendingRestartWorkItem?.cancel()
        pendingRestartWorkItem = nil
        guard settings.insertPhraseEnabled else { return }

        let engine = AVAudioEngine()
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = false
        request.taskHint = .confirmation
        request.contextualStrings = insertPhraseVariants
        if #available(macOS 13, *) {
            // Do not force on-device recognition for this very short command.
            // The recent failures show the listener can start but never emit
            // partials; letting Speech choose the best recognition path is more
            // reliable than pinning it to the local recognizer after the main
            // recorder has just used the input route.
            request.requiresOnDeviceRecognition = false
        }

        let inputNode = engine.inputNode

        // Prefer the same selected microphone that just succeeded for the main
        // recording. The latest failed test showed the system-default route
        // delivered only one buffer and then stalled, while the selected route
        // had recorded successfully moments earlier.
        let usingSystemDefaultInput: Bool
        if !settings.selectedMicrophoneID.isEmpty {
            inputNode.applyPreferredInputDevice(uid: settings.selectedMicrophoneID)
            usingSystemDefaultInput = false
        } else {
            usingSystemDefaultInput = true
        }
        
        let format = inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            logger.warning("Insert phrase listener input format unavailable — retrying")
            DiagnosticLogger.shared.write("insert", "Start failed invalid input format sampleRate=\(format.sampleRate) channels=\(format.channelCount)")
            scheduleRestart(after: restartBackoff)
            return
        }

        recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                self.lastPartialAt = .now
                self.restartBackoff = 0.4
                let transcribed = result.bestTranscription.formattedString.lowercased()
                let normalized = self.normalizedPhraseText(transcribed)
                DiagnosticLogger.shared.write("insert", "Heard partial='\(transcribed)' normalized='\(normalized)' final=\(result.isFinal) buffers=\(self.appendedAudioBufferCount)")
                for variant in self.insertPhraseVariants {
                    if normalized.contains(self.normalizedPhraseText(variant)) {
                        self.logger.info("Insert phrase detected: '\(transcribed)'")
                        DiagnosticLogger.shared.write("insert", "Matched phrase variant=\(variant) transcript='\(transcribed)'")
                        DispatchQueue.main.async { self.triggerInsert(reason: "speechMatch:\(variant)") }
                        return
                    }
                }
            }
            if let error {
                let nsError = error as NSError
                if self.isNormalRecognitionEnd(nsError) {
                    self.logger.debug("Insert phrase recognition session ended normally (code=\(nsError.code, privacy: .public))")
                    DiagnosticLogger.shared.write("insert", "Recognition ended normally code=\(nsError.code)")
                    let shouldRestart = self.shouldRestartAfterRecognitionEnd && self.settings.insertPhraseEnabled
                    self.tearDownAudio()
                    if shouldRestart {
                        self.scheduleRestart(after: 0.3)
                    }
                    return
                }

                self.logger.warning("Insert phrase recognition error: \(error.localizedDescription)")
                DiagnosticLogger.shared.write("insert", "Recognition error=\(error.localizedDescription)")
                let shouldRestart = self.shouldRestartAfterRecognitionEnd && self.settings.insertPhraseEnabled
                self.tearDownAudio()
                if shouldRestart {
                    self.scheduleRestart(after: self.restartBackoff)
                }
            }
        }

        inputNode.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self, weak request] buffer, _ in
            guard let self else { return }
            let levelDB = self.rmsDB(buffer)
            self.noteAudioBuffer(frameLength: buffer.frameLength, levelDB: levelDB)

            // Do not let Speech.framework back-pressure stall the real-time tap.
            // The failing v1.0.18 log showed exactly one buffer followed by no
            // partials, which is consistent with the tap being blocked by the
            // recognizer. Copy and append off the audio thread so voice-activity
            // fallback and diagnostics keep receiving buffers even if Speech
            // hangs.
            guard let copiedBuffer = self.copyBuffer(buffer) else {
                DiagnosticLogger.shared.write("insert", "Failed to copy audio buffer for Speech append")
                return
            }
            self.speechAppendQueue.async {
                request?.append(copiedBuffer)
            }
        }

        do {
            engine.prepare()
            try engine.start()
            audioEngine = engine
            recognitionRequest = request
            isListening = true
            shouldRestartAfterRecognitionEnd = true
            restartBackoff = 0.4
            listeningStartedAt = .now
            firstAudioBufferAt = .distantPast
            appendedAudioBufferCount = 0
            voiceActivityStartedAt = nil
            lastVoiceActivityAt = .distantPast
            lastPartialAt = .distantPast
            hasTriggeredInsert = false
            scheduleStaleListeningWatchdog()
            logger.info("Insert phrase listener started — listening for '\(self.settings.insertPhrase)'")
            DiagnosticLogger.shared.write("insert", "Listening started phrase=\(settings.insertPhrase) variants=\(insertPhraseVariants.joined(separator: "|")) sampleRate=\(format.sampleRate) channels=\(format.channelCount) systemDefaultInput=\(usingSystemDefaultInput) selectedMicrophoneID=\(settings.selectedMicrophoneID) taskHint=confirmation requiresOnDevice=false voiceFallbackThresholdDB=\(Self.voiceActivityThresholdDB)")
        } catch {
            logger.error("Insert phrase listener failed to start: \(error.localizedDescription)")
            DiagnosticLogger.shared.write("insert", "Start failed error=\(error.localizedDescription)")
            tearDownAudio()
            if shouldRestartAfterRecognitionEnd || settings.insertPhraseEnabled {
                scheduleRestart(after: restartBackoff)
            }
        }
    }

    private func scheduleRestart(after delay: TimeInterval) {
        guard settings.insertPhraseEnabled else { return }
        shouldRestartAfterRecognitionEnd = true
        pendingRestartWorkItem?.cancel()
        let actualDelay = min(delay, Self.maxBackoff)
        restartBackoff = min(max(restartBackoff * 1.6, 0.4), Self.maxBackoff)
        DiagnosticLogger.shared.write("insert", "Scheduling restart delay=\(actualDelay)")
        let item = DispatchWorkItem { [weak self] in
            self?.startListening()
        }
        pendingRestartWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + actualDelay, execute: item)
    }

    private func noteAudioBuffer(frameLength: AVAudioFrameCount, levelDB: Float) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isListening else { return }
            self.appendedAudioBufferCount += 1
            if self.firstAudioBufferAt == .distantPast {
                self.firstAudioBufferAt = .now
                let startupMs = self.firstAudioBufferAt.timeIntervalSince(self.listeningStartedAt) * 1000
                DiagnosticLogger.shared.write("insert", "First audio buffer received frameLength=\(frameLength) startupMs=\(startupMs) levelDB=\(levelDB)")
            }

            if levelDB >= Self.voiceActivityThresholdDB {
                let now = Date()
                if self.voiceActivityStartedAt == nil {
                    self.voiceActivityStartedAt = now
                    DiagnosticLogger.shared.write("insert", "Voice activity started levelDB=\(levelDB) buffer=\(self.appendedAudioBufferCount)")
                    self.triggerInsert(reason: "voiceActivityImmediateFallback")
                    return
                }
                self.lastVoiceActivityAt = now
                self.scheduleVoiceActivityFallback()
            }
        }
    }

    private func scheduleVoiceActivityFallback() {
        voiceFallbackWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self,
                  self.isListening,
                  !self.hasTriggeredInsert,
                  self.settings.insertPhraseEnabled,
                  let startedAt = self.voiceActivityStartedAt else { return }

            let now = Date()
            let voiceDuration = self.lastVoiceActivityAt.timeIntervalSince(startedAt)
            let silenceDuration = now.timeIntervalSince(self.lastVoiceActivityAt)
            guard voiceDuration >= Self.voiceActivityMinimumDuration,
                  silenceDuration >= Self.voiceActivitySilenceDelay else {
                self.scheduleVoiceActivityFallback()
                return
            }

            DiagnosticLogger.shared.write("insert", "Voice activity fallback inserting voiceDuration=\(voiceDuration) silenceDuration=\(silenceDuration) buffers=\(self.appendedAudioBufferCount) heardSpeechPartial=\(self.lastPartialAt != .distantPast)")
            self.triggerInsert(reason: "voiceActivityFallback")
        }
        voiceFallbackWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.voiceActivitySilenceDelay, execute: item)
    }

    private func triggerInsert(reason: String) {
        guard !hasTriggeredInsert else {
            DiagnosticLogger.shared.write("insert", "Trigger ignored duplicate reason=\(reason)")
            return
        }
        hasTriggeredInsert = true
        shouldRestartAfterRecognitionEnd = false
        pendingRestartWorkItem?.cancel()
        pendingRestartWorkItem = nil
        voiceFallbackWorkItem?.cancel()
        voiceFallbackWorkItem = nil
        DiagnosticLogger.shared.write("insert", "Triggering insert reason=\(reason)")
        onInsert()
        stopListening()
    }

    private func rmsDB(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData, buffer.frameLength > 0 else {
            return -160.0
        }
        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)
        var sum: Float = 0
        for channel in 0..<channelCount {
            let samples = channelData[channel]
            for frame in 0..<frameLength {
                let sample = samples[frame]
                sum += sample * sample
            }
        }
        let meanSquare = sum / Float(max(channelCount * frameLength, 1))
        guard meanSquare > 0 else { return -160.0 }
        return 10 * log10(meanSquare)
    }

    private func copyBuffer(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let copied = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameLength) else {
            return nil
        }
        copied.frameLength = buffer.frameLength
        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        if let src = buffer.floatChannelData, let dst = copied.floatChannelData {
            for channel in 0..<channelCount {
                dst[channel].update(from: src[channel], count: frameLength)
            }
            return copied
        }
        if let src = buffer.int16ChannelData, let dst = copied.int16ChannelData {
            for channel in 0..<channelCount {
                dst[channel].update(from: src[channel], count: frameLength)
            }
            return copied
        }
        if let src = buffer.int32ChannelData, let dst = copied.int32ChannelData {
            for channel in 0..<channelCount {
                dst[channel].update(from: src[channel], count: frameLength)
            }
            return copied
        }
        return nil
    }

    private func scheduleStaleListeningWatchdog() {
        staleListeningWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self,
                  self.isListening,
                  self.shouldRestartAfterRecognitionEnd,
                  self.settings.insertPhraseEnabled else { return }

            let secondsSinceStart = Date().timeIntervalSince(self.listeningStartedAt)
            let hasAudioBuffers = self.firstAudioBufferAt != .distantPast
            let hasHeardPartial = self.lastPartialAt != .distantPast
            if !hasAudioBuffers && secondsSinceStart >= Self.noAudioBufferTimeout {
                DiagnosticLogger.shared.write("insert", "No audio buffers after \(secondsSinceStart)s; restarting insert listener")
                self.tearDownAudio()
                self.scheduleRestart(after: 0.2)
                return
            }

            if hasAudioBuffers && !hasHeardPartial && secondsSinceStart >= Self.staleListeningTimeout {
                let firstBufferMs = self.firstAudioBufferAt.timeIntervalSince(self.listeningStartedAt) * 1000
                DiagnosticLogger.shared.write("insert", "Audio buffers without Speech partials after \(secondsSinceStart)s buffers=\(self.appendedAudioBufferCount) firstBufferMs=\(firstBufferMs); restarting insert listener")
                self.tearDownAudio()
                self.scheduleRestart(after: 0.25)
                return
            }

            self.scheduleStaleListeningWatchdog()
        }
        staleListeningWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.listenerHealthCheckInterval, execute: item)
    }

    private func normalizedPhraseText(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "!", with: "")
            .replacingOccurrences(of: "?", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func tearDownAudio() {
        staleListeningWorkItem?.cancel()
        staleListeningWorkItem = nil
        voiceFallbackWorkItem?.cancel()
        voiceFallbackWorkItem = nil
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        recognitionRequest = nil
        isListening = false
        appendedAudioBufferCount = 0
        firstAudioBufferAt = .distantPast
        voiceActivityStartedAt = nil
        lastVoiceActivityAt = .distantPast
    }

    private func isNormalRecognitionEnd(_ error: NSError) -> Bool {
        error.code == 1110 ||
        error.code == 216 ||
        error.code == 301 ||
        error.domain == "kAFAssistantErrorDomain"
    }
}
