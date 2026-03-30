import AppKit
import Foundation
import os

@Observable
final class PipelineCoordinator {
    private let logger = Logger(subsystem: "com.macvoice.app", category: "core")

    private let settings: Settings
    private let permissionManager: PermissionManager
    let audioRecorder: AudioRecorder
    private let mediaController: MediaController
    private let audioSignalPlayer: AudioSignalPlayer
    private let transcriptionEngine: TranscriptionEngine
    private let textInserter: TextInserter
    private let sendPhraseDetector: SendPhraseDetector
    private let transcriptionCleaner: TranscriptionCleaner
    private let historyStore: HistoryStore
    private weak var wakePhraseListener: WakePhraseListener?
    private weak var insertPhraseListener: InsertPhraseListener?

    private(set) var state: PipelineState = .idle
    private var recordingURL: URL?
    /// Prompt override for the current activation — cleared after each pipeline run.
    private var activePromptID: UUID?
    /// Pending work item for auto-dismiss after copy.
    private var copyDismissWorkItem: DispatchWorkItem?

    /// Callback when overlay should show/hide
    var onOverlayShow: (() -> Void)?
    var onOverlayDismiss: (() -> Void)?

    init(
        settings: Settings,
        permissionManager: PermissionManager,
        audioRecorder: AudioRecorder,
        mediaController: MediaController,
        audioSignalPlayer: AudioSignalPlayer,
        transcriptionEngine: TranscriptionEngine,
        textInserter: TextInserter,
        sendPhraseDetector: SendPhraseDetector,
        transcriptionCleaner: TranscriptionCleaner,
        historyStore: HistoryStore,
        wakePhraseListener: WakePhraseListener? = nil,
        insertPhraseListener: InsertPhraseListener? = nil
    ) {
        self.settings = settings
        self.permissionManager = permissionManager
        self.audioRecorder = audioRecorder
        self.mediaController = mediaController
        self.audioSignalPlayer = audioSignalPlayer
        self.transcriptionEngine = transcriptionEngine
        self.textInserter = textInserter
        self.sendPhraseDetector = sendPhraseDetector
        self.transcriptionCleaner = transcriptionCleaner
        self.historyStore = historyStore
        self.wakePhraseListener = wakePhraseListener
        self.insertPhraseListener = insertPhraseListener

        setupCallbacks()
    }

    private func setupCallbacks() {
        // Forward audio buffers to the send phrase detector (only when enabled)
        audioRecorder.onAudioBuffer = { [weak self] buffer in
            guard let self, self.settings.sendPhraseEnabled else { return }
            self.sendPhraseDetector.appendBuffer(buffer)
        }

        // Feed silence duration to send phrase detector (only when enabled)
        audioRecorder.onSilenceDetected = { [weak self] duration in
            guard let self, self.state == .recording, self.settings.sendPhraseEnabled else { return }
            self.sendPhraseDetector.checkSilenceAfterPhrase(silenceDuration: duration)
        }

        // Restart send phrase detector when engine rebuilds (format change)
        audioRecorder.onEngineRebuilt = { [weak self] in
            guard let self, self.state == .recording, self.settings.sendPhraseEnabled else { return }
            self.logger.info("Engine rebuilt — restarting send phrase detector")
            self.sendPhraseDetector.stopMonitoring()
            self.sendPhraseDetector.startMonitoring()
        }

        // When send phrase + silence confirmed → stop and deliver
        sendPhraseDetector.onSendConfirmed = { [weak self] in
            guard let self, self.state == .recording else { return }
            self.logger.info("Send phrase confirmed — delivering")
            Task { @MainActor [weak self] in
                await self?.finalizePipeline()
            }
        }
    }

    /// Primary entry point — triggered by shortcut or wake phrase.
    /// - Parameter promptID: Optional prompt override for AI cleanup; nil = use selected prompt.
    func activate(promptID: UUID? = nil) {
        guard state == .idle else {
            logger.warning("Pipeline already active (state: \(self.state.displayName))")
            return
        }

        if settings.micDisconnected {
            logger.info("Starting on-demand recording while idle mic listeners are disconnected")
        }

        guard permissionManager.microphoneGranted else {
            logger.error("Microphone permission not granted")
            transition(to: .error("Microphone access required"))
            return
        }

        activePromptID = promptID

        Task { @MainActor in
            await runPipeline()
        }
    }

    /// Cancel the current pipeline.
    func cancel() {
        logger.info("Pipeline cancelled from state: \(self.state.displayName)")
        dismiss()
    }

    /// Manually finish recording (e.g. from overlay "Done" button).
    func finishRecording() {
        guard state == .recording else { return }
        logger.info("Manual finish recording requested")
        Task { @MainActor in
            await finalizePipeline()
        }
    }

