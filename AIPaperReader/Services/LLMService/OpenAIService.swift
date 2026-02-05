//
//  OpenAIService.swift
//  AIPaperReader
//
//  Created by Claude on 2/4/26.
//

import Foundation

/// OpenAI-compatible API service (works with OpenAI, SiliconFlow, DeepSeek, etc.)
class OpenAIService: BaseLLMService, LLMServiceProtocol {

    private var activeTask: URLSessionDataTask?

    func sendMessage(
        messages: [ChatMessage],
        systemPrompt: String,
        onToken: @escaping (String) -> Void,
        onComplete: @escaping () -> Void,
        onError: @escaping (LLMError) -> Void
    ) async throws {

        // Validate API key
        if config.provider.requiresAPIKey && config.apiKey.isEmpty {
            throw LLMError.apiKeyMissing
        }

        // Build URL
        let baseURL = config.baseURL.trimmingCharacters(in: .init(charactersIn: "/"))
        guard let url = URL(string: "\(baseURL)/v1/chat/completions") else {
            throw LLMError.invalidURL
        }

        // Build request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if !config.apiKey.isEmpty {
            request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        }

        // Build body
        let messagesPayload = buildMessagesPayload(messages: messages, systemPrompt: systemPrompt)
        let body: [String: Any] = [
            "model": config.modelName,
            "messages": messagesPayload,
            "stream": true,
            "temperature": config.temperature,
            "max_tokens": config.maxTokens
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Custom session for streaming with strict timeout to detect stalls
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 30 // 30s timeout if no data received
        sessionConfig.timeoutIntervalForResource = 300 // 5m total timeout (adjustable)
        let session = URLSession(configuration: sessionConfig)

        // Execute streaming request
        do {
            let (bytes, response) = try await session.bytes(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw LLMError.connectionFailed
            }

            if httpResponse.statusCode != 200 {
                // Try to read error message
                var errorBody = ""
                for try await line in bytes.lines {
                    errorBody += line
                }
                throw LLMError.httpError(httpResponse.statusCode, errorBody)
            }

            // Process SSE stream
            for try await line in bytes.lines {
                // Check for cancellation
                try Task.checkCancellation()

                // Skip keep-alives or comments
                if line.isEmpty || line.hasPrefix(":") { continue }

                // Robust SSE parsing
                var dataStart = line.startIndex
                if line.hasPrefix("data:") {
                     dataStart = line.index(line.startIndex, offsetBy: 5)
                } else if line.hasPrefix("data: ") {
                     dataStart = line.index(line.startIndex, offsetBy: 6)
                } else {
                    // Ignore non-data lines (like event:, id:, retry:)
                    continue
                }
                
                var data = String(line[dataStart...])
                if data.hasPrefix(" ") {
                    data = String(data.dropFirst())
                }

                if data == "[DONE]" {
                    await MainActor.run { onComplete() }
                    return
                }

                // Parse JSON
                guard let jsonData = data.data(using: .utf8) else { continue }

                do {
                    if let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                       let choices = json["choices"] as? [[String: Any]],
                       let firstChoice = choices.first,
                       let delta = firstChoice["delta"] as? [String: Any],
                       let content = delta["content"] as? String {
                        await MainActor.run { onToken(content) }
                    }
                } catch {
                    // Ignore parsing errors for individual chunks
                    continue
                }
            }

            // Stream ended without [DONE]
            await MainActor.run { onComplete() }

        } catch is CancellationError {
            throw LLMError.cancelled
        } catch let error as LLMError {
            throw error
        } catch {
            throw LLMError.networkError(error)
        }
    }

    func testConnection() async throws -> Bool {
        // Validate API key
        if config.provider.requiresAPIKey && config.apiKey.isEmpty {
            throw LLMError.apiKeyMissing
        }

        // Build URL for models endpoint
        let baseURL = config.baseURL.trimmingCharacters(in: .init(charactersIn: "/"))
        // Some providers need /v1/models, some just /models. Using standard OpenAI format.
        guard let url = URL(string: "\(baseURL)/v1/models") else {
            throw LLMError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10

        if !config.apiKey.isEmpty {
            request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (_, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }

            return httpResponse.statusCode == 200
        } catch {
            throw LLMError.networkError(error)
        }
    }

    func fetchAvailableModels() async throws -> [String] {
        // Validate API key
        if config.provider.requiresAPIKey && config.apiKey.isEmpty {
            throw LLMError.apiKeyMissing
        }

        // Build URL
        let baseURL = config.baseURL.trimmingCharacters(in: .init(charactersIn: "/"))
        guard let url = URL(string: "\(baseURL)/v1/models") else {
            throw LLMError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        if !config.apiKey.isEmpty {
            request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return config.provider.defaultFreeModels
            }

            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let dataArray = json["data"] as? [[String: Any]] {
                let models = dataArray.compactMap { $0["id"] as? String }
                return models.isEmpty ? config.provider.defaultFreeModels : models
            }

            return config.provider.defaultFreeModels
        } catch {
            return config.provider.defaultFreeModels
        }
    }
}
