import AppKit
import ApplicationServices
import os

final class TextInserter {
    private let logger = Logger(subsystem: "com.macvoice.app", category: "input")

    private var savedElement: AXUIElement?

    /// Capture the currently focused text field for later insertion.
    func captureActiveElement() {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedElement: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        if result == .success, let element = focusedElement {
            savedElement = (element as! AXUIElement)
            logger.info("Captured active text element")
        } else {
            savedElement = nil
            logger.warning("Could not capture active text element (error: \(result.rawValue))")
        }
    }

    /// Insert text into the previously captured element and press Enter.
    func insertTextAndSubmit(_ text: String) {
        guard !text.isEmpty else {
            logger.warning("Empty text — skipping insertion")
            return
        }

        // Always use clipboard paste — it works universally including VS Code,
        // Electron apps, and web browsers where AX value setting often silently fails.
        pasteText(text)

        // Small delay before Enter to let the paste land
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [self] in
            pressEnter()
        }
    }

    private func pasteText(_ text: String) {
        // Save current clipboard
        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)

        // Set text to clipboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Simulate Cmd+V
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) // 'V' key
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cgAnnotatedSessionEventTap)
        keyUp?.post(tap: .cgAnnotatedSessionEventTap)

        logger.info("Text pasted via clipboard fallback")

        // Restore previous clipboard after a brief delay
        if let previousContents {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                pasteboard.clearContents()
                pasteboard.setString(previousContents, forType: .string)
            }
        }
    }

    private func pressEnter() {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x24, keyDown: true) // Return key
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x24, keyDown: false)
        keyDown?.post(tap: .cgAnnotatedSessionEventTap)
        keyUp?.post(tap: .cgAnnotatedSessionEventTap)

        logger.info("Enter key pressed")
    }

    func reset() {
        savedElement = nil
    }
}
