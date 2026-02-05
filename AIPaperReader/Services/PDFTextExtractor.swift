//
//  PDFTextExtractor.swift
//  AIPaperReader
//
//  Created by Claude on 2/4/26.
//

import Foundation
import PDFKit

/// Service for extracting text content from PDF documents
class PDFTextExtractor {

    // MARK: - Types

    struct ExtractionResult {
        let text: String
        let pageCount: Int
        let extractedPages: Range<Int>
        let estimatedTokens: Int
    }

    struct TextChunk: Identifiable, Hashable {
        let id = UUID()
        let text: String
        let pageRange: Range<Int>
        let score: Double = 0.0 // For retrieval ranking
    }

    struct PageRange {
        let ranges: [ClosedRange<Int>]

        /// Parse a page range string like "1-5,8,10-15"
        static func parse(_ input: String, maxPage: Int) -> PageRange? {
            var ranges: [ClosedRange<Int>] = []

            let parts = input.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }

            for part in parts {
                if part.contains("-") {
                    let bounds = part.split(separator: "-").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
                    guard bounds.count == 2 else { return nil }
                    let start = max(1, bounds[0])
                    let end = min(maxPage, bounds[1])
                    if start <= end {
                        ranges.append(start...end)
                    }
                } else if let page = Int(part) {
                    let validPage = max(1, min(maxPage, page))
                    ranges.append(validPage...validPage)
                }
            }

            return ranges.isEmpty ? nil : PageRange(ranges: ranges)
        }

