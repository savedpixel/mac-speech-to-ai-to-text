import AppKit
import os

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let logger = Logger(subsystem: "com.macvoice.app", category: "core")

    private var menuBarController: MenuBarController?
    private var recordingOverlayPanel: RecordingOverlayPanel?
    let settings = Settings()
    let permissionManager = PermissionManager()
    var pipelineCoordinator: PipelineCoordinator!
    let promptStore = PromptStore()
    let historyStore = HistoryStore()
    let audioPlayer = AudioPlayer()
    private(set) lazy var audioSignalPlayer = AudioSignalPlayer(settings: settings)
    private(set) lazy var transcriptionCleaner = TranscriptionCleaner(settings: settings, promptStore: promptStore)
    private(set) lazy var transcriptionEngine = TranscriptionEngine(settings: settings)
    private var shortcutManager: ShortcutManager!
    private var wakePhraseListener: WakePhraseListener!
    private var insertPhraseListener: InsertPhraseListener!
    private var serviceProvider: ServiceProvider!

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("Mac Voice launching")

        // Prune old recordings based on auto-delete setting
        historyStore.pruneOldRecordings(olderThanDays: settings.autoDeleteDays)

        let audioRecorder = AudioRecorder(settings: settings)
        let mediaController = MediaController()
        let textInserter = TextInserter()
        let sendPhraseDetector = SendPhraseDetector(settings: settings)
        wakePhraseListener = WakePhraseListener(settings: settings) { [weak self] in
            self?.pipelineCoordinator.activate()
        }

        insertPhraseListener = InsertPhraseListener(settings: settings) { [weak self] in
            self?.pipelineCoordinator.insertResult()
        }

        pipelineCoordinator = PipelineCoordinator(
            settings: settings,
            permissionManager: permissionManager,
            audioRecorder: audioRecorder,
            mediaController: mediaController,
            audioSignalPlayer: audioSignalPlayer,
            transcriptionEngine: transcriptionEngine,
            textInserter: textInserter,
            sendPhraseDetector: sendPhraseDetector,
            transcriptionCleaner: transcriptionCleaner,
            historyStore: historyStore,
            wakePhraseListener: wakePhraseListener,
            insertPhraseListener: insertPhraseListener
        )

        // Create overlay panel
        recordingOverlayPanel = RecordingOverlayPanel(
            pipelineCoordinator: pipelineCoordinator,
            audioRecorder: audioRecorder
        )

        // Wire overlay show/dismiss
        pipelineCoordinator.onOverlayShow = { [weak self] in
            self?.recordingOverlayPanel?.show()
        }
        pipelineCoordinator.onOverlayDismiss = { [weak self] in
            self?.recordingOverlayPanel?.dismiss()
        }

        settings.micDisconnected = !settings.keepMicrophoneConnected

        menuBarController = MenuBarController(
            pipelineCoordinator: pipelineCoordinator,
            permissionManager: permissionManager,
            settings: settings
        )

        shortcutManager = ShortcutManager(settings: settings) { [weak self] promptID in
            self?.pipelineCoordinator.activate(promptID: promptID)
        }

        // Register macOS Services provider for right-click → Services → "Start Mac Voice"
        serviceProvider = ServiceProvider { [weak self] in
            self?.pipelineCoordinator.activate()
        }
        NSApp.servicesProvider = serviceProvider
        NSUpdateDynamicServices()

        // React to wake phrase toggle — start/stop listener and release mic
        settings.onWakePhraseToggled = { [weak self] enabled in
            guard let self else { return }
            if enabled && self.settings.keepMicrophoneConnected && !self.settings.micDisconnected {
                self.logger.info("Wake phrase enabled — starting listener")
                self.wakePhraseListener.startListening()
            } else {
                self.logger.info("Wake phrase disabled — stopping listener, releasing mic")
                self.wakePhraseListener.stopListening()
            }
        }

        // React to mic disconnect toggle — stop/start all mic-holding listeners
        settings.onMicDisconnectedChanged = { [weak self] disconnected in
            guard let self else { return }
            if disconnected {
                self.logger.info("Mic disconnected by user — stopping all listeners")
                self.wakePhraseListener.stopListening()
                self.insertPhraseListener.stopListening()
            } else {
                self.logger.info("Mic reconnected by user — restarting enabled listeners")
                if self.settings.keepMicrophoneConnected,
                   self.settings.wakePhraseEnabled,
                   self.permissionManager.microphoneGranted {
                    self.wakePhraseListener.startListening()
                }
            }
        }
        
        settings.onMicrophoneChanged = { [weak self] _ in
            guard let self else { return }
            self.logger.info("Microphone changed — restarting listeners if running")
            if self.wakePhraseListener.isListening {
                self.wakePhraseListener.stopListening()
                self.wakePhraseListener.startListening()
            }
            if self.insertPhraseListener.isListening {
                self.insertPhraseListener.stopListening()
                self.insertPhraseListener.startListening()
            }
        }

        Task {
            await permissionManager.checkAllPermissions()

            if permissionManager.microphoneGranted,
               settings.keepMicrophoneConnected,
               settings.wakePhraseEnabled,
               !settings.micDisconnected {
                wakePhraseListener.startListening()
            }

            await transcriptionEngine.loadModel()
            await transcriptionEngine.fetchAvailableModels()
            transcriptionEngine.scanDownloadedModels()
        }

        logger.info("Mac Voice launched successfully")

        // Intercept main window close to hide instead of destroy
        DispatchQueue.main.async { [weak self] in
            if let window = NSApplication.shared.windows.first(where: { $0.title == "Mac Voice" }) {
                window.delegate = self
                window.minSize = NSSize(width: 920, height: 620)
                window.maxSize = NSSize(width: 1280, height: 920)
            }
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        logger.info("Mac Voice terminating")
        wakePhraseListener?.stopListening()
    }
}
