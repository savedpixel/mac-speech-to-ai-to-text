import Foundation
import Testing

@testable import MacSpeechToAIToText

// MARK: - KeychainHelper Tests

@Suite("KeychainHelper Tests")
struct KeychainHelperTests {
    @Test("Save and read cycle")
    func saveReadCycle() {
        let key = "test_key_\(UUID().uuidString)"
        defer { _ = KeychainHelper.delete(key: key) }

        let saved = KeychainHelper.save(key: key, value: "test_value")
        #expect(saved)

        let read = KeychainHelper.read(key: key)
        #expect(read == "test_value")
    }

    @Test("Overwrite existing key")
    func overwriteExistingKey() {
        let key = "test_overwrite_\(UUID().uuidString)"
        defer { _ = KeychainHelper.delete(key: key) }

        _ = KeychainHelper.save(key: key, value: "first")
        _ = KeychainHelper.save(key: key, value: "second")

        let read = KeychainHelper.read(key: key)
        #expect(read == "second")
    }

    @Test("Read nonexistent key returns nil")
    func readNonexistent() {
        let read = KeychainHelper.read(key: "nonexistent_key_\(UUID().uuidString)")
        #expect(read == nil)
    }

    @Test("Delete key")
    func deleteKey() {
        let key = "test_delete_\(UUID().uuidString)"
        _ = KeychainHelper.save(key: key, value: "value")
        let deleted = KeychainHelper.delete(key: key)
        #expect(deleted)
        #expect(KeychainHelper.read(key: key) == nil)
    }
}

// MARK: - CleanupPrompt Tests

@Suite("CleanupPrompt Tests")
struct CleanupPromptTests {
    @Test("Codable roundtrip")
    func codableRoundtrip() throws {
        let prompt = CleanupPrompt(
            id: UUID(),
            name: "Test",
            systemPrompt: "Clean text",
            isBuiltIn: false
        )
        let data = try JSONEncoder().encode(prompt)
        let decoded = try JSONDecoder().decode(CleanupPrompt.self, from: data)
        #expect(decoded.id == prompt.id)
        #expect(decoded.name == prompt.name)
        #expect(decoded.systemPrompt == prompt.systemPrompt)
        #expect(decoded.isBuiltIn == prompt.isBuiltIn)
    }

    @Test("Static default has correct fields")
    func staticDefault() {
        let d = CleanupPrompt.default
        #expect(d.isBuiltIn == true)
        #expect(d.name == "Default Cleanup")
        #expect(!d.systemPrompt.isEmpty)
    }
}

// MARK: - TranscriptionRecord Tests

@Suite("TranscriptionRecord Tests")
struct TranscriptionRecordTests {
    @Test("Codable roundtrip with nil optional fields")
    func codableRoundtripNils() throws {
        let record = TranscriptionRecord(rawText: "Hello world")
        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(TranscriptionRecord.self, from: data)
        #expect(decoded.id == record.id)
        #expect(decoded.rawText == "Hello world")
        #expect(decoded.cleanedText == nil)
        #expect(decoded.promptUsed == nil)
        #expect(decoded.audioFileName == nil)
        #expect(decoded.folderID == nil)
        #expect(decoded.isArchived == false)
    }

    @Test("Codable roundtrip with all fields populated")
    func codableRoundtripFull() throws {
        let folderID = UUID()
        let record = TranscriptionRecord(
            rawText: "raw",
            cleanedText: "cleaned",
            promptUsed: "Default",
            audioFileName: "test.wav",
            folderID: folderID,
            isArchived: true
        )
        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(TranscriptionRecord.self, from: data)
        #expect(decoded.cleanedText == "cleaned")
        #expect(decoded.folderID == folderID)
        #expect(decoded.isArchived == true)
    }

