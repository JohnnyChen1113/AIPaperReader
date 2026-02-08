//
//  LLMProvider.swift
//  AIPaperReader
//
//  Created by Claude on 2/4/26.
//

import Foundation
import SwiftUI

enum LLMProvider: String, Codable, CaseIterable, Identifiable {
    case openaiCompatible = "OpenAI Compatible"
    case ollama = "Ollama"
    case siliconflow = "SiliconFlow"
    case deepseek = "DeepSeek"
    case bioInfoArk = "BioInfoArk"
    case threeZeroTwo = "302.AI"

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
        case .threeZeroTwo:
            return "https://api.302.ai"
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
        case .threeZeroTwo:
            return "https://302.ai"
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

    /// 服务商图标
    var providerIcon: String {
        switch self {
        case .siliconflow: return "cpu"
        case .deepseek: return "brain.head.profile"
        case .openaiCompatible: return "globe"
        case .ollama: return "desktopcomputer"
        case .bioInfoArk: return "server.rack"
        case .threeZeroTwo: return "sparkle"
        }
    }

    /// 服务商品牌色
    var brandColor: Color {
        switch self {
        case .siliconflow: return .blue
        case .deepseek: return .indigo
        case .openaiCompatible: return .green
        case .ollama: return .gray
        case .bioInfoArk: return .purple
        case .threeZeroTwo: return .orange
        }
    }

    /// 服务商描述
    var providerDescription: String {
        switch self {
        case .siliconflow:
            return "国内服务，有免费额度，支持多种开源模型"
        case .deepseek:
            return "DeepSeek 官方 API，性价比高"
        case .openaiCompatible:
            return "OpenAI 或其他兼容 API"
        case .ollama:
            return "本地运行，完全免费，需要自行部署"
        case .bioInfoArk:
            return "国内直连，支持 GPT-5/Claude-4.5 等顶尖模型"
        case .threeZeroTwo:
            return "聚合平台，支持 800+ 模型，覆盖所有主流 AI"
        }
    }

    /// 默认推荐的模型（最新主流模型）
    var defaultFreeModels: [String] {
        switch self {
        case .openaiCompatible:
            return ["gpt-4o", "gpt-4o-mini", "gpt-4-turbo"]
        case .ollama:
            return ["llama3.2", "qwen2.5", "gemma2", "mistral"]
        case .siliconflow:
            return [
                "Pro/deepseek-ai/DeepSeek-V3.2",
                "Pro/deepseek-ai/DeepSeek-R1",
                "Pro/moonshotai/Kimi-K2.5",
                "Qwen/Qwen3-235B-A22B-Instruct-2507",
                "Pro/zai-org/GLM-4.7",
                "Pro/deepseek-ai/DeepSeek-V3"
            ]
        case .deepseek:
            return ["deepseek-chat", "deepseek-reasoner"]
        case .bioInfoArk:
            return [
                "gpt-5",
                "claude-sonnet-4-5",
                "gemini-2.5-pro",
                "grok-3",
                "o4-mini",
                "gpt-4.1"
            ]
        case .threeZeroTwo:
            return [
                "gpt-5.2",
                "claude-opus-4-6",
                "gemini-2.5-pro",
                "deepseek-v3.2",
                "grok-4.1",
                "qwen3-max"
            ]
        }
    }

    // MARK: - Embedding 配置

    /// 是否支持 Embedding API
    var supportsEmbedding: Bool {
        switch self {
        case .deepseek:
            return false
        default:
            return true
        }
    }

    /// 默认 Embedding API 基础 URL
    var defaultEmbeddingBaseURL: String {
        switch self {
        case .siliconflow:
            return "https://api.siliconflow.cn/v1"
        case .openaiCompatible:
            return "https://api.openai.com/v1"
        case .ollama:
            return "http://localhost:11434/v1"
        case .bioInfoArk:
            return "https://oa.ai01.org/v1"
        case .threeZeroTwo:
            return "https://api.302.ai/v1"
        case .deepseek:
            return ""
        }
    }

    /// 默认 Embedding 模型名称
    var defaultEmbeddingModel: String {
        switch self {
        case .siliconflow:
            return "BAAI/bge-m3"
        case .openaiCompatible, .bioInfoArk, .threeZeroTwo:
            return "text-embedding-3-small"
        case .ollama:
            return "nomic-embed-text"
        case .deepseek:
            return ""
        }
    }

    /// 可用的 Embedding 模型列表（供用户选择）
    var availableEmbeddingModels: [String] {
        switch self {
        case .siliconflow:
            return ["BAAI/bge-m3", "Qwen/Qwen3-Embedding-8B"]
        case .openaiCompatible, .bioInfoArk, .threeZeroTwo:
            return ["text-embedding-3-small", "text-embedding-3-large"]
        case .ollama:
            return ["nomic-embed-text", "mxbai-embed-large"]
        case .deepseek:
            return []
        }
    }
}

