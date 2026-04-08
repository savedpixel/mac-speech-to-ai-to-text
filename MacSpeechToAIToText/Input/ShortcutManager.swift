import AppKit
import Carbon.HIToolbox
import HotKey
import os

final class ShortcutManager {
    private let logger = Logger(subsystem: "com.macvoice.app", category: "input")

    private let settings: Settings
    private let onActivate: (UUID?) -> Void
    /// Keyed by ShortcutBinding.id so deregistration is clean.
    private var hotKeys: [UUID: HotKey] = [:]

    init(settings: Settings, onActivate: @escaping (UUID?) -> Void) {
        self.settings = settings
        self.onActivate = onActivate
        registerHotKeys()

        settings.onShortcutBindingsChanged = { [weak self] in
            self?.registerHotKeys()
        }
    }

    func registerHotKeys() {
        hotKeys.removeAll() // deregisters all previous HotKeys

        var seen: Set<String> = []

        for binding in settings.shortcutBindings {
            guard let key = Key(carbonKeyCode: UInt32(binding.keyCode)) else {
                logger.warning("Invalid key code: \(binding.keyCode) in binding '\(binding.label)'")
                continue
            }

            let comboKey = "\(binding.keyCode)-\(binding.modifiers)"
            if seen.contains(comboKey) {
                logger.warning("Duplicate shortcut combo in binding '\(binding.label)' — skipping")
                continue
            }
            seen.insert(comboKey)

            let nsModifiers = NSEvent.ModifierFlags(rawValue: UInt(binding.modifiers))
            let hotKey = HotKey(key: key, modifiers: nsModifiers)
            let promptID = binding.promptID
            hotKey.keyDownHandler = { [weak self] in
                self?.logger.info("Shortcut triggered: '\(binding.label)'")
                self?.onActivate(promptID)
            }
            hotKeys[binding.id] = hotKey
        }

        logger.info("Registered \(self.hotKeys.count) global shortcut(s)")
    }
}
