//
//  BriefingService.swift
//  AIPaperReader
//
//  Created by Claude on 2/7/26.
//

import Foundation
import PDFKit

/// 论文简报生成服务
@MainActor
class BriefingService: ObservableObject {
    @Published var brief: PaperBrief = PaperBrief()
    @Published var isGenerating: Bool = false
    @Published var progress: Double = 0.0
    @Published var currentField: String = ""
    @Published var errorMessage: String?

    private var currentTask: Task<Void, Never>?
    private let textExtractor = PDFTextExtractor()

    // 简报缓存（基于文档 URL hash）
    private static var cache: [String: PaperBrief] = [:]

    /// 检查是否有缓存的简报
    func getCachedBrief(for documentURL: URL?) -> PaperBrief? {
        guard let url = documentURL else { return nil }
        return Self.cache[url.absoluteString]
    }

    /// 生成论文简报
    func generateBrief(
        document: PDFDocument,
        service: LLMServiceProtocol
    ) {
        // 检查缓存
        if let url = document.documentURL,
           let cached = Self.cache[url.absoluteString] {
            self.brief = cached
            return
        }

        isGenerating = true
        progress = 0.0
        errorMessage = nil
        brief = PaperBrief()

        currentTask = Task {
            do {
                // 提取 PDF 内容（重点提取前几页和后几页）
                let content = extractBriefingContent(from: document)
                progress = 0.1

                // 构建 prompt
                let prompt = buildBriefingPrompt(content: content)
                progress = 0.15

                // 调用 LLM
                currentField = "生成中..."
                var streamedText = ""

                let messages = [ChatMessage.user(prompt)]
                let systemPrompt = """
                You are an expert academic paper analyst. You help readers quickly understand research papers by extracting key information and presenting it in a structured format. Always respond in the same language as the paper content. If the paper is in English, respond in Chinese for the structured fields to help Chinese readers.
                """

                try await service.sendMessage(
                    messages: messages,
                    systemPrompt: systemPrompt,
                    onToken: { [weak self] token in
                        streamedText += token
                        self?.updateProgress(from: streamedText)
                    },
                    onComplete: { [weak self] in
                        self?.parseBrief(from: streamedText)
                        self?.brief.isComplete = true
                        self?.isGenerating = false
                        self?.progress = 1.0
                        self?.currentField = ""

                        // 缓存结果
                        if let url = document.documentURL {
                            Self.cache[url.absoluteString] = self?.brief
                        }
                    },
                    onError: { [weak self] error in
                        self?.errorMessage = error.localizedDescription
                        self?.isGenerating = false
                    }
                )
            } catch {
                errorMessage = error.localizedDescription
                isGenerating = false
            }
        }
    }

    /// 取消生成
    func cancel() {
        currentTask?.cancel()
        isGenerating = false
        currentField = ""
    }

    /// 重新生成
    func regenerate(document: PDFDocument, service: LLMServiceProtocol) {
        if let url = document.documentURL {
            Self.cache.removeValue(forKey: url.absoluteString)
        }
        generateBrief(document: document, service: service)
    }

    // MARK: - Private

    private func extractBriefingContent(from document: PDFDocument) -> String {
        let pageCount = document.pageCount

        // 策略：提取前 5 页（通常包含摘要、引言）+ 后 2 页（通常包含结论、参考文献前的内容）
        let frontPages = min(5, pageCount)
        let backPages = min(2, max(0, pageCount - frontPages))

        var parts: [String] = []

        // 提取前 N 页
        let frontResult = textExtractor.extractText(from: document, pages: 0..<frontPages)
        parts.append(frontResult.text)

        // 提取后 N 页（避免重复）
        if backPages > 0 && pageCount > frontPages {
            let backStart = pageCount - backPages
            let backResult = textExtractor.extractText(from: document, pages: backStart..<pageCount)
            parts.append(backResult.text)
        }

        // 如果文档很短，提取全文
        if pageCount <= 7 {
            return textExtractor.extractTextWithBudget(from: document, tokenBudget: 12000).text
        }

        return parts.joined(separator: "\n\n--- ... ---\n\n")
    }

