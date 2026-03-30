import AppKit
import os

/// macOS Services provider — adds "Start Mac Voice" to the system-wide right-click → Services menu.
final class ServiceProvider: NSObject {
    private let logger = Logger(subsystem: "com.macvoice.app", category: "input")
    private let activateAction: () -> Void

    init(activateAction: @escaping () -> Void) {
        self.activateAction = activateAction
        super.init()
    }

    /// Called by NSServices when the user selects "Start Mac Voice" from the context menu.
    @objc func startMacVoice(
        _ pboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        logger.info("Service invoked — activating Mac Voice")
        DispatchQueue.main.async { [weak self] in
            self?.activateAction()
        }
    }
}
