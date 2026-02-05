//
//  ContextManager.swift
//  AIPaperReader
//
//  Created by JohnnyChan on 2/4/26.
//

import Foundation
import PDFKit

/// Manages document context for RAG (Retrieval-Augmented Generation)
class ContextManager: ObservableObject {
    @Published var isIngesting: Bool = false
    @Published var ingestionProgress: Double = 0.0
    @Published var isEmbedding: Bool = false // New state for embedding generation
    
    private var chunks: [PDFTextExtractor.TextChunk] = []
    private var chunkEmbeddings: [[Double]] = []
    private let extractor = PDFTextExtractor()
    
    /// Ingest a document by extracting chunks and optionally generating embeddings
    func ingest(document: PDFDocument) async {
        await MainActor.run {
            self.isIngesting = true
            self.ingestionProgress = 0.0
            self.chunks = []
            self.chunkEmbeddings = []
        }
        
        // 1. Extract Chunks
        let extractedChunks = await Task.detached(priority: .userInitiated) {
            return self.extractor.extractChunks(from: document) { progress in
                Task { @MainActor in
                    // Scaling progress: 0-0.5 for extraction, 0.5-1.0 for embedding
                    self.ingestionProgress = progress * 0.5
                }
            }
        }.value
        
        await MainActor.run {
            self.chunks = extractedChunks
            print("Extracted \(extractedChunks.count) chunks")
        }
        
        // 2. Generate Embeddings (if API Key is present)
        let settings = AppSettings.shared
        if !settings.embeddingApiKey.isEmpty {
            await MainActor.run {
                self.isEmbedding = true
            }
            
            let config = EmbeddingConfig(
                baseURL: settings.embeddingBaseURL,
                apiKey: settings.embeddingApiKey,
                modelName: settings.embeddingModelName
            )
            let service = EmbeddingService(config: config)
            
            do {
                // Batch process chunks to avoid timeouts
                let batchSize = 10
                var allEmbeddings: [[Double]] = []
                let texts = extractedChunks.map { $0.text }
                
                for i in stride(from: 0, to: texts.count, by: batchSize) {
                    let end = min(i + batchSize, texts.count)
                    let batch = Array(texts[i..<end])
                    
                    let embeddings = try await service.embed(texts: batch)
                    allEmbeddings.append(contentsOf: embeddings)
                    
                    // Update progress (0.5 to 1.0)
                    let progress = 0.5 + (Double(end) / Double(texts.count) * 0.5)
                    await MainActor.run {
                        self.ingestionProgress = progress
                    }
                }
                
                let finalEmbeddings = allEmbeddings
                await MainActor.run {
                    self.chunkEmbeddings = finalEmbeddings
                    self.isEmbedding = false
                    self.isIngesting = false
                    print("Generated \(finalEmbeddings.count) embeddings")
                }
            } catch {
                print("Failed to generate embeddings: \(error)")
                await MainActor.run {
                    self.isEmbedding = false
                    self.isIngesting = false
                }
            }
        } else {
            await MainActor.run {
                self.isIngesting = false
                self.ingestionProgress = 1.0
            }
        }
    }
    
    /// Retrieve relevant chunks using Vector Search (if available) or Keyword Match
    func retrieve(query: String, limit: Int = 3) async -> [PDFTextExtractor.TextChunk] {
        guard !chunks.isEmpty else { return [] }
        
        // Try Vector Search first
        if !chunkEmbeddings.isEmpty && !AppSettings.shared.embeddingApiKey.isEmpty {
            do {
                let config = EmbeddingConfig(
                    baseURL: AppSettings.shared.embeddingBaseURL,
                    apiKey: AppSettings.shared.embeddingApiKey,
                    modelName: AppSettings.shared.embeddingModelName
                )
                let service = EmbeddingService(config: config)
                let queryEmbedding = try await service.embed(text: query)
                
                // Calculate cosine similarity
                let scoredChunks = zip(chunks, chunkEmbeddings).map { (chunk, embedding) -> (PDFTextExtractor.TextChunk, Double) in
                    let score = cosineSimilarity(queryEmbedding, embedding)
                    return (chunk, score)
                }
                
                // Sort by score
                let sorted = scoredChunks.sorted { $0.1 > $1.1 }
                
                // Filter low relevance? (Optional)
                return sorted.prefix(limit).map { $0.0 }
                
            } catch {
                print("Vector search failed, falling back to keyword: \(error)")
            }
        }
        
        // Fallback to Keyword Search
        return retrieveKeyword(query: query, limit: limit)
    }
    
    private func retrieveKeyword(query: String, limit: Int) -> [PDFTextExtractor.TextChunk] {
        let queryTerms = Set(query.lowercased().split(separator: " ").map { String($0) })
        var scoredChunks: [(chunk: PDFTextExtractor.TextChunk, score: Double)] = []
        
        for chunk in chunks {
            var score = 0.0
            let chunkTextOriginal = chunk.text.lowercased()
            for term in queryTerms {
                let matches = chunkTextOriginal.components(separatedBy: term).count - 1
                if matches > 0 { score += Double(matches) }
            }
            if score > 0 { scoredChunks.append((chunk, score)) }
        }
        
        scoredChunks.sort { $0.score > $1.score }
        return scoredChunks.prefix(limit).map { $0.chunk }
    }
    
    private func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count else { return 0.0 }
        let dotProduct = zip(a, b).map(*).reduce(0, +)
        let magnitudeA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let magnitudeB = sqrt(b.map { $0 * $0 }.reduce(0, +))
        guard magnitudeA > 0 && magnitudeB > 0 else { return 0.0 }
        return dotProduct / (magnitudeA * magnitudeB)
    }
    
    func clear() {
        self.chunks = []
        self.chunkEmbeddings = []
        self.isIngesting = false
        self.isEmbedding = false
        self.ingestionProgress = 0.0
    }
}
