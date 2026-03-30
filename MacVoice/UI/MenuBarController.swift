import AppKit
import os

extension Notification.Name {
    static let showMainWindow = Notification.Name("showMainWindow")
}

final class MenuBarController: NSObject, NSMenuDelegate {
    private let logger = Logger(subsystem: "com.macvoice.app", category: "ui")

    private let statusItem: NSStatusItem
    private let pipelineCoordinator: PipelineCoordinator
    private let permissionManager: PermissionManager
    private let settings: Settings
    private var observation: Any?

    init(
        pipelineCoordinator: PipelineCoordinator,
        permissionManager: PermissionManager,
        settings: Settings
    ) {
        self.pipelineCoordinator = pipelineCoordinator
        self.permissionManager = permissionManager
        self.settings = settings
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        super.init()
        setupStatusItem()
        observeState()
        logger.debug("MenuBarController initialized")
    }

    private func setupStatusItem() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "mic.circle", accessibilityDescription: "Mac Voice")
        }
        rebuildMenu()
    }

    private func observeState() {
        observation = withObservationTracking {
            _ = pipelineCoordinator.state
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                self?.updateIcon()
                self?.rebuildMenu()
                self?.observeState()
            }
        }
    }

    private func updateIcon() {
        if settings.micDisconnected && pipelineCoordinator.state == .idle {
            statusItem.button?.image = NSImage(
                systemSymbolName: "mic.slash.circle",
                accessibilityDescription: "Mac Voice — Mic Disconnected"
            )
            return
        }

        let symbolName: String
        switch pipelineCoordinator.state {
        case .idle:
            symbolName = "mic.circle"
        case .preparingToRecord:
            symbolName = "mic.circle.fill"
        case .recording:
            symbolName = "mic.fill"
        case .transcribing:
            symbolName = "text.bubble"
        case .cleaning:
            symbolName = "sparkles"
        case .completed:
            symbolName = "checkmark.circle"
        case .error:
            symbolName = "exclamationmark.triangle"
        }

        statusItem.button?.image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: "Mac Voice"
        )
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.delegate = self

        // Status
        let statusItem = NSMenuItem(
            title: "Status: \(pipelineCoordinator.state.displayName)",
            action: nil,
            keyEquivalent: ""
        )
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        menu.addItem(.separator())

        // Record toggle
        if pipelineCoordinator.state.isActive {
            let stopItem = NSMenuItem(
                title: "Stop Recording",
                action: #selector(stopRecording),
                keyEquivalent: ""
            )
            stopItem.target = self
            menu.addItem(stopItem)
        } else {
            let startItem = NSMenuItem(
                title: "Start Recording",
                action: #selector(startRecording),
                keyEquivalent: ""
            )
            startItem.target = self
            menu.addItem(startItem)
        }

        menu.addItem(.separator())

        // Mic disconnect toggle
        let micItem = NSMenuItem(
            title: settings.micDisconnected ? "Connect Microphone" : "Disconnect Microphone",
            action: #selector(toggleMicDisconnect),
            keyEquivalent: ""
        )
        micItem.target = self
        if settings.micDisconnected {
            micItem.image = NSImage(systemSymbolName: "mic.slash", accessibilityDescription: nil)
        } else {
            micItem.image = NSImage(systemSymbolName: "mic", accessibilityDescription: nil)
        }
        menu.addItem(micItem)

        menu.addItem(.separator())

        // Media detection
        let mediaItems = detectPlayingMedia()
        if !mediaItems.isEmpty {
            for info in mediaItems {
                let item = NSMenuItem(title: info, action: nil, keyEquivalent: "")
                item.isEnabled = false
                item.image = NSImage(systemSymbolName: "speaker.wave.2", accessibilityDescription: nil)
                menu.addItem(item)
            }
            menu.addItem(.separator())
        }

        // Show main window
        let showItem = NSMenuItem(
            title: "Show Mac Voice",
            action: #selector(showMainWindow),
            keyEquivalent: ""
        )
        showItem.target = self
        menu.addItem(showItem)

        // Preferences
        let prefsItem = NSMenuItem(
            title: "Preferences…",
            action: #selector(openPreferences),
            keyEquivalent: ","
        )
        prefsItem.target = self
        menu.addItem(prefsItem)

        menu.addItem(.separator())

        // Quit
        let quitItem = NSMenuItem(
            title: "Quit Mac Voice",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        self.statusItem.menu = menu
    }

    @objc private func startRecording() {
        pipelineCoordinator.activate()
    }

    @objc private func stopRecording() {
        pipelineCoordinator.cancel()
    }

    @objc private func toggleMicDisconnect() {
        settings.micDisconnected.toggle()
        updateIcon()
        rebuildMenu()
    }

    @objc private func openPreferences() {
        showMainWindow()
    }

    @objc private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" || $0.title == "Mac Voice" }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            // Fallback: open via notification
            NotificationCenter.default.post(name: .showMainWindow, object: nil)
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu()
    }

    // MARK: - Media Detection

    private func detectPlayingMedia() -> [String] {
        var results: [String] = []
        let apps = NSWorkspace.shared.runningApplications

        // Spotify
        if apps.contains(where: { $0.bundleIdentifier == "com.spotify.client" }) {
            if spotifyIsPlaying() {
                results.append("Spotify is open and music is playing")
            } else {
                results.append("Spotify is open")
            }
        }

        return results
    }

    private func spotifyIsPlaying() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", "tell application \"Spotify\" to return player state as string"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) {
                if process.isRunning { process.terminate() }
            }
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let result = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return result == "playing"
        } catch {
            return false
        }
    }
}