    // MARK: - Pipeline Stages

    @MainActor
    private func runPipeline() async {
        // Stage 1: Prepare
        transition(to: .preparingToRecord)

        wakePhraseListener?.pauseListening()
        textInserter.captureActiveElement()
        await mediaController.pauseMedia()
        await audioSignalPlayer.playReadyBeep()
        onOverlayShow?()

        // Stage 2: Record
        transition(to: .recording)

        do {
            recordingURL = try await audioRecorder.startRecording()
              if settings.sendPhraseEnabled {
                  sendPhraseDetector.startMonitoring()
                  logger.info("Recording — say '\(self.settings.sendPhrase)' to send")
              } else {
                  logger.info("Recording — press Done to finish")
              }
        } catch {
            logger.error("Failed to start recording: \(error.localizedDescription)")
            cleanup()
            transition(to: .error("Recording failed: \(error.localizedDescription)"))
        }
    }

    @MainActor
    private func finalizePipeline() async {
        guard state == .recording else { return }

        // Stop recording & send phrase detector
        sendPhraseDetector.stopMonitoring()
        guard let url = audioRecorder.stopRecording() else {
            cleanup()
            transition(to: .error("No recording file"))
            return
        }

        // Copy audio to history BEFORE transcription so it's never lost
        let audioFileName = historyStore.copyAudioFile(from: url)

        // Save a pending record immediately — survives force-quit during transcription
        var pendingRecord = TranscriptionRecord(rawText: "", audioFileName: audioFileName, transcriptionStatus: .pending, whisperModel: settings.whisperModel)
        historyStore.addRecord(pendingRecord)
        let pendingID = pendingRecord.id

        transition(to: .transcribing)

        do {
            let text = try await transcriptionEngine.transcribe(audioFileURL: url)
            logger.info("Transcription: \(text)")

            let rawText = removeWakePhrase(from: removeSendPhrase(from: text))

            // Attempt AI cleanup
            var cleanedText: String? = nil
            var cleanupFailed = false
            var cleanupFailureReason: String? = nil

            if settings.aiCleanupEnabled {
                // Transcription done — single beep
                await audioSignalPlayer.playTranscriptionDoneBeep()
                transition(to: .cleaning)
                do {
                    cleanedText = try await transcriptionCleaner.clean(rawText, promptID: activePromptID)
                    // AI cleanup succeeded — double beep
                    await audioSignalPlayer.playAIDoneBeep()
                } catch {
                    logger.warning("AI cleanup failed: \(error.localizedDescription)")
                    cleanupFailed = true
                    cleanupFailureReason = error.localizedDescription
                }
            } else {
                // No AI cleanup — single beep for completion
                await audioSignalPlayer.playTranscriptionDoneBeep()
            }

            let result = TranscriptionResult(
                rawText: rawText,
                cleanedText: cleanedText,
                cleanupFailed: cleanupFailed,
                cleanupFailureReason: cleanupFailureReason
            )

            // Update the pending record to success
            var updated = pendingRecord
            updated.rawText = rawText
            updated.cleanedText = cleanedText
            updated.transcriptionStatus = .success
            historyStore.updateRecord(updated)

            transition(to: .completed(result))
            logger.info("Pipeline completed — awaiting user action")

            // Auto-insert if enabled
            if settings.autoInsertEnabled {
                logger.info("Auto-insert enabled — inserting result")
                insertResult()
            }
        } catch {
            logger.error("Transcription failed: \(error.localizedDescription)")

            // Save a failed record — audio is already preserved
            var failedRecord = pendingRecord
            failedRecord.transcriptionStatus = .failed(error.localizedDescription)
            historyStore.updateRecord(failedRecord)

            cleanup()
            transition(to: .error("Transcription failed: \(error.localizedDescription)"))
        }

        // Cleanup temp file (audio already copied to history dir)
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - User Actions (from overlay)

    func copyResult() {
        guard case .completed(let result) = state else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(result.displayText, forType: .string)
        logger.info("Result copied to clipboard")

        if settings.keepOverlayOpenOnCopy {
            logger.info("Keeping overlay open after copy")
            copyDismissWorkItem?.cancel()
            let delay = settings.copyAutoDismissDelay
            if delay > 0 {
                let item = DispatchWorkItem { [weak self] in self?.dismiss() }
                copyDismissWorkItem = item
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(delay), execute: item)
                logger.info("Auto-dismiss scheduled in \(delay)s")
            }
        } else {
            dismiss()
        }
    }

    func insertResult() {
        guard case .completed(let result) = state else { return }
        textInserter.insertTextAndSubmit(result.displayText)
        logger.info("Result inserted")
        dismiss()
    }

    func dismiss() {
        cleanup()
        transition(to: .idle)
        onOverlayDismiss?()
    }

