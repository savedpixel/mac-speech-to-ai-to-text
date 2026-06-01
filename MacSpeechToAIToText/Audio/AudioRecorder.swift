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
    private let maxWaveformSamples = 720
    private let waveformFramesPerSecond: Double = 18
    private let bluetoothRouteSettleDelayMs: UInt64 = 800
    private let configChangeDebounceSeconds: TimeInterval = 0.35
    private let configChangeIgnoreWindowSeconds: TimeInterval = 0.75
    private var waveformFramesPerBucket: Int = 2450
    private var waveformAccumulatedPeak: Float = 0
    private var waveformAccumulatedPower: Float = 0
    private var waveformAccumulatedFrameCount = 0
    private var lastWaveformAmplitude: Float = 0

    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private(set) var isRecording = false
    private(set) var currentAudioLevel: Float = -160
    private(set) var recordingStartDate: Date = .now
    private(set) var waveformSampleInterval: TimeInterval = 1.0 / 18.0
    private(set) var waveformSamples: [Float] = []
    private var recordingURL: URL?
    private var configObserver: Any?
    private var pendingConfigChangeWorkItem: DispatchWorkItem?
    private var isRebuildingEngine = false
    private var ignoreConfigChangesUntil: Date = .distantPast
    private var activeRecordingSampleRate: Double = 0
    private var activeRecordingChannelCount: AVAudioChannelCount = 0
    private var lastAudioBufferAt: Date = .distantPast
    private let settings: Settings

    /// Callback fired when silence is detected for a given duration.
    /// Parameters: (silenceDuration: TimeInterval)
    var onSilenceDetected: ((TimeInterval) -> Void)?

    /// Callback to forward audio buffers to other consumers (e.g. send phrase detector)
    var onAudioBuffer: ((AVAudioPCMBuffer) -> Void)?

    /// Callback fired when speech resumes after a silent period.
    var onSpeechDetected: (() -> Void)?

    /// Callback fired after the audio engine is rebuilt due to config change
    var onEngineRebuilt: (() -> Void)?

    private var lastSpeechTime: Date = .now
    private let silenceLevelThreshold: Float = -30.0 // dB — tolerant of background noise

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
        let url = tempDir.appendingPathComponent("macspeech_recording_\(UUID().uuidString).wav")
        recordingURL = url
        DiagnosticLogger.shared.write("audio", "startRecording requested selectedMicrophoneID=\(settings.selectedMicrophoneID.isEmpty ? "system-default" : settings.selectedMicrophoneID) url=\(url.lastPathComponent)")

        if shouldPrimeInputRouteBeforeRecording() {
            DiagnosticLogger.shared.write("audio", "Priming Bluetooth input route before recording")
            // Only Bluetooth devices need the extra route-settling pass. For USB and wired mics,
            // the fixed 800ms wait makes recording feel laggy and causes missed opening words.
            do {
                let probe = AVAudioEngine()
                if !settings.selectedMicrophoneID.isEmpty {
                    _ = probe.inputNode.applyPreferredInputDevice(uid: settings.selectedMicrophoneID)
                }
                let _ = probe.inputNode.outputFormat(forBus: 0)
                probe.prepare()
                try probe.start()
                probe.stop()
                try await Task.sleep(nanoseconds: bluetoothRouteSettleDelayMs * 1_000_000)
            } catch {
                logger.info("Bluetooth route probe skipped (non-fatal): \(error.localizedDescription)")
                DiagnosticLogger.shared.write("audio", "Bluetooth route probe skipped error=\(error.localizedDescription)")
            }
        }

        try await setupEngineWithRetry(fileURL: url)
        recordingStartDate = .now
        waveformSamples.removeAll(keepingCapacity: true)
        resetWaveformState()
        isRecording = true

        logger.info("Recording started: \(url.lastPathComponent)")
        DiagnosticLogger.shared.write("audio", "Recording started url=\(url.lastPathComponent)")
        return url
    }

    func stopRecording() -> URL? {
        teardownEngine()
        audioFile = nil
        isRecording = false
        currentAudioLevel = 0.0
        waveformSamples.removeAll(keepingCapacity: true)
        resetWaveformState()

        logger.info("Recording stopped")
        DiagnosticLogger.shared.write("audio", "Recording stopped url=\(recordingURL?.lastPathComponent ?? "nil")")
        return recordingURL
    }

    // MARK: - Engine lifecycle

    private func setupEngineWithRetry(fileURL: URL) async throws {
        let maxAttempts = 4
        var lastError: Error?

        for attempt in 1...maxAttempts {
            do {
                try setupEngine(fileURL: fileURL, recreateAudioFile: true)
                if attempt > 1 {
                    logger.info("Recording engine started after retry \(attempt, privacy: .public)")
                }
                DiagnosticLogger.shared.write("audio", "Recording engine started attempt=\(attempt)")
                return
            } catch {
                lastError = error
                logger.warning("Recording engine start failed on attempt \(attempt, privacy: .public)/\(maxAttempts, privacy: .public): \(error.localizedDescription)")
                DiagnosticLogger.shared.write("audio", "Recording engine start failed attempt=\(attempt)/\(maxAttempts) error=\(error.localizedDescription)")
                teardownEngine()

                guard attempt < maxAttempts else { break }
                let backoffMs = UInt64(150 * attempt * attempt)
                try await Task.sleep(nanoseconds: backoffMs * 1_000_000)
            }
        }

        throw lastError ?? NSError(
            domain: "com.macvoice.app",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Recording engine failed to start"]
        )
    }

    private func setupEngine(fileURL: URL, recreateAudioFile: Bool) throws {
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode

        if !settings.selectedMicrophoneID.isEmpty {
            let didApplyPreferredInput = inputNode.applyPreferredInputDevice(uid: settings.selectedMicrophoneID)
            if !didApplyPreferredInput {
                logger.warning("Preferred microphone unavailable — falling back to current system input")
                DiagnosticLogger.shared.write("audio", "Preferred microphone unavailable id=\(settings.selectedMicrophoneID); falling back to system input")
            }
        }

        let format = inputNode.outputFormat(forBus: 0)
        waveformFramesPerBucket = max(1, Int(format.sampleRate / waveformFramesPerSecond))
        waveformSampleInterval = Double(waveformFramesPerBucket) / format.sampleRate

        logger.debug("Audio format: rate=\(format.sampleRate, privacy: .public), ch=\(format.channelCount, privacy: .public)")
        DiagnosticLogger.shared.write("audio", "Input format sampleRate=\(format.sampleRate) channels=\(format.channelCount)")

        guard format.sampleRate > 0 else {
            throw NSError(domain: "com.macvoice.app", code: 1, userInfo: [NSLocalizedDescriptionKey: "No audio input available (sample rate 0)"])
        }

        if recreateAudioFile || !canReuseOpenAudioFile(for: format) {
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
        }

        lastSpeechTime = .now

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            self.processBuffer(buffer)
        }

        engine.prepare()
        try engine.start()

        activeRecordingSampleRate = format.sampleRate
        activeRecordingChannelCount = format.channelCount
        lastAudioBufferAt = .now

        configObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            self?.handleConfigChange()
        }

        audioEngine = engine
        ignoreConfigChangesUntil = Date().addingTimeInterval(configChangeIgnoreWindowSeconds)
    }



    private func shouldPrimeInputRouteBeforeRecording() -> Bool {
        guard !settings.selectedMicrophoneID.isEmpty else { return false }
        guard let transportType = transportTypeForDevice(uid: settings.selectedMicrophoneID) else {
            return false
        }

        return transportType == kAudioDeviceTransportTypeBluetooth
            || transportType == kAudioDeviceTransportTypeBluetoothLE
    }

    private func canReuseOpenAudioFile(for format: AVAudioFormat) -> Bool {
        guard let audioFile else { return false }
        let currentFormat = audioFile.processingFormat
        return currentFormat.sampleRate == format.sampleRate
            && currentFormat.channelCount == format.channelCount
    }

    private func transportTypeForDevice(uid: String) -> UInt32? {
        for deviceID in allInputDeviceIDs() {
            guard uidForDevice(deviceID) == uid else { continue }

            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyTransportType,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var transportType: UInt32 = 0
            var size = UInt32(MemoryLayout<UInt32>.size)
            let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &transportType)
            if status == noErr {
                return transportType
            }
        }
        return nil
    }

    private func allInputDeviceIDs() -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr else {
            return []
        }

        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = Array(repeating: AudioDeviceID(0), count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceIDs) == noErr else {
            return []
        }

        return deviceIDs.filter { deviceHasInput($0) }
    }

    private func deviceHasInput(_ deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size) == noErr else {
            return false
        }

        let bufferList = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { bufferList.deallocate() }

        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, bufferList) == noErr else {
            return false
        }

        let audioBufferList = bufferList.assumingMemoryBound(to: AudioBufferList.self)
        let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
        return buffers.contains { $0.mNumberChannels > 0 }
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
        pendingConfigChangeWorkItem?.cancel()
        pendingConfigChangeWorkItem = nil
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
        guard isRecording else { return }
        guard Date() >= ignoreConfigChangesUntil else {
            logger.debug("Ignoring audio engine config change during stabilization window")
            return
        }

        pendingConfigChangeWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.rebuildEngineAfterConfigChange()
        }
        pendingConfigChangeWorkItem = workItem

        logger.warning("Audio engine config changed — scheduling rebuild")
        DiagnosticLogger.shared.write("audio", "Audio engine config changed; scheduling debounce rebuild")
        DispatchQueue.main.asyncAfter(deadline: .now() + configChangeDebounceSeconds, execute: workItem)
    }

    private func rebuildEngineAfterConfigChange() {
        guard isRecording else { return }
        guard !isRebuildingEngine else {
            logger.debug("Skipping engine rebuild — rebuild already in progress")
            return
        }
        guard Date() >= ignoreConfigChangesUntil else {
            logger.debug("Skipping engine rebuild — still within stabilization window")
            return
        }

        isRebuildingEngine = true
        defer { isRebuildingEngine = false }

        if canKeepCurrentEngineAfterConfigChange() {
            ignoreConfigChangesUntil = Date().addingTimeInterval(configChangeIgnoreWindowSeconds)
            pendingConfigChangeWorkItem = nil
            return
        }

        teardownEngine()

        guard let url = recordingURL else {
            logger.error("No recording URL — cannot rebuild engine")
            return
        }

        do {
            try setupEngine(fileURL: url, recreateAudioFile: false)
            lastSpeechTime = .now
            logger.info("Audio engine rebuilt successfully after config change")
            DiagnosticLogger.shared.write("audio", "Audio engine rebuilt after config change")
            onEngineRebuilt?()
        } catch {
            logger.error("Failed to rebuild audio engine: \(error.localizedDescription)")
            DiagnosticLogger.shared.write("audio", "Audio engine rebuild failed error=\(error.localizedDescription)")
        }
    }

    private func canKeepCurrentEngineAfterConfigChange() -> Bool {
        guard let engine = audioEngine else { return false }

        let format = engine.inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            logger.warning("Audio config changed to invalid format — rebuilding")
            return false
        }

        let formatUnchanged = format.sampleRate == activeRecordingSampleRate
            && format.channelCount == activeRecordingChannelCount
        let recentlyReceivedAudio = Date().timeIntervalSince(lastAudioBufferAt) < 1.5

        if formatUnchanged {
            if !engine.isRunning {
                do {
                    engine.prepare()
                    try engine.start()
                    lastAudioBufferAt = .now
                    logger.info("Audio engine restarted after same-format config change")
                    DiagnosticLogger.shared.write("audio", "Config change restarted existing engine; format unchanged recentlyReceivedAudio=\(recentlyReceivedAudio)")
                } catch {
                    logger.warning("Same-format audio engine restart failed — rebuilding: \(error.localizedDescription)")
                    DiagnosticLogger.shared.write("audio", "Config change same-format restart failed; rebuilding error=\(error.localizedDescription)")
                    return false
                }
            } else {
                logger.info("Audio config change kept same input format — keeping recorder running")
                DiagnosticLogger.shared.write("audio", "Config change ignored; format unchanged engineRunning=true recentlyReceivedAudio=\(recentlyReceivedAudio)")
            }
            return true
        }

        logger.warning(
            "Audio config change requires rebuild (formatUnchanged=\(formatUnchanged, privacy: .public), recentlyReceivedAudio=\(recentlyReceivedAudio, privacy: .public))"
        )
        DiagnosticLogger.shared.write("audio", "Config change requires rebuild formatUnchanged=\(formatUnchanged) recentlyReceivedAudio=\(recentlyReceivedAudio)")
        return false
    }

    private func processBuffer(_ buffer: AVAudioPCMBuffer) {
        lastAudioBufferAt = .now

        // Write to file
        do {
            try audioFile?.write(from: buffer)
        } catch {
            logger.error("Failed to write audio buffer: \(error.localizedDescription)")
        }

        // Forward buffer to consumers
        onAudioBuffer?(buffer)

        updateWaveformSamples(from: buffer)

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
            onSpeechDetected?()
            lastSpeechTime = .now
        } else {
            let silenceDuration = Date.now.timeIntervalSince(lastSpeechTime)
            onSilenceDetected?(silenceDuration)
        }
    }

    private func updateWaveformSamples(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }

        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return }

        var peak: Float = 0
        var powerSum: Float = 0
        for index in 0..<frameCount {
            let magnitude = abs(channelData[index])
            peak = max(peak, magnitude)
            powerSum += magnitude * magnitude
        }

        waveformAccumulatedPeak = max(waveformAccumulatedPeak, peak)
        waveformAccumulatedPower += powerSum
        waveformAccumulatedFrameCount += frameCount

        guard waveformAccumulatedFrameCount >= waveformFramesPerBucket else { return }

        let rms = sqrt(waveformAccumulatedPower / Float(max(1, waveformAccumulatedFrameCount)))
        let blendedAmplitude = max(rms * 0.95, waveformAccumulatedPeak * 0.38)
        let gatedAmplitude = max(0, blendedAmplitude - 0.012)
        let normalizedAmplitude = min(1, pow(gatedAmplitude * 4.6, 1.55))
        let smoothing: Float = normalizedAmplitude > lastWaveformAmplitude ? 0.44 : 0.16
        let smoothedAmplitude = lastWaveformAmplitude + (normalizedAmplitude - lastWaveformAmplitude) * smoothing
        lastWaveformAmplitude = smoothedAmplitude

        waveformSamples.append(smoothedAmplitude)
        if waveformSamples.count > maxWaveformSamples {
            waveformSamples.removeFirst(waveformSamples.count - maxWaveformSamples)
        }

        waveformAccumulatedPeak = 0
        waveformAccumulatedPower = 0
        waveformAccumulatedFrameCount = 0
    }

    private func resetWaveformState() {
        waveformAccumulatedPeak = 0
        waveformAccumulatedPower = 0
        waveformAccumulatedFrameCount = 0
        lastWaveformAmplitude = 0
    }
}