    @Test("Backward-compatible decode from old JSON without new fields")
    func backwardCompatDecode() throws {
        // Simulate old JSON without transcriptionStatus, whisperModel, retranscriptionHistory
        let oldJSON = """
        {"id":"00000000-0000-0000-0000-000000000099","date":0,"rawText":"old record","isArchived":false}
        """
        let data = oldJSON.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(TranscriptionRecord.self, from: data)
        #expect(decoded.rawText == "old record")
        #expect(decoded.whisperModel == nil)
        #expect(decoded.retranscriptionHistory == nil)
        if case .success = decoded.transcriptionStatus {
            // expected
        } else {
            Issue.record("Expected .success status for old records")
        }
    }

    @Test("Codable roundtrip with new fields")
    func codableRoundtripNewFields() throws {
        let record = TranscriptionRecord(
            rawText: "test",
            transcriptionStatus: .failed("Model not loaded"),
            whisperModel: "tiny",
            retranscriptionHistory: [
                RetranscriptionEntry(date: .now, model: "base", prompt: nil, rawText: "retried", cleanedText: nil)
            ]
        )
        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(TranscriptionRecord.self, from: data)
        if case .failed(let msg) = decoded.transcriptionStatus {
            #expect(msg == "Model not loaded")
        } else {
            Issue.record("Expected .failed status")
        }
        #expect(decoded.whisperModel == "tiny")
        #expect(decoded.retranscriptionHistory?.count == 1)
    }
}

// MARK: - HistoryFolder Tests

@Suite("HistoryFolder Tests")
struct HistoryFolderTests {
    @Test("Codable roundtrip")
    func codableRoundtrip() throws {
        let folder = HistoryFolder(name: "Work", colorName: "blue")
        let data = try JSONEncoder().encode(folder)
        let decoded = try JSONDecoder().decode(HistoryFolder.self, from: data)
        #expect(decoded.id == folder.id)
        #expect(decoded.name == "Work")
        #expect(decoded.colorName == "blue")
    }

    @Test("Creation with defaults")
    func creationDefaults() {
        let folder = HistoryFolder(name: "Test")
        #expect(folder.colorName == nil)
        #expect(!folder.id.uuidString.isEmpty)
    }
}

// MARK: - PipelineState Tests

@Suite("PipelineState Tests")
struct PipelineStateTests {
    @Test("New transitions are valid")
    func newTransitions() {
        #expect(PipelineState.transcribing.canTransition(to: .cleaning) == true)
        #expect(PipelineState.cleaning.canTransition(to: .completed(
            TranscriptionResult(rawText: "t", cleanedText: "c", cleanupFailed: false)
        )) == true)
        #expect(PipelineState.transcribing.canTransition(to: .completed(
            TranscriptionResult(rawText: "t", cleanedText: nil, cleanupFailed: false)
        )) == true)
        let result = TranscriptionResult(rawText: "t", cleanedText: nil, cleanupFailed: false)
        #expect(PipelineState.completed(result).canTransition(to: .idle) == true)
    }

    @Test("Old .inserting transitions removed")
    func noInsertingState() {
        // .inserting no longer exists as a state
        // Verify that transcribing can't go directly to states that only .inserting used to reach
        // (transcribing → idle was never valid without going through .inserting first;
        // now it's valid via cancellation, but transcribing → recording is still invalid)
        #expect(PipelineState.transcribing.canTransition(to: .recording) == false)
        #expect(PipelineState.transcribing.canTransition(to: .preparingToRecord) == false)
    }

    @Test("Completed equality")
    func completedEquality() {
        let r1 = TranscriptionResult(rawText: "a", cleanedText: "b", cleanupFailed: false)
        let r2 = TranscriptionResult(rawText: "a", cleanedText: "b", cleanupFailed: false)
        let r3 = TranscriptionResult(rawText: "x", cleanedText: nil, cleanupFailed: true)
        #expect(PipelineState.completed(r1) == PipelineState.completed(r2))
        #expect(PipelineState.completed(r1) != PipelineState.completed(r3))
    }

    @Test("Cleaning state transitions")
    func cleaningTransitions() {
        #expect(PipelineState.cleaning.canTransition(to: .error("fail")) == true)
        #expect(PipelineState.cleaning.canTransition(to: .idle) == true) // cancellation
        #expect(PipelineState.cleaning.canTransition(to: .recording) == false)
        #expect(PipelineState.cleaning.isActive == true)
    }

    @Test("Completed state is not active")
    func completedNotActive() {
        let result = TranscriptionResult(rawText: "t", cleanedText: nil, cleanupFailed: false)
        #expect(PipelineState.completed(result).isActive == false)
    }

    @Test("Display names for new states")
    func displayNames() {
        #expect(PipelineState.cleaning.displayName == "Cleaning up…")
        let result = TranscriptionResult(rawText: "t", cleanedText: nil, cleanupFailed: false)
        #expect(PipelineState.completed(result).displayName == "Complete")
    }
}

