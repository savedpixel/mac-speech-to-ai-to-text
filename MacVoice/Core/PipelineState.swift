import Foundation

struct TranscriptionResult: Equatable {
    let rawText: String
    let cleanedText: String?
    let cleanupFailed: Bool
    let cleanupFailureReason: String?

    init(rawText: String, cleanedText: String?, cleanupFailed: Bool, cleanupFailureReason: String? = nil) {
        self.rawText = rawText
        self.cleanedText = cleanedText
        self.cleanupFailed = cleanupFailed
        self.cleanupFailureReason = cleanupFailureReason
    }

    var displayText: String {
        cleanedText ?? rawText
    }
}

enum PipelineState: Equatable {
    case idle
    case preparingToRecord
    case recording
    case transcribing
    case cleaning
    case completed(TranscriptionResult)
    case error(String)

    static func == (lhs: PipelineState, rhs: PipelineState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.preparingToRecord, .preparingToRecord),
             (.recording, .recording),
             (.transcribing, .transcribing),
             (.cleaning, .cleaning):
            return true
        case (.completed(let a), .completed(let b)):
            return a == b
        case (.error(let a), .error(let b)):
            return a == b
        default:
            return false
        }
    }

    var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .preparingToRecord: return "Preparing…"
        case .recording: return "Recording"
        case .transcribing: return "Transcribing…"
        case .cleaning: return "Cleaning up…"
        case .completed: return "Complete"
        case .error(let message): return "Error: \(message)"
        }
    }

    var isActive: Bool {
        switch self {
        case .idle, .error, .completed: return false
        default: return true
        }
    }

    /// Valid next states from current state
    func canTransition(to next: PipelineState) -> Bool {
        switch (self, next) {
        case (.idle, .preparingToRecord): return true
        case (.preparingToRecord, .recording): return true
        case (.preparingToRecord, .error): return true
        case (.recording, .transcribing): return true
        case (.recording, .error): return true
        case (.transcribing, .cleaning): return true
        case (.transcribing, .completed): return true
        case (.transcribing, .error): return true
        case (.cleaning, .completed): return true
        case (.cleaning, .error): return true
        case (.completed, .idle): return true
        case (.error, .idle): return true
        // Allow cancellation from any active state
        case (_, .idle) where self.isActive: return true
        default: return false
        }
    }
}
