//
//  ChatPanelView.swift
//  AIPaperReader
//
//  Created by Claude on 2/4/26.
//

import SwiftUI
import PDFKit

struct ChatPanelView: View {
    @ObservedObject var viewModel: ChatViewModel
    let document: PDFDocument?
    let currentPageIndex: Int
    
    @Environment(\.modelContext) private var modelContext

    @State private var showQuickActionSettings: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            ChatPanelHeader(
                hasMessages: !viewModel.messages.isEmpty,
                isIngesting: viewModel.isIngesting,
                ingestionProgress: viewModel.ingestionProgress,
                onClear: viewModel.clearChat,
                onShowSettings: { showQuickActionSettings = true }
            )

            Divider()

            // Page range selector
            if document != nil {
                PageRangeSelectorView(
                    pageRangeOption: $viewModel.pageRangeOption,
                    customPageRange: $viewModel.customPageRange,
                    estimatedTokens: viewModel.estimatedTokens,
                    pageCount: document?.pageCount ?? 0
                )
                .onChange(of: viewModel.pageRangeOption) { _, _ in
                    viewModel.updateTokenEstimate(document: document, currentPageIndex: currentPageIndex)
                }
                .onChange(of: viewModel.customPageRange) { _, _ in
                    viewModel.updateTokenEstimate(document: document, currentPageIndex: currentPageIndex)
                }

                Divider()
            }

            // Messages area
            if viewModel.messages.isEmpty && !viewModel.isGenerating {
                BilingualEmptyStateView(
                    hasDocument: document != nil,
                    presetQuestions: ChatViewModel.allPresetQuestions,
                    onSelectPreset: { question in
                        viewModel.sendPresetQuestion(question, document: document, currentPageIndex: currentPageIndex)
                    }
                )
            } else {
                MessagesScrollView(viewModel: viewModel)
            }

            // Error message
            if let error = viewModel.errorMessage {
                ErrorBannerView(message: error) {
                    viewModel.errorMessage = nil
                }
            }

            Divider()

            // Preset questions (显示在输入框上方)
            if !viewModel.messages.isEmpty && !viewModel.isGenerating {
                BilingualPresetQuestionsView(
                    questions: ChatViewModel.allPresetQuestions
                ) { question in
                    viewModel.sendPresetQuestion(question, document: document, currentPageIndex: currentPageIndex)
                }

                Divider()
            }

            // Input area
            ChatInputView(
                inputText: $viewModel.inputText,
                isGenerating: viewModel.isGenerating,
                onSend: {
                    viewModel.sendMessage(document: document, currentPageIndex: currentPageIndex)
                },
                onStop: viewModel.stopGenerating
            )
        }
        .frame(minWidth: 300, idealWidth: 400, maxWidth: 500)
        .onAppear {
            viewModel.setModelContext(modelContext)
            if let document = document, let documentURL = document.documentURL {
                viewModel.loadSession(for: documentURL.absoluteString)
            }
            viewModel.updateTokenEstimate(document: document, currentPageIndex: currentPageIndex)
        }
        .onChange(of: document) { _, newDoc in
            if let newDoc = newDoc, let documentURL = newDoc.documentURL {
                viewModel.loadSession(for: documentURL.absoluteString)
            }
            viewModel.updateTokenEstimate(document: newDoc, currentPageIndex: currentPageIndex)
        }
        .onChange(of: currentPageIndex) { _, newIndex in
            if viewModel.pageRangeOption == .currentPage {
                viewModel.updateTokenEstimate(document: document, currentPageIndex: newIndex)
            }
        }
        .sheet(isPresented: $showQuickActionSettings) {
            QuickActionSettingsView()
        }
    }
}

// MARK: - Chat Panel Header

struct ChatPanelHeader: View {
    var hasMessages: Bool
    var isIngesting: Bool = false
    var ingestionProgress: Double = 0.0
    var onClear: () -> Void
    var onShowSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("chat_title", systemImage: "bubble.left.and.bubble.right")
                    .font(.headline)

                Spacer()

