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
    var isBuiltIn: Bool = true

    static func custom(chinese: String) -> PresetQuestion {
        PresetQuestion(english: chinese, chinese: chinese, isBuiltIn: false)
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
            chinese: "总结这篇论文的主要贡献"
        ),
        PresetQuestion(
            english: "What is the research methodology used?",
            chinese: "这篇论文使用了什么研究方法？"
        ),
        PresetQuestion(
            english: "List the main conclusions",
            chinese: "列出主要结论"
        ),
        PresetQuestion(
            english: "What are the limitations of this study?",
            chinese: "这项研究有哪些局限性？"
        ),
        PresetQuestion(
            english: "Explain the key findings",
            chinese: "解释主要发现"
        ),
        PresetQuestion(
            english: "How is the introduction written? What writing tips can I learn?",
            chinese: "Introduction 是如何行文的？我可以学到哪些写作技巧？"
        )
    ]

    /// 获取所有预设问题（内置 + 用户自定义）
    static var allPresetQuestions: [PresetQuestion] {
        var questions = builtInQuestions
        questions.append(contentsOf: AppSettings.shared.customQuickActions)
        return questions
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
        
        // Clear from database too? Or just create new session?
        // For now, let's just clear memory. 
        // If user wants to delete history, we need a dedicated delete function.
        // But the previous behavior was "reset for new document".
        // With persistence, "clearChat" usually means "Start New Conversation" or "Delete".
        // Let's assume it's "Start Fresh" for now, but keep old session in history?
        // Actually, ContentView calls this on doc change.
        currentSession = nil 
    }

    func updateTokenEstimate(document: PDFDocument?, currentPageIndex: Int) {
        guard let document = document else {
            estimatedTokens = 0
            return
        }

        Task {
            let content = await extractPDFContent(from: document, currentPageIndex: currentPageIndex, query: "")
            await MainActor.run {
                estimatedTokens = textExtractor.estimateTokenCount(content)
            }
        }
    }

    // MARK: - Private Methods

    private func extractPDFContent(from document: PDFDocument, currentPageIndex: Int, query: String) async -> String {
        switch pageRangeOption {
        case .all:
            // Try RAG first if we have context
            if !query.isEmpty {
                // Smart Context: If text is selected, prioritize it!
                if let selection = currentSelection, !selection.isEmpty {
                    print("Using Smart Context (Selection)")
                    return "--- User Selected Text (High Prority) ---\n\(selection)\n\n--- Document Context ---\n" + textExtractor.extractTextWithBudget(from: document, tokenBudget: settings.llmContextTokenBudget / 2).text
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
