import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct MainWindowView: View {
    var historyStore: HistoryStore
    var promptStore: PromptStore
    @Bindable var settings: Settings
    var permissionManager: PermissionManager
    var transcriptionCleaner: TranscriptionCleaner
    var transcriptionEngine: TranscriptionEngine
    var audioPlayer: AudioPlayer
    var audioSignalPlayer: AudioSignalPlayer

    var body: some View {
        HistoryContentView(
            historyStore: historyStore,
            audioPlayer: audioPlayer,
            transcriptionEngine: transcriptionEngine,
            transcriptionCleaner: transcriptionCleaner,
            promptStore: promptStore,
            settings: settings,
            permissionManager: permissionManager,
            audioSignalPlayer: audioSignalPlayer
        )
        .navigationTitle("Mac Speech to AI to Text")
        .frame(maxWidth: 1180, maxHeight: .infinity)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .frame(minWidth: 920, minHeight: 620)
    }
}

/// Wraps history with its own folder sidebar
struct HistoryContentView: View {
    var historyStore: HistoryStore
    var audioPlayer: AudioPlayer
    var transcriptionEngine: TranscriptionEngine
    var transcriptionCleaner: TranscriptionCleaner
    var promptStore: PromptStore
    @Bindable var settings: Settings
    var permissionManager: PermissionManager
    var audioSignalPlayer: AudioSignalPlayer

    enum HistorySection: Hashable {
        case all
        case unfiled
        case folder(UUID)
        case archive
        case failed
        case prompts
        case settings
    }

    @State private var selectedSection: HistorySection = .all
    @State private var selectedRecord: TranscriptionRecord?
    @State private var selectedPromptID: UUID?

