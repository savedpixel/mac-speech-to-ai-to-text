import AppKit
import ApplicationServices
import os

final class TextInserter {
    private let logger = Logger(subsystem: "com.macvoice.app", category: "input")

    private struct InsertionTarget {
        let focusedElement: AXUIElement?
        let appPID: pid_t?
        let appBundleIdentifier: String?
        let appBundleURL: URL?
        let appName: String
        let elementFrame: CGRect?
    }

    private struct ReturnTarget {
        let appPID: pid_t
        let appBundleIdentifier: String?
        let appBundleURL: URL?
        let appName: String
    }

    private var savedTarget: InsertionTarget?

    /// Capture the currently focused text field for later insertion.
    func captureActiveElement() {
        let frontmostApp = NSWorkspace.shared.frontmostApplication
        let systemWide = AXUIElementCreateSystemWide()
        var focusedElement: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        let element = focusedElement.map { $0 as! AXUIElement }
        let appName = frontmostApp?.localizedName ?? "unknown"
        savedTarget = InsertionTarget(
            focusedElement: result == .success ? element : nil,
            appPID: frontmostApp?.processIdentifier,
            appBundleIdentifier: frontmostApp?.bundleIdentifier,
            appBundleURL: frontmostApp?.bundleURL,
            appName: appName,
            elementFrame: element.flatMap(Self.elementFrame)
        )

        if result == .success, let element = focusedElement {
            logger.info("Captured active text element in \(appName, privacy: .public)")
            DiagnosticLogger.shared.write("input", "Captured insertion target app=\(appName) pid=\(frontmostApp?.processIdentifier ?? -1) bundle=\(frontmostApp?.bundleIdentifier ?? "nil") element=\(element) frame=\(savedTarget?.elementFrame?.debugDescription ?? "nil")")
        } else {
            logger.warning("Could not capture active text element in \(appName, privacy: .public) (error: \(result.rawValue, privacy: .public)); will restore app only")
            DiagnosticLogger.shared.write("input", "Captured insertion target app-only app=\(appName) pid=\(frontmostApp?.processIdentifier ?? -1) bundle=\(frontmostApp?.bundleIdentifier ?? "nil") axError=\(result.rawValue)")
        }
    }

    /// Insert text into the previously captured element and press Enter.
    @MainActor
    func insertTextAndSubmit(_ text: String) async -> Bool {
        guard !text.isEmpty else {
            logger.warning("Empty text — skipping insertion")
            DiagnosticLogger.shared.write("input", "Insert skipped empty text")
            return false
        }

        let target = savedTarget
        let returnTarget = captureReturnTarget(excluding: target)
        DiagnosticLogger.shared.write("input", "Insert requested chars=\(text.count) targetApp=\(target?.appName ?? "nil") pid=\(target?.appPID ?? -1)")

        await restoreTarget(target)

        let frontmostAfterRestore = NSWorkspace.shared.frontmostApplication
        DiagnosticLogger.shared.write("input", "Before paste frontmost=\(frontmostAfterRestore?.localizedName ?? "nil") pid=\(frontmostAfterRestore?.processIdentifier ?? -1) expectedPid=\(target?.appPID ?? -1)")

        // Always use clipboard paste — it works universally including VS Code,
        // Electron apps, and web browsers where AX value setting often silently fails.
        pasteText(text)

        // Small delay before Enter to let the paste land
        try? await Task.sleep(nanoseconds: 180_000_000)
        pressEnter()

        DiagnosticLogger.shared.write("input", "Insert submitted frontmost=\(NSWorkspace.shared.frontmostApplication?.localizedName ?? "nil") pid=\(NSWorkspace.shared.frontmostApplication?.processIdentifier ?? -1)")
        try? await Task.sleep(nanoseconds: 160_000_000)
        await restoreReturnTarget(returnTarget)
        return true
    }

    @MainActor
    func debugRestoreSavedTargetOnly() async {
        await restoreTarget(savedTarget)
    }

    func hasSavedTargetForDebugging() -> Bool {
        savedTarget != nil
    }