// MARK: - PromptStore Tests

@Suite("PromptStore Tests")
struct PromptStoreTests {
    @Test("Seeds default prompt on init")
    func seedsDefault() {
        let store = PromptStore()
        #expect(!store.prompts.isEmpty)
        #expect(store.prompts.contains(where: { $0.isBuiltIn }))
    }

    @Test("CRUD operations")
    func crudOperations() {
        let store = PromptStore()
        let initialCount = store.prompts.count

        // Add
        let newPrompt = CleanupPrompt(id: UUID(), name: "Custom", systemPrompt: "Clean", isBuiltIn: false)
        store.add(newPrompt)
        #expect(store.prompts.count == initialCount + 1)

        // Update
        var updated = newPrompt
        updated.name = "Updated"
        store.update(updated)
        #expect(store.prompts.first(where: { $0.id == newPrompt.id })?.name == "Updated")

        // Delete
        store.delete(id: newPrompt.id)
        #expect(store.prompts.count == initialCount)
    }

    @Test("Cannot delete built-in prompt")
    func cannotDeleteBuiltIn() {
        let store = PromptStore()
        let builtIn = store.prompts.first(where: { $0.isBuiltIn })!
        store.delete(id: builtIn.id)
        #expect(store.prompts.contains(where: { $0.id == builtIn.id }))
    }

    @Test("Selected prompt ID defaults to built-in")
    func selectedPromptDefault() {
        let store = PromptStore()
        #expect(store.selectedPromptID == CleanupPrompt.default.id)
    }
}

// MARK: - HistoryStore Tests

@Suite("HistoryStore Tests")
struct HistoryStoreTests {
    @Test("Add and list records")
    func addAndList() {
        let store = HistoryStore()
        let initialCount = store.records.count
        store.addRecord(TranscriptionRecord(rawText: "test"))
        #expect(store.records.count == initialCount + 1)
        // Clean up
        if let id = store.records.first?.id {
            store.deleteRecords([id])
        }
    }

    @Test("Delete records")
    func deleteRecords() {
        let store = HistoryStore()
        let record = TranscriptionRecord(rawText: "to delete")
        store.addRecord(record)
        store.deleteRecords([record.id])
        #expect(!store.records.contains(where: { $0.id == record.id }))
    }

    @Test("Folder CRUD")
    func folderCRUD() {
        let store = HistoryStore()
        let folder = store.createFolder(name: "Test Folder")
        #expect(store.folders.contains(where: { $0.id == folder.id }))

        store.renameFolder(id: folder.id, name: "Renamed")
        #expect(store.folders.first(where: { $0.id == folder.id })?.name == "Renamed")

        store.deleteFolder(id: folder.id)
        #expect(!store.folders.contains(where: { $0.id == folder.id }))
    }

    @Test("Move to folder")
    func moveToFolder() {
        let store = HistoryStore()
        let folder = store.createFolder(name: "Folder")
        let record = TranscriptionRecord(rawText: "moveable")
        store.addRecord(record)

        store.moveRecords([record.id], toFolder: folder.id)
        let moved = store.records.first(where: { $0.id == record.id })
        #expect(moved?.folderID == folder.id)

        // Clean up
        store.deleteRecords([record.id])
        store.deleteFolder(id: folder.id)
    }