    private var hasFailedRecords: Bool { !historyStore.failedRecords.isEmpty }
    private var folderIDs: Set<UUID> { Set(historyStore.folders.map(\.id)) }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSection) {
                Section("App") {
                    Label("Prompts", systemImage: "text.quote")
                        .tag(HistorySection.prompts)
                }
                
                Section("Library") {
                    Label("All", systemImage: "tray.full")
                        .tag(HistorySection.all)
                        .onDrop(of: [.plainText], isTargeted: nil) { providers in
                            handleDrop(providers, toFolder: nil, unarchive: true)
                        }
                }

                if !historyStore.folders.isEmpty {
                    Section("Folders") {
                        ForEach(historyStore.folders) { folder in
                            Label(folder.name, systemImage: "folder")
                                .tag(HistorySection.folder(folder.id))
                                .contextMenu {
                                    Button("Delete Folder") {
                                        historyStore.deleteFolder(id: folder.id)
                                    }
                                }
                                .onDrop(of: [.plainText], isTargeted: nil) { providers in
                                    handleDrop(providers, toFolder: folder.id, unarchive: true)
                                }
                        }
                    }
                }

                Section {
                    Label("Archive", systemImage: "archivebox")
                        .tag(HistorySection.archive)
                        .onDrop(of: [.plainText], isTargeted: nil) { providers in
                            handleDropToArchive(providers)
                        }
                    if hasFailedRecords {
                        Label("Failed", systemImage: "exclamationmark.circle")
                            .tag(HistorySection.failed)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Divider()
                    Button(action: {
                        selectedSection = .settings
                    }) {
                        HStack {
                            Image(systemName: "gear")
                                .frame(width: 16)
                            Text("Settings")
                            Spacer()
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 8)
                    .background(selectedSection == .settings ? Color.accentColor.opacity(0.15) : Color.clear)
                    .cornerRadius(6)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
                }
                .background(.background)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 190)
            .onAppear(perform: normalizeSelectedSection)
            .onChange(of: hasFailedRecords) { _, _ in normalizeSelectedSection() }
            .onChange(of: folderIDs) { _, _ in normalizeSelectedSection() }
            .toolbar {
                ToolbarItem {
                    Button(action: addFolder) {
                        Image(systemName: "folder.badge.plus")
                    }
                    .help("New Folder")
                }
            }
        } detail: {
            switch selectedSection {
            case .all, .unfiled, .folder, .archive, .failed:
                NavigationSplitView {
                    HistoryListView(
                        historyStore: historyStore,
                        section: selectedSection,
                        selectedRecord: $selectedRecord
                    )
                    .navigationSplitViewColumnWidth(min: 220, ideal: 280)
                } detail: {
                    if let record = selectedRecord {
                        HistoryDetailView(
                            record: record,
                            historyStore: historyStore,
                            audioPlayer: audioPlayer,
                            transcriptionEngine: transcriptionEngine,
                            transcriptionCleaner: transcriptionCleaner,
                            promptStore: promptStore,
                            settings: settings
                        )
                        .id(record.id)
                    } else {
                        ContentUnavailableView("Select a Transcription", systemImage: "text.bubble", description: Text("Choose a transcription from the list to view details."))
                    }
                }
            case .prompts:
                NavigationSplitView {
                    PromptListView(promptStore: promptStore, selectedPromptID: $selectedPromptID)
                        .navigationSplitViewColumnWidth(min: 240, ideal: 300)
                } detail: {
                    if let id = selectedPromptID,
                       let prompt = promptStore.prompts.first(where: { $0.id == id }) {
                        PromptEditorView(prompt: prompt, promptStore: promptStore)
                    } else {
                        ContentUnavailableView("Select a Prompt", systemImage: "text.quote", description: Text("Choose a prompt to edit."))
                    }
                }
            case .settings:
                SettingsContentView(
                    settings: settings,
                    permissionManager: permissionManager,
                    transcriptionCleaner: transcriptionCleaner,
                    transcriptionEngine: transcriptionEngine,
                    promptStore: promptStore,
                    audioSignalPlayer: audioSignalPlayer
                )
            }
        }
    }

    private func addFolder() {
        _ = historyStore.createFolder(name: "New Folder")
    }

    private func normalizeSelectedSection() {
        switch selectedSection {
        case .unfiled:
            selectedSection = .all
        case .failed where !hasFailedRecords:
            selectedSection = .all
        case .folder(let id) where !folderIDs.contains(id):
            selectedSection = .all
        default:
            break
        }
    }

    private func handleDrop(_ providers: [NSItemProvider], toFolder folderID: UUID?, unarchive: Bool) -> Bool {
        var handled = false
        for provider in providers {
            provider.loadObject(ofClass: NSString.self) { item, _ in
                guard let str = item as? String, let id = UUID(uuidString: str) else { return }
                DispatchQueue.main.async {
                    let ids: Set<UUID> = [id]
                    if unarchive { historyStore.unarchiveRecords(ids) }
                    historyStore.moveRecords(ids, toFolder: folderID)
                }
            }
            handled = true
        }
        return handled
    }

    private func handleDropToArchive(_ providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers {
            provider.loadObject(ofClass: NSString.self) { item, _ in
                guard let str = item as? String, let id = UUID(uuidString: str) else { return }
                DispatchQueue.main.async {
                    historyStore.archiveRecords([id])
                }
            }
            handled = true
        }
        return handled
    }
}

struct SettingsContentView: View {
    @Bindable var settings: Settings
    var permissionManager: PermissionManager
    var transcriptionCleaner: TranscriptionCleaner
    var transcriptionEngine: TranscriptionEngine
    var promptStore: PromptStore
    var audioSignalPlayer: AudioSignalPlayer

    @State private var recordingBindingID: UUID?
    @State private var apiKeyText: String = ""
    @State private var showSavedIndicator = false
    @State private var savedTimer: Timer?
    @State private var testState: TestConnectionState = .idle
    @State private var microphones: [MicrophoneOption] = []
    @State private var didAppear = false

    private enum TestConnectionState {
        case idle
        case testing
        case success(String)
        case failure(String)
    }

