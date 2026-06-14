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
    @State private var nestedColumnVisibility: NavigationSplitViewVisibility = .all

    private var hasFailedRecords: Bool { !historyStore.failedRecords.isEmpty }
    private var folderIDs: Set<UUID> { Set(historyStore.folders.map(\.id)) }
    private var appVersionDisplay: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "v\(version) (\(build))"
    }

    var body: some View {
        HStack(spacing: 0) {
            primarySidebar
                .frame(width: 210)

            Divider()

            detailContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            nestedColumnVisibility = .all
            normalizeSelectedSection()
        }
        .onChange(of: hasFailedRecords) { _, _ in normalizeSelectedSection() }
        .onChange(of: folderIDs) { _, _ in normalizeSelectedSection() }
    }

    private var primarySidebar: some View {
        VStack(spacing: 0) {
            List(selection: $selectedSection) {
                Section("App") {
                    Label("Prompts", systemImage: "text.quote")
                        .tag(HistorySection.prompts)
                    Label("Settings", systemImage: "gear")
                        .tag(HistorySection.settings)
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
            .listStyle(.sidebar)

            Divider()

            Text(appVersionDisplay)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 2)
                .accessibilityLabel("App version \(appVersionDisplay)")

            Button(action: addFolder) {
                Label("New Folder", systemImage: "folder.badge.plus")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder private var detailContent: some View {
        switch selectedSection {
        case .all, .unfiled, .folder, .archive, .failed:
            NavigationSplitView(columnVisibility: $nestedColumnVisibility) {
                HistoryListView(
                    historyStore: historyStore,
                    section: selectedSection,
                    selectedRecord: $selectedRecord
                )
                .navigationSplitViewColumnWidth(min: 220, ideal: 280)
                .onAppear {
                    nestedColumnVisibility = .all
                }
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
            NavigationSplitView(columnVisibility: $nestedColumnVisibility) {
                PromptListView(promptStore: promptStore, selectedPromptID: $selectedPromptID)
                    .navigationSplitViewColumnWidth(min: 240, ideal: 300)
                    .onAppear {
                        nestedColumnVisibility = .all
                    }
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
    @State private var pendingDownloadModel: String = ""
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
                diagnosticsSection
                transcriptionSection
                aiCleanupSection
                mediaSection
                overlaySection
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
        .onChange(of: settings.diagnosticFileLoggingEnabled) { _, _ in flashSaved() }
        .onChange(of: settings.soundPreset) { oldValue, newValue in
            guard didAppear, oldValue != newValue else { return }
            flashSaved()
            Task { await audioSignalPlayer.playReadyBeep() }
        }
        .onAppear {
            refreshMicrophones()
            syncPendingDownloadModel()
            didAppear = true
        }
        .onChange(of: transcriptionEngine.availableModels) { _, _ in
            syncPendingDownloadModel()
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

    @ViewBuilder private var diagnosticsSection: some View {
        Section("Diagnostics") {
            Toggle("Diagnostic File Logging", isOn: $settings.diagnosticFileLoggingEnabled)

            Text("When enabled, MacVoice writes microphone startup, shortcut, permission, and pipeline events to a local diagnostic file.")
                .font(.caption)
                .foregroundStyle(.secondary)

            LabeledContent("Current Log:") {
                Text(DiagnosticLogger.currentLogFileURL.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }

            HStack {
                Button("Reveal Log File") {
                    revealDiagnosticLogFile()
                }
                .buttonStyle(.bordered)

                Button("Copy Log Path") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(DiagnosticLogger.currentLogFileURL.path, forType: .string)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    @ViewBuilder private var transcriptionSection: some View {
        Section("Transcription") {
            LabeledContent("Active Model:") {
                Text(Settings.whisperModelDisplayName(settings.whisperModel))
            }

            HStack(spacing: 8) {
                switch transcriptionEngine.modelState {
                case .notLoaded:
                    Label("Selected model not prepared", systemImage: "circle.dashed")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                case .preparingLocal:
                    ProgressView()
                        .controlSize(.small)
                    Text("Preparing local model…")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                case .downloading:
                    ProgressView()
                        .controlSize(.small)
                    Text("Downloading selected model…")
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

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Model Storage:")
                    Text(settings.modelStoragePath.isEmpty ? "Default (~/Documents/huggingface/)" : settings.modelStoragePath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Button("Choose…") {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    panel.canCreateDirectories = true
                    panel.allowsMultipleSelection = false
                    panel.prompt = "Select"
                    panel.message = "Choose where Whisper models are stored"
                    if panel.runModal() == .OK, let url = panel.url {
                        settings.modelStoragePath = url.path
                    }
                }
                if !settings.modelStoragePath.isEmpty {
                    Button("Reset") {
                        settings.modelStoragePath = ""
                    }
                    .foregroundStyle(.secondary)
                }
            }

            Divider()

            if transcriptionEngine.downloadedModels.isEmpty {
                Text("No models downloaded")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                let totalSize = transcriptionEngine.downloadedModels.reduce(Int64(0)) { $0 + $1.sizeBytes }
                Text("Downloaded Models — \(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(transcriptionEngine.downloadedModels) { model in
                    let isSelected = transcriptionEngine.isSelectedModel(model.name)
                    let isLoaded = transcriptionEngine.isLoadedModel(model.name)

                    HStack {
                        Text(Settings.whisperModelDisplayName(model.name))
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: model.sizeBytes, countStyle: .file))
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        if isSelected {
                            Text(selectedDownloadedModelStatusLabel(isLoaded: isLoaded))
                                .foregroundStyle(selectedDownloadedModelStatusColor(isLoaded: isLoaded))
                                .font(.caption)
                        } else {
                            Button("Use") {
                                transcriptionEngine.selectModel(model.name)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        Button("Delete", role: .destructive) {
                            try? transcriptionEngine.deleteModel(model.name)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(isSelected)
                    }
                }
            }

            let availableModelsToDownload = transcriptionEngine.availableModelsToDownload()
            if !availableModelsToDownload.isEmpty {
                Divider()

                HStack {
                    Picker("Download New Model:", selection: pendingDownloadModelBinding(options: availableModelsToDownload)) {
                        ForEach(availableModelsToDownload, id: \.self) { model in
                            Text(Settings.whisperModelDisplayName(model)).tag(model)
                        }
                    }

                    Button("Download & Use") {
                        let modelName = pendingDownloadModelBinding(options: availableModelsToDownload).wrappedValue
                        guard !modelName.isEmpty else { return }
                        Task { await transcriptionEngine.loadModel(modelName) }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            Button("Refresh") {
                transcriptionEngine.scanDownloadedModels()
                syncPendingDownloadModel()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private func pendingDownloadModelBinding(options: [String]) -> Binding<String> {
        Binding(
            get: {
                if options.contains(pendingDownloadModel) {
                    return pendingDownloadModel
                }
                return options.first ?? ""
            },
            set: { pendingDownloadModel = $0 }
        )
    }

    private func syncPendingDownloadModel() {
        let options = transcriptionEngine.availableModelsToDownload()
        guard let firstOption = options.first else {
            pendingDownloadModel = ""
            return
        }

        if !options.contains(pendingDownloadModel) {
            pendingDownloadModel = firstOption
        }
    }

    private func selectedDownloadedModelStatusLabel(isLoaded: Bool) -> String {
        if isLoaded {
            return "In Use"
        }

        switch transcriptionEngine.modelState {
        case .preparingLocal:
            return "Preparing"
        case .downloading:
            return "Downloading"
        case .failed:
            return "Needs Attention"
        case .notLoaded:
            return "Selected"
        case .loaded:
            return "In Use"
        }
    }

    private func selectedDownloadedModelStatusColor(isLoaded: Bool) -> Color {
        if isLoaded {
            return .green
        }

        switch transcriptionEngine.modelState {
        case .failed:
            return .red
        default:
            return .secondary
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

                VStack(alignment: .leading, spacing: 6) {
                    SecureField("Paste new API key to replace stored key", text: $apiKeyText)
                        .textContentType(.password)
                        .onSubmit { testConnection() }

                    Text(apiKeyStatusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.disabled)
                }

                HStack(spacing: 8) {
                    Button(apiKeyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Test Connection" : "Save & Test Connection") {
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

    private var apiKeyStatusText: String {
        let pending = apiKeyText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !pending.isEmpty {
            return "New key ready to save. It will replace the stored key when you test."
        }

        let saved = settings.aiCleanupAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !saved.isEmpty else {
            return "No API key saved. Paste a key above, then choose Save & Test Connection."
        }

        return "Saved API key ending in …\(String(saved.suffix(4))). Paste a new key above to replace it."
    }

    private func testConnection() {
        let pastedKey = apiKeyText.trimmingCharacters(in: .whitespacesAndNewlines)
        let isTestingReplacementKey = !pastedKey.isEmpty
        testState = .testing

        Task {
            let result = await transcriptionCleaner.testAPIKey(apiKey: isTestingReplacementKey ? pastedKey : nil)
            await MainActor.run {
                switch result {
                case .success(let preview):
                    if isTestingReplacementKey {
                        settings.aiCleanupAPIKey = pastedKey
                        apiKeyText = ""
                        flashSaved()
                    }
                    let message = preview.isEmpty ? "Connected" : preview
                    testState = .success(isTestingReplacementKey ? "Saved & connected: \(message)" : message)
                case .failure(let error):
                    let prefix = isTestingReplacementKey ? "New pasted key failed: " : ""
                    testState = .failure(prefix + error.localizedDescription)
                }
            }
        }
    }

    private func revealDiagnosticLogFile() {
        let url = DiagnosticLogger.currentLogFileURL
        try? FileManager.default.createDirectory(at: DiagnosticLogger.diagnosticsDirectory, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? Data().write(to: url)
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
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