    // MARK: - Helpers

    private func transition(to newState: PipelineState) {
        let oldState = state
        guard oldState.canTransition(to: newState) else {
            logger.warning("Invalid transition: \(oldState.displayName) → \(newState.displayName)")
            return
        }
        state = newState
        logger.info("Pipeline: \(oldState.displayName) → \(newState.displayName)")

        // Start insert phrase listener when completed; stop it otherwise
        if case .completed = newState, settings.keepMicrophoneConnected, !settings.micDisconnected {
            insertPhraseListener?.startListening()
        } else if isListeningForInsert {
            insertPhraseListener?.stopListening()
        }

        // Auto-reset from error after a delay
        if case .error = newState {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                if case .error = self?.state {
                    self?.dismiss()
                }
            }
        }
    }

    private var isListeningForInsert: Bool {
        insertPhraseListener?.isListening ?? false
    }

    private func cleanup() {
        sendPhraseDetector.stopMonitoring()
        _ = audioRecorder.stopRecording()
        textInserter.reset()
        insertPhraseListener?.stopListening()
        copyDismissWorkItem?.cancel()
        copyDismissWorkItem = nil
        activePromptID = nil

        if !settings.keepMicrophoneConnected && !settings.micDisconnected {
            settings.micDisconnected = true
        }

        if settings.autoResumeMedia {
            mediaController.resumeMedia()
        }

        if settings.keepMicrophoneConnected && !settings.micDisconnected {
            wakePhraseListener?.resumeListening()
        }
    }

    private func removeSendPhrase(from text: String) -> String {
        let phrase = settings.sendPhrase.lowercased().trimmingCharacters(in: .whitespaces)
        guard !phrase.isEmpty else { return text }

        // Build variants: base, comma/no-comma, ok/okay swaps
        var variants = [phrase]
        let noPunctuation = phrase.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: ".", with: "")
        if noPunctuation != phrase { variants.append(noPunctuation) }
        for v in Array(variants) {
            if v.hasPrefix("ok ") {
                variants.append("okay" + v.dropFirst(2))
            } else if v.hasPrefix("okay ") {
                variants.append("ok" + v.dropFirst(4))
            }
        }

        let normalized = text.lowercased()
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: ".", with: "")
        let normalizedVariants = variants.map {
            $0.replacingOccurrences(of: ",", with: "")
              .replacingOccurrences(of: ".", with: "")
        }

        // Search from the end of the text
        for variant in normalizedVariants {
            if normalized.hasSuffix(variant) {
                // Walk backwards in original text to find start position of match
                var vi = variant.endIndex
                var ti = text.endIndex
                while vi > variant.startIndex && ti > text.startIndex {
                    ti = text.index(before: ti)
                    let tc = text[ti].lowercased()
                    if tc == "," || tc == "." { continue }
                    vi = variant.index(before: vi)
                }
                let cleaned = String(text[text.startIndex..<ti])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return cleaned.isEmpty ? text : cleaned
            }
        }
        return text
    }

    private func removeWakePhrase(from text: String) -> String {
        let phrase = settings.wakePhrase.lowercased().trimmingCharacters(in: .whitespaces)
        guard !phrase.isEmpty else { return text }

        // Build the same variants as WakePhraseListener
        var variants = [phrase]
        let words = phrase.split(separator: " ")
        if words.count >= 2 {
            variants.append(words[0] + ", " + words.dropFirst().joined(separator: " "))
        }
        if phrase.hasPrefix("ok ") {
            variants.append("okay" + phrase.dropFirst(2))
            variants.append("okay," + phrase.dropFirst(2))
        } else if phrase.hasPrefix("okay ") {
            variants.append("ok" + phrase.dropFirst(4))
            variants.append("ok," + phrase.dropFirst(4))
        }

        // Strip from the beginning of the transcription (normalize punctuation for matching)
        let normalized = text.lowercased()
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: ".", with: "")
        let normalizedVariants = variants.map {
            $0.replacingOccurrences(of: ",", with: "")
              .replacingOccurrences(of: ".", with: "")
        }

        for variant in normalizedVariants {
            if normalized.hasPrefix(variant) {
                // Find the end position in the original text
                // Walk the original text skipping punctuation to find where the variant ends
                var vi = variant.startIndex
                var ti = text.startIndex
                while vi < variant.endIndex && ti < text.endIndex {
                    let tc = text[ti].lowercased()
                    if tc == "," || tc == "." {
                        ti = text.index(after: ti)
                        continue
                    }
                    vi = variant.index(after: vi)
                    ti = text.index(after: ti)
                }
                let cleaned = String(text[ti...]).trimmingCharacters(in: .whitespacesAndNewlines)
                return cleaned.isEmpty ? text : cleaned
            }
        }
        return text
    }
}
