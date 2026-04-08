import AppKit
import Foundation
import os

@Observable
final class Settings {
    private let logger = Logger(subsystem: "com.macvoice.app", category: "core")
    private let defaults = UserDefaults.standard

    // MARK: - Keys

    private enum Key {
        static let sendPhrase = "sendPhrase"
        static let silenceThreshold = "silenceThreshold"
        static let whisperModel = "whisperModel"
        static let autoResumeMedia = "autoResumeMedia"
        static let shortcutKeyCode = "shortcutKeyCode"
        static let shortcutModifiers = "shortcutModifiers"
        static let wakePhraseEnabled = "wakePhraseEnabled"
        static let wakePhrase = "wakePhrase"
        static let aiCleanupEnabled = "aiCleanupEnabled"
        static let aiCleanupProvider = "aiCleanupProvider"
        static let aiCleanupModelID = "aiCleanupModelID"
        static let aiCleanupCustomEndpoint = "aiCleanupCustomEndpoint"
        static let aiCleanupCustomModel = "aiCleanupCustomModel"
        static let autoDeleteDays = "autoDeleteDays"
        static let sendPhraseEnabled = "sendPhraseEnabled"
        static let autoInsertEnabled = "autoInsertEnabled"
        static let shortcutBindings = "shortcutBindings"
        static let insertPhrase = "insertPhrase"
        static let insertPhraseEnabled = "insertPhraseEnabled"
        static let keepOverlayOpenOnCopy = "keepOverlayOpenOnCopy"
        static let copyAutoDismissDelay = "copyAutoDismissDelay"
        static let soundPreset = "soundPreset"
        static let beepVolume = "beepVolume"
        static let beepEnabled = "beepEnabled"
        static let selectedMicrophoneID = "selectedMicrophoneID"
        static let keepMicrophoneConnected = "keepMicrophoneConnected"
    }

    // MARK: - Whisper Model

    /// Fallback model names when dynamic fetch fails.
    static let fallbackModels = ["tiny", "base", "small", "medium", "large-v2", "large-v3"]

    static func whisperModelDisplayName(_ model: String) -> String {
        switch model {
        case "tiny": return "Tiny (fastest, ~1GB)"
        case "base": return "Base (~1GB)"
        case "small": return "Small (~2GB)"
        case "medium": return "Medium (~5GB)"
        case "large": return "Large (~10GB)"
        case "large-v2": return "Large v2 (~10GB)"
        case "large-v3": return "Large v3 (~10GB)"
        case "large-v3-turbo", "large-v3_turbo": return "Large v3 Turbo (best)"
        default: return model.capitalized
        }
    }

    static var defaultSoundPresetRawValue: String {
        SoundPreset.allCases.first?.rawValue ?? SoundPreset.electronic.rawValue
    }

    static func sanitizeSoundPreset(_ rawValue: String?) -> String {
        guard let rawValue, SoundPreset(rawValue: rawValue) != nil else {
            return defaultSoundPresetRawValue
        }
        return rawValue
    }

    // MARK: - Properties

    var sendPhrase: String {
        didSet { defaults.set(sendPhrase, forKey: Key.sendPhrase) }
    }

    var silenceThreshold: Double {
        didSet { defaults.set(silenceThreshold, forKey: Key.silenceThreshold) }
    }

    var whisperModel: String {
        didSet { defaults.set(whisperModel, forKey: Key.whisperModel) }
    }

    var autoResumeMedia: Bool {
        didSet { defaults.set(autoResumeMedia, forKey: Key.autoResumeMedia) }
    }

    var shortcutKeyCode: UInt16 {
        didSet {
            defaults.set(Int(shortcutKeyCode), forKey: Key.shortcutKeyCode)
            shortcutDisplayString = Self.buildDisplayString(keyCode: shortcutKeyCode, modifiers: shortcutModifiers)
            onShortcutChanged?()
        }
    }

    var shortcutModifiers: UInt {
        didSet {
            defaults.set(Int(shortcutModifiers), forKey: Key.shortcutModifiers)
            shortcutDisplayString = Self.buildDisplayString(keyCode: shortcutKeyCode, modifiers: shortcutModifiers)
            onShortcutChanged?()
        }
    }

    private(set) var shortcutDisplayString: String = ""

    /// Callback fired when shortcut key combo changes. Set by ShortcutManager.
    /// - Note: Deprecated — use `onShortcutBindingsChanged` instead.
    var onShortcutChanged: (() -> Void)?

    // MARK: - Multi-Shortcut Bindings

