import Foundation

struct AIModel: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let displayName: String
}

enum AIProvider: String, CaseIterable, Identifiable, Codable {
    case openai
    case groq
    case mistral
    case deepseek
    case xai
    case togetherAI
    case fireworksAI
    case openRouter
    case perplexity
    case googleGemini
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openai: return "OpenAI"
        case .groq: return "Groq"
        case .mistral: return "Mistral"
        case .deepseek: return "DeepSeek"
        case .xai: return "xAI (Grok)"
        case .togetherAI: return "Together AI"
        case .fireworksAI: return "Fireworks AI"
        case .openRouter: return "OpenRouter"
        case .perplexity: return "Perplexity"
        case .googleGemini: return "Google Gemini"
        case .custom: return "Custom"
        }
    }

    var baseURL: String {
        switch self {
        case .openai: return "https://api.openai.com"
        case .groq: return "https://api.groq.com"
        case .mistral: return "https://api.mistral.ai"
        case .deepseek: return "https://api.deepseek.com"
        case .xai: return "https://api.x.ai"
        case .togetherAI: return "https://api.together.xyz"
        case .fireworksAI: return "https://api.fireworks.ai"
        case .openRouter: return "https://openrouter.ai"
        case .perplexity: return "https://api.perplexity.ai"
        case .googleGemini: return "https://generativelanguage.googleapis.com"
        case .custom: return ""
        }
    }

    var endpointPath: String {
        switch self {
        case .openai: return "/v1/chat/completions"
        case .groq: return "/openai/v1/chat/completions"
        case .mistral: return "/v1/chat/completions"
        case .deepseek: return "/chat/completions"
        case .xai: return "/v1/chat/completions"
        case .togetherAI: return "/v1/chat/completions"
        case .fireworksAI: return "/inference/v1/chat/completions"
        case .openRouter: return "/api/v1/chat/completions"
        case .perplexity: return "/v1/chat/completions"
        case .googleGemini: return "/v1beta/openai/chat/completions"
        case .custom: return ""
        }
    }

    var fullEndpointURL: String {
        baseURL + endpointPath
    }

    var models: [AIModel] {
        switch self {
        case .openai:
            return [
                AIModel(id: "gpt-4o", displayName: "GPT-4o"),
                AIModel(id: "gpt-4o-mini", displayName: "GPT-4o Mini"),
                AIModel(id: "gpt-4.1", displayName: "GPT-4.1"),
                AIModel(id: "gpt-4.1-mini", displayName: "GPT-4.1 Mini"),
                AIModel(id: "gpt-4.1-nano", displayName: "GPT-4.1 Nano"),
                AIModel(id: "o3-mini", displayName: "o3 Mini"),
                AIModel(id: "o4-mini", displayName: "o4 Mini"),
            ]
        case .groq:
            return [
                AIModel(id: "llama-3.3-70b-versatile", displayName: "Llama 3.3 70B"),
                AIModel(id: "llama-3.1-8b-instant", displayName: "Llama 3.1 8B"),
                AIModel(id: "qwen/qwen3-32b", displayName: "Qwen3 32B"),
            ]
        case .mistral:
            return [
                AIModel(id: "mistral-large-latest", displayName: "Mistral Large"),
                AIModel(id: "mistral-medium-latest", displayName: "Mistral Medium"),
                AIModel(id: "mistral-small-latest", displayName: "Mistral Small"),
                AIModel(id: "codestral-latest", displayName: "Codestral"),
            ]
        case .deepseek:
            return [
                AIModel(id: "deepseek-chat", displayName: "DeepSeek Chat"),
                AIModel(id: "deepseek-reasoner", displayName: "DeepSeek Reasoner"),
            ]
        case .xai:
            return [
                AIModel(id: "grok-4", displayName: "Grok 4"),
                AIModel(id: "grok-3", displayName: "Grok 3"),
                AIModel(id: "grok-3-mini", displayName: "Grok 3 Mini"),
            ]
        case .togetherAI:
            return [
                AIModel(id: "deepseek-ai/DeepSeek-V3.1", displayName: "DeepSeek V3.1"),
                AIModel(id: "meta-llama/Llama-3.3-70B-Instruct-Turbo", displayName: "Llama 3.3 70B Turbo"),
                AIModel(id: "Qwen/Qwen3-235B-A22B-Instruct-2507-tput", displayName: "Qwen3 235B"),
                AIModel(id: "mistralai/Mistral-Small-24B-Instruct-2501", displayName: "Mistral Small 24B"),
            ]
        case .fireworksAI:
            return [
                AIModel(id: "accounts/fireworks/models/deepseek-v3p1", displayName: "DeepSeek V3.1"),
                AIModel(id: "accounts/fireworks/models/llama-v3-70b-instruct", displayName: "Llama 3 70B"),
                AIModel(id: "accounts/fireworks/models/qwen2-72b-instruct", displayName: "Qwen2 72B"),
            ]
        case .openRouter:
            return [
                AIModel(id: "openai/gpt-4o", displayName: "GPT-4o"),
                AIModel(id: "anthropic/claude-sonnet-4-6", displayName: "Claude Sonnet 4.6"),
                AIModel(id: "google/gemini-2.5-flash", displayName: "Gemini 2.5 Flash"),
                AIModel(id: "deepseek/deepseek-chat", displayName: "DeepSeek Chat"),
                AIModel(id: "meta-llama/llama-3.3-70b-instruct", displayName: "Llama 3.3 70B"),
            ]
        case .perplexity:
            return [
                AIModel(id: "sonar", displayName: "Sonar"),
                AIModel(id: "sonar-pro", displayName: "Sonar Pro"),
                AIModel(id: "sonar-reasoning-pro", displayName: "Sonar Reasoning Pro"),
            ]
        case .googleGemini:
            return [
                AIModel(id: "gemini-2.5-pro", displayName: "Gemini 2.5 Pro"),
                AIModel(id: "gemini-2.5-flash", displayName: "Gemini 2.5 Flash"),
                AIModel(id: "gemini-2.5-flash-lite", displayName: "Gemini 2.5 Flash Lite"),
            ]
        case .custom:
            return []
        }
    }

    /// Attempt to identify a provider from a legacy endpoint URL string.
    static func fromEndpointURL(_ url: String) -> AIProvider? {
        let lowered = url.lowercased()
        for provider in AIProvider.allCases where provider != .custom {
            if lowered.contains(provider.baseURL.lowercased().replacingOccurrences(of: "https://", with: "")) {
                return provider
            }
        }
        return nil
    }
}
