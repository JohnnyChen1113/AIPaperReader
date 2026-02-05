//
//  EmbeddingService.swift
//  AIPaperReader
//
//  Created by JohnnyChan on 2/4/26.
//

import Foundation

struct EmbeddingConfig {
    var baseURL: String
    var apiKey: String
    var modelName: String
}

enum EmbeddingError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case decodingError(Error)
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL configuration"
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        case .invalidResponse: return "Invalid response from server"
        case .decodingError(let error): return "Failed to decode response: \(error.localizedDescription)"
        case .serverError(let msg): return "Server error: \(msg)"
        }
    }
}

class EmbeddingService {
    private let config: EmbeddingConfig
    private let session: URLSession
    
    init(config: EmbeddingConfig) {
        self.config = config
        self.session = URLSession.shared
    }
    
    /// Generate embeddings for a single text string
    func embed(text: String) async throws -> [Double] {
        let embeddings = try await embed(texts: [text])
        guard let first = embeddings.first else {
            throw EmbeddingError.invalidResponse
        }
        return first
    }
    
    /// Generate embeddings for multiple text strings
    func embed(texts: [String]) async throws -> [[Double]] {
        guard !texts.isEmpty else { return [] }
        
        // Ensure URL ends with /embeddings or v1/embeddings
        var urlString = config.baseURL
        if !urlString.hasSuffix("/embeddings") {
            if urlString.hasSuffix("/") {
                urlString += "embeddings"
            } else {
                urlString += "/embeddings"
            }
        }
        
        guard let url = URL(string: urlString) else {
            throw EmbeddingError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Sanitize texts: remove newlines which might affect some embedding models
        let sanitizedTexts = texts.map { $0.replacingOccurrences(of: "\n", with: " ") }
        
        let payload: [String: Any] = [
            "input": sanitizedTexts,
            "model": config.modelName,
            "encoding_format": "float"
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw EmbeddingError.networkError(URLError(.badServerResponse))
        }
        
        guard httpResponse.statusCode == 200 else {
            // Try to decode error message
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorObj = errorJson["error"] as? [String: Any],
               let message = errorObj["message"] as? String {
                throw EmbeddingError.serverError(message)
            }
            throw EmbeddingError.serverError("Status code \(httpResponse.statusCode)")
        }
        
        do {
            let result = try JSONDecoder().decode(OpenAIEmbeddingResponse.self, from: data)
            // Sort by index to ensure order matches input
            let sortedData = result.data.sorted { $0.index < $1.index }
            return sortedData.map { $0.embedding }
        } catch {
            throw EmbeddingError.decodingError(error)
        }
    }
}

// MARK: - Response Models

struct OpenAIEmbeddingResponse: Decodable {
    struct EmbeddingData: Decodable {
        let object: String
        let index: Int
        let embedding: [Double]
    }
    
    let object: String
    let data: [EmbeddingData]
    let model: String
    let usage: Usage?
    
    struct Usage: Decodable {
        let prompt_tokens: Int
        let total_tokens: Int
    }
}
