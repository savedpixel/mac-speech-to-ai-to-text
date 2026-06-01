import Foundation
import os

actor TranscriptionCleaner {
    private static let urlSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        configuration.httpMaximumConnectionsPerHost = 4
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }()

    private let logger = Logger(subsystem: "com.macvoice.app", category: "transcription")
    private let settings: Settings
    private let promptStore: PromptStore

    enum CleanerError: Error, LocalizedError, Equatable {
        case disabled
        case noAPIKey
        case networkError(String)
        case apiError(statusCode: Int, message: String)
        case invalidResponse(String)
        case timeout

        var errorDescription: String? {
            switch self {
            case .disabled:
                return "AI cleanup is disabled"
            case .noAPIKey:
                return "No API key configured"
            case .networkError(let message):
                return "Network error: \(message)"
            case .apiError(let statusCode, let message):
                return "API error \(statusCode): \(message)"
            case .invalidResponse(let reason):
                return "Invalid API response: \(reason)"
            case .timeout:
                return "API request timed out"
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
        let provider = settings.aiCleanupProvider

        let resolvedPrompt: CleanupPrompt
        if let promptID, let found = promptStore.prompts.first(where: { $0.id == promptID }) {
            resolvedPrompt = found
        } else {
            resolvedPrompt = promptStore.selectedPrompt
        }

        let data = try await sendChatCompletion(
            endpoint: endpoint,
            apiKey: apiKey,
            provider: provider,
            model: model,
            messages: [
                ["role": "system", "content": resolvedPrompt.systemPrompt],
                ["role": "user", "content": text],
            ],
            maxTokens: Self.maxResponseTokens(forInputCharacterCount: text.count),
            purpose: "cleanup"
        )

        let cleaned = try Self.extractAssistantContent(from: data).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            throw CleanerError.invalidResponse("provider returned an empty assistant message")
        }

        logger.info("AI cleanup complete: \(text.count) → \(cleaned.count) chars")
        DiagnosticLogger.shared.write("ai-cleanup", "Cleanup complete provider=\(provider.displayName) model=\(model) inputChars=\(text.count) outputChars=\(cleaned.count)")
        return cleaned
    }

    func testAPIKey(apiKey overrideAPIKey: String? = nil) async -> Result<String, CleanerError> {
        let apiKey = (overrideAPIKey ?? settings.aiCleanupAPIKey).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else { return .failure(.noAPIKey) }

        do {
            let data = try await sendChatCompletion(
                endpoint: settings.resolvedEndpoint,
                apiKey: apiKey,
                provider: settings.aiCleanupProvider,
                model: settings.resolvedModel,
                messages: [["role": "user", "content": "Reply with OK only."]],
                maxTokens: 8,
                purpose: "test"
            )
            let content = try Self.extractAssistantContent(from: data)
            let preview = String(content.prefix(50)).trimmingCharacters(in: .whitespacesAndNewlines)
            return .success(preview.isEmpty ? "OK" : preview)
        } catch let error as CleanerError {
            return .failure(error)
        } catch {
            return .failure(.networkError(error.localizedDescription))
        }
    }

    private func sendChatCompletion(
        endpoint: String,
        apiKey: String,
        provider: AIProvider,
        model: String,
        messages: [[String: String]],
        maxTokens: Int,
        purpose: String
    ) async throws -> Data {
        guard !endpoint.isEmpty, let url = URL(string: endpoint), let scheme = url.scheme, scheme.hasPrefix("http") else {
            throw CleanerError.invalidResponse("invalid endpoint URL")
        }
        guard !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CleanerError.invalidResponse("missing model name")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 20

        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": 0.2,
            "max_tokens": maxTokens,
            "stream": false,
        ]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            throw CleanerError.invalidResponse("request body could not be encoded")
        }

        let started = Date()
        DiagnosticLogger.shared.write("ai-cleanup", "Request started purpose=\(purpose) provider=\(provider.displayName) model=\(model) maxTokens=\(maxTokens) endpointHost=\(url.host ?? "unknown")")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await Self.urlSession.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            DiagnosticLogger.shared.write("ai-cleanup", "Request timed out purpose=\(purpose) provider=\(provider.displayName) elapsedMs=\(Self.elapsedMilliseconds(since: started))")
            throw CleanerError.timeout
        } catch {
            DiagnosticLogger.shared.write("ai-cleanup", "Request network failure purpose=\(purpose) provider=\(provider.displayName) error=\(error.localizedDescription)")
            throw CleanerError.networkError(error.localizedDescription)
        }

        let elapsed = Self.elapsedMilliseconds(since: started)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CleanerError.invalidResponse("missing HTTP response")
        }

        DiagnosticLogger.shared.write("ai-cleanup", "Response received purpose=\(purpose) provider=\(provider.displayName) status=\(httpResponse.statusCode) bytes=\(data.count) elapsedMs=\(elapsed)")

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = Self.extractProviderErrorMessage(from: data) ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            logger.error("AI provider returned status \(httpResponse.statusCode, privacy: .public): \(message, privacy: .public)")
            throw CleanerError.apiError(statusCode: httpResponse.statusCode, message: message)
        }

        return data
    }

    static func extractAssistantContent(from data: Data) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CleanerError.invalidResponse("response was not JSON")
        }

        if let providerError = extractProviderErrorMessage(fromJSONObject: json) {
            throw CleanerError.invalidResponse(providerError)
        }

        guard let choices = json["choices"] as? [[String: Any]], !choices.isEmpty else {
            throw CleanerError.invalidResponse("response did not include choices")
        }

        for choice in choices {
            if let message = choice["message"] as? [String: Any],
               let content = extractTextContent(from: message["content"]) {
                return content
            }

            if let text = choice["text"] as? String {
                return text
            }

            if let delta = choice["delta"] as? [String: Any],
               let content = extractTextContent(from: delta["content"]) {
                return content
            }
        }

        throw CleanerError.invalidResponse("choices did not include assistant content")
    }

    static func extractProviderErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            let body = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return body?.isEmpty == false ? String(body!.prefix(240)) : nil
        }
        return extractProviderErrorMessage(fromJSONObject: json)
    }

    private static func extractProviderErrorMessage(fromJSONObject json: [String: Any]) -> String? {
        if let error = json["error"] as? [String: Any] {
            let message = (error["message"] as? String) ?? (error["error"] as? String) ?? "provider returned an error"
            let code = (error["code"] as? String) ?? (error["type"] as? String)
            if let code, !code.isEmpty {
                return "\(message) (\(code))"
            }
            return message
        }

        if let message = json["message"] as? String, !message.isEmpty {
            return message
        }

        return nil
    }

    private static func extractTextContent(from value: Any?) -> String? {
        if let string = value as? String {
            return string
        }

        if let parts = value as? [[String: Any]] {
            let text = parts.compactMap { part -> String? in
                if let text = part["text"] as? String { return text }
                if let text = part["content"] as? String { return text }
                return nil
            }.joined()
            return text.isEmpty ? nil : text
        }

        return nil
    }

    private static func maxResponseTokens(forInputCharacterCount characterCount: Int) -> Int {
        // Short cleanup/translation/extraction prompts do not need the old 2048-token ceiling.
        // Keep the cap high enough for longer translation-style prompts while cutting latency on common short dictations.
        let estimatedOutputTokens = Int(Double(characterCount) / 2.8) + 160
        return min(2048, max(384, estimatedOutputTokens))
    }

    private static func elapsedMilliseconds(since start: Date) -> Int {
        Int(Date().timeIntervalSince(start) * 1000)
    }
}
