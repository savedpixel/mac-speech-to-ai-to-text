import AppKit
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

    init(settings: Settings) {
        self.settings = settings
    }

    // MARK: - Public API

    func playReadyBeep() async {
        await playPreset()
        logger.debug("Ready beep played")
    }

    func playRecordingFinishedBeep() async {
        await playPreset()
        logger.debug("Recording finished beep played")
    }

    func playSendPhraseReadyBeep() async {
        await playPreset()
        logger.debug("Send phrase ready beep played")
    }

    func playTranscriptionDoneBeep() async {
        await playPreset()
        logger.debug("Transcription done beep played")
    }

    func playAIDoneBeep() async {
        await playPreset()
        try? await Task.sleep(nanoseconds: 80_000_000)
        await playPreset()
        logger.debug("AI done double beep played")
    }

    // MARK: - Playback

    @MainActor
    private func playPreset(volumeScale: Float = 1.0) async {
        guard settings.beepEnabled else { return }
        let preset = SoundPreset(rawValue: settings.soundPreset) ?? .metallic
        guard let url = Bundle.main.url(forResource: preset.fileName, withExtension: "wav") else {
            logger.warning("Beep sound file not found: \(preset.fileName).wav in \(Bundle.main.resourcePath ?? "nil")")
            return
        }

        guard let sound = NSSound(contentsOf: url, byReference: true) else {
            logger.warning("Failed to create NSSound from \(preset.fileName).wav")
            return
        }

        sound.volume = Float(settings.beepVolume) * volumeScale
        sound.play()

        let durationNs = UInt64(sound.duration * 1_000_000_000) + 50_000_000
        try? await Task.sleep(nanoseconds: durationNs)
    }
}