    var shortcutBindings: [ShortcutBinding] {
        didSet {
            if let data = try? JSONEncoder().encode(shortcutBindings) {
                defaults.set(data, forKey: Key.shortcutBindings)
            }
            onShortcutBindingsChanged?()
        }
    }

    /// Callback fired when shortcut bindings change. Set by ShortcutManager.
    var onShortcutBindingsChanged: (() -> Void)?

    // MARK: - Insert Phrase

    var insertPhrase: String {
        didSet { defaults.set(insertPhrase, forKey: Key.insertPhrase) }
    }

    var insertPhraseEnabled: Bool {
        didSet { defaults.set(insertPhraseEnabled, forKey: Key.insertPhraseEnabled) }
    }

    // MARK: - Copy Overlay Behavior

    var keepOverlayOpenOnCopy: Bool {
        didSet { defaults.set(keepOverlayOpenOnCopy, forKey: Key.keepOverlayOpenOnCopy) }
    }

    /// Auto-dismiss delay in seconds after Copy. 0 = never auto-dismiss.
    var copyAutoDismissDelay: Int {
        didSet { defaults.set(copyAutoDismissDelay, forKey: Key.copyAutoDismissDelay) }
    }

    var wakePhraseEnabled: Bool {
        didSet {
            defaults.set(wakePhraseEnabled, forKey: Key.wakePhraseEnabled)
            onWakePhraseToggled?(wakePhraseEnabled)
        }
    }

    var wakePhrase: String {
        didSet { defaults.set(wakePhrase, forKey: Key.wakePhrase) }
    }

    var keepMicrophoneConnected: Bool {
        didSet {
            defaults.set(keepMicrophoneConnected, forKey: Key.keepMicrophoneConnected)

            if !keepMicrophoneConnected {
                if wakePhraseEnabled {
                    wakePhraseEnabled = false
                }
                micDisconnected = true
            } else if micDisconnected {
                micDisconnected = false
            }
        }
    }

    /// Callback fired when `wakePhraseEnabled` changes. Set by AppDelegate.
    var onWakePhraseToggled: ((Bool) -> Void)?

    // MARK: - AI Cleanup

    var aiCleanupEnabled: Bool {
        didSet { defaults.set(aiCleanupEnabled, forKey: Key.aiCleanupEnabled) }
    }

    var aiCleanupProvider: AIProvider {
        didSet {
            defaults.set(aiCleanupProvider.rawValue, forKey: Key.aiCleanupProvider)
            // Reset model to first available when switching providers
            if let first = aiCleanupProvider.models.first {
                aiCleanupModelID = first.id
            }
        }
    }

    var aiCleanupModelID: String {
        didSet { defaults.set(aiCleanupModelID, forKey: Key.aiCleanupModelID) }
    }

    var aiCleanupCustomEndpoint: String {
        didSet { defaults.set(aiCleanupCustomEndpoint, forKey: Key.aiCleanupCustomEndpoint) }
    }

    var aiCleanupCustomModel: String {
        didSet { defaults.set(aiCleanupCustomModel, forKey: Key.aiCleanupCustomModel) }
    }

    var aiCleanupAPIKey: String {
        get { KeychainHelper.read(key: "aiCleanupAPIKey") ?? "" }
        set {
            if newValue.isEmpty {
                _ = KeychainHelper.delete(key: "aiCleanupAPIKey")
            } else {
                _ = KeychainHelper.save(key: "aiCleanupAPIKey", value: newValue)
            }
        }
    }

    /// Resolved endpoint URL based on provider selection.
    var resolvedEndpoint: String {
        aiCleanupProvider == .custom ? aiCleanupCustomEndpoint : aiCleanupProvider.fullEndpointURL
    }

    /// Resolved model ID based on provider selection.
    var resolvedModel: String {
        aiCleanupProvider == .custom ? aiCleanupCustomModel : aiCleanupModelID
    }

    var autoDeleteDays: Int {
        didSet { defaults.set(autoDeleteDays, forKey: Key.autoDeleteDays) }
    }

    var sendPhraseEnabled: Bool {
        didSet { defaults.set(sendPhraseEnabled, forKey: Key.sendPhraseEnabled) }
    }

    var autoInsertEnabled: Bool {
        didSet { defaults.set(autoInsertEnabled, forKey: Key.autoInsertEnabled) }
    }

    var soundPreset: String {
        didSet {
            let sanitized = Self.sanitizeSoundPreset(soundPreset)
            if sanitized != soundPreset {
                soundPreset = sanitized
                return
            }
            defaults.set(sanitized, forKey: Key.soundPreset)
        }
    }

