//
//  OllamaService.swift
//  AIPaperReader
//
//  Created by Claude on 2/4/26.
//

import Foundation

/// Ollama local model service
class OllamaService: BaseLLMService, LLMServiceProtocol {

    func sendMessage(
        messages: [ChatMessage],
        systemPrompt: String,
        onToken: @escaping (String) -> Void,
        onComplete: @escaping () -> Void,
        onError: @escaping (LLMError) -> Void
    ) async throws {

        // Build URL
        let baseURL = config.baseURL.trimmingCharacters(in: .init(charactersIn: "/"))
        guard let url = URL(string: "\(baseURL)/api/chat") else {
            throw LLMError.invalidURL
        }

        // Build request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Build Ollama-specific message format
        var ollamaMessages: [[String: String]] = [
            ["role": "system", "content": systemPrompt]
        ]

        for message in messages {
            ollamaMessages.append([
                "role": message.role.rawValue,
                "content": message.content
            ])
        }

        let body: [String: Any] = [
            "model": config.modelName,
            "messages": ollamaMessages,
            "stream": true,
            "options": [
                "temperature": config.temperature,
                "num_predict": config.maxTokens
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Execute streaming request
        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw LLMError.connectionFailed
            }

            if httpResponse.statusCode != 200 {
                var errorBody = ""
                for try await line in bytes.lines {
                    errorBody += line
                }
                throw LLMError.httpError(httpResponse.statusCode, errorBody)
            }

            // Process Ollama streaming format (NDJSON)
            for try await line in bytes.lines {
                try Task.checkCancellation()

                guard !line.isEmpty,
                      let jsonData = line.data(using: .utf8) else { continue }

                do {
                    if let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                        // Check if done
                        if let done = json["done"] as? Bool, done {
                            await MainActor.run { onComplete() }
                            return
                        }

                        // Extract content from message
                        if let message = json["message"] as? [String: Any],
                           let content = message["content"] as? String {
                            await MainActor.run { onToken(content) }
                        }
                    }
                } catch {
                    continue
                }
            }

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
        let baseURL = config.baseURL.trimmingCharacters(in: .init(charactersIn: "/"))
        guard let url = URL(string: "\(baseURL)/api/tags") else {
            throw LLMError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5

        do {
            let (_, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }

            return httpResponse.statusCode == 200
        } catch {
            throw LLMError.connectionFailed
        }
    }

    func fetchAvailableModels() async throws -> [String] {
        let baseURL = config.baseURL.trimmingCharacters(in: .init(charactersIn: "/"))
        guard let url = URL(string: "\(baseURL)/api/tags") else {
            throw LLMError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return config.provider.defaultFreeModels
            }

            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let models = json["models"] as? [[String: Any]] {
                let modelNames = models.compactMap { $0["name"] as? String }
                return modelNames.isEmpty ? config.provider.defaultFreeModels : modelNames
            }

            return config.provider.defaultFreeModels
        } catch {
            return config.provider.defaultFreeModels
        }
    }
}
