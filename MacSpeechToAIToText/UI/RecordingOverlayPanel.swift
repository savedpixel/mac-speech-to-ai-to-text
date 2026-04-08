import AppKit
import SwiftUI
import os

final class RecordingOverlayPanel {
    private let logger = Logger(subsystem: "com.macvoice.app", category: "ui")
    private var panel: NSPanel?
    private let pipelineCoordinator: PipelineCoordinator
    private let audioRecorder: AudioRecorder

    init(pipelineCoordinator: PipelineCoordinator, audioRecorder: AudioRecorder) {
        self.pipelineCoordinator = pipelineCoordinator
        self.audioRecorder = audioRecorder
    }

    func show() {
        if panel != nil { dismiss() }

        let overlayView = RecordingOverlayView(
            pipelineCoordinator: pipelineCoordinator,
            audioRecorder: audioRecorder
        )
        let hostingView = NSHostingView(rootView: overlayView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 520, height: 380)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 380),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.contentView = hostingView
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false

        // Center on screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - 260
            let y = screenFrame.midY - 190
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            panel.animator().alphaValue = 1
        }

        self.panel = panel
        logger.debug("Recording overlay shown")
    }

    func dismiss() {
        guard let panel else { return }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            panel.orderOut(nil)
            self?.panel = nil
        })

        logger.debug("Recording overlay dismissed")
    }
}
