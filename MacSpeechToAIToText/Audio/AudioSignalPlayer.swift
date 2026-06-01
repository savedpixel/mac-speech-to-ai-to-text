import AVFoundation
import Foundation
import os

enum SoundPreset: String, CaseIterable, Codable {
    case electronic = "beep-button-electronic"
    case high = "beep-button-high"
    case metallic = "digital-chirp"
    case metallicTiny = "digital-ping"
    case doubleChime = "digital-beep-chirp"
    case double = "digital-beep-high"

    var displayName: String {
        switch self {
        case .electronic: return "Electronic"
        case .high: return "High"
        case .metallic: return "Metallic"
        case .metallicTiny: return "Metallic Tiny"
        case .doubleChime: return "Double Chime"
        case .double: return "Double"
        }
    }

    /// WAV filename (without extension) in the app bundle Resources.
    var fileName: String { rawValue }
}

final class AudioSignalPlayer {
    private let logger = Logger(subsystem: "com.macvoice.app", category: "audio")
    private let settings: Settings
    @MainActor private var cachedSoundData: [SoundPreset: Data] = [:]
    /// Retains short-lived signal players until playback finishes. Without this,
    /// the local playback object can deallocate before macOS actually plays it.
    @MainActor private var activePlayers: [UUID: AVAudioPlayer] = [:]

    init(settings: Settings) {
        self.settings = settings
    }

    @MainActor
    func preloadSounds() {
        let startedAt = DispatchTime.now()
        var loadedCount = 0
        var loadedBytes = 0

        for preset in SoundPreset.allCases {
            guard cachedSoundData[preset] == nil else { continue }
            guard let url = Bundle.main.url(forResource: preset.fileName, withExtension: "wav") else {
                DiagnosticLogger.shared.write("audio", "Preload missing beep preset=\(preset.fileName) resourcePath=\(Bundle.main.resourcePath ?? "nil")")
                continue
            }

            do {
                let data = try Data(contentsOf: url, options: [.mappedIfSafe])
                cachedSoundData[preset] = data
                loadedCount += 1
                loadedBytes += data.count
            } catch {
                DiagnosticLogger.shared.write("audio", "Preload failed preset=\(preset.fileName) error=\(error.localizedDescription)")
            }
        }

        let selectedPreset = SoundPreset(rawValue: settings.soundPreset) ?? .metallic
        if let data = cachedSoundData[selectedPreset] {
            do {
                let warmupPlayer = try AVAudioPlayer(data: data)
                warmupPlayer.volume = 0
                warmupPlayer.prepareToPlay()
            } catch {
                DiagnosticLogger.shared.write("audio", "Warmup failed preset=\(selectedPreset.fileName) error=\(error.localizedDescription)")
            }
        }

        let elapsedMs = Self.elapsedMilliseconds(since: startedAt)
        DiagnosticLogger.shared.write("audio", "Preloaded beep sounds loadedCount=\(loadedCount) cachedCount=\(cachedSoundData.count) bytes=\(loadedBytes) selected=\(selectedPreset.fileName) elapsedMs=\(elapsedMs)")
    }

    // MARK: - Public API

    func playReadyBeep() async {
        let played = await playPreset()
        logger.debug("Ready beep played")
        DiagnosticLogger.shared.write("audio", "Ready beep requested played=\(played)")
    }

    @discardableResult
    func playRecordingStartedBeep() async -> Bool {
        let played = await playPreset(volumeScale: 1.0)
        logger.debug("Recording started beep played")
        DiagnosticLogger.shared.write("audio", "Recording started beep requested played=\(played)")
        return played
    }

    func playRecordingFinishedBeep() async {
        let played = await playPreset()
        logger.debug("Recording finished beep played")
        DiagnosticLogger.shared.write("audio", "Recording finished beep requested played=\(played)")
    }

    func playSendAcceptedBeep() async {
        let firstPlayed = await playPreset(volumeScale: 1.0)
        try? await Task.sleep(nanoseconds: 80_000_000)
        let secondPlayed = await playPreset(volumeScale: 0.85)
        logger.debug("Send accepted beep played")
        DiagnosticLogger.shared.write("audio", "Send accepted beep requested firstPlayed=\(firstPlayed) secondPlayed=\(secondPlayed)")
    }

    func playSendPhraseReadyBeep() async {
        let played = await playPreset()
        logger.debug("Send phrase ready beep played")
        DiagnosticLogger.shared.write("audio", "Send phrase ready beep requested played=\(played)")
    }

