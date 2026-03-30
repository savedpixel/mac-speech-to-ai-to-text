import AppKit
import Carbon.HIToolbox
import os

final class MediaController {
    private let logger = Logger(subsystem: "com.macvoice.app", category: "audio")

    private var pausedApp: String?
    private var pausedWithMediaKey = false

    /// Media apps to check, in priority order
    private let mediaApps: [(name: String, checkScript: String, pauseScript: String, resumeScript: String)] = [
        (
            name: "Spotify",
            checkScript: "tell application \"System Events\" to (name of processes) contains \"Spotify\"",
            pauseScript: "tell application \"Spotify\" to if player state is playing then pause",
            resumeScript: "tell application \"Spotify\" to play"
        ),
        (
            name: "Music",
            checkScript: "tell application \"System Events\" to (name of processes) contains \"Music\"",
            pauseScript: "tell application \"Music\" to if player state is playing then pause",
            resumeScript: "tell application \"Music\" to play"
        ),
    ]

    func pauseMedia() async {
        pausedApp = nil
        pausedWithMediaKey = false

        if isSpotifyPlaying() {
            pressPlayPauseKey()
            pausedApp = "Spotify"
            pausedWithMediaKey = true
            logger.info("Paused Spotify via system play/pause key")
            return
        }

        for app in mediaApps {
            guard app.name != "Spotify" else { continue }

            // Check if the app is running
            guard runAppleScript(app.checkScript) == "true" else { continue }

            // Check if playing and pause
            let wasPlaying = runAppleScript(
                "tell application \"\(app.name)\" to return player state is playing"
            ) == "true"

            guard wasPlaying else {
                logger.debug("\(app.name, privacy: .public) running but not playing")
                continue
            }

            runAppleScript(app.pauseScript)
            pausedApp = app.name
            logger.info("Paused \(app.name, privacy: .public)")
            return
        }

        logger.info("No media playing — skipping pause")
    }

    func resumeMedia() {
        if pausedWithMediaKey {
            pressPlayPauseKey()
            logger.info("Resumed media via system play/pause key")
            pausedApp = nil
            pausedWithMediaKey = false
            return
        }

        guard let appName = pausedApp else {
            logger.debug("No app was paused by us — skipping resume")
            return
        }

        if let app = mediaApps.first(where: { $0.name == appName }) {
            runAppleScript(app.resumeScript)
            logger.info("Resumed \(appName, privacy: .public)")
        }
        pausedApp = nil
    }

    private func isSpotifyPlaying() -> Bool {
        runAppleScript("tell application \"Spotify\" to return player state as string") == "playing"
    }

    private func pressPlayPauseKey() {
        postMediaKeyEvent(key: NX_KEYTYPE_PLAY, keyDown: true)
        usleep(10_000)
        postMediaKeyEvent(key: NX_KEYTYPE_PLAY, keyDown: false)
    }

    private func postMediaKeyEvent(key: Int32, keyDown: Bool) {
        let flags = NSEvent.ModifierFlags(rawValue: 0xA00)
        let state: Int32 = keyDown ? 0xA : 0xB
        let data1 = Int((key << 16) | (state << 8))

        guard let event = NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: flags,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            subtype: 8,
            data1: data1,
            data2: -1
        ) else {
            logger.error("Failed to create system media key event")
            return
        }

        event.cgEvent?.post(tap: CGEventTapLocation.cghidEventTap)
    }

    @discardableResult
    private func runAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        let script = NSAppleScript(source: source)
        let result = script?.executeAndReturnError(&error)
        if let error {
            logger.debug("AppleScript error: \(error, privacy: .public)")
            return nil
        }
        return result?.stringValue
    }
}