    var body: some View {
        ScrollView {
            Form {
                voiceInputSection
                shortcutsSection
                soundSection
                transcriptionSection
                aiCleanupSection
                mediaSection
                overlaySection
                downloadedModelsSection
                storageSection
                permissionsSection
            }
            .formStyle(.grouped)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .overlay(alignment: .top) {
            if showSavedIndicator {
                Text("Settings saved ✓")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showSavedIndicator)
        .onChange(of: settings.sendPhrase) { _, _ in flashSaved() }
        .onChange(of: settings.sendPhraseEnabled) { _, _ in flashSaved() }
        .onChange(of: settings.silenceThreshold) { _, _ in flashSaved() }
        .onChange(of: settings.whisperModel) { _, _ in flashSaved() }
        .onChange(of: settings.autoResumeMedia) { _, _ in flashSaved() }
        .onChange(of: settings.keepMicrophoneConnected) { _, _ in flashSaved() }
        .onChange(of: settings.wakePhraseEnabled) { _, _ in flashSaved() }
        .onChange(of: settings.aiCleanupEnabled) { _, _ in flashSaved() }
        .onChange(of: settings.aiCleanupProvider) { _, _ in flashSaved() }
        .onChange(of: settings.aiCleanupModelID) { _, _ in flashSaved() }
        .onChange(of: settings.soundPreset) { oldValue, newValue in
            guard didAppear, oldValue != newValue else { return }
            flashSaved()
            Task { await audioSignalPlayer.playReadyBeep() }
        }
        .onAppear {
            refreshMicrophones()
            didAppear = true
        }
    }

    // MARK: - Sections

    @ViewBuilder private var voiceInputSection: some View {
        Section("Voice Input") {
            Picker("Microphone", selection: $settings.selectedMicrophoneID) {
                Text("System Default").tag("")
                ForEach(microphones) { microphone in
                    Text(microphone.name).tag(microphone.id)
                }
            }

            Toggle("Send Phrase", isOn: $settings.sendPhraseEnabled)

            TextField("Send Phrase", text: $settings.sendPhrase)
                .disabled(!settings.sendPhraseEnabled)
                .opacity(settings.sendPhraseEnabled ? 1.0 : 0.5)

            Toggle("Keep Microphone Connected", isOn: $settings.keepMicrophoneConnected)

            if !settings.keepMicrophoneConnected {
                Text("The microphone stays off while idle. Shortcut recording will pause Spotify with the keyboard play/pause key, then connect the mic only for the recording.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Silence Threshold:")
                Slider(value: $settings.silenceThreshold, in: 0.5...5.0, step: 0.5)
                Text("\(settings.silenceThreshold, specifier: "%.1f")s")
                    .monospacedDigit()
                    .frame(width: 35)
            }
            .disabled(!settings.sendPhraseEnabled)
            .opacity(settings.sendPhraseEnabled ? 1.0 : 0.5)

            Toggle("Wake Phrase Enabled", isOn: $settings.wakePhraseEnabled)
                .disabled(!settings.keepMicrophoneConnected)
                .opacity(settings.keepMicrophoneConnected ? 1.0 : 0.5)

            TextField("Wake Phrase", text: $settings.wakePhrase)
                .disabled(!settings.keepMicrophoneConnected || !settings.wakePhraseEnabled)
                .opacity(settings.keepMicrophoneConnected && settings.wakePhraseEnabled ? 1.0 : 0.5)

            Toggle("Insert Phrase Enabled", isOn: $settings.insertPhraseEnabled)

            TextField("Insert Phrase", text: $settings.insertPhrase)
                .disabled(!settings.insertPhraseEnabled)
                .opacity(settings.insertPhraseEnabled ? 1.0 : 0.5)

            if settings.insertPhraseEnabled && !settings.autoInsertEnabled && !settings.keepMicrophoneConnected {
                Text("If insert phrase is enabled, the microphone stays connected after recording until the insert phrase is spoken or the result is dismissed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Toggle("Auto-Insert After Transcription", isOn: $settings.autoInsertEnabled)
        }
    }

    @ViewBuilder private var shortcutsSection: some View {
        Section("Shortcuts") {
            ForEach(settings.shortcutBindings.indices, id: \.self) { index in
                ShortcutBindingRowView(
                    binding: $settings.shortcutBindings[index],
                    promptStore: promptStore,
                    onDelete: { settings.shortcutBindings.remove(at: index) }
                )
            }

            Button {
                let newBinding = ShortcutBinding(
                    keyCode: 9,
                    modifiers: UInt(NSEvent.ModifierFlags([.command, .shift]).rawValue),
                    label: ""
                )
                settings.shortcutBindings.append(newBinding)
            } label: {
                Label("Add Shortcut", systemImage: "plus")
            }
        }
    }

    @ViewBuilder private var soundSection: some View {
        Section("Sound") {
            Toggle("Enable Notification Sound", isOn: $settings.beepEnabled)

            HStack {
                Picker("Notification Sound", selection: $settings.soundPreset) {
                    ForEach(SoundPreset.allCases, id: \.self) { preset in
                        Text(preset.displayName).tag(preset.rawValue)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    Task { await audioSignalPlayer.playReadyBeep() }
                } label: {
                    Image(systemName: "play.fill")
                }
                .buttonStyle(.borderless)
                .foregroundColor(.accentColor)
            }

            HStack {
                Text("Volume:")
                Slider(value: $settings.beepVolume, in: 0.0...1.0, step: 0.1)
                Text("\(Int(settings.beepVolume * 100))%")
                    .monospacedDigit()
                    .frame(width: 35)
            }
        }
    }

    @ViewBuilder private var transcriptionSection: some View {
        Section("Transcription") {
            Picker("Whisper Model:", selection: $settings.whisperModel) {
                if transcriptionEngine.availableModels.isEmpty {
                    ForEach(Settings.fallbackModels, id: \.self) { model in
                        Text(Settings.whisperModelDisplayName(model)).tag(model)
                    }
                } else {
                    ForEach(transcriptionEngine.availableModels, id: \.self) { model in
                        Text(Settings.whisperModelDisplayName(model)).tag(model)
                    }
                }
            }
            .onChange(of: settings.whisperModel) { _, _ in
                Task { await transcriptionEngine.reloadModel() }
            }

            HStack(spacing: 8) {
                switch transcriptionEngine.modelState {
                case .notLoaded:
                    Label("Model not loaded", systemImage: "circle.dashed")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                case .loading:
                    ProgressView()
                        .controlSize(.small)
                    Text("Downloading & loading model…")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                case .loaded:
                    Label("Model ready", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                case .failed(let msg):
                    Label(msg, systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
    }

    @ViewBuilder private var aiCleanupSection: some View {
        Section("AI Cleanup") {
            Toggle("Enable AI Cleanup", isOn: $settings.aiCleanupEnabled)

            if settings.aiCleanupEnabled {
                Picker("Provider:", selection: $settings.aiCleanupProvider) {
                    ForEach(AIProvider.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }

                if settings.aiCleanupProvider == .custom {
                    TextField("Endpoint", text: $settings.aiCleanupCustomEndpoint)
                    TextField("Model", text: $settings.aiCleanupCustomModel)
                } else {
                    Picker("Model:", selection: $settings.aiCleanupModelID) {
                        ForEach(settings.aiCleanupProvider.models) { model in
                            Text(model.displayName).tag(model.id)
                        }
                    }

                    LabeledContent("Endpoint:") {
                        Text(settings.aiCleanupProvider.fullEndpointURL)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }

                SecureField("API Key", text: $apiKeyText)
                    .onAppear { apiKeyText = settings.aiCleanupAPIKey }
                    .onChange(of: apiKeyText) { _, newValue in
                        settings.aiCleanupAPIKey = newValue
                    }

                HStack(spacing: 8) {
                    Button("Test Connection") {
                        testConnection()
                    }
                    .buttonStyle(.bordered)
                    .disabled({
                        if case .testing = testState { return true }
                        return false
                    }())

                    switch testState {
                    case .idle:
                        EmptyView()
                    case .testing:
                        ProgressView()
                            .controlSize(.small)
                    case .success(let msg):
                        Label(msg, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    case .failure(let msg):
                        Label(msg, systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
        }
    }

    @ViewBuilder private var mediaSection: some View {
        Section("Media") {
            Toggle("Auto-Resume Media After Recording", isOn: $settings.autoResumeMedia)
        }
    }

    @ViewBuilder private var overlaySection: some View {
        Section("Overlay") {
            Toggle("Keep Overlay Open After Copy", isOn: $settings.keepOverlayOpenOnCopy)

            if settings.keepOverlayOpenOnCopy {
                HStack {
                    Text("Auto-dismiss after:")
                    Spacer()
                    if settings.copyAutoDismissDelay == 0 {
                        Text("Never").foregroundStyle(.secondary)
                    } else {
                        Text("\(settings.copyAutoDismissDelay)s").foregroundStyle(.secondary)
                    }
                    Stepper("", value: $settings.copyAutoDismissDelay, in: 0...60, step: 5)
                        .labelsHidden()
                }
            }
        }
    }

    @ViewBuilder private var downloadedModelsSection: some View {
        Section("Downloaded Models") {
            if transcriptionEngine.downloadedModels.isEmpty {
                Text("No models downloaded")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                let totalSize = transcriptionEngine.downloadedModels.reduce(Int64(0)) { $0 + $1.sizeBytes }
                Text("Total: \(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(transcriptionEngine.downloadedModels) { model in
                    HStack {
                        Text(Settings.whisperModelDisplayName(model.name))
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: model.sizeBytes, countStyle: .file))
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        Button("Delete", role: .destructive) {
                            try? transcriptionEngine.deleteModel(model.name)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }

            Button("Refresh") {
                transcriptionEngine.scanDownloadedModels()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    @ViewBuilder private var storageSection: some View {
        Section("Storage") {
            Picker("Auto-delete recordings:", selection: $settings.autoDeleteDays) {
                Text("Never").tag(0)
                Text("After 7 days").tag(7)
                Text("After 30 days").tag(30)
                Text("After 90 days").tag(90)
                Text("After 1 year").tag(365)
            }
        }
    }

    @ViewBuilder private var permissionsSection: some View {
        Section("Permissions") {
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

            Button("Refresh Permission Status") {
                Task { await permissionManager.checkAllPermissions() }
            }
        }
    }

    private func flashSaved() {
        savedTimer?.invalidate()
        withAnimation { showSavedIndicator = true }
        savedTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
            DispatchQueue.main.async {
                withAnimation { showSavedIndicator = false }
            }
        }
    }

    private func refreshMicrophones() {
        microphones = AudioRecorder.availableMicrophones()
        if !settings.selectedMicrophoneID.isEmpty &&
            !microphones.contains(where: { $0.id == settings.selectedMicrophoneID }) {
            settings.selectedMicrophoneID = ""
        }
    }

    private func testConnection() {
        testState = .testing
        Task {
            let result = await transcriptionCleaner.testAPIKey()
            await MainActor.run {
                switch result {
                case .success(let preview):
                    testState = .success(preview.isEmpty ? "Connected" : preview)
                case .failure(let error):
                    testState = .failure(error.localizedDescription)
                }
            }
        }
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

// MARK: - Shortcut Binding Row

private struct ShortcutBindingRowView: View {
    @Binding var binding: ShortcutBinding
    var promptStore: PromptStore
    var onDelete: () -> Void

    @State private var isRecording = false

    var body: some View {
        HStack(spacing: 10) {
            ShortcutRecorderButton(
                displayString: binding.displayString,
                isRecording: $isRecording,
                onRecord: { keyCode, modifiers in
                    binding.keyCode = keyCode
                    binding.modifiers = modifiers
                }
            )
            .frame(width: 96, alignment: .leading)

            HStack(spacing: 8) {
                Picker("Prompt", selection: $binding.promptID) {
                    Text("Default Prompt").tag(Optional<UUID>.none)
                    ForEach(promptStore.prompts) { prompt in
                        Text(prompt.name).tag(Optional(prompt.id))
                    }
                }
                .labelsHidden()
                .frame(width: 220, alignment: .trailing)

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}
