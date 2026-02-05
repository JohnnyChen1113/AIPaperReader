//
//  ContentView.swift
//  AIPaperReader
//
//  Created by JohnnyChan on 2/4/26.
//

import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var viewModel = PDFReaderViewModel()
    @StateObject private var chatViewModel = ChatViewModel()
    @ObservedObject private var settings = AppSettings.shared
    @State private var sidebarVisibility: NavigationSplitViewVisibility = .all
    @State private var selectedSidebarTab: SidebarTab = .thumbnails
    @State private var isShowingSearch: Bool = false
    @State private var isDropTargeted: Bool = false
    @State private var showChatPanel: Bool = true
    @State private var showSetupGuide: Bool = false
    @State private var displayMode: PDFDisplayMode = .singlePageContinuous

    /// 检查是否需要设置（没有配置API Key）
    private var needsSetup: Bool {
        let apiKey = AppSettings.shared.llmApiKey
        return apiKey.isEmpty
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $sidebarVisibility) {
            SidebarView(
                document: viewModel.document,
                currentPageIndex: $viewModel.currentPageIndex,
                selectedTab: $selectedSidebarTab
            )
        } detail: {
            HSplitView {
                // Main content area (PDF + optional chat)
                ZStack {
                    if viewModel.document != nil {
                        VStack(spacing: 0) {
                            // PDF Toolbar
                            PDFToolbarView(
                                scaleFactor: $viewModel.scaleFactor,
                                displayMode: $displayMode,
                                currentPageIndex: $viewModel.currentPageIndex,
                                pageCount: viewModel.document?.pageCount ?? 0,
                                onGoToPage: { pageIndex in
                                    viewModel.goToPage(pageIndex)
                                }
                            )

                            Divider()

                            // Search bar
                            if isShowingSearch {
                                SearchBar(
                                    searchText: $viewModel.searchText,
                                    isShowing: $isShowingSearch,
                                    onSearch: viewModel.search
                                )
                                .transition(.move(edge: .top).combined(with: .opacity))
                            }

                            // PDF Reader
                            PDFReaderView(
                                document: viewModel.document,
                                currentPageIndex: $viewModel.currentPageIndex,
                                scaleFactor: $viewModel.scaleFactor,
                                searchText: $viewModel.searchText,
                                displayMode: $displayMode,
                                onSelectionChanged: { text in
                                    viewModel.handleSelectionChanged(text)
                                    chatViewModel.currentSelection = text
                                },
                                onContextAction: { action, text in
                                    handleContextAction(action, text: text)
                                },
                                onAnnotate: { annotationType in
                                    // 可以在这里处理标注事件，例如显示提示
                                    print("Added annotation: \(annotationType.rawValue)")
                                }
                            )
                        }
                    } else {
                        // Welcome view when no document is open
                        WelcomeView(
                            needsSetup: needsSetup,
                            onOpenFile: viewModel.openDocument,
                            onSetup: { showSetupGuide = true }
                        )
                    }

                    // Drop overlay
                    if isDropTargeted {
                        DropOverlayView()
                    }
                }
                .frame(minWidth: 400, minHeight: 400)

                // Chat panel (right side)
                if showChatPanel {
                    ChatPanelView(
                        viewModel: chatViewModel,
                        document: viewModel.document,
                        currentPageIndex: viewModel.currentPageIndex
                    )
                    .frame(minWidth: 300, idealWidth: 400, maxWidth: 500)
                }
            }
        }
        .toolbar {
            PDFToolbar(
                viewModel: viewModel,
                isShowingSearch: $isShowingSearch,
                sidebarVisibility: $sidebarVisibility
            )

            ToolbarItem(placement: .automatic) {
                Divider()
            }

            ToolbarItem(placement: .automatic) {
                Button(action: { showChatPanel.toggle() }) {
                    Image(systemName: showChatPanel ? "bubble.left.and.bubble.right.fill" : "bubble.left.and.bubble.right")
                }
                .help("menu_toggle_chat")
            }
        }
        .onDrop(of: [.pdf, .fileURL], isTargeted: $isDropTargeted) { providers in
            viewModel.handleDrop(providers: providers)
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .animation(.easeInOut(duration: 0.2), value: isShowingSearch)
        .animation(.easeInOut(duration: 0.2), value: showChatPanel)
        // Handle menu commands via notifications
        .onReceive(NotificationCenter.default.publisher(for: .openDocument)) { _ in
            viewModel.openDocument()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openDocumentURL)) { notification in
            if let url = notification.object as? URL {
                viewModel.loadDocument(from: url)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .zoomIn)) { _ in
            viewModel.zoomIn()
        }
        .onReceive(NotificationCenter.default.publisher(for: .zoomOut)) { _ in
            viewModel.zoomOut()
        }
        .onReceive(NotificationCenter.default.publisher(for: .zoomToFit)) { _ in
            viewModel.zoomToFit()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleSearch)) { _ in
            isShowingSearch.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleChat)) { _ in
            showChatPanel.toggle()
        }
        // Clear chat when document changes
        .onChange(of: viewModel.documentModel?.id) { _, _ in
            chatViewModel.clearChat()
            if let document = viewModel.document {
                chatViewModel.ingestDocument(document)
            }
        }
        // 设置向导
        .sheet(isPresented: $showSetupGuide) {
            SetupGuideView()
        }
        // 首次启动时如果需要设置，自动显示向导
        .onAppear {
            if needsSetup {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showSetupGuide = true
                }
            }
        }
    }

    /// 处理右键菜单的AI操作
    private func handleContextAction(_ action: PDFContextAction, text: String) {
        // 确保聊天面板打开
        if !showChatPanel {
            showChatPanel = true
        }

        // 根据操作类型构建提示语
        // 根据操作类型构建提示语
        var prompt: String
        switch action {
        case .translateToChinese:
            prompt = AppSettings.shared.promptTranslate
        case .explain:
            prompt = AppSettings.shared.promptExplain
        case .summarize:
            prompt = AppSettings.shared.promptSummarize
        case .searchWeb, .copy:
            return // 这些操作在 PDFView 中直接处理
        }
        
        // Replace placeholder
        prompt = prompt.replacingOccurrences(of: "{selection}", with: text)

        // 发送到聊天
        chatViewModel.inputText = prompt
        chatViewModel.sendMessage(document: viewModel.document, currentPageIndex: viewModel.currentPageIndex)
    }
}