    var beepVolume: Double {
        didSet { defaults.set(beepVolume, forKey: Key.beepVolume) }
    }

    var beepEnabled: Bool {
        didSet { defaults.set(beepEnabled, forKey: Key.beepEnabled) }
    }

    var selectedMicrophoneID: String {
        didSet { 
            defaults.set(selectedMicrophoneID, forKey: Key.selectedMicrophoneID) 
            onMicrophoneChanged?(selectedMicrophoneID)
        }
    }
    
    /// Callback fired when `selectedMicrophoneID` changes. Set by AppDelegate.
    var onMicrophoneChanged: ((String) -> Void)?

    // MARK: - Mic Disconnect (runtime only, not persisted)

    /// When true, passive mic listeners are stopped while the app is idle.
    var micDisconnected: Bool = false {
        didSet { onMicDisconnectedChanged?(micDisconnected) }
    }

    /// Callback fired when `micDisconnected` changes. Set by AppDelegate.
    var onMicDisconnectedChanged: ((Bool) -> Void)?

    // MARK: - Init

    init() {
        let defs = UserDefaults.standard

        // Register defaults
        defs.register(defaults: [
            Key.sendPhrase: "OK, send",
            Key.silenceThreshold: 2.0,
            Key.whisperModel: "tiny",
            Key.autoResumeMedia: true,
            Key.shortcutKeyCode: 9,   // V key
            Key.shortcutModifiers: Int(NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue),
            Key.wakePhraseEnabled: true,
            Key.wakePhrase: "Ok Voice",
            Key.aiCleanupEnabled: false,
            Key.aiCleanupProvider: AIProvider.openai.rawValue,
            Key.aiCleanupModelID: "gpt-4o-mini",
            Key.aiCleanupCustomEndpoint: "",
            Key.aiCleanupCustomModel: "",
            Key.autoDeleteDays: 0,
            Key.sendPhraseEnabled: true,
            Key.autoInsertEnabled: false,
            Key.insertPhrase: "Insert",
            Key.insertPhraseEnabled: true,
            Key.keepOverlayOpenOnCopy: false,
            Key.copyAutoDismissDelay: 0,
            Key.soundPreset: Self.defaultSoundPresetRawValue,
            Key.beepVolume: 0.7,
            Key.beepEnabled: true,
            Key.selectedMicrophoneID: "",
            Key.keepMicrophoneConnected: false,
        ])

        self.sendPhrase = defs.string(forKey: Key.sendPhrase) ?? "OK, send"
        self.silenceThreshold = defs.double(forKey: Key.silenceThreshold)
        self.whisperModel = defs.string(forKey: Key.whisperModel) ?? "tiny"
        self.autoResumeMedia = defs.bool(forKey: Key.autoResumeMedia)
        self.shortcutKeyCode = UInt16(defs.integer(forKey: Key.shortcutKeyCode))
        self.shortcutModifiers = UInt(defs.integer(forKey: Key.shortcutModifiers))
        self.wakePhraseEnabled = defs.bool(forKey: Key.wakePhraseEnabled)
        self.wakePhrase = defs.string(forKey: Key.wakePhrase) ?? "Ok Voice"
        self.keepMicrophoneConnected = defs.object(forKey: Key.keepMicrophoneConnected) != nil
            ? defs.bool(forKey: Key.keepMicrophoneConnected)
            : false
        self.aiCleanupEnabled = defs.bool(forKey: Key.aiCleanupEnabled)
        self.aiCleanupCustomEndpoint = defs.string(forKey: Key.aiCleanupCustomEndpoint) ?? ""
        self.aiCleanupCustomModel = defs.string(forKey: Key.aiCleanupCustomModel) ?? ""
        self.autoDeleteDays = defs.integer(forKey: Key.autoDeleteDays)
        self.sendPhraseEnabled = defs.bool(forKey: Key.sendPhraseEnabled)
        self.autoInsertEnabled = defs.bool(forKey: Key.autoInsertEnabled)
        self.soundPreset = Self.sanitizeSoundPreset(defs.string(forKey: Key.soundPreset))
        self.beepVolume = defs.object(forKey: Key.beepVolume) != nil ? defs.double(forKey: Key.beepVolume) : 0.7
        self.beepEnabled = defs.object(forKey: Key.beepEnabled) != nil ? defs.bool(forKey: Key.beepEnabled) : true
        let storedMicrophoneID = defs.string(forKey: Key.selectedMicrophoneID) ?? ""
        if storedMicrophoneID.isEmpty {
            self.selectedMicrophoneID = ""
        } else {
            let availableMicrophoneIDs = Set(AudioRecorder.availableMicrophones().map(\.id))
            self.selectedMicrophoneID = availableMicrophoneIDs.contains(storedMicrophoneID) ? storedMicrophoneID : ""
        }

        // Load new settings
        self.insertPhrase = defs.string(forKey: Key.insertPhrase) ?? "Insert"
        self.insertPhraseEnabled = defs.bool(forKey: Key.insertPhraseEnabled)
        self.keepOverlayOpenOnCopy = defs.bool(forKey: Key.keepOverlayOpenOnCopy)
        self.copyAutoDismissDelay = defs.integer(forKey: Key.copyAutoDismissDelay)

        // Load or migrate shortcut bindings from legacy single-shortcut keys
        if let data = defs.data(forKey: Key.shortcutBindings),
           let bindings = try? JSONDecoder().decode([ShortcutBinding].self, from: data),
           !bindings.isEmpty {
            self.shortcutBindings = bindings
        } else {
            let legacyKeyCode = UInt16(defs.integer(forKey: Key.shortcutKeyCode))
            let legacyModifiers = UInt(defs.integer(forKey: Key.shortcutModifiers))
            let migrated = ShortcutBinding(keyCode: legacyKeyCode, modifiers: legacyModifiers, label: "Default")
            self.shortcutBindings = [migrated]
            if let data = try? JSONEncoder().encode([migrated]) {
                defs.set(data, forKey: Key.shortcutBindings)
            }
            logger.info("Migrated legacy shortcut to shortcutBindings")
        }

        // Migrate from legacy aiCleanupEndpoint/aiCleanupModel if present
        if let legacyEndpoint = defs.string(forKey: "aiCleanupEndpoint"),
           defs.string(forKey: Key.aiCleanupProvider) == nil {
            if let matched = AIProvider.fromEndpointURL(legacyEndpoint) {
                self.aiCleanupProvider = matched
                self.aiCleanupModelID = defs.string(forKey: "aiCleanupModel") ?? matched.models.first?.id ?? ""
            } else {
                self.aiCleanupProvider = .custom
                self.aiCleanupCustomEndpoint = legacyEndpoint
                self.aiCleanupCustomModel = defs.string(forKey: "aiCleanupModel") ?? ""
                self.aiCleanupModelID = ""
            }
            // Persist migrated values
            defs.set(aiCleanupProvider.rawValue, forKey: Key.aiCleanupProvider)
            defs.set(aiCleanupModelID, forKey: Key.aiCleanupModelID)
            defs.set(aiCleanupCustomEndpoint, forKey: Key.aiCleanupCustomEndpoint)
            defs.set(aiCleanupCustomModel, forKey: Key.aiCleanupCustomModel)
            // Clean up legacy keys
            defs.removeObject(forKey: "aiCleanupEndpoint")
            defs.removeObject(forKey: "aiCleanupModel")
            logger.info("Migrated legacy AI cleanup settings to provider: \(self.aiCleanupProvider.displayName)")
        } else {
            self.aiCleanupProvider = AIProvider(rawValue: defs.string(forKey: Key.aiCleanupProvider) ?? "") ?? .openai
            self.aiCleanupModelID = defs.string(forKey: Key.aiCleanupModelID) ?? "gpt-4o-mini"
        }
        self.shortcutDisplayString = Self.buildDisplayString(
            keyCode: UInt16(defs.integer(forKey: Key.shortcutKeyCode)),
            modifiers: UInt(defs.integer(forKey: Key.shortcutModifiers))
        )

        if !keepMicrophoneConnected {
            self.wakePhraseEnabled = false
            defs.set(false, forKey: Key.wakePhraseEnabled)
        }

        defs.set(self.soundPreset, forKey: Key.soundPreset)

        logger.debug("Settings loaded")
    }

    // MARK: - Shortcut Display

    static func buildDisplayString(keyCode: UInt16, modifiers: UInt) -> String {
        let flags = NSEvent.ModifierFlags(rawValue: modifiers)
        var parts: [String] = []
        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.shift) { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }

        let keyName = keyCodeToString(keyCode)
        parts.append(keyName)
        return parts.joined()
    }

    private static func keyCodeToString(_ keyCode: UInt16) -> String {
        let map: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "↩",
            37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
            44: "/", 45: "N", 46: "M", 47: ".", 48: "⇥", 49: "Space",
            50: "`", 51: "⌫", 53: "⎋",
            96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8",
            101: "F9", 109: "F10", 111: "F12", 103: "F11",
            118: "F4", 120: "F2", 122: "F1",
        ]
        return map[keyCode] ?? "Key\(keyCode)"
    }
}