// MARK: - Model Metadata System

/// 模型能力标签
enum ModelTag: String, CaseIterable {
    case free
    case reasoning
    case fast
    case coding
    case multimodal
    case large

    var displayName: String {
        switch self {
        case .free: return "免费"
        case .reasoning: return "推理"
        case .fast: return "快速"
        case .coding: return "编程"
        case .multimodal: return "多模态"
        case .large: return "大参数"
        }
    }

    var color: Color {
        switch self {
        case .free: return .green
        case .reasoning: return .purple
        case .fast: return .orange
        case .coding: return .blue
        case .multimodal: return .pink
        case .large: return .indigo
        }
    }

    var icon: String {
        switch self {
        case .free: return "gift"
        case .reasoning: return "brain"
        case .fast: return "bolt.fill"
        case .coding: return "chevron.left.forwardslash.chevron.right"
        case .multimodal: return "eye"
        case .large: return "chart.bar.fill"
        }
    }
}

/// 模型元数据
struct ModelMetadata {
    let displayName: String
    let icon: String
    let tags: [ModelTag]
    let providerName: String

    /// 根据模型 ID 获取元数据
    static func metadata(for modelId: String, provider: LLMProvider? = nil) -> ModelMetadata {
        let id = modelId.lowercased()
        let shortName = modelId.components(separatedBy: "/").last ?? modelId

        let icon = inferIcon(from: id)
        let tags = inferTags(from: id, provider: provider)
        let displayName = inferDisplayName(from: shortName)
        let providerName = inferProvider(from: modelId)

        return ModelMetadata(
            displayName: displayName,
            icon: icon,
            tags: tags,
            providerName: providerName
        )
    }

    private static func inferIcon(from id: String) -> String {
        if id.contains("claude") { return "sparkles" }
        if id.contains("gpt") || id.hasPrefix("o1") || id.hasPrefix("o3") || id.hasPrefix("o4") { return "brain.head.profile" }
        if id.contains("gemini") { return "diamond" }
        if id.contains("deepseek") { return "water.waves" }
        if id.contains("qwen") || id.contains("qwq") { return "cloud" }
        if id.contains("glm") { return "cube" }
        if id.contains("llama") { return "hare" }
        if id.contains("grok") { return "bolt" }
        if id.contains("kimi") || id.contains("moonshot") { return "moon.stars" }
        if id.contains("mistral") { return "wind" }
        if id.contains("ernie") { return "leaf" }
        return "cpu"
    }

    private static func inferTags(from id: String, provider: LLMProvider?) -> [ModelTag] {
        var tags: [ModelTag] = []

        if id.contains("reasoner") || id.contains("-r1") || id.contains("thinking") ||
           id.hasPrefix("o1") || id.hasPrefix("o3") || id.hasPrefix("o4") ||
           id.contains("qwq") || id.contains("z1") {
            tags.append(.reasoning)
        }

        if id.contains("coder") || id.contains("codex") || id.contains("code") {
            tags.append(.coding)
        }

        if id.contains("vl") || id.contains("vision") || id.contains("4v") ||
           id.contains("omni") {
            tags.append(.multimodal)
        }

        if id.contains("mini") || id.contains("nano") || id.contains("flash") ||
           id.contains("lite") || id.contains("turbo") || id.contains("fast") ||
           id.contains("air") {
            tags.append(.fast)
        }

        if id.contains("235b") || id.contains("480b") || id.contains("405b") ||
           id.contains("opus") || id.contains("max") || id.contains("72b") {
            tags.append(.large)
        }

        if provider == .siliconflow && id.hasPrefix("pro/") {
            tags.append(.free)
        }

        return tags
    }

    private static func inferDisplayName(from name: String) -> String {
        var result = name
        if result.hasSuffix("-Instruct") {
            result = String(result.dropLast("-Instruct".count))
        }
        return result
    }

    private static func inferProvider(from modelId: String) -> String {
        let id = modelId.lowercased()
        if id.contains("gpt") || id.hasPrefix("o1") || id.hasPrefix("o3") || id.hasPrefix("o4") { return "OpenAI" }
        if id.contains("claude") { return "Anthropic" }
        if id.contains("gemini") { return "Google" }
        if id.contains("deepseek") { return "DeepSeek" }
        if id.contains("qwen") || id.contains("qwq") { return "Alibaba" }
        if id.contains("glm") { return "Zhipu" }
        if id.contains("llama") { return "Meta" }
        if id.contains("grok") { return "xAI" }
        if id.contains("kimi") || id.contains("moonshot") { return "Moonshot" }
        if id.contains("mistral") { return "Mistral" }
        return ""
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
        modelName: String = "Pro/deepseek-ai/DeepSeek-V3.2",
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
