import SwiftUI
import AppKit

struct PreferencesView: View {
    @Bindable var settings: Settings
    var permissionManager: PermissionManager
    var promptStore: PromptStore

    @State private var recordingBindingID: UUID?

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gear") }

            permissionsTab
                .tabItem { Label("Permissions", systemImage: "lock.shield") }
        }
        .frame(width: 480, height: 420)
        .padding()
    }

    // MARK: - General Tab

    @ViewBuilder private var voiceInputSection: some View {
        Section("Voice Input") {
            TextField("Send Phrase", text: $settings.sendPhrase)
            Toggle("Send Phrase Enabled", isOn: $settings.sendPhraseEnabled)
            Toggle("Keep Microphone Connected", isOn: $settings.keepMicrophoneConnected)
            Toggle("Wake Phrase Enabled", isOn: $settings.wakePhraseEnabled)
                .disabled(!settings.keepMicrophoneConnected)
                .opacity(settings.keepMicrophoneConnected ? 1.0 : 0.5)
            Toggle("Auto-Insert After Transcription", isOn: $settings.autoInsertEnabled)
            Toggle("Insert Phrase Enabled", isOn: $settings.insertPhraseEnabled)
            TextField("Insert Phrase", text: $settings.insertPhrase)
                .disabled(!settings.insertPhraseEnabled)
                .opacity(settings.insertPhraseEnabled ? 1.0 : 0.5)
        }
    }

    @ViewBuilder private var shortcutsSection: some View {
        Section("Shortcuts") {
            VStack(alignment: .leading, spacing: 8) {
                PrefsShortcutRowsView(
                    bindings: $settings.shortcutBindings,
                    recordingBindingID: $recordingBindingID
                )
                Button {
                    let newBinding = ShortcutBinding(
                        keyCode: 9,
                        modifiers: UInt(NSEvent.ModifierFlags([.command, .shift]).rawValue),
                        label: "Shortcut \(settings.shortcutBindings.count + 1)"
                    )
                    settings.shortcutBindings.append(newBinding)
                } label: { Label("Add Shortcut", systemImage: "plus") }
                .buttonStyle(.borderless)
                .foregroundColor(.accentColor)
            }
        }
    }

    private var generalTab: some View {
        Form {
            voiceInputSection
            shortcutsSection
            Section("Overlay") {
                Toggle("Keep Overlay Open After Copy", isOn: $settings.keepOverlayOpenOnCopy)
            }
            Section("Transcription") {
                Picker("Whisper Model:", selection: $settings.whisperModel) {
                    ForEach(Settings.fallbackModels, id: \.self) { model in
                        Text(Settings.whisperModelDisplayName(model)).tag(model)
                    }
                }
            }
            Section("Media") {
                Toggle("Auto-Resume Media After Recording", isOn: $settings.autoResumeMedia)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Permissions Tab

    private var permissionsTab: some View {
        Form {
            Section("Required Permissions") {
                permissionRow(
                    title: "Accessibility",
                    granted: permissionManager.accessibilityGranted,
                    action: { permissionManager.requestAccessibility() }
                )

                permissionRow(
                    title: "Microphone",
                    granted: permissionManager.microphoneGranted,
                    action: { permissionManager.openMicrophoneSettings() }
                )

                permissionRow(
                    title: "Input Monitoring",
                    granted: permissionManager.inputMonitoringGranted,
                    action: { permissionManager.openInputMonitoringSettings() }
                )
            }

            Section {
                Button("Refresh Permission Status") {
                    Task { await permissionManager.checkAllPermissions() }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func permissionRow(title: String, granted: Bool, action: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(granted ? .green : .red)
            Text(title)
            Spacer()
            if !granted {
                Button("Grant") { action() }
                    .buttonStyle(.bordered)
            }
        }
    }
}

// MARK: - Prefs Shortcut Rows

private struct PrefsShortcutRowsView: View {
    @Binding var bindings: [ShortcutBinding]
    @Binding var recordingBindingID: UUID?

    var body: some View {
        ForEach(bindings.indices, id: \.self) { index in
            HStack(spacing: 8) {
                TextField("Label", text: $bindings[index].label)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                ShortcutRecorderButton(
                    displayString: bindings[index].displayString,
                    isRecording: Binding<Bool>(
                        get: { recordingBindingID == bindings[index].id },
                        set: { rec in
                            let id = bindings[index].id
                            recordingBindingID = rec ? id : nil
                        }
                    ),
                    onRecord: { keyCode, modifiers in
                        bindings[index].keyCode = keyCode
                        bindings[index].modifiers = modifiers
                        recordingBindingID = nil
                    }
                )
                Button(role: .destructive) {
                    bindings.remove(at: index)
                } label: {
                    Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
            }
        }
    }
}

// MARK: - Shortcut Recorder

struct ShortcutRecorderButton: NSViewRepresentable {
    let displayString: String
    @Binding var isRecording: Bool
    let onRecord: (_ keyCode: UInt16, _ modifiers: UInt) -> Void

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(title: displayString.isEmpty ? "Click to set" : displayString, target: context.coordinator, action: #selector(Coordinator.clicked))
        button.bezelStyle = .rounded
        button.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return button
    }

    func updateNSView(_ button: NSButton, context: Context) {
        if isRecording {
            button.title = "Press shortcut…"
        } else {
            button.title = displayString.isEmpty ? "Click to set" : displayString
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject {
        let parent: ShortcutRecorderButton
        var monitor: Any?

        init(parent: ShortcutRecorderButton) {
            self.parent = parent
        }

        @objc func clicked() {
            parent.isRecording = true
            // Listen for the next key-down event globally
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
                // Require at least one modifier
                guard !modifiers.isEmpty else { return event }

                self.parent.onRecord(event.keyCode, modifiers.rawValue)
                self.parent.isRecording = false
                if let m = self.monitor {
                    NSEvent.removeMonitor(m)
                    self.monitor = nil
                }
                return nil // consume the event
            }
        }
    }
}
