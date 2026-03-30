import Foundation
import os

@Observable
final class HistoryStore {
    private let logger = Logger(subsystem: "com.macvoice.app", category: "core")
    private let baseDir: URL
    private let historyURL: URL
    private let foldersURL: URL
    private let recordingsDir: URL

    private(set) var records: [TranscriptionRecord] = []
    private(set) var folders: [HistoryFolder] = []

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("MacVoice", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        self.baseDir = dir
        self.historyURL = dir.appendingPathComponent("history.json")
        self.foldersURL = dir.appendingPathComponent("folders.json")
        self.recordingsDir = dir.appendingPathComponent("recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: recordingsDir, withIntermediateDirectories: true)

        loadRecords()
        loadFolders()
    }

    // MARK: - Filtered Views

    var unfiledRecords: [TranscriptionRecord] {
        records.filter { $0.folderID == nil && !$0.isArchived }
    }

    var archivedRecords: [TranscriptionRecord] {
        records.filter { $0.isArchived }
    }

    var unarchivedRecords: [TranscriptionRecord] {
        records.filter { !$0.isArchived }
    }

    var failedRecords: [TranscriptionRecord] {
        records.filter { if case .failed = $0.transcriptionStatus { return true }; return false }
    }

    func records(inFolder folderID: UUID) -> [TranscriptionRecord] {
        records.filter { $0.folderID == folderID && !$0.isArchived }
    }

    // MARK: - Record CRUD

    func addRecord(_ record: TranscriptionRecord) {
        records.insert(record, at: 0)
        saveRecords()
    }

    func updateRecord(_ record: TranscriptionRecord) {
        guard let index = records.firstIndex(where: { $0.id == record.id }) else { return }
        records[index] = record
        saveRecords()
    }

    func deleteRecords(_ ids: Set<UUID>) {
        let toDelete = records.filter { ids.contains($0.id) }
        for record in toDelete {
            if let fileName = record.audioFileName {
                let audioURL = recordingsDir.appendingPathComponent(fileName)
                try? FileManager.default.removeItem(at: audioURL)
            }
        }
        records.removeAll(where: { ids.contains($0.id) })
        saveRecords()
    }

    // MARK: - Folder Operations

    func moveRecords(_ ids: Set<UUID>, toFolder folderID: UUID?) {
        for i in records.indices {
            if ids.contains(records[i].id) {
                records[i].folderID = folderID
            }
        }
        saveRecords()
    }

    func archiveRecords(_ ids: Set<UUID>) {
        for i in records.indices {
            if ids.contains(records[i].id) {
                records[i].isArchived = true
            }
        }
        saveRecords()
    }

    func unarchiveRecords(_ ids: Set<UUID>) {
        for i in records.indices {
            if ids.contains(records[i].id) {
                records[i].isArchived = false
            }
        }
        saveRecords()
    }

    // MARK: - Folder CRUD

    func createFolder(name: String) -> HistoryFolder {
        let folder = HistoryFolder(name: name)
        folders.append(folder)
        saveFolders()
        return folder
    }

    func renameFolder(id: UUID, name: String) {
        guard let index = folders.firstIndex(where: { $0.id == id }) else { return }
        folders[index].name = name
        saveFolders()
    }

    func deleteFolder(id: UUID) {
        // Move records in this folder to unfiled
        for i in records.indices {
            if records[i].folderID == id {
                records[i].folderID = nil
            }
        }
        folders.removeAll(where: { $0.id == id })
        saveFolders()
        saveRecords()
    }

    // MARK: - Audio File Management

    func copyAudioFile(from sourceURL: URL) -> String? {
        let fileName = "\(UUID().uuidString).wav"
        let destURL = recordingsDir.appendingPathComponent(fileName)
        do {
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
            return fileName
        } catch {
            logger.error("Failed to copy audio file: \(error.localizedDescription)")
            return nil
        }
    }

    /// URL for a recording's audio file, or nil if missing.
    func audioFileURL(for record: TranscriptionRecord) -> URL? {
        guard let fileName = record.audioFileName else { return nil }
        let url = recordingsDir.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Delete records (and audio) older than the given number of days. 0 = never.
    func pruneOldRecordings(olderThanDays days: Int) {
        guard days > 0 else { return }
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .distantPast
        let old = records.filter { $0.date < cutoff }
        guard !old.isEmpty else { return }

        for record in old {
            if let fileName = record.audioFileName {
                let audioURL = recordingsDir.appendingPathComponent(fileName)
                try? FileManager.default.removeItem(at: audioURL)
            }
        }
        let oldIDs = Set(old.map(\.id))
        records.removeAll(where: { oldIDs.contains($0.id) })
        saveRecords()
        logger.info("Pruned \(old.count) old recordings")
    }

    // MARK: - Persistence

    private func loadRecords() {
        guard FileManager.default.fileExists(atPath: historyURL.path) else { return }
        do {
            let data = try Data(contentsOf: historyURL)
            records = try JSONDecoder().decode([TranscriptionRecord].self, from: data)
        } catch {
            logger.error("Failed to load history: \(error.localizedDescription)")
            records = []
        }
    }

    private func saveRecords() {
        do {
            let data = try JSONEncoder().encode(records)
            try data.write(to: historyURL, options: .atomic)
        } catch {
            logger.error("Failed to save history: \(error.localizedDescription)")
        }
    }

    private func loadFolders() {
        guard FileManager.default.fileExists(atPath: foldersURL.path) else { return }
        do {
            let data = try Data(contentsOf: foldersURL)
            folders = try JSONDecoder().decode([HistoryFolder].self, from: data)
        } catch {
            logger.error("Failed to load folders: \(error.localizedDescription)")
            folders = []
        }
    }

    private func saveFolders() {
        do {
            let data = try JSONEncoder().encode(folders)
            try data.write(to: foldersURL, options: .atomic)
        } catch {
            logger.error("Failed to save folders: \(error.localizedDescription)")
        }
    }
}
