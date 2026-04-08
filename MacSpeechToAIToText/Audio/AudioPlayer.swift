import AVFoundation
import Foundation
import os

@Observable
final class AudioPlayer: NSObject, AVAudioPlayerDelegate {
    private let logger = Logger(subsystem: "com.macvoice.app", category: "audio")

    private var player: AVAudioPlayer?
    private(set) var isPlaying = false
    private(set) var duration: TimeInterval = 0
    private(set) var currentTime: TimeInterval = 0
    private var timer: Timer?

    var playbackProgress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }

    func play(url: URL) {
        stop()
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()
            duration = player?.duration ?? 0
            player?.play()
            isPlaying = true
            startTimer()
            logger.info("Playing: \(url.lastPathComponent)")
        } catch {
            logger.error("Failed to play audio: \(error.localizedDescription)")
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
        stopTimer()
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        stopTimer()
    }

    func seek(to time: TimeInterval) {
        player?.currentTime = time
        currentTime = time
    }

    func togglePlayPause(url: URL) {
        if isPlaying {
            pause()
        } else if player != nil {
            player?.play()
            isPlaying = true
            startTimer()
        } else {
            play(url: url)
        }
    }

    // MARK: - AVAudioPlayerDelegate

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        currentTime = 0
        stopTimer()
    }

    // MARK: - Timer

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let player = self.player else { return }
            self.currentTime = player.currentTime
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
