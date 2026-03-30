import AVFoundation
import AudioToolbox
import CoreAudio
import os

struct MicrophoneOption: Identifiable, Hashable {
    let id: String
    let name: String
}

@Observable
final class AudioRecorder {
    private let logger = Logger(subsystem: "com.macvoice.app", category: "audio")

    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private(set) var isRecording = false
    private(set) var currentAudioLevel: Float = 0.0
    private var recordingURL: URL?
    private var configObserver: Any?
    private let settings: Settings

    /// Callback fired when silence is detected for a given duration.
    /// Parameters: (silenceDuration: TimeInterval)
    var onSilenceDetected: ((TimeInterval) -> Void)?

    /// Callback to forward audio buffers to other consumers (e.g. send phrase detector)
    var onAudioBuffer: ((AVAudioPCMBuffer) -> Void)?

    /// Callback fired after the audio engine is rebuilt due to config change
    var onEngineRebuilt: (() -> Void)?

    private var lastSpeechTime: Date = .now
    private let silenceLevelThreshold: Float = -40.0 // dB

    init(settings: Settings) {
        self.settings = settings
    }

    static func availableMicrophones() -> [MicrophoneOption] {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        )
        .devices
        .map { MicrophoneOption(id: $0.uniqueID, name: $0.localizedName) }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func startRecording() async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let url = tempDir.appendingPathComponent("macvoice_recording_\(UUID().uuidString).wav")
        recordingURL = url

        // Pre-trigger BT audio route change by briefly touching the input node.
        // This causes the A2DP→HFP switch to happen before we install our real tap,
        // preventing the config-change rebuild that causes the mic indicator to flash.
        let probe = AVAudioEngine()
        let _ = probe.inputNode.outputFormat(forBus: 0)
        probe.prepare()
        try probe.start()
        probe.stop()

        // Wait for the BT route to settle
        try await Task.sleep(for: .milliseconds(800))

        try setupEngine(fileURL: url)
        isRecording = true

        logger.info("Recording started: \(url.lastPathComponent)")
        return url
    }

    func stopRecording() -> URL? {
        teardownEngine()
        audioFile = nil
        isRecording = false
        currentAudioLevel = 0.0

        logger.info("Recording stopped")
        return recordingURL
    }

    // MARK: - Engine lifecycle

    private func setupEngine(fileURL: URL) throws {
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode

        if !settings.selectedMicrophoneID.isEmpty {
            inputNode.applyPreferredInputDevice(uid: settings.selectedMicrophoneID)
        }

        let format = inputNode.outputFormat(forBus: 0)

        logger.debug("Audio format: rate=\(format.sampleRate, privacy: .public), ch=\(format.channelCount, privacy: .public)")

        guard format.sampleRate > 0 else {
            throw NSError(domain: "com.macvoice.app", code: 1, userInfo: [NSLocalizedDescriptionKey: "No audio input available (sample rate 0)"])
        }

        audioFile = try AVAudioFile(
            forWriting: fileURL,
            settings: [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: format.sampleRate,
                AVNumberOfChannelsKey: format.channelCount,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
            ]
        )

        lastSpeechTime = .now

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            self.processBuffer(buffer)
        }

        engine.prepare()
        try engine.start()

        configObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            self?.handleConfigChange()
        }

        audioEngine = engine
    }



    private func uidForDevice(_ deviceID: AudioDeviceID) -> String? {
        var uidAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var uidRef: CFString = "" as CFString
        var uidSize = UInt32(MemoryLayout<CFString>.size)

        let status = AudioObjectGetPropertyData(deviceID, &uidAddress, 0, nil, &uidSize, &uidRef)
        return status == noErr ? (uidRef as String) : nil
    }

    private func teardownEngine() {
        if let observer = configObserver {
            NotificationCenter.default.removeObserver(observer)
            configObserver = nil
        }
        if let engine = audioEngine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        audioEngine = nil
    }

    private func handleConfigChange() {
        guard isRecording, let engine = audioEngine else { return }
        logger.warning("Audio engine config changed — restarting in-place")

        let inputNode = engine.inputNode
        inputNode.removeTap(onBus: 0)

        // Get the new format after the route change
        let newFormat = inputNode.outputFormat(forBus: 0)
        logger.debug("New format: rate=\(newFormat.sampleRate, privacy: .public), ch=\(newFormat.channelCount, privacy: .public)")

        guard newFormat.sampleRate > 0, newFormat.channelCount > 0 else {
            logger.error("New format invalid — cannot restart")
            return
        }

        // Recreate audio file with new format
        if let url = recordingURL {
            do {
                audioFile = try AVAudioFile(
                    forWriting: url,
                    settings: [
                        AVFormatIDKey: Int(kAudioFormatLinearPCM),
                        AVSampleRateKey: newFormat.sampleRate,
                        AVNumberOfChannelsKey: newFormat.channelCount,
                        AVLinearPCMBitDepthKey: 16,
                        AVLinearPCMIsFloatKey: false,
                    ]
                )
            } catch {
                logger.error("Failed to recreate audio file: \(error.localizedDescription)")
            }
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: newFormat) { [weak self] buffer, _ in
            guard let self else { return }
            self.processBuffer(buffer)
        }

        do {
            engine.prepare()
            try engine.start()
            lastSpeechTime = .now
            logger.info("Audio engine restarted in-place")
            onEngineRebuilt?()
        } catch {
            logger.error("Failed to restart audio engine: \(String(describing: error), privacy: .public)")
        }
    }

    private func processBuffer(_ buffer: AVAudioPCMBuffer) {
        // Write to file
        do {
            try audioFile?.write(from: buffer)
        } catch {
            logger.error("Failed to write audio buffer: \(error.localizedDescription)")
        }

        // Forward buffer to consumers
        onAudioBuffer?(buffer)

        // Calculate RMS level
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)
        var sum: Float = 0
        for i in 0..<frameCount {
            sum += channelData[i] * channelData[i]
        }
        let rms = sqrt(sum / Float(frameCount))
        let db = 20 * log10(max(rms, 1e-10))

        currentAudioLevel = db

        // Silence detection
        if db > silenceLevelThreshold {
            lastSpeechTime = .now
        } else {
            let silenceDuration = Date.now.timeIntervalSince(lastSpeechTime)
            onSilenceDetected?(silenceDuration)
        }
    }
}
