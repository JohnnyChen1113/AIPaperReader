//
//  LLMServiceFactory.swift
//  AIPaperReader
//
//  Created by Claude on 2/4/26.
//

import Foundation

/// Factory for creating LLM service instances
class LLMServiceFactory {

    /// Create an LLM service based on the configuration
    static func create(config: LLMConfig) -> LLMServiceProtocol {
        switch config.provider {
        case .ollama:
            return OllamaService(config: config)
        case .openaiCompatible, .siliconflow, .deepseek, .bioInfoArk:
            return OpenAIService(config: config)
        }
    }

    /// Create a service with default configuration for a provider
    static func create(provider: LLMProvider, apiKey: String = "") -> LLMServiceProtocol {
        let config = LLMConfig(
            provider: provider,
            baseURL: provider.defaultBaseURL,
            apiKey: apiKey,
            modelName: provider.defaultFreeModels.first ?? ""
        )
        return create(config: config)
    }
}