    private static func elementFrame(_ element: AXUIElement) -> CGRect? {
        var positionObject: AnyObject?
        var sizeObject: AnyObject?
        let positionResult = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionObject)
        let sizeResult = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeObject)
        guard positionResult == .success,
              sizeResult == .success,
              let positionObject,
              let sizeObject,
              CFGetTypeID(positionObject) == AXValueGetTypeID(),
              CFGetTypeID(sizeObject) == AXValueGetTypeID() else {
            return nil
        }
        let positionValue = positionObject as! AXValue
        let sizeValue = sizeObject as! AXValue

        var point = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue, .cgPoint, &point),
              AXValueGetValue(sizeValue, .cgSize, &size) else {
            return nil
        }

        return CGRect(origin: point, size: size)
    }

    private func captureReturnTarget(excluding target: InsertionTarget?) -> ReturnTarget? {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            DiagnosticLogger.shared.write("input", "Return target capture skipped no frontmost app")
            return nil
        }

        if frontmostApp.bundleIdentifier == Bundle.main.bundleIdentifier {
            DiagnosticLogger.shared.write("input", "Return target capture skipped MacVoice frontmost")
            return nil
        }

        if let targetPID = target?.appPID,
           frontmostApp.processIdentifier == targetPID {
            DiagnosticLogger.shared.write("input", "Return target capture skipped because frontmost is insertion target app=\(frontmostApp.localizedName ?? "nil") pid=\(frontmostApp.processIdentifier)")
            return nil
        }

        if let targetBundle = target?.appBundleIdentifier,
           frontmostApp.bundleIdentifier == targetBundle {
            DiagnosticLogger.shared.write("input", "Return target capture skipped because frontmost bundle matches target app=\(frontmostApp.localizedName ?? "nil") bundle=\(targetBundle)")
            return nil
        }

        let returnTarget = ReturnTarget(
            appPID: frontmostApp.processIdentifier,
            appBundleIdentifier: frontmostApp.bundleIdentifier,
            appBundleURL: frontmostApp.bundleURL,
            appName: frontmostApp.localizedName ?? "unknown"
        )
        DiagnosticLogger.shared.write("input", "Captured return target app=\(returnTarget.appName) pid=\(returnTarget.appPID) bundle=\(returnTarget.appBundleIdentifier ?? "nil")")
        return returnTarget
    }

    @MainActor
    private func restoreReturnTarget(_ returnTarget: ReturnTarget?) async {
        guard let returnTarget else {
            DiagnosticLogger.shared.write("input", "Return target restore skipped none")
            return
        }

        let app =
            NSRunningApplication(processIdentifier: returnTarget.appPID) ??
            returnTarget.appBundleIdentifier.flatMap {
                NSRunningApplication.runningApplications(withBundleIdentifier: $0)
                    .first { !$0.isTerminated }
            }

        if let app, !app.isTerminated {
            app.unhide()
            let activatedPlain = app.activate(options: [])
            let activatedIgnoring = app.activate(options: [.activateIgnoringOtherApps])
            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            let frontmostResult = AXUIElementSetAttributeValue(
                appElement,
                kAXFrontmostAttribute as CFString,
                kCFBooleanTrue
            )
            let raiseResult = AXUIElementPerformAction(appElement, kAXRaiseAction as CFString)
            DiagnosticLogger.shared.write("input", "Restored return app app=\(returnTarget.appName) pid=\(app.processIdentifier) activatedPlain=\(activatedPlain) activatedIgnoring=\(activatedIgnoring) axFrontmost=\(frontmostResult.rawValue) axRaise=\(raiseResult.rawValue)")
            try? await Task.sleep(nanoseconds: 180_000_000)
        } else if let appURL = returnTarget.appBundleURL {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            let reopened = try? await NSWorkspace.shared.openApplication(at: appURL, configuration: configuration)
            DiagnosticLogger.shared.write("input", "Reopened return app app=\(returnTarget.appName) url=\(appURL.path) reopenedPid=\(reopened?.processIdentifier ?? -1)")
            try? await Task.sleep(nanoseconds: 300_000_000)
        } else {
            DiagnosticLogger.shared.write("input", "Return target unavailable app=\(returnTarget.appName) pid=\(returnTarget.appPID) bundle=\(returnTarget.appBundleIdentifier ?? "nil")")
        }

        if !isReturnTargetFrontmost(returnTarget) {
            activateReturnTargetByAppleScript(returnTarget)
            try? await Task.sleep(nanoseconds: 180_000_000)
        }

        DiagnosticLogger.shared.write("input", "Return restore finished returnApp=\(returnTarget.appName) frontmost=\(NSWorkspace.shared.frontmostApplication?.localizedName ?? "nil") pid=\(NSWorkspace.shared.frontmostApplication?.processIdentifier ?? -1)")
    }

    @MainActor
    private func restoreTarget(_ target: InsertionTarget?) async {
        guard let target else {
            logger.warning("No saved insertion target — pasting into current focus")
            DiagnosticLogger.shared.write("input", "No saved insertion target; paste will use current focus")
            return
        }

        if let app = runningApplication(for: target) {
            restoreRunningApplication(app, target: target)
            try? await Task.sleep(nanoseconds: 220_000_000)
        } else {
            logger.warning("Saved insertion app no longer running: \(target.appName, privacy: .public)")
            DiagnosticLogger.shared.write("input", "Saved insertion app unavailable app=\(target.appName) pid=\(target.appPID ?? -1) bundle=\(target.appBundleIdentifier ?? "nil")")

            if let appURL = target.appBundleURL {
                let configuration = NSWorkspace.OpenConfiguration()
                configuration.activates = true
                let reopened = try? await NSWorkspace.shared.openApplication(at: appURL, configuration: configuration)
                DiagnosticLogger.shared.write("input", "Workspace reopen target app=\(target.appName) url=\(appURL.path) reopenedPid=\(reopened?.processIdentifier ?? -1)")
                try? await Task.sleep(nanoseconds: 450_000_000)
            }
        }

        if !isExpectedAppFrontmost(target) {
            activateByAppleScript(target)
            try? await Task.sleep(nanoseconds: 300_000_000)
        }

        if let element = target.focusedElement {
            focusElement(element, target: target)
            try? await Task.sleep(nanoseconds: 180_000_000)
        }

        if !isExpectedAppFrontmost(target), let frame = target.elementFrame {
            clickSavedElementCenter(frame, target: target)
            try? await Task.sleep(nanoseconds: 220_000_000)
        }

        if let element = target.focusedElement {
            focusElement(element, target: target)
            try? await Task.sleep(nanoseconds: 120_000_000)
        }

        DiagnosticLogger.shared.write("input", "Restore finished targetApp=\(target.appName) frontmost=\(NSWorkspace.shared.frontmostApplication?.localizedName ?? "nil") pid=\(NSWorkspace.shared.frontmostApplication?.processIdentifier ?? -1)")
    }

    @MainActor
    private func restoreRunningApplication(_ app: NSRunningApplication, target: InsertionTarget) {
        app.unhide()
        let activatedPlain = app.activate(options: [])
        let activatedIgnoring = app.activate(options: [.activateIgnoringOtherApps])

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        let frontmostResult = AXUIElementSetAttributeValue(
            appElement,
            kAXFrontmostAttribute as CFString,
            kCFBooleanTrue
        )
        let raiseResult = AXUIElementPerformAction(appElement, kAXRaiseAction as CFString)

        logger.info("Restoring insertion app \(target.appName, privacy: .public), activatedPlain=\(activatedPlain, privacy: .public), activatedIgnoring=\(activatedIgnoring, privacy: .public)")
        DiagnosticLogger.shared.write("input", "Restoring insertion app app=\(target.appName) pid=\(app.processIdentifier) activatedPlain=\(activatedPlain) activatedIgnoring=\(activatedIgnoring) axFrontmost=\(frontmostResult.rawValue) axRaise=\(raiseResult.rawValue)")
    }

    private func focusElement(_ element: AXUIElement, target: InsertionTarget) {
        let systemWide = AXUIElementCreateSystemWide()
        let appElement = target.appPID.map { AXUIElementCreateApplication($0) }

        let appFrontmostResult = appElement.map {
            AXUIElementSetAttributeValue($0, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        }

        let systemResult = AXUIElementSetAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            element
        )
        let elementResult = AXUIElementSetAttributeValue(
            element,
            kAXFocusedAttribute as CFString,
            kCFBooleanTrue
        )
        let raiseResult = AXUIElementPerformAction(element, kAXRaiseAction as CFString)
        logger.info("Restored insertion AX focus system=\(systemResult.rawValue, privacy: .public) element=\(elementResult.rawValue, privacy: .public)")
        DiagnosticLogger.shared.write("input", "Restored AX focus app=\(target.appName) appFrontmost=\(appFrontmostResult?.rawValue ?? Int32.min) systemResult=\(systemResult.rawValue) elementResult=\(elementResult.rawValue) elementRaise=\(raiseResult.rawValue)")
    }

    private func clickSavedElementCenter(_ frame: CGRect, target: InsertionTarget) {
        guard frame.width > 0, frame.height > 0 else { return }
        let point = CGPoint(x: frame.midX, y: frame.midY)
        let source = CGEventSource(stateID: .hidSystemState)
        let move = CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)
        let down = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
        let up = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
        move?.post(tap: .cgAnnotatedSessionEventTap)
        down?.post(tap: .cgAnnotatedSessionEventTap)
        up?.post(tap: .cgAnnotatedSessionEventTap)
        DiagnosticLogger.shared.write("input", "Clicked saved insertion frame center app=\(target.appName) point=\(point.debugDescription) frame=\(frame.debugDescription)")
    }

    private func activateByAppleScript(_ target: InsertionTarget) {
        let scriptSource: String
        if let bundleIdentifier = target.appBundleIdentifier {
            scriptSource = "tell application id \"\(bundleIdentifier)\" to activate"
        } else {
            scriptSource = "tell application \"\(target.appName.replacingOccurrences(of: "\"", with: "\\\""))\" to activate"
        }

        var errorInfo: NSDictionary?
        let result = NSAppleScript(source: scriptSource)?.executeAndReturnError(&errorInfo)
        DiagnosticLogger.shared.write("input", "AppleScript activate app=\(target.appName) result=\(result?.stringValue ?? "nil") error=\(errorInfo?.description ?? "nil")")
    }

    private func activateReturnTargetByAppleScript(_ returnTarget: ReturnTarget) {
        let scriptSource: String
        if let bundleIdentifier = returnTarget.appBundleIdentifier {
            scriptSource = "tell application id \"\(bundleIdentifier)\" to activate"
        } else {
            scriptSource = "tell application \"\(returnTarget.appName.replacingOccurrences(of: "\"", with: "\\\""))\" to activate"
        }

        var errorInfo: NSDictionary?
        let result = NSAppleScript(source: scriptSource)?.executeAndReturnError(&errorInfo)
        DiagnosticLogger.shared.write("input", "AppleScript activate returnApp=\(returnTarget.appName) result=\(result?.stringValue ?? "nil") error=\(errorInfo?.description ?? "nil")")
    }

    private func isExpectedAppFrontmost(_ target: InsertionTarget) -> Bool {
        guard let frontmost = NSWorkspace.shared.frontmostApplication else { return false }
        if let targetPID = target.appPID, frontmost.processIdentifier == targetPID {
            return true
        }
        if let bundleIdentifier = target.appBundleIdentifier,
           frontmost.bundleIdentifier == bundleIdentifier {
            return true
        }
        return false
    }

    private func isReturnTargetFrontmost(_ returnTarget: ReturnTarget) -> Bool {
        guard let frontmost = NSWorkspace.shared.frontmostApplication else { return false }
        if frontmost.processIdentifier == returnTarget.appPID {
            return true
        }
        if let bundleIdentifier = returnTarget.appBundleIdentifier,
           frontmost.bundleIdentifier == bundleIdentifier {
            return true
        }
        return false
    }

    private func runningApplication(for target: InsertionTarget) -> NSRunningApplication? {
        if let pid = target.appPID,
           let app = NSRunningApplication(processIdentifier: pid),
           !app.isTerminated {
            return app
        }

        if let bundleIdentifier = target.appBundleIdentifier {
            return NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
                .first { !$0.isTerminated }
        }

        return nil
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
        savedTarget = nil
    }
}