    @Test("Archive and unarchive")
    func archiveUnarchive() {
        let store = HistoryStore()
        let record = TranscriptionRecord(rawText: "archivable")
        store.addRecord(record)

        store.archiveRecords([record.id])
        #expect(store.archivedRecords.contains(where: { $0.id == record.id }))
        #expect(!store.unarchivedRecords.contains(where: { $0.id == record.id }))

        store.unarchiveRecords([record.id])
        #expect(!store.archivedRecords.contains(where: { $0.id == record.id }))
        #expect(store.unarchivedRecords.contains(where: { $0.id == record.id }))

        store.deleteRecords([record.id])
    }

    @Test("Filtered views: unfiled records")
    func unfiledRecords() {
        let store = HistoryStore()
        let record = TranscriptionRecord(rawText: "unfiled")
        store.addRecord(record)
        #expect(store.unfiledRecords.contains(where: { $0.id == record.id }))
        store.deleteRecords([record.id])
    }

    @Test("Filtered views: records in folder")
    func recordsInFolder() {
        let store = HistoryStore()
        let folder = store.createFolder(name: "F")
        let record = TranscriptionRecord(rawText: "in folder")
        store.addRecord(record)
        store.moveRecords([record.id], toFolder: folder.id)
        #expect(store.records(inFolder: folder.id).contains(where: { $0.id == record.id }))
        store.deleteRecords([record.id])
        store.deleteFolder(id: folder.id)
    }

    @Test("Batch delete")
    func batchDelete() {
        let store = HistoryStore()
        let r1 = TranscriptionRecord(rawText: "one")
        let r2 = TranscriptionRecord(rawText: "two")
        store.addRecord(r1)
        store.addRecord(r2)
        store.deleteRecords([r1.id, r2.id])
        #expect(!store.records.contains(where: { $0.id == r1.id }))
        #expect(!store.records.contains(where: { $0.id == r2.id }))
    }

    @Test("Prune old recordings by age")
    func pruneOldRecordings() {
        let store = HistoryStore()

        // Add a record dated 30 days ago
        let oldRecord = TranscriptionRecord(
            date: Calendar.current.date(byAdding: .day, value: -30, to: .now)!,
            rawText: "old record"
        )
        store.addRecord(oldRecord)

        // Add a recent record
        let newRecord = TranscriptionRecord(rawText: "new record")
        store.addRecord(newRecord)

        // Prune records older than 7 days
        store.pruneOldRecordings(olderThanDays: 7)

        #expect(!store.records.contains(where: { $0.id == oldRecord.id }))
        #expect(store.records.contains(where: { $0.id == newRecord.id }))

        // Clean up
        store.deleteRecords([newRecord.id])
    }

    @Test("Delete folder moves records to unfiled")
    func deleteFolderMovesRecords() {
        let store = HistoryStore()
        let folder = store.createFolder(name: "ToDelete")
        let record = TranscriptionRecord(rawText: "in folder")
        store.addRecord(record)
        store.moveRecords([record.id], toFolder: folder.id)

        store.deleteFolder(id: folder.id)
        let updated = store.records.first(where: { $0.id == record.id })
        #expect(updated?.folderID == nil)

        store.deleteRecords([record.id])
    }
}

// MARK: - TranscriptionResult Tests

@Suite("TranscriptionResult Tests")
struct TranscriptionResultTests {
    @Test("Display text uses cleaned when available")
    func displayTextCleaned() {
        let r = TranscriptionResult(rawText: "raw", cleanedText: "cleaned", cleanupFailed: false)
        #expect(r.displayText == "cleaned")
    }

    @Test("Display text falls back to raw")
    func displayTextFallback() {
        let r = TranscriptionResult(rawText: "raw", cleanedText: nil, cleanupFailed: true)
        #expect(r.displayText == "raw")
    }
}

// MARK: - AIProvider Tests

@Suite("AIProvider Tests")
struct AIProviderTests {
    @Test("All non-custom providers have models")
    func allProvidersHaveModels() {
        for provider in AIProvider.allCases where provider != .custom {
            #expect(!provider.models.isEmpty, "Provider \(provider.displayName) has no models")
        }
    }

