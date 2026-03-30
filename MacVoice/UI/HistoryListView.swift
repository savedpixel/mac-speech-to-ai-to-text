import SwiftUI
import UniformTypeIdentifiers

struct HistoryListView: View {
    var historyStore: HistoryStore
    let section: HistoryContentView.HistorySection
    @Binding var selectedRecord: TranscriptionRecord?

    @State private var selectedIDs: Set<UUID> = []
    @State private var searchText = ""
    @State private var showDeleteConfirmation = false

    private var filteredRecords: [TranscriptionRecord] {
        let base: [TranscriptionRecord]
        switch section {
        case .all:
            base = historyStore.unarchivedRecords
        case .unfiled:
            base = historyStore.unfiledRecords
        case .folder(let id):
            base = historyStore.records(inFolder: id)
        case .archive:
            base = historyStore.archivedRecords
        case .failed:
            base = historyStore.failedRecords
        case .prompts, .settings:
            base = []
        }

        if searchText.isEmpty { return base }
        return base.filter {
            ($0.cleanedText ?? $0.rawText).localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List(filteredRecords, selection: $selectedIDs) { record in
            recordRow(record)
                .tag(record.id)
                .onDrag {
                    NSItemProvider(object: record.id.uuidString as NSString)
                }
                .contextMenu {
                    let targetIDs = selectedIDs.contains(record.id) ? selectedIDs : [record.id]

                    Button("Copy Text") {
                        let texts = filteredRecords
                            .filter { targetIDs.contains($0.id) }
                            .map { $0.cleanedText ?? $0.rawText }
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(texts.joined(separator: "\n\n"), forType: .string)
                    }

                    if !historyStore.folders.isEmpty {
                        Menu("Move to Folder") {
                            ForEach(historyStore.folders) { folder in
                                Button(folder.name) {
                                    historyStore.moveRecords(targetIDs, toFolder: folder.id)
                                }
                            }
                            Divider()
                            Button("Unfiled") {
                                historyStore.moveRecords(targetIDs, toFolder: nil)
                            }
                        }
                    }

                    if section != .archive {
                        Button("Archive") {
                            historyStore.archiveRecords(targetIDs)
                        }
                    } else {
                        Button("Unarchive") {
                            historyStore.unarchiveRecords(targetIDs)
                        }
                    }
                    Divider()
                    Button("Delete", role: .destructive) {
                        historyStore.deleteRecords(targetIDs)
                    }
                }
        }
        .searchable(text: $searchText, prompt: "Search transcriptions…")
        .onChange(of: selectedIDs) { _, newValue in
            if let id = newValue.first {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    selectedRecord = filteredRecords.first(where: { $0.id == id })
                }
            } else {
                selectedRecord = nil
            }
        }
        .onAppear {
            if selectedIDs.isEmpty, let first = filteredRecords.first {
                selectedIDs = [first.id]
                selectedRecord = first
            }
        }
        .onChange(of: section) { _, _ in
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                selectedIDs.removeAll()
                selectedRecord = nil
                if let first = filteredRecords.first {
                    selectedIDs = [first.id]
                    selectedRecord = first
                }
            }
        }
        .toolbar {
            ToolbarItemGroup {
                if !selectedIDs.isEmpty {
                    Menu {
                        ForEach(historyStore.folders) { folder in
                            Button(folder.name) {
                                historyStore.moveRecords(selectedIDs, toFolder: folder.id)
                            }
                        }
                        Divider()
                        Button("Unfiled") {
                            historyStore.moveRecords(selectedIDs, toFolder: nil)
                        }
                    } label: {
                        Image(systemName: "folder")
                    }
                    .help("Move to Folder")

                    if section != .archive {
                        Button {
                            historyStore.archiveRecords(selectedIDs)
                        } label: {
                            Image(systemName: "archivebox")
                        }
                        .help("Archive")
                    } else {
                        Button {
                            historyStore.unarchiveRecords(selectedIDs)
                        } label: {
                            Image(systemName: "tray.and.arrow.up")
                        }
                        .help("Unarchive")
                    }

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .help("Delete Selected")
                }
            }
        }
        .alert("Delete \(selectedIDs.count) record(s)?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                historyStore.deleteRecords(selectedIDs)
                selectedIDs.removeAll()
                selectedRecord = nil
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func recordRow(_ record: TranscriptionRecord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                if case .failed = record.transcriptionStatus {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
                Text(record.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if case .failed = record.transcriptionStatus {
                Text("Transcription failed")
                    .lineLimit(1)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .italic()
            } else {
                Text((record.cleanedText ?? record.rawText).prefix(80))
                    .lineLimit(2)
                    .font(.body)
            }
        }
        .padding(.vertical, 4)
    }
}

struct HistoryDetailView: View {
    let record: TranscriptionRecord
    var historyStore: HistoryStore
    var audioPlayer: AudioPlayer
    var transcriptionEngine: TranscriptionEngine
    var transcriptionCleaner: TranscriptionCleaner
    var promptStore: PromptStore
    @Bindable var settings: Settings

    @State private var showRetranscribeSheet = false
    @State private var retranscribeModel: String = ""
    @State private var retranscribePromptID: UUID = CleanupPrompt.default.id
    @State private var retranscribeProgress: RetranscribeProgress = .idle
    @State private var cachedAudioURL: URL?

    private enum RetranscribeProgress: Equatable {
        case idle
        case transcribing
        case cleaning
        case done(String)
        case failed(String)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Text(record.date, format: .dateTime)
                        .font(.headline)

                    if case .failed(let msg) = record.transcriptionStatus {
                        Label("Failed", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                            .help(msg)
                    }

                    Spacer()

                    if record.isArchived {
                        Button("Unarchive") {
                            historyStore.unarchiveRecords([record.id])
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button("Archive") {
                            historyStore.archiveRecords([record.id])
                        }
                        .buttonStyle(.bordered)
                    }

                    Button(role: .destructive) {
                        historyStore.deleteRecords([record.id])
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.bordered)
                }

                // Metadata row
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Text("Folder:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("", selection: Binding(
                            get: { record.folderID },
                            set: { newFolder in
                                historyStore.moveRecords([record.id], toFolder: newFolder)
                            }
                        )) {
                            Text("Unfiled").tag(UUID?.none)
                            ForEach(historyStore.folders) { folder in
                                Text(folder.name).tag(UUID?.some(folder.id))
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .fixedSize()
                    }

                    if let model = record.whisperModel {
                        Text("Model: \(Settings.whisperModelDisplayName(model))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let prompt = record.promptUsed {
                        Text("Prompt: \(prompt)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }

                // Playback bar
                if let audioURL = cachedAudioURL {
                    GroupBox("Recording") {
                        HStack(spacing: 12) {
                            Button {
                                audioPlayer.togglePlayPause(url: audioURL)
                            } label: {
                                Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.title2)
                            }
                            .buttonStyle(.plain)

                            if audioPlayer.duration > 0 {
                                Slider(
                                    value: Binding(
                                        get: { audioPlayer.currentTime },
                                        set: { audioPlayer.seek(to: $0) }
                                    ),
                                    in: 0...audioPlayer.duration
                                )

                                Text(formatTime(audioPlayer.currentTime) + " / " + formatTime(audioPlayer.duration))
                                    .font(.caption)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Re-transcribe button
                if record.audioFileName != nil {
                    Button {
                        retranscribeModel = settings.whisperModel
                        retranscribePromptID = promptStore.selectedPromptID
                        showRetranscribeSheet = true
                    } label: {
                        Label("Re-transcribe", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(.bordered)
                }

                // Transcription text
                if case .failed = record.transcriptionStatus {
                    GroupBox("Transcription") {
                        Text("No transcription — use Re-transcribe to try again")
                            .foregroundStyle(.secondary)
                            .italic()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    if let cleaned = record.cleanedText {
                        HStack {
                            Text("Cleaned Text")
                                .font(.headline)
                            Spacer()
                            Button("Copy") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(cleaned, forType: .string)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        GroupBox {
                            Text(cleaned)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    if !record.rawText.isEmpty {
                        HStack {
                            Text("Raw Text")
                                .font(.headline)
                            Spacer()
                            Button("Copy") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(record.rawText, forType: .string)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        GroupBox {
                            Text(record.rawText)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .padding()
        }
        .frame(minWidth: 300)
        .task(id: record.id) {
            audioPlayer.stop()
            cachedAudioURL = historyStore.audioFileURL(for: record)
        }
        .sheet(isPresented: $showRetranscribeSheet) {
            retranscribeSheet
        }
        .sheet(isPresented: Binding(
            get: { retranscribeProgress != .idle },
            set: { if !$0 { retranscribeProgress = .idle } }
        )) {
            retranscribeProgressSheet
        }
    }

    // MARK: - Re-transcribe Sheet

    private var retranscribeSheet: some View {
        VStack(spacing: 16) {
            Text("Re-transcribe Recording")
                .font(.headline)

            Picker("Model:", selection: $retranscribeModel) {
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

            Picker("Cleanup Prompt:", selection: $retranscribePromptID) {
                ForEach(promptStore.prompts) { prompt in
                    Text(prompt.name).tag(prompt.id)
                }
            }

            HStack {
                Button("Cancel") {
                    showRetranscribeSheet = false
                }
                .buttonStyle(.bordered)

                Button("Re-transcribe") {
                    showRetranscribeSheet = false
                    performRetranscription()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 360)
    }

    @ViewBuilder
    private var retranscribeProgressSheet: some View {
        VStack(spacing: 16) {
            switch retranscribeProgress {
            case .idle:
                EmptyView()
            case .transcribing:
                ProgressView()
                    .controlSize(.large)
                Text("Transcribing…")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            case .cleaning:
                ProgressView()
                    .controlSize(.large)
                Text("Cleaning up via AI…")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            case .done(let text):
                Label("Re-transcription complete", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                ScrollView {
                    Text(text)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 150)
                Button("Done") {
                    retranscribeProgress = .idle
                }
                .buttonStyle(.borderedProminent)
            case .failed(let msg):
                Image(systemName: "xmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.red)
                Text(msg)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Dismiss") {
                    retranscribeProgress = .idle
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(20)
        .frame(minWidth: 340, minHeight: 160)
    }

    private func performRetranscription() {
        guard let audioURL = historyStore.audioFileURL(for: record) else { return }
        retranscribeProgress = .transcribing

        Task {
            if retranscribeModel != transcriptionEngine.loadedModelName {
                await transcriptionEngine.loadModel(retranscribeModel)
            }

            do {
                let rawText = try await transcriptionEngine.transcribe(audioFileURL: audioURL)

                var cleanedText: String? = nil
                if settings.aiCleanupEnabled {
                    await MainActor.run { retranscribeProgress = .cleaning }
                    cleanedText = try? await transcriptionCleaner.clean(rawText)
                }

                let entry = RetranscriptionEntry(
                    date: .now,
                    model: retranscribeModel,
                    prompt: promptStore.prompts.first(where: { $0.id == retranscribePromptID })?.name,
                    rawText: rawText,
                    cleanedText: cleanedText
                )

                var updated = record
                updated.rawText = rawText
                updated.cleanedText = cleanedText
                updated.transcriptionStatus = .success
                updated.whisperModel = retranscribeModel
                var history = updated.retranscriptionHistory ?? []
                history.append(entry)
                updated.retranscriptionHistory = history
                historyStore.updateRecord(updated)

                await MainActor.run {
                    retranscribeProgress = .done(cleanedText ?? rawText)
                }
            } catch {
                await MainActor.run {
                    retranscribeProgress = .failed("Re-transcription failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