    func playTranscriptionDoneBeep() async {
        let played = await playPreset()
        logger.debug("Transcription done beep played")
        DiagnosticLogger.shared.write("audio", "Transcription done beep requested played=\(played)")
    }

    func playAIDoneBeep() async {
        let firstPlayed = await playPreset()
        try? await Task.sleep(nanoseconds: 80_000_000)
        let secondPlayed = await playPreset()
        logger.debug("AI done double beep played")
        DiagnosticLogger.shared.write("audio", "AI done double beep requested firstPlayed=\(firstPlayed) secondPlayed=\(secondPlayed)")
    }

    func playInsertDoneBeep() async {
        let played = await playPreset()
        logger.debug("Insert confirmation beep played")
        DiagnosticLogger.shared.write("audio", "Insert confirmation beep requested played=\(played)")
    }

    // MARK: - Playback

    @MainActor
    @discardableResult
    private func playPreset(volumeScale: Float = 1.0) async -> Bool {
        let startedAt = DispatchTime.now()
        guard settings.beepEnabled else {
            DiagnosticLogger.shared.write("audio", "Beep skipped because beepEnabled=false")
            return false
        }

        let preset = SoundPreset(rawValue: settings.soundPreset) ?? .metallic
        let dataLoadStart = DispatchTime.now()
        guard let data = soundData(for: preset) else {
            return false
        }
        let dataLoadMs = Self.elapsedMilliseconds(since: dataLoadStart)

        let player: AVAudioPlayer
        let createStart = DispatchTime.now()
        do {
            player = try AVAudioPlayer(data: data)
            player.volume = Float(settings.beepVolume) * volumeScale
        } catch {
            logger.warning("Failed to create beep player for \(preset.fileName).wav: \(error.localizedDescription)")
            DiagnosticLogger.shared.write("audio", "Beep player failed preset=\(preset.fileName) error=\(error.localizedDescription) dataLoadMs=\(dataLoadMs)")
            return false
        }
        let createMs = Self.elapsedMilliseconds(since: createStart)

        let prepareStart = DispatchTime.now()
        let didPrepare = player.prepareToPlay()
        let prepareMs = Self.elapsedMilliseconds(since: prepareStart)

        let id = UUID()
        activePlayers[id] = player

        let playStart = DispatchTime.now()
        guard player.play() else {
            activePlayers[id] = nil
            logger.warning("Beep player refused to play \(preset.fileName).wav")
            DiagnosticLogger.shared.write("audio", "Beep play returned false preset=\(preset.fileName) dataLoadMs=\(dataLoadMs) createMs=\(createMs) prepareMs=\(prepareMs)")
            return false
        }
        let playCallMs = Self.elapsedMilliseconds(since: playStart)

        let duration = max(player.duration, 0.1)
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.25) { [weak self] in
            self?.activePlayers[id] = nil
        }

        let totalStartMs = Self.elapsedMilliseconds(since: startedAt)
        DiagnosticLogger.shared.write("audio", "Beep playing preset=\(preset.fileName) volume=\(player.volume) duration=\(duration) cached=\(cachedSoundData[preset] != nil) dataLoadMs=\(dataLoadMs) createMs=\(createMs) prepareMs=\(prepareMs) didPrepare=\(didPrepare) playCallMs=\(playCallMs) totalStartMs=\(totalStartMs) activePlayers=\(activePlayers.count)")
        let durationNs = UInt64(duration * 1_000_000_000) + 50_000_000
        try? await Task.sleep(nanoseconds: durationNs)
        return true
    }

    @MainActor
    private func soundData(for preset: SoundPreset) -> Data? {
        if let data = cachedSoundData[preset] {
            return data
        }

        guard let url = Bundle.main.url(forResource: preset.fileName, withExtension: "wav") else {
            logger.warning("Beep sound file not found: \(preset.fileName).wav in \(Bundle.main.resourcePath ?? "nil")")
            DiagnosticLogger.shared.write("audio", "Beep file missing preset=\(preset.fileName) resourcePath=\(Bundle.main.resourcePath ?? "nil")")
            return nil
        }

        do {
            let data = try Data(contentsOf: url, options: [.mappedIfSafe])
            cachedSoundData[preset] = data
            DiagnosticLogger.shared.write("audio", "Lazy-loaded beep preset=\(preset.fileName) bytes=\(data.count)")
            return data
        } catch {
            DiagnosticLogger.shared.write("audio", "Beep data load failed preset=\(preset.fileName) error=\(error.localizedDescription)")
            return nil
        }
    }

    private static func elapsedMilliseconds(since start: DispatchTime) -> Double {
        let nanos = DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds
        return Double(nanos) / 1_000_000.0
    }
}
