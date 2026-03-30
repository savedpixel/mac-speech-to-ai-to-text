import AppKit
import AVFoundation
import Speech
import os

@Observable
final class PermissionManager {
    private let logger = Logger(subsystem: "com.macvoice.app", category: "core")

    var accessibilityGranted = false
    var microphoneGranted = false
    var inputMonitoringGranted = false
    var speechRecognitionGranted = false

    var allGranted: Bool {
        accessibilityGranted && microphoneGranted && inputMonitoringGranted
    }

    func checkAllPermissions() async {
        checkAccessibility()
        await checkMicrophone()
        await checkSpeechRecognition()
        checkInputMonitoring()

        logger.info(
            "Permissions — accessibility: \(self.accessibilityGranted), mic: \(self.microphoneGranted), speech: \(self.speechRecognitionGranted), input: \(self.inputMonitoringGranted)"
        )
    }

    func checkAccessibility() {
        accessibilityGranted = AXIsProcessTrusted()
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        accessibilityGranted = AXIsProcessTrustedWithOptions(options)
    }

    func checkMicrophone() async {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            microphoneGranted = true
        case .notDetermined:
            microphoneGranted = await AVCaptureDevice.requestAccess(for: .audio)
        default:
            microphoneGranted = false
        }
    }

    func checkInputMonitoring() {
        // No programmatic API to check Input Monitoring.
        // We assume granted if accessibility is granted, as they often go together.
        // The actual check happens when CGEvent tap is created — it fails if not granted.
        inputMonitoringGranted = accessibilityGranted
    }

    func checkSpeechRecognition() async {
        let status = SFSpeechRecognizer.authorizationStatus()
        switch status {
        case .authorized:
            speechRecognitionGranted = true
        case .notDetermined:
            speechRecognitionGranted = await withCheckedContinuation { cont in
                SFSpeechRecognizer.requestAuthorization { status in
                    cont.resume(returning: status == .authorized)
                }
            }
        default:
            speechRecognitionGranted = false
        }
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func openInputMonitoringSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
}
