import Foundation

struct ShortcutBinding: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var keyCode: UInt16
    var modifiers: UInt
    /// Nil = use the globally selected prompt; non-nil = override with this specific prompt.
    var promptID: UUID?
    var label: String

    var displayString: String {
        Settings.buildDisplayString(keyCode: keyCode, modifiers: modifiers)
    }
}