                Button(action: onShowSettings) {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("chat_quick_actions")

                if hasMessages {
                    Button(action: onClear) {
                        Image(systemName: "trash")
                        .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("chat_clear")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // Progress Bar
            if isIngesting {
                ProgressView(value: ingestionProgress)
                    .progressViewStyle(.linear)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .tint(.accentColor)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}

// MARK: - Messages Scroll View

struct MessagesScrollView: View {
    @ObservedObject var viewModel: ChatViewModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.messages) { message in
                        ChatBubbleView(message: message, isStreaming: false)
                            .id(message.id)
                    }

                    // Streaming message
                    if viewModel.isGenerating && (viewModel.isSearchingContext || !viewModel.currentStreamingText.isEmpty) {
                        StreamingMessageView(
                            content: viewModel.currentStreamingText,
                            isSearching: viewModel.isSearchingContext
                        )
                            .id("streaming")
                    }
                }
                .padding(.vertical, 8)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.currentStreamingText) { _, _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if viewModel.isGenerating {
            // No animation for streaming to prevent lag
            proxy.scrollTo("streaming", anchor: .bottom)
        } else {
            withAnimation(.easeOut(duration: 0.2)) {
                if let lastMessage = viewModel.messages.last {
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
        }
    }
}

// MARK: - Empty State View (保留旧版兼容)

struct EmptyStateView: View {
    var hasDocument: Bool
    var presetQuestions: [String]
    var onSelectPreset: (String) -> Void

    var body: some View {
        BilingualEmptyStateView(
            hasDocument: hasDocument,
            presetQuestions: ChatViewModel.allPresetQuestions,
            onSelectPreset: onSelectPreset
        )
    }
}

// MARK: - Bilingual Empty State View (中英双语)

struct BilingualEmptyStateView: View {
    var hasDocument: Bool
    var presetQuestions: [PresetQuestion]
    var onSelectPreset: (String) -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            if hasDocument {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary.opacity(0.5))

                Text("chat_empty_doc_desc")
                    .font(.headline)
                    .foregroundColor(.secondary)

                Text("chat_preset_title")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(presetQuestions.prefix(8)) { question in
                            BilingualQuestionButton(question: question, onSelect: onSelectPreset)
                        }
                    }
                    .padding()
                }
                .background(Color.secondary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .frame(maxHeight: 280)
            } else {
                Image(systemName: "doc.text")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary.opacity(0.5))

                Text("chat_empty_doc")
                    .font(.headline)
                    .foregroundColor(.secondary)

                Text("chat_empty_doc_desc")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

// MARK: - Bilingual Question Button

struct BilingualQuestionButton: View {
    let question: PresetQuestion
    var onSelect: (String) -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: { onSelect(question.chinese) }) {
            VStack(alignment: .leading, spacing: 2) {
                // 英文
                if question.isBuiltIn {
                    Text(question.english)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                // 中文
                HStack {
                    Image(systemName: question.isBuiltIn ? "arrow.right.circle" : "star.fill")
                        .foregroundColor(question.isBuiltIn ? .accentColor : .orange)
                        .font(.caption)
                    Text(question.chinese)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Bilingual Preset Questions View (显示在输入框上方的快捷按钮)

struct BilingualPresetQuestionsView: View {
    let questions: [PresetQuestion]
    var onSelect: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(questions.prefix(6)) { question in
                    Button(action: { onSelect(question.chinese) }) {
                        Text(question.chinese)
                            .font(.caption)
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - 旧版 PresetQuestionsView 兼容
struct PresetQuestionsView: View {
    let questions: [String]
    var onSelect: (String) -> Void

    var body: some View {
        BilingualPresetQuestionsView(
            questions: ChatViewModel.allPresetQuestions,
            onSelect: onSelect
        )
    }
}

// MARK: - Error Banner View

struct ErrorBannerView: View {
    var message: String
    var onDismiss: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.orange)

            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.orange.opacity(0.1))
    }
}

// MARK: - Quick Action Settings View (自定义快捷操作设置)

struct QuickActionSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = AppSettings.shared

    @State private var newActionText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("chat_quick_actions")
                    .font(.headline)
                Spacer()
                Button("chat_done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            // 内置问题（不可删除）
            Form {
                Section {
                    ForEach(ChatViewModel.builtInQuestions) { question in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(question.chinese)
                                .fontWeight(.medium)
                            Text(question.english)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("chat_builtin_questions")
                } footer: {
                    Text("chat_builtin_desc")
                }

                // 自定义问题（可删除）
                Section {
                    ForEach(Array(settings.customQuickActions.enumerated()), id: \.element.id) { index, question in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(question.chinese)
                                    .fontWeight(.medium)
                            }
                            Spacer()
                            Button(action: {
                                settings.removeCustomQuickAction(at: index)
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }

                    if settings.customQuickActions.isEmpty {
                        Text("chat_no_custom")
                            .foregroundColor(.secondary)
                            .italic()
                    }
                } header: {
                    Text("chat_custom_questions")
                }

                // 添加新问题
                Section {
                    HStack {
                        TextField("chat_enter_new", text: $newActionText)
                            .textFieldStyle(.roundedBorder)

                        Button(action: addNewAction) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                        }
                        .disabled(newActionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("chat_add_new")
                } footer: {
                    Text("chat_add_desc")
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 450, height: 500)
    }

    private func addNewAction() {
        let trimmed = newActionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        settings.addCustomQuickAction(trimmed)
        newActionText = ""
    }
}

#Preview {
    ChatPanelView(
        viewModel: ChatViewModel(),
        document: nil,
        currentPageIndex: 0
    )
}
