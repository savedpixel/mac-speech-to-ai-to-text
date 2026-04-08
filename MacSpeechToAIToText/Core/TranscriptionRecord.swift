import Foundation

enum TranscriptionStatus: Codable, Hashable {
    case success
    case failed(String)
    case pending
}

struct RetranscriptionEntry: Codable, Hashable {
    let date: Date
    let model: String
    let prompt: String?
    let rawText: String
    let cleanedText: String?
}

struct TranscriptionRecord: Codable, Identifiable, Hashable {
    let id: UUID
    let date: Date
    var rawText: String
    var cleanedText: String?
    var promptUsed: String?
    var audioFileName: String?
    var folderID: UUID?
    var isArchived: Bool
    var transcriptionStatus: TranscriptionStatus
    var whisperModel: String?
    var retranscriptionHistory: [RetranscriptionEntry]?
    var cleanupFailed: Bool
    var cleanupFailureReason: String?

    init(
        id: UUID = UUID(),
        date: Date = .now,
        rawText: String,
        cleanedText: String? = nil,
        promptUsed: String? = nil,
        audioFileName: String? = nil,
        folderID: UUID? = nil,
        isArchived: Bool = false,
        transcriptionStatus: TranscriptionStatus = .success,
        whisperModel: String? = nil,
        retranscriptionHistory: [RetranscriptionEntry]? = nil,
        cleanupFailed: Bool = false,
        cleanupFailureReason: String? = nil
    ) {
        self.id = id
        self.date = date
        self.rawText = rawText
        self.cleanedText = cleanedText
        self.promptUsed = promptUsed
        self.audioFileName = audioFileName
        self.folderID = folderID
        self.isArchived = isArchived
        self.transcriptionStatus = transcriptionStatus
        self.whisperModel = whisperModel
        self.retranscriptionHistory = retranscriptionHistory
        self.cleanupFailed = cleanupFailed
        self.cleanupFailureReason = cleanupFailureReason
    }

    // Backward-compatible decoding — new fields default gracefully
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        rawText = try container.decode(String.self, forKey: .rawText)
        cleanedText = try container.decodeIfPresent(String.self, forKey: .cleanedText)
        promptUsed = try container.decodeIfPresent(String.self, forKey: .promptUsed)
        audioFileName = try container.decodeIfPresent(String.self, forKey: .audioFileName)
        folderID = try container.decodeIfPresent(UUID.self, forKey: .folderID)
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        transcriptionStatus = try container.decodeIfPresent(TranscriptionStatus.self, forKey: .transcriptionStatus) ?? .success
        whisperModel = try container.decodeIfPresent(String.self, forKey: .whisperModel)
        retranscriptionHistory = try container.decodeIfPresent([RetranscriptionEntry].self, forKey: .retranscriptionHistory)
        cleanupFailed = try container.decodeIfPresent(Bool.self, forKey: .cleanupFailed) ?? false
        cleanupFailureReason = try container.decodeIfPresent(String.self, forKey: .cleanupFailureReason)
    }
}
