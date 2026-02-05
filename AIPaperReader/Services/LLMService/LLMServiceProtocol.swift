//
//  LLMServiceProtocol.swift
//  AIPaperReader
//
//  Created by Claude on 2/4/26.
//

import Foundation

/// Protocol defining the interface for LLM service implementations
protocol LLMServiceProtocol {
    /// The configuration for this service
    var config: LLMConfig { get }

    /// Send a message and receive a streaming response
    /// - Parameters:
    ///   - messages: The conversation history
    ///   - systemPrompt: The system prompt to use
    ///   - onToken: Callback for each token received
    ///   - onComplete: Callback when streaming is complete
    ///   - onError: Callback when an error occurs
    func sendMessage(
        messages: [ChatMessage],
        systemPrompt: String,
        onToken: @escaping (String) -> Void,
        onComplete: @escaping () -> Void,
        onError: @escaping (LLMError) -> Void
    ) async throws

    /// Test if the connection is working
    func testConnection() async throws -> Bool

    /// Get available models from the server (if supported)
    func fetchAvailableModels() async throws -> [String]

    /// Cancel any ongoing request
    func cancel()
}

/// Base implementation with common functionality
class BaseLLMService {
    let config: LLMConfig
    var currentTask: Task<Void, Never>?

    init(config: LLMConfig) {
        self.config = config
    }

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
    }

    /// Build the messages array for the API request
    func buildMessagesPayload(messages: [ChatMessage], systemPrompt: String) -> [[String: String]] {
        var payload: [[String: String]] = []

        // Add system prompt
        payload.append(["role": "system", "content": systemPrompt])

        // Add conversation messages
        for message in messages {
            payload.append([
                "role": message.role.rawValue,
                "content": message.content
            ])
        }

        return payload
    }
}
