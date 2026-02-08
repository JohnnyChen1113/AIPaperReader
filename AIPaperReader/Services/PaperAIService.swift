//
//  PaperAIService.swift
//  AIPaperReader
//
//  Created by Claude on 2/7/26.
//

import Foundation
import PDFKit

/// 论文 AI 分析服务 — 生成摘要和标签
class PaperAIService {

    /// 生成模式
    enum GenerationMode: String {
        case abstract = "摘要"    // 基于前 2 页（通常包含 abstract）
        case fullText = "全文"    // 基于全文（受 token 限制）
    }

    /// AI 生成结果
    struct GenerationResult {
        let brief: PaperBrief
        let tags: [String]
    }

    /// AI 生成错误
    enum GenerationError: LocalizedError {
        case noPDFFile
        case cannotOpenPDF
        case noTextExtracted
        case llmError(String)
        case parseError(String)
        case noAPIKey

        var errorDescription: String? {
            switch self {
            case .noPDFFile:
                return "找不到 PDF 文件"
            case .cannotOpenPDF:
                return "无法打开 PDF 文件"
            case .noTextExtracted:
                return "无法从 PDF 中提取文本"
            case .llmError(let msg):
                return "AI 服务错误: \(msg)"
            case .parseError(let msg):
                return "解析 AI 响应失败: \(msg)"
            case .noAPIKey:
                return "请先配置 API Key"
            }
        }
    }

    // MARK: - Public API

    /// 为论文生成摘要和标签
    static func generateBriefAndTags(
        for paper: PaperItem,
        mode: GenerationMode,
        existingTags: [String]
    ) async throws -> GenerationResult {
        // 1. 检查 API Key
        let settings = AppSettings.shared
        guard !settings.llmApiKey.isEmpty else {
            throw GenerationError.noAPIKey
        }

        // 2. 提取 PDF 文本
        guard let fileURL = paper.fileURL else {
            throw GenerationError.noPDFFile
        }

        // 尝试使用 security-scoped bookmark 访问文件
        let accessed = fileURL.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        guard let document = PDFDocument(url: fileURL) else {
            throw GenerationError.cannotOpenPDF
        }

        let extractor = PDFTextExtractor()
        let text: String

        switch mode {
        case .abstract:
            // 前 2 页通常包含标题、作者、abstract
            let maxPages = min(2, document.pageCount)
            let result = extractor.extractText(from: document, pages: 0..<maxPages)
            text = result.text
        case .fullText:
            // 全文提取，限制 token 预算
            let result = extractor.extractTextWithBudget(from: document, tokenBudget: 12000)
            text = result.text
        }

        guard !text.isEmpty else {
            throw GenerationError.noTextExtracted
        }

        // 3. 构建 prompt
        let prompt = buildPrompt(paperContent: text, existingTags: existingTags)

        // 4. 调用 LLM
        let responseText = try await callLLM(prompt: prompt)

        // 5. 解析 JSON 响应
        let result = try parseResponse(responseText, paper: paper)

        return result
    }

    // MARK: - Private Methods

    /// 构建 AI prompt
    private static func buildPrompt(paperContent: String, existingTags: [String]) -> String {
        var prompt = """
        你是一个学术论文分析助手。请仔细分析以下论文内容，返回一个 JSON 对象。

        论文内容：
        \(paperContent)

        """

        if !existingTags.isEmpty {
            prompt += """

            用户已有的标签列表（请优先从中选择合适的标签）：
            \(existingTags.joined(separator: "、"))

            """
        }

        prompt += """

        请返回如下格式的 JSON（所有描述性内容用中文）：
        {
            "title": "论文标题",
            "authors": "作者（如果能识别的话）",
            "researchQuestion": "研究问题（1-2句话）",
            "methodology": "研究方法（1-2句话）",
            "keyFindings": "主要发现（2-3句话）",
            "contributions": "主要贡献（1-2句话）",
            "limitations": "局限性（1句话，如果无法判断可留空）",
            "keywords": ["关键词1", "关键词2", "关键词3"],
            "tags": ["标签1", "标签2", "标签3"]
        }

        注意：
        1. 仅返回 JSON，不要包含其他文字或 markdown 格式标记
        2. tags 是用于分类管理的标签（如"机器学习"、"生物信息"、"综述"等），3-5个为宜
        3. keywords 是论文本身的关键词
        4. 如果有已有标签列表，请优先从中选择合适的标签
        """

        return prompt
    }

    /// 调用 LLM 服务获取响应
    private static func callLLM(prompt: String) async throws -> String {
        let settings = AppSettings.shared
        let service = LLMServiceFactory.create(config: settings.llmConfig)

        var fullResponse = ""
        var llmError: Error?

        // 使用 streaming 接口，收集完整响应
        try await service.sendMessage(
            messages: [ChatMessage.user(prompt)],
            systemPrompt: "你是一个学术论文分析助手。请严格按照用户要求的 JSON 格式返回结果。",
            onToken: { token in
                fullResponse += token
            },
            onComplete: {
                // 完成
            },
            onError: { error in
                llmError = error
            }
        )

        if let error = llmError {
            throw GenerationError.llmError(error.localizedDescription)
        }

        guard !fullResponse.isEmpty else {
            throw GenerationError.llmError("AI 返回了空响应")
        }

        return fullResponse
    }

    /// 解析 LLM 返回的 JSON 响应
    private static func parseResponse(_ response: String, paper: PaperItem) throws -> GenerationResult {
        // 尝试提取 JSON（AI 可能返回额外文本或 markdown 代码块）
        let jsonString = extractJSON(from: response)

        guard let data = jsonString.data(using: .utf8) else {
            throw GenerationError.parseError("无法将响应转换为数据")
        }

        // 尝试解析为字典
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GenerationError.parseError("AI 返回的不是有效的 JSON 格式")
        }

        // 构建 PaperBrief
        var brief = PaperBrief()
        brief.title = (dict["title"] as? String) ?? paper.title
        brief.authors = (dict["authors"] as? String) ?? paper.authors
        brief.researchQuestion = (dict["researchQuestion"] as? String) ?? ""
        brief.methodology = (dict["methodology"] as? String) ?? ""
        brief.keyFindings = (dict["keyFindings"] as? String) ?? ""
        brief.contributions = (dict["contributions"] as? String) ?? ""
        brief.limitations = (dict["limitations"] as? String) ?? ""
        brief.keywords = (dict["keywords"] as? [String]) ?? []
        brief.generatedAt = Date()
        brief.isComplete = true

        // 提取 tags
        let tags = (dict["tags"] as? [String]) ?? brief.keywords.prefix(3).map { String($0) }

        return GenerationResult(brief: brief, tags: tags)
    }

    /// 从 AI 响应中提取 JSON 部分（处理 markdown 代码块等）
    private static func extractJSON(from response: String) -> String {
        var text = response.trimmingCharacters(in: .whitespacesAndNewlines)

        // 移除 markdown 代码块标记
        if text.hasPrefix("```json") {
            text = String(text.dropFirst(7))
        } else if text.hasPrefix("```") {
            text = String(text.dropFirst(3))
        }
        if text.hasSuffix("```") {
            text = String(text.dropLast(3))
        }

        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // 尝试找到第一个 { 和最后一个 }
        if let firstBrace = text.firstIndex(of: "{"),
           let lastBrace = text.lastIndex(of: "}") {
            text = String(text[firstBrace...lastBrace])
        }

        return text
    }
}