    @Test("Custom provider has empty models")
    func customProviderHasEmptyModels() {
        #expect(AIProvider.custom.models.isEmpty)
    }

    @Test("All providers have display names")
    func allProvidersHaveDisplayNames() {
        for provider in AIProvider.allCases {
            #expect(!provider.displayName.isEmpty)
        }
    }

    @Test("Non-custom providers have valid endpoint URLs")
    func endpointURLsValid() {
        for provider in AIProvider.allCases where provider != .custom {
            let url = provider.fullEndpointURL
            #expect(url.hasPrefix("https://"), "Provider \(provider.displayName) URL doesn't start with https")
            #expect(url.contains("/"), "Provider \(provider.displayName) URL has no path")
            #expect(URL(string: url) != nil, "Provider \(provider.displayName) has invalid URL")
        }
    }

    @Test("Custom provider has empty URL components")
    func customProviderEmptyURL() {
        #expect(AIProvider.custom.baseURL.isEmpty)
        #expect(AIProvider.custom.endpointPath.isEmpty)
        #expect(AIProvider.custom.fullEndpointURL.isEmpty)
    }

    @Test("fromEndpointURL matches known providers")
    func fromEndpointURLMatches() {
        #expect(AIProvider.fromEndpointURL("https://api.openai.com/v1/chat/completions") == .openai)
        #expect(AIProvider.fromEndpointURL("https://api.groq.com/openai/v1/chat/completions") == .groq)
        #expect(AIProvider.fromEndpointURL("https://api.mistral.ai/v1/chat/completions") == .mistral)
        #expect(AIProvider.fromEndpointURL("https://api.deepseek.com/chat/completions") == .deepseek)
        #expect(AIProvider.fromEndpointURL("https://api.x.ai/v1/chat/completions") == .xai)
    }

    @Test("fromEndpointURL returns nil for unknown")
    func fromEndpointURLUnknown() {
        #expect(AIProvider.fromEndpointURL("https://example.com/api") == nil)
        #expect(AIProvider.fromEndpointURL("") == nil)
    }

    @Test("All model IDs are non-empty")
    func allModelIDsNonEmpty() {
        for provider in AIProvider.allCases {
            for model in provider.models {
                #expect(!model.id.isEmpty, "\(provider.displayName) has model with empty id")
                #expect(!model.displayName.isEmpty, "\(provider.displayName) has model with empty displayName")
            }
        }
    }

    @Test("OpenAI has expected models")
    func openaiModels() {
        let ids = AIProvider.openai.models.map(\.id)
        #expect(ids.contains("gpt-4o"))
        #expect(ids.contains("gpt-4o-mini"))
    }
}

// MARK: - Settings Provider Config Tests

@Suite("Settings Provider Config Tests")
struct SettingsProviderTests {
    @Test("Resolved endpoint for known provider")
    func resolvedEndpointKnown() {
        let s = Settings()
        s.aiCleanupProvider = .groq
        #expect(s.resolvedEndpoint == AIProvider.groq.fullEndpointURL)
    }

    @Test("Resolved endpoint for custom provider")
    func resolvedEndpointCustom() {
        let s = Settings()
        s.aiCleanupProvider = .custom
        s.aiCleanupCustomEndpoint = "https://my-server.com/v1/chat"
        #expect(s.resolvedEndpoint == "https://my-server.com/v1/chat")
    }

    @Test("Resolved model for known provider")
    func resolvedModelKnown() {
        let s = Settings()
        s.aiCleanupProvider = .mistral
        s.aiCleanupModelID = "mistral-large-latest"
        #expect(s.resolvedModel == "mistral-large-latest")
    }

    @Test("Resolved model for custom provider")
    func resolvedModelCustom() {
        let s = Settings()
        s.aiCleanupProvider = .custom
        s.aiCleanupCustomModel = "my-model"
        #expect(s.resolvedModel == "my-model")
    }

    @Test("sendPhraseEnabled defaults to true")
    func sendPhraseEnabledDefault() {
        let s = Settings()
        #expect(s.sendPhraseEnabled == true)
    }
}