struct WelcomeView: View {
    var needsSetup: Bool
    var onOpenFile: () -> Void
    var onSetup: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)

            VStack(spacing: 8) {
                Text("app_name")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("app_subtitle")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // 大模型配置卡片（始终显示，状态不同样式不同）
            ModelSetupCard(needsSetup: needsSetup, onSetup: onSetup)

            // 开始使用按钮
            VStack(spacing: 16) {
                Button(action: onOpenFile) {
                    HStack {
                        Image(systemName: "folder")
                        Text("welcome_open_pdf")
                    }
                    .frame(minWidth: 160)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Text("welcome_drag_drop")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // 快捷键提示
            VStack(alignment: .leading, spacing: 8) {
                Text("welcome_shortcuts")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                Group {
                    ShortcutHintRow(keys: "⌘O", description: NSLocalizedString("shortcut_open", comment: ""))
                    ShortcutHintRow(keys: "⌘F", description: NSLocalizedString("shortcut_search", comment: ""))
                    ShortcutHintRow(keys: "⌘+/⌘-", description: NSLocalizedString("shortcut_zoom", comment: ""))
                    ShortcutHintRow(keys: "⌘L", description: NSLocalizedString("shortcut_chat", comment: ""))
                    ShortcutHintRow(keys: "⌘,", description: NSLocalizedString("shortcut_settings", comment: ""))
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 大模型配置卡片（始终显示）
struct ModelSetupCard: View {
    var needsSetup: Bool
    var onSetup: () -> Void
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        VStack(spacing: 12) {
            if needsSetup {
                // 未配置状态 - 醒目提示
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.orange)
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("setup_required_title")
                            .fontWeight(.semibold)
                        Text("setup_required_desc")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }

                Button(action: onSetup) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("setup_button_configure")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                // 已配置状态 - 显示当前配置
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("setup_configured_title")
                            .fontWeight(.medium)
                        Text("\(settings.llmProvider.displayName) - \(formatModelName(settings.llmModelName))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()

                    Button(action: onSetup) {
                        HStack(spacing: 4) {
                            Image(systemName: "gearshape")
                            Text("setup_button_change")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding()
        .frame(maxWidth: 350)
        .background(needsSetup ? Color.orange.opacity(0.1) : Color.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(needsSetup ? Color.orange.opacity(0.3) : Color.green.opacity(0.3), lineWidth: 1)
        )
    }

    private func formatModelName(_ name: String) -> String {
        let parts = name.components(separatedBy: "/")
        return parts.last ?? name
    }
}

/// 旧版设置提示卡片（保留兼容）
struct SetupPromptCard: View {
    var onSetup: () -> Void

    var body: some View {
        ModelSetupCard(needsSetup: true, onSetup: onSetup)
    }
}

struct ShortcutHintRow: View {
    let keys: String
    let description: String

    var body: some View {
        HStack {
            Text(keys)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 4))

            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct DropOverlayView: View {
    var body: some View {
        ZStack {
            Color.accentColor.opacity(0.1)

            VStack(spacing: 16) {
                Image(systemName: "arrow.down.doc")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)

                Text("welcome_drag_drop")
                    .font(.headline)
                    .foregroundColor(.accentColor)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [10]))
                .padding(20)
        )
    }
}

#Preview {
    ContentView()
}