    private func buildBriefingPrompt(content: String) -> String {
        return """
        请分析以下学术论文内容，并按照以下 JSON 格式返回结构化的论文简报。只返回 JSON，不要添加其他内容。

        要求：
        1. 每个字段用中文回答
        2. 保持简洁，每个字段 2-5 句话
        3. keywords 返回 3-6 个关键词的数组

        返回格式：
        ```json
        {
            "title": "论文标题",
            "authors": "作者列表",
            "researchQuestion": "研究问题描述",
            "methodology": "研究方法描述",
            "keyFindings": "主要发现",
            "contributions": "主要贡献",
            "limitations": "局限性",
            "keywords": ["关键词1", "关键词2", "关键词3"]
        }
        ```

        论文内容：
        \(content)
        """
    }

    private func updateProgress(from text: String) {
        // 根据已解析字段数量更新进度
        let fieldCount = 8.0
        var parsed = 0.0
        if text.contains("\"title\"") { parsed += 1; currentField = "标题" }
        if text.contains("\"authors\"") { parsed += 1; currentField = "作者" }
        if text.contains("\"researchQuestion\"") { parsed += 1; currentField = "研究问题" }
        if text.contains("\"methodology\"") { parsed += 1; currentField = "研究方法" }
        if text.contains("\"keyFindings\"") { parsed += 1; currentField = "主要发现" }
        if text.contains("\"contributions\"") { parsed += 1; currentField = "主要贡献" }
        if text.contains("\"limitations\"") { parsed += 1; currentField = "局限性" }
        if text.contains("\"keywords\"") { parsed += 1; currentField = "关键词" }
        progress = 0.15 + (parsed / fieldCount) * 0.8
    }

    private func parseBrief(from text: String) {
        // 尝试从 LLM 响应中提取 JSON
        var jsonString = text

        // 去除 markdown code block 标记
        if let start = jsonString.range(of: "```json") {
            jsonString = String(jsonString[start.upperBound...])
        } else if let start = jsonString.range(of: "```") {
            jsonString = String(jsonString[start.upperBound...])
        }
        if let end = jsonString.range(of: "```", options: .backwards) {
            jsonString = String(jsonString[..<end.lowerBound])
        }

        jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)

        // 尝试解析 JSON
        guard let data = jsonString.data(using: .utf8) else {
            fallbackParse(from: text)
            return
        }

        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                brief.title = json["title"] as? String ?? brief.title
                brief.authors = json["authors"] as? String ?? brief.authors
                brief.researchQuestion = json["researchQuestion"] as? String ?? brief.researchQuestion
                brief.methodology = json["methodology"] as? String ?? brief.methodology
                brief.keyFindings = json["keyFindings"] as? String ?? brief.keyFindings
                brief.contributions = json["contributions"] as? String ?? brief.contributions
                brief.limitations = json["limitations"] as? String ?? brief.limitations
                if let kw = json["keywords"] as? [String] {
                    brief.keywords = kw
                }
                brief.generatedAt = Date()
            }
        } catch {
            fallbackParse(from: text)
        }
    }

    /// 降级解析：如果 JSON 解析失败，尝试从文本中提取
    private func fallbackParse(from text: String) {
        brief.title = extractSection(from: text, key: "title") ?? "解析失败"
        brief.authors = extractSection(from: text, key: "authors") ?? ""
        brief.researchQuestion = extractSection(from: text, key: "researchQuestion") ?? ""
        brief.methodology = extractSection(from: text, key: "methodology") ?? ""
        brief.keyFindings = extractSection(from: text, key: "keyFindings") ?? ""
        brief.contributions = extractSection(from: text, key: "contributions") ?? ""
        brief.limitations = extractSection(from: text, key: "limitations") ?? ""
        brief.generatedAt = Date()
    }

    private func extractSection(from text: String, key: String) -> String? {
        // Try to find "key": "value" pattern
        let pattern = "\"\(key)\"\\s*:\\s*\"([^\"]*)\""
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[range])
    }
}
