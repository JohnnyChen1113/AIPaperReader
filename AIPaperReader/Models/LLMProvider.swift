//
//  LLMProvider.swift
//  AIPaperReader
//
//  Created by Claude on 2/4/26.
//

import Foundation

enum LLMProvider: String, Codable, CaseIterable, Identifiable {
    case openaiCompatible = "OpenAI Compatible"
    case ollama = "Ollama"
    case siliconflow = "SiliconFlow"
    case deepseek = "DeepSeek"
    case bioInfoArk = "BioInfoArk"

    var id: String { rawValue }

    var defaultBaseURL: String {
        switch self {
        case .openaiCompatible:
            return "https://api.openai.com"
        case .ollama:
            return "http://localhost:11434"
        case .siliconflow:
            return "https://api.siliconflow.cn"
        case .deepseek:
            return "https://api.deepseek.com"
        case .bioInfoArk:
            return "https://oa.ai01.org/v1"
        }
    }

    var helpURL: String {
        switch self {
        case .openaiCompatible:
            return "https://platform.openai.com/api-keys"
        case .ollama:
            return "https://ollama.com"
        case .siliconflow:
            return "https://cloud.siliconflow.cn/account/ak"
        case .deepseek:
            return "https://platform.deepseek.com/api_keys"
        case .bioInfoArk:
            return "https://www.bioinfoark.com"
        }
    }

    var requiresAPIKey: Bool {
        switch self {
        case .ollama:
            return false
        default:
            return true
        }
    }

    var displayName: String {
        rawValue
    }

    /// 默认推荐的免费模型
    var defaultFreeModels: [String] {
        switch self {
        case .openaiCompatible:
            return ["gpt-4o-mini", "gpt-3.5-turbo"]
        case .ollama:
            return ["llama3.2", "qwen2.5", "mistral"]
        case .siliconflow:
            // 硅基流动免费/推荐模型
            return [
                "deepseek-ai/DeepSeek-V3",
                "Qwen/Qwen2.5-72B-Instruct",
                "THUDM/GLM-4-9B-0414",
                "Qwen/Qwen2.5-7B-Instruct",
                "Qwen/Qwen2.5-Coder-7B-Instruct"
            ]
        case .deepseek:
            return ["deepseek-chat", "deepseek-reasoner"]
        case .bioInfoArk:
            return ["gpt-4o", "gpt-4o-mini", "claude-3-5-sonnet-20240620", "gemini-1.5-pro"]
        }
    }
}

/// 模型信息
struct ModelInfo: Identifiable, Codable, Equatable {
    var id: String { modelId }
    let modelId: String
    let displayName: String
    let ownedBy: String?
    var isEnabled: Bool
    var isFree: Bool

    init(modelId: String, displayName: String? = nil, ownedBy: String? = nil, isEnabled: Bool = false, isFree: Bool = false) {
        self.modelId = modelId
        self.displayName = displayName ?? modelId.components(separatedBy: "/").last ?? modelId
        self.ownedBy = ownedBy
        self.isEnabled = isEnabled
        self.isFree = isFree
    }
}

struct LLMConfig: Codable, Equatable {
    var provider: LLMProvider
    var baseURL: String
    var apiKey: String
    var modelName: String
    var temperature: Double
    var maxTokens: Int
    var contextTokenBudget: Int
    var enabledModels: [String]  // 用户选择启用的模型列表

    init(
        provider: LLMProvider = .siliconflow,
        baseURL: String? = nil,
        apiKey: String = "",
        modelName: String = "deepseek-ai/DeepSeek-V3",
        temperature: Double = 0.7,
        maxTokens: Int = 4096,
        contextTokenBudget: Int = 16000,
        enabledModels: [String]? = nil
    ) {
        self.provider = provider
        self.baseURL = baseURL ?? provider.defaultBaseURL
        self.apiKey = apiKey
        self.modelName = modelName
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.contextTokenBudget = contextTokenBudget
        self.enabledModels = enabledModels ?? provider.defaultFreeModels
    }

    static var `default`: LLMConfig {
        LLMConfig()
    }
}

enum LLMError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case httpError(Int, String?)
    case decodingError(Error)
    case streamingError(String)
    case apiKeyMissing
    case connectionFailed
    case tokenLimitExceeded
    case cancelled

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .httpError(let code, let message):
            return "HTTP error \(code): \(message ?? "Unknown error")"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .streamingError(let message):
            return "Streaming error: \(message)"
        case .apiKeyMissing:
            return "API key is required"
        case .connectionFailed:
            return "Failed to connect to the server"
        case .tokenLimitExceeded:
            return "Token limit exceeded"
        case .cancelled:
            return "Request was cancelled"
        }
    }
}
