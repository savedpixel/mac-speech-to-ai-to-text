import AppKit
import SwiftUI
import os

final class PreferencesWindowController: NSWindowController {
    private let logger = Logger(subsystem: "com.macvoice.app", category: "ui")

    convenience init(settings: Settings, permissionManager: PermissionManager, promptStore: PromptStore) {
        let preferencesView = PreferencesView(
            settings: settings,
            permissionManager: permissionManager,
            promptStore: promptStore
        )
        let hostingController = NSHostingController(rootView: preferencesView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Mac Voice Preferences"
        window.styleMask = [.titled, .closable]
        window.center()
        window.setFrameAutosaveName("PreferencesWindow")

        self.init(window: window)
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(nil)
        logger.debug("Preferences window opened")
    }
}
