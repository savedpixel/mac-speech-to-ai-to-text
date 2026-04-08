import Foundation
import os

actor TranscriptionCleaner {
    private let logger = Logger(subsystem: "com.macvoice.app", category: "transcription")
    private let settings: Settings
    private let promptStore: PromptStore

    enum CleanerError: Error, LocalizedError {
        case disabled
        case noAPIKey
        case networkError(Error)
        case invalidResponse
        case timeout

        var errorDescription: String? {
            switch self {
            case .disabled: return "AI cleanup is disabled"
            case .noAPIKey: return "No API key configured"
            case .networkError(let error): return "Network error: \(error.localizedDescription)"
            case .invalidResponse: return "Invalid API response"
            case .timeout: return "API request timed out"
            }
        }
    }

    init(settings: Settings, promptStore: PromptStore) {
        self.settings = settings
        self.promptStore = promptStore
    }

    func clean(_ text: String, promptID: UUID? = nil) async throws -> String {
        guard settings.aiCleanupEnabled else { throw CleanerError.disabled }

        let apiKey = settings.aiCleanupAPIKey
        guard !apiKey.isEmpty else { throw CleanerError.noAPIKey }

        let endpoint = settings.resolvedEndpoint
        let model = settings.resolvedModel

        // Use override prompt if provided; fall back to selected prompt
        let resolvedPrompt: CleanupPrompt
        if let promptID, let found = promptStore.prompts.first(where: { $0.id == promptID }) {
            resolvedPrompt = found
        } else {
            resolvedPrompt = promptStore.selectedPrompt
        }
        let systemPrompt = resolvedPrompt.systemPrompt

        guard let url = URL(string: endpoint) else { throw CleanerError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text],
            ],
            "temperature": 0.3,
            "max_tokens": 2048,
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw CleanerError.timeout
        } catch {
            throw CleanerError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            logger.error("API returned non-success status")
            throw CleanerError.invalidResponse
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw CleanerError.invalidResponse
        }

        let cleaned = content.trimmingCharacters(in: .whitespacesAndNewlines)
        logger.info("AI cleanup complete: \(text.count) → \(cleaned.count) chars")
        return cleaned
    }

    func testAPIKey() async -> Result<String, CleanerError> {
        let apiKey = settings.aiCleanupAPIKey
        guard !apiKey.isEmpty else { return .failure(.noAPIKey) }

        let endpoint = settings.resolvedEndpoint
        let model = settings.resolvedModel

        guard !endpoint.isEmpty, let url = URL(string: endpoint) else {
            return .failure(.invalidResponse)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": "Hi"],
            ],
            "max_tokens": 5,
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            return .failure(.networkError(error))
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            return .failure(.timeout)
        } catch {
            return .failure(.networkError(error))
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            return .failure(.invalidResponse)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            return .failure(.invalidResponse)
        }

        let preview = String(content.prefix(50)).trimmingCharacters(in: .whitespacesAndNewlines)
        return .success(preview)
    }
}