        /// Convert to zero-based page indices
        func toIndices() -> [Int] {
            var indices: Set<Int> = []
            for range in ranges {
                for page in range {
                    indices.insert(page - 1) // Convert to 0-based index
                }
            }
            return indices.sorted()
        }
    }

    // MARK: - Properties

    private let maxTokenBudget: Int

    // MARK: - Initialization

    init(maxTokenBudget: Int = 16000) {
        self.maxTokenBudget = maxTokenBudget
    }

    // MARK: - Public Methods

    /// Extract text from all pages of a PDF document
    func extractFullText(from document: PDFDocument) -> ExtractionResult {
        return extractText(from: document, pages: 0..<document.pageCount)
    }

    /// Extract text from specific page indices
    func extractText(from document: PDFDocument, pages: Range<Int>) -> ExtractionResult {
        var textParts: [String] = []
        let validRange = max(0, pages.lowerBound)..<min(document.pageCount, pages.upperBound)

        for index in validRange {
            if let page = document.page(at: index),
               let pageText = page.string {
                let cleanedText = cleanText(pageText)
                if !cleanedText.isEmpty {
                    textParts.append("--- Page \(index + 1) ---\n\(cleanedText)")
                }
            }
        }

        let fullText = textParts.joined(separator: "\n\n")
        let tokens = estimateTokenCount(fullText)

        return ExtractionResult(
            text: fullText,
            pageCount: document.pageCount,
            extractedPages: validRange,
            estimatedTokens: tokens
        )
    }

    /// Extract text from pages specified by a range string (e.g., "1-5,8,10-15")
    func extractText(from document: PDFDocument, rangeString: String) -> ExtractionResult? {
        guard let pageRange = PageRange.parse(rangeString, maxPage: document.pageCount) else {
            return nil
        }

        let indices = pageRange.toIndices()
        var textParts: [String] = []

        for index in indices {
            if let page = document.page(at: index),
               let pageText = page.string {
                let cleanedText = cleanText(pageText)
                if !cleanedText.isEmpty {
                    textParts.append("--- Page \(index + 1) ---\n\(cleanedText)")
                }
            }
        }

        let fullText = textParts.joined(separator: "\n\n")
        let tokens = estimateTokenCount(fullText)

        let minIndex = indices.min() ?? 0
        let maxIndex = indices.max() ?? 0

        return ExtractionResult(
            text: fullText,
            pageCount: document.pageCount,
            extractedPages: minIndex..<(maxIndex + 1),
            estimatedTokens: tokens
        )
    }

    /// Extract text with token budget constraint
    func extractTextWithBudget(from document: PDFDocument, tokenBudget: Int? = nil) -> ExtractionResult {
        let budget = tokenBudget ?? maxTokenBudget
        var textParts: [String] = []
        var totalTokens = 0
        var lastExtractedPage = 0

        for index in 0..<document.pageCount {
            guard let page = document.page(at: index),
                  let pageText = page.string else { continue }

            let cleanedText = cleanText(pageText)
            if cleanedText.isEmpty { continue }

            let pageTextWithHeader = "--- Page \(index + 1) ---\n\(cleanedText)"
            let pageTokens = estimateTokenCount(pageTextWithHeader)

            if totalTokens + pageTokens > budget {
                // Would exceed budget, stop here
                break
            }

            textParts.append(pageTextWithHeader)
            totalTokens += pageTokens
            lastExtractedPage = index
        }

        let fullText = textParts.joined(separator: "\n\n")

        return ExtractionResult(
            text: fullText,
            pageCount: document.pageCount,
            extractedPages: 0..<(lastExtractedPage + 1),
            estimatedTokens: totalTokens
        )
    }

    /// Extract text chunks using sliding window approach
    func extractChunks(from document: PDFDocument, chunkSize: Int = 1000, overlap: Int = 200, onProgress: ((Double) -> Void)? = nil) -> [TextChunk] {
        var chunks: [TextChunk] = []
        var currentTokenCount = 0
        var currentChunkText = ""
        var currentStartPage = 0
        var currentParagraphs: [String] = []
        
        // Iterate through pages
        for pageIndex in 0..<document.pageCount {
            // Report progress
            if pageIndex % 5 == 0 {
                onProgress?(Double(pageIndex) / Double(document.pageCount))
            }

            guard let page = document.page(at: pageIndex),
                  let pageText = page.string else { continue }
            
            let cleanedPageText = cleanText(pageText)
            if cleanedPageText.isEmpty { continue }
            
            // Split into paragraphs to preserve some structure
            let paragraphs = cleanedPageText.components(separatedBy: "\n\n")
            
            for paragraph in paragraphs {
                let paragraphTokens = estimateTokenCount(paragraph)
                
                // If adding this paragraph exceeds chunk size significantly
                if currentTokenCount + paragraphTokens > chunkSize + (chunkSize / 10) {
                    // Create chunk from current accumulated text
                    if !currentChunkText.isEmpty {
                        chunks.append(TextChunk(
                            text: currentChunkText.trimmingCharacters(in: .whitespacesAndNewlines),
                            pageRange: currentStartPage..<(pageIndex + 1)
                        ))
                    }
                    
                    // Start new chunk with overlap
                    // Simple overlap: keep last few paragraphs that fit within overlap limit
                    var newStartText = ""
                    var newStartTokens = 0
                    var paragraphsKeeping = 0
                    
                    // Iterate backwards to find paragraphs to keep for overlap
                    for p in currentParagraphs.reversed() {
                        let pTokens = estimateTokenCount(p)
                        if newStartTokens + pTokens <= overlap {
                            newStartText = p + "\n\n" + newStartText
                            newStartTokens += pTokens
                            paragraphsKeeping += 1
                        } else {
                            break
                        }
                    }
                    
                    currentChunkText = newStartText + paragraph + "\n\n"
                    currentTokenCount = newStartTokens + paragraphTokens
                    currentParagraphs = currentParagraphs.suffix(paragraphsKeeping) + [paragraph]
                    currentStartPage = pageIndex // Approximation
                    
                } else {
                    currentChunkText += paragraph + "\n\n"
                    currentTokenCount += paragraphTokens
                    currentParagraphs.append(paragraph)
                    if currentTokenCount == 0 {
                        currentStartPage = pageIndex
                    }
                }
            }
        }
        
        // Add final chunk
        if !currentChunkText.isEmpty {
            chunks.append(TextChunk(
                text: currentChunkText.trimmingCharacters(in: .whitespacesAndNewlines),
                pageRange: currentStartPage..<(document.pageCount)
            ))
        }
        
        return chunks
    }

    /// Get selected text from PDFView
    func extractSelectedText(from pdfView: PDFView) -> String? {
        return pdfView.currentSelection?.string
    }

    /// Get the page number of the current selection
    func getSelectionPageIndex(from pdfView: PDFView) -> Int? {
        guard let selection = pdfView.currentSelection,
              let firstPage = selection.pages.first,
              let document = pdfView.document else {
            return nil
        }
        return document.index(for: firstPage)
    }

    // MARK: - Token Estimation

    /// Estimate token count for text
    /// Rough estimation: English ~4 chars/token, CJK ~1.5 chars/token
    func estimateTokenCount(_ text: String) -> Int {
        var englishChars = 0
        var cjkChars = 0

        for scalar in text.unicodeScalars {
            if scalar.isASCII {
                englishChars += 1
            } else if isCJK(scalar) {
                cjkChars += 1
            } else {
                // Other Unicode characters, treat as ~2 chars/token
                englishChars += 2
            }
        }

        return englishChars / 4 + Int(Double(cjkChars) / 1.5)
    }

    /// Check if a unicode scalar is CJK (Chinese, Japanese, Korean)
    private func isCJK(_ scalar: Unicode.Scalar) -> Bool {
        let value = scalar.value
        // CJK Unified Ideographs
        if value >= 0x4E00 && value <= 0x9FFF { return true }
        // CJK Unified Ideographs Extension A
        if value >= 0x3400 && value <= 0x4DBF { return true }
        // CJK Unified Ideographs Extension B
        if value >= 0x20000 && value <= 0x2A6DF { return true }
        // Hiragana
        if value >= 0x3040 && value <= 0x309F { return true }
        // Katakana
        if value >= 0x30A0 && value <= 0x30FF { return true }
        // Hangul Syllables
        if value >= 0xAC00 && value <= 0xD7AF { return true }
        return false
    }

    // MARK: - Text Cleaning

    /// Clean extracted text by removing excessive whitespace and fixing common issues
    private func cleanText(_ text: String) -> String {
        var result = text

        // Replace multiple spaces with single space
        result = result.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)

        // Replace multiple newlines with double newline (paragraph break)
        result = result.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)

        // Remove leading/trailing whitespace from each line
        let lines = result.components(separatedBy: "\n")
        result = lines.map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: "\n")

        // Remove hyphenation at line breaks (common in PDFs)
        result = result.replacingOccurrences(of: "-\n", with: "")

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Document Info

    /// Get document metadata
    func getDocumentInfo(from document: PDFDocument) -> [String: String] {
        var info: [String: String] = [:]

        if let attributes = document.documentAttributes {
            if let title = attributes[PDFDocumentAttribute.titleAttribute] as? String {
                info["title"] = title
            }
            if let author = attributes[PDFDocumentAttribute.authorAttribute] as? String {
                info["author"] = author
            }
            if let subject = attributes[PDFDocumentAttribute.subjectAttribute] as? String {
                info["subject"] = subject
            }
            if let keywords = attributes[PDFDocumentAttribute.keywordsAttribute] as? String {
                info["keywords"] = keywords
            }
            if let creator = attributes[PDFDocumentAttribute.creatorAttribute] as? String {
                info["creator"] = creator
            }
        }

        info["pageCount"] = String(document.pageCount)

        return info
    }
}
