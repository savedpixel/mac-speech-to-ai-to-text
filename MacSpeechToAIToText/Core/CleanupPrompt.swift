import Foundation

struct CleanupPrompt: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var systemPrompt: String
    let isBuiltIn: Bool

    static let `default` = CleanupPrompt(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "Default Cleanup",
        systemPrompt: """
        You are a transcription cleanup assistant. Clean up the following speech-to-text transcription:
        - Fix grammar and punctuation
        - Remove filler words (um, uh, like, you know, etc.)
        - Remove false starts and repetitions
        - Preserve the original meaning and intent
        - Keep the same tone and style
        - Do NOT add information that wasn't in the original
        - Return ONLY the cleaned text, no explanations
        """,
        isBuiltIn: true
    )
}
