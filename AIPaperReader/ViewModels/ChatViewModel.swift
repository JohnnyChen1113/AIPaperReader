//
//  ChatViewModel.swift
//  AIPaperReader
//
//  Created by Claude on 2/4/26.
//

import SwiftUI
import SwiftData
import PDFKit
import Combine

enum PageRangeOption: String, CaseIterable {
    case all = "Full Document"
    case currentPage = "Current Page"
    case custom = "Custom Range"

    var displayName: String {
        switch self {
        case .all: return "全文"
        case .currentPage: return "当前页"
        case .custom: return "自定义范围"
        }
    }
}

/// 预设问题结构
struct PresetQuestion: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var english: String
    var chinese: String
    var icon: String = "arrow.right.circle"
    var isBuiltIn: Bool = true

    static func custom(chinese: String) -> PresetQuestion {
        PresetQuestion(english: chinese, chinese: chinese, icon: "star.fill", isBuiltIn: false)
    }
}

@MainActor
class ChatViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var messages: [ChatMessage] = [] {
        didSet {
           // Autosave logic could go here, but doing it explicitly is safer
        }
    }
    @Published var inputText: String = ""
    @Published var isGenerating: Bool = false
    @Published var currentStreamingText: String = ""
    @Published var errorMessage: String?

    @Published var pageRangeOption: PageRangeOption = .all
    @Published var customPageRange: String = ""
    @Published var estimatedTokens: Int = 0
    @Published var ingestionProgress: Double = 0.0
    @Published var isIngesting: Bool = false
    @Published var currentSelection: String?
    @Published var isSearchingContext: Bool = false

    // MARK: - Private Properties

    private var llmService: LLMServiceProtocol?
    private let textExtractor = PDFTextExtractor()
    private let contextManager = ContextManager()
    private var currentTask: Task<Void, Never>?
    private let settings = AppSettings.shared
    
    // Persistence
    var modelContext: ModelContext?
    var currentSession: ChatSession?

    // MARK: - Preset Questions (中英双语)

    static let builtInQuestions: [PresetQuestion] = [
        PresetQuestion(
            english: "Summarize the main contributions of this paper",
            chinese: "总结这篇论文的主要贡献",
            icon: "star.fill"
        ),
        PresetQuestion(
            english: "What is the research methodology used?",
            chinese: "这篇论文使用了什么研究方法？",
            icon: "testtube.2"
        ),
        PresetQuestion(
            english: "List the main conclusions",
            chinese: "列出主要结论",
            icon: "checkmark.seal.fill"
        ),
        PresetQuestion(
            english: "What are the limitations of this study?",
            chinese: "这项研究有哪些局限性？",
            icon: "exclamationmark.triangle.fill"
        ),
        PresetQuestion(
            english: "Explain the key findings",
            chinese: "解释主要发现",
            icon: "lightbulb.fill"
        ),
        PresetQuestion(
            english: "How is the introduction written? What writing tips can I learn?",
            chinese: "Introduction 是如何行文的？我可以学到哪些写作技巧？",
            icon: "pencil.and.outline"
        )
    ]

    /// 获取所有预设问题（仅内置问题，自定义操作现在是独立的 CustomQuickAction）
    static var allPresetQuestions: [PresetQuestion] {
        return builtInQuestions
    }

    /// 旧版兼容：只返回英文问题
    static var presetQuestions: [String] {
        builtInQuestions.map { $0.english }
    }

    private var cancellables = Set<AnyCancellable>()

    init() {
        updateLLMService()
        
        // bind context manager progress
        contextManager.$ingestionProgress
            .receive(on: RunLoop.main)
            .assign(to: \.ingestionProgress, on: self)
            .store(in: &cancellables)
            
        contextManager.$isIngesting
            .receive(on: RunLoop.main)
            .assign(to: \.isIngesting, on: self)
            .store(in: &cancellables)
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    func loadSession(for documentId: String) {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<ChatSession>(
            predicate: #Predicate { $0.documentId == documentId },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        do {
            if let existingSession = try context.fetch(descriptor).first {
                self.currentSession = existingSession
                // Sort messages by timestamp
                let sortedMessages = existingSession.messages.sorted { $0.timestamp < $1.timestamp }
                self.messages = sortedMessages.map { model in
                    if model.role == .user {
                        return ChatMessage.user(model.content)
                    } else {
                        return ChatMessage.assistant(model.content)
                    }
                }
            } else {
                // Create new session
                let newSession = ChatSession(documentId: documentId)
                context.insert(newSession)
                self.currentSession = newSession
                self.messages = []
            }
        } catch {
            print("Failed to load session: \(error)")
        }
    }
    
    func saveMessage(_ message: ChatMessage) {
        guard let context = modelContext, let session = currentSession else { return }
        
        // Convert UI model to SwiftData model
        let msgModel = ChatMessageModel(
            role: message.role,
            content: message.content
        )
        msgModel.session = session // Set relationship (assuming optional or set 'messages' array)
        session.messages.append(msgModel) // Add to relationship
        
        do {
            try context.save()
        } catch {
            print("Failed to save message: \(error)")
        }
    }

    func updateLLMService() {
        let config = settings.llmConfig
        llmService = LLMServiceFactory.create(config: config)
    }

    func ingestDocument(_ document: PDFDocument) {
        Task {
            await contextManager.ingest(document: document)
        }
    }

    // MARK: - Public Methods

    func sendMessage(document: PDFDocument?, currentPageIndex: Int) {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let document = document else {
            errorMessage = "Please open a PDF document first"
            return
        }

        let userMessageContent = inputText
        inputText = ""

        // Add user message
        let userMessage = ChatMessage.user(userMessageContent)
        messages.append(userMessage)
        saveMessage(userMessage)

        // Start generating
        isGenerating = true
        currentStreamingText = ""
        errorMessage = nil

        currentTask = Task {
            do {
                // Extract PDF content based on page range
                await MainActor.run { self.isSearchingContext = true }
                let pdfContent = await extractPDFContent(from: document, currentPageIndex: currentPageIndex, query: userMessageContent)
                await MainActor.run { self.isSearchingContext = false }

                // Build system prompt
                let systemPrompt = buildSystemPrompt(pdfContent: pdfContent)

                // Update LLM service with latest config
                updateLLMService()

                guard let service = llmService else {
                    throw LLMError.connectionFailed
                }

                // Send to LLM
                try await service.sendMessage(
                    messages: messages,
                    systemPrompt: systemPrompt,
                    onToken: { [weak self] token in
                        self?.currentStreamingText += token
                    },
                    onComplete: { [weak self] in
                        self?.finalizeResponse()
                    },
                    onError: { [weak self] error in
                        self?.handleError(error)
                    }
                )
            } catch {
                handleError(error)
            }
        }
    }

    func sendPresetQuestion(_ question: String, document: PDFDocument?, currentPageIndex: Int) {
        inputText = question
        sendMessage(document: document, currentPageIndex: currentPageIndex)
    }

    func stopGenerating() {
        currentTask?.cancel()
        llmService?.cancel()
        finalizeResponse()
    }

    func clearChat() {
        messages.removeAll()
        currentStreamingText = ""
        errorMessage = nil
        contextManager.clear()
        currentSession = nil
    }

    /// 开始新的聊天会话（保留旧的历史）
    func startNewChat(for documentId: String) {
        guard let context = modelContext else { return }

        // 创建新的会话
        let newSession = ChatSession(documentId: documentId, title: "New Chat \(Date().formatted(date: .abbreviated, time: .shortened))")
        context.insert(newSession)
        self.currentSession = newSession
        self.messages = []

        do {
            try context.save()
        } catch {
            print("Failed to create new session: \(error)")
        }
    }

    /// 删除指定的聊天会话
    func deleteSession(_ session: ChatSession) {
        guard let context = modelContext else { return }

        // 如果删除的是当前会话，清空当前聊天
        if session.id == currentSession?.id {
            messages.removeAll()
            currentSession = nil
        }

        context.delete(session)

        do {
            try context.save()
        } catch {
            print("Failed to delete session: \(error)")
        }
    }

    /// 获取当前文档的所有历史会话
    func fetchSessions(for documentId: String) -> [ChatSession] {
        guard let context = modelContext else { return [] }

        let descriptor = FetchDescriptor<ChatSession>(
            predicate: #Predicate { $0.documentId == documentId },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        do {
            return try context.fetch(descriptor)
        } catch {
            print("Failed to fetch sessions: \(error)")
            return []
        }
    }

    /// 切换到指定的会话
    func switchToSession(_ session: ChatSession) {
        self.currentSession = session
        // 按时间排序消息
        let sortedMessages = session.messages.sorted { $0.timestamp < $1.timestamp }
        self.messages = sortedMessages.map { model in
            if model.role == .user {
                return ChatMessage.user(model.content)
            } else {
                return ChatMessage.assistant(model.content)
            }
        }
    }

    // MARK: - Chat Export

    /// 将当前聊天导出为 Markdown 格式
    func exportChatAsMarkdown() -> String {
        var md = "# 聊天记录\n\n"
        if let session = currentSession {
            md += "- 文档: \(session.documentId)\n"
            md += "- 日期: \(Date().formatted(date: .long, time: .shortened))\n\n"
        }
        md += "---\n\n"

        for message in messages {
            switch message.role {
            case .user:
                md += "## 🧑 用户\n\n\(message.content)\n\n---\n\n"
            case .assistant:
                md += "## 🤖 AI 助手\n\n\(message.content)\n\n---\n\n"
            case .system:
                break
            }
        }
        return md
    }

    /// 导出聊天记录到文件
    func exportChatToFile() {
        guard !messages.isEmpty else { return }
        let markdown = exportChatAsMarkdown()
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "chat-export-\(Date().formatted(date: .numeric, time: .omitted)).md"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? markdown.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    func updateTokenEstimate(document: PDFDocument?, currentPageIndex: Int) {
        guard let document = document else {
            estimatedTokens = 0
            return
        }

        Task {
            let content = await extractPDFContent(from: document, currentPageIndex: currentPageIndex, query: "")

            await MainActor.run {
                // 计算 PDF 内容的 token
                let contentTokens = textExtractor.estimateTokenCount(content)

                // 计算 system prompt 的 token（不包含 PDF 内容占位符）
                let systemPromptBase = settings.systemPrompt.replacingOccurrences(of: "{pdf_content}", with: "")
                let systemPromptTokens = textExtractor.estimateTokenCount(systemPromptBase)

                // 计算历史对话的 token
                let historyTokens = messages.reduce(0) { total, message in
                    total + textExtractor.estimateTokenCount(message.content)
                }

                // 总计
                estimatedTokens = contentTokens + systemPromptTokens + historyTokens
            }
        }
    }

    // MARK: - Private Methods

    private func extractPDFContent(from document: PDFDocument, currentPageIndex: Int, query: String) async -> String {
        // 捕获选中的文本（用完后清空）
        let selectionText = currentSelection

        switch pageRangeOption {
        case .all:
            // Try RAG first if we have context
            if !query.isEmpty {
                // Smart Context: If text is selected, prioritize it!
                if let selection = selectionText, !selection.isEmpty {
                    print("Using Smart Context (Selection)")
                    // 清空选择，避免后续提问仍然使用
                    await MainActor.run { self.currentSelection = nil }
                    return "--- User Selected Text (High Priority) ---\n\(selection)\n\n--- Document Context ---\n" + textExtractor.extractTextWithBudget(from: document, tokenBudget: settings.llmContextTokenBudget / 2).text
                }

                let relevantChunks = await contextManager.retrieve(query: query)
                if !relevantChunks.isEmpty {
                    print("Using RAG: Found \(relevantChunks.count) relevant chunks")
                    return relevantChunks.map { "--- Page \($0.pageRange.lowerBound + 1)-\($0.pageRange.upperBound) ---\n\($0.text)" }.joined(separator: "\n\n")
                }
            }

            // Fallback to token budget extraction (e.g. for summarization or no matches)
            let result = textExtractor.extractTextWithBudget(
                from: document,
                tokenBudget: settings.llmContextTokenBudget
            )
            return result.text

        case .currentPage:
            let result = textExtractor.extractText(
                from: document,
                pages: currentPageIndex..<(currentPageIndex + 1)
            )
            return result.text

        case .custom:
            if let result = textExtractor.extractText(from: document, rangeString: customPageRange) {
                return result.text
            }
            // Fall back to current page if custom range is invalid
            let result = textExtractor.extractText(
                from: document,
                pages: currentPageIndex..<(currentPageIndex + 1)
            )
            return result.text
        }
    }

    private func buildSystemPrompt(pdfContent: String) -> String {
        var prompt = settings.systemPrompt

        // Replace placeholder with actual content
        prompt = prompt.replacingOccurrences(of: "{pdf_content}", with: pdfContent)

        return prompt
    }

    private func finalizeResponse() {
        if !currentStreamingText.isEmpty {
            let assistantMessage = ChatMessage.assistant(currentStreamingText)
            messages.append(assistantMessage)
            saveMessage(assistantMessage)
        }
        currentStreamingText = ""
        isGenerating = false
    }

    private func handleError(_ error: Error) {
        isGenerating = false

        if let llmError = error as? LLMError {
            switch llmError {
            case .cancelled:
                // Don't show error for cancellation
                return
            default:
                errorMessage = llmError.localizedDescription
            }
        } else {
            errorMessage = error.localizedDescription
        }

        // Add error message to chat if there was streaming content
        if !currentStreamingText.isEmpty {
            currentStreamingText += "\n\n[Error: \(errorMessage ?? "Unknown error")]"
            finalizeResponse()
        }
    }
}
