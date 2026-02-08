//
//  ContentView.swift
//  AIPaperReader
//
//  Created by JohnnyChan on 2/4/26.
//

import SwiftUI
import PDFKit
import UniformTypeIdentifiers

/// 应用模式
enum AppMode {
    case library
    case reader
}

struct ContentView: View {
    @StateObject private var tabManager = TabManager()
    @StateObject private var libraryViewModel = LibraryViewModel()
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.modelContext) private var modelContext
    @State private var appMode: AppMode = .library
    @State private var selectedLibrarySection: LibrarySection = .all
    @State private var sidebarVisibility: NavigationSplitViewVisibility = .all
    @State private var selectedSidebarTab: SidebarTab = .thumbnails
    @State private var isShowingSearch: Bool = false
    @State private var isDropTargeted: Bool = false
    @State private var showChatPanel: Bool = true
    @State private var showSetupGuide: Bool = false
    @State private var displayMode: PDFDisplayMode = .singlePageContinuous
    @State private var requestedPageJump: Int? = nil
    @State private var requestedRotation: Int? = nil
    @State private var requestedZoomFit: ZoomFitMode? = nil

    /// 当前活跃 Tab 的 ViewModel（便捷访问）
    private var viewModel: PDFReaderViewModel? {
        tabManager.activeTab?.viewModel
    }

    private var chatViewModel: ChatViewModel? {
        tabManager.activeTab?.chatViewModel
    }

    /// 检查是否需要设置（没有配置API Key）
    private var needsSetup: Bool {
        let apiKey = AppSettings.shared.llmApiKey
        return apiKey.isEmpty
    }

    var body: some View {
        mainView
            .setupTabNotificationHandlers(
                tabManager: tabManager,
                isShowingSearch: $isShowingSearch,
                showChatPanel: $showChatPanel,
                requestedPageJump: $requestedPageJump
            )
            .sheet(isPresented: $showSetupGuide) {
                SetupGuideView()
            }
            .onAppear {
                libraryViewModel.setModelContext(modelContext)
                tabManager.setModelContext(modelContext)
                if needsSetup {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showSetupGuide = true
                    }
                }
            }
            .onChange(of: tabManager.activeTabId) { _, _ in
                // 切换到 reader 模式并重置搜索
                if tabManager.activeTab != nil {
                    appMode = .reader
                }
                isShowingSearch = false
                requestedPageJump = nil
            }
            .onChange(of: tabManager.tabs.count) { _, newCount in
                // 所有 Tab 关闭后回到文献库
                if newCount == 0 {
                    appMode = .library
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .toggleLibrary)) { _ in
                appMode = (appMode == .library) ? .reader : .library
            }
            .onChange(of: appMode) { _, newMode in
                // 防御性：进入文献库模式时再次检查是否需要配置引导
                if newMode == .library && needsSetup && !showSetupGuide {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        if needsSetup {
                            showSetupGuide = true
                        }
                    }
                }
            }
    }

    @ViewBuilder
    private var mainView: some View {
        NavigationSplitView(columnVisibility: $sidebarVisibility) {
            sidebarContent
        } detail: {
            detailContent
        }
        .toolbar {
            // 文献库/阅读器模式切换按钮
            ToolbarItem(placement: .navigation) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        appMode = (appMode == .library) ? .reader : .library
                    }
                }) {
                    Image(systemName: appMode == .library ? "book.fill" : "books.vertical")
                }
                .help(appMode == .library ? "切换到阅读器" : "显示文献库 (⌘⇧L)")
            }

            if appMode == .reader, let vm = viewModel {
                PDFToolbar(
                    viewModel: vm,
                    isShowingSearch: $isShowingSearch,
                    sidebarVisibility: $sidebarVisibility
                )
            }
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
            tabManager.handleDrop(providers: providers)
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel?.errorMessage != nil },
            set: { if !$0 { viewModel?.errorMessage = nil } }
        )) {
            Button("OK") { viewModel?.errorMessage = nil }
        } message: {
            Text(viewModel?.errorMessage ?? "")
        }
        .animation(.easeInOut(duration: 0.2), value: isShowingSearch)
        .animation(.easeInOut(duration: 0.2), value: showChatPanel)
        .animation(.easeInOut(duration: 0.2), value: appMode)
    }

    // MARK: - View Components

    @ViewBuilder
    private var sidebarContent: some View {
        if appMode == .library {
            LibrarySidebarView(
                viewModel: libraryViewModel,
                selectedSection: $selectedLibrarySection,
                onOpenPaper: { url in
                    tabManager.openDocument(url: url)
                    appMode = .reader
                }
            )
        } else if let vm = viewModel {
            SidebarView(
                document: vm.document,
                currentPageIndex: Binding(
                    get: { vm.currentPageIndex },
                    set: { vm.currentPageIndex = $0 }
                ),
                selectedTab: $selectedSidebarTab,
                onPageSelected: { pageIndex in
                    requestedPageJump = pageIndex
                }
            )
        } else {
            VStack {
                Spacer()
                Text("请打开一个 PDF 文档")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        if appMode == .library {
            LibraryView(
                viewModel: libraryViewModel,
                selectedSection: selectedLibrarySection,
                onOpenPaper: { url in
                    tabManager.openDocument(url: url)
                    appMode = .reader
                }
            )
        } else {
            HSplitView {
                mainContentArea
                    .frame(minWidth: 400, minHeight: 400)

                if showChatPanel, let chatVM = chatViewModel, let vm = viewModel {
                    ChatPanelView(
                        viewModel: chatVM,
                        document: vm.document,
                        currentPageIndex: vm.currentPageIndex
                    )
                    .frame(minWidth: 300, idealWidth: 400, maxWidth: 500)
                }
            }
        }
    }

    @ViewBuilder
    private var mainContentArea: some View {
        ZStack {
            if let _ = tabManager.activeTab {
                VStack(spacing: 0) {
                    // Tab Bar（多于1个 Tab 时显示）
                    if tabManager.tabs.count > 1 {
                        DocumentTabBar(tabManager: tabManager)
                        Divider()
                    }

                    // PDF 内容
                    if let vm = viewModel {
                        pdfContentView(viewModel: vm)
                    }
                }
            } else {
                WelcomeView(
                    needsSetup: needsSetup,
                    onOpenFile: { tabManager.openDocumentFromPanel() },
                    onSetup: { showSetupGuide = true },
                    recentFiles: loadRecentFiles(),
                    onOpenRecent: { url in
                        tabManager.openDocument(url: url)
                    },
                    onShowLibrary: { appMode = .library }
                )
            }

            if isDropTargeted {
                DropOverlayView()
            }

            if let vm = viewModel, vm.isLoading {
                LoadingOverlayView(message: vm.loadingMessage)
            }
        }
    }

    @ViewBuilder
    private func pdfContentView(viewModel vm: PDFReaderViewModel) -> some View {
        VStack(spacing: 0) {
            PDFToolbarView(
                scaleFactor: Binding(
                    get: { vm.scaleFactor },
                    set: { vm.scaleFactor = $0 }
                ),
                displayMode: $displayMode,
                currentPageIndex: Binding(
                    get: { vm.currentPageIndex },
                    set: { vm.currentPageIndex = $0 }
                ),
                pageCount: vm.document?.pageCount ?? 0,
                onGoToPage: { pageIndex in
                    requestedPageJump = pageIndex
                },
                onRotate: { degrees in
                    requestedRotation = degrees
                },
                onZoomToFit: { mode in
                    requestedZoomFit = mode
                }
            )

            Divider()

            if isShowingSearch {
                SearchBar(
                    searchText: Binding(
                        get: { vm.searchText },
                        set: { vm.searchText = $0 }
                    ),
                    isShowing: $isShowingSearch,
                    onSearch: vm.search
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            PDFReaderView(
                document: vm.document,
                currentPageIndex: Binding(
                    get: { vm.currentPageIndex },
                    set: { vm.currentPageIndex = $0 }
                ),
                scaleFactor: Binding(
                    get: { vm.scaleFactor },
                    set: { vm.scaleFactor = $0 }
                ),
                searchText: Binding(
                    get: { vm.searchText },
                    set: { vm.searchText = $0 }
                ),
                displayMode: $displayMode,
                requestedPageJump: $requestedPageJump,
                requestedRotation: $requestedRotation,
                requestedZoomFit: $requestedZoomFit,
                onSelectionChanged: { text in
                    vm.handleSelectionChanged(text)
                    chatViewModel?.currentSelection = text
                },
                onContextAction: { action, text in
                    handleContextAction(action, text: text)
                },
                onAnnotate: { annotationType in
                    vm.markAnnotationChanged()
                    print("Added annotation: \(annotationType.rawValue)")
                },
                onScaleChanged: { newScale in
                    vm.scaleFactor = newScale
                }
            )
        }
        .onChange(of: vm.currentPageIndex) { _, _ in
            vm.saveReadingProgress()
        }
    }

    /// 处理右键菜单的AI操作
    private func handleContextAction(_ action: PDFContextAction, text: String) {
        guard let chatVM = chatViewModel, let vm = viewModel else { return }

        // 确保聊天面板打开
        if !showChatPanel {
            showChatPanel = true
        }

        var prompt: String
        switch action {
        case .translateToChinese:
            prompt = AppSettings.shared.promptTranslate
        case .explain:
            prompt = AppSettings.shared.promptExplain
        case .summarize:
            prompt = AppSettings.shared.promptSummarize
        case .searchWeb, .copy:
            return
        }

        prompt = prompt.replacingOccurrences(of: "{selection}", with: text)

        chatVM.inputText = prompt
        chatVM.sendMessage(document: vm.document, currentPageIndex: vm.currentPageIndex)
    }

    // MARK: - Recent Files

    private func loadRecentFiles() -> [RecentFileItem] {
        let progressKey = "com.bioinfoark.aipaperreader.readingProgress"
        guard let data = UserDefaults.standard.data(forKey: progressKey),
              let progress = try? JSONDecoder().decode([String: ReadingProgress].self, from: data) else {
            return []
        }

        return progress.compactMap { (urlString, prog) -> RecentFileItem? in
            guard let url = URL(string: urlString) else { return nil }
            // 只保留还存在的文件
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            return RecentFileItem(
                url: url,
                title: url.deletingPathExtension().lastPathComponent,
                lastReadDate: prog.lastReadDate,
                pageIndex: prog.pageIndex
            )
        }
        .sorted { $0.lastReadDate > $1.lastReadDate }
        .prefix(10)
        .map { $0 }
    }
}

/// 最近文件项
struct RecentFileItem: Identifiable {
    var id: URL { url }
    let url: URL
    let title: String
    let lastReadDate: Date
    let pageIndex: Int
}

struct WelcomeView: View {
    var needsSetup: Bool
    var onOpenFile: () -> Void
    var onSetup: () -> Void
    var recentFiles: [RecentFileItem] = []
    var onOpenRecent: ((URL) -> Void)? = nil
    var onShowLibrary: (() -> Void)? = nil

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
            VStack(spacing: 12) {
                Button(action: onOpenFile) {
                    HStack {
                        Image(systemName: "folder")
                        Text("welcome_open_pdf")
                    }
                    .frame(minWidth: 160)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                if let showLib = onShowLibrary {
                    Button(action: showLib) {
                        HStack {
                            Image(systemName: "books.vertical")
                            Text("打开文献库")
                        }
                        .frame(minWidth: 160)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                Text("welcome_drag_drop")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // 最近打开的文件
            if !recentFiles.isEmpty, let onRecent = onOpenRecent {
                VStack(alignment: .leading, spacing: 8) {
                    Text("最近打开")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    ForEach(recentFiles.prefix(5)) { item in
                        Button(action: { onRecent(item.url) }) {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.text.fill")
                                    .foregroundColor(.accentColor)
                                    .font(.caption)
                                    .frame(width: 16)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(item.title)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)

                                    Text("\(item.lastReadDate.formatted(date: .abbreviated, time: .shortened)) · 第 \(item.pageIndex + 1) 页")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(Color.secondary.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: 350)
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

/// 加载状态覆盖层
struct LoadingOverlayView: View {
    var message: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))

                Text(message)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.7))
            )
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

// MARK: - View Extension for Notification Handling (Tab-aware)

extension View {
    func setupTabNotificationHandlers(
        tabManager: TabManager,
        isShowingSearch: Binding<Bool>,
        showChatPanel: Binding<Bool>,
        requestedPageJump: Binding<Int?>
    ) -> some View {
        self
            .onReceive(NotificationCenter.default.publisher(for: .openDocument)) { _ in
                tabManager.openDocumentFromPanel()
            }
            .onReceive(NotificationCenter.default.publisher(for: .openDocumentURL)) { notification in
                if let url = notification.object as? URL {
                    tabManager.openDocument(url: url)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .zoomIn)) { _ in
                tabManager.activeTab?.viewModel.zoomIn()
            }
            .onReceive(NotificationCenter.default.publisher(for: .zoomOut)) { _ in
                tabManager.activeTab?.viewModel.zoomOut()
            }
            .onReceive(NotificationCenter.default.publisher(for: .zoomToFit)) { _ in
                tabManager.activeTab?.viewModel.zoomToFit()
            }
            .onReceive(NotificationCenter.default.publisher(for: .toggleSearch)) { _ in
                isShowingSearch.wrappedValue.toggle()
            }
            .onReceive(NotificationCenter.default.publisher(for: .toggleChat)) { _ in
                showChatPanel.wrappedValue.toggle()
            }
            .onReceive(NotificationCenter.default.publisher(for: .saveDocument)) { _ in
                if let vm = tabManager.activeTab?.viewModel {
                    _ = vm.saveDocument()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .saveDocumentAs)) { _ in
                tabManager.activeTab?.viewModel.saveDocumentAs()
            }
            .onReceive(NotificationCenter.default.publisher(for: .goToNextPage)) { _ in
                if let vm = tabManager.activeTab?.viewModel,
                   vm.currentPageIndex < vm.pageCount - 1 {
                    requestedPageJump.wrappedValue = vm.currentPageIndex + 1
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .goToPreviousPage)) { _ in
                if let vm = tabManager.activeTab?.viewModel,
                   vm.currentPageIndex > 0 {
                    requestedPageJump.wrappedValue = vm.currentPageIndex - 1
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .goToFirstPage)) { _ in
                requestedPageJump.wrappedValue = 0
            }
            .onReceive(NotificationCenter.default.publisher(for: .goToLastPage)) { _ in
                if let vm = tabManager.activeTab?.viewModel {
                    requestedPageJump.wrappedValue = vm.pageCount - 1
                }
            }
    }
}

// Keep old extension for backward compatibility
extension View {
    func setupNotificationHandlers(
        viewModel: PDFReaderViewModel,
        chatViewModel: ChatViewModel,
        isShowingSearch: Binding<Bool>,
        showChatPanel: Binding<Bool>,
        requestedPageJump: Binding<Int?>
    ) -> some View {
        self
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
                isShowingSearch.wrappedValue.toggle()
            }
            .onReceive(NotificationCenter.default.publisher(for: .toggleChat)) { _ in
                showChatPanel.wrappedValue.toggle()
            }
            .onReceive(NotificationCenter.default.publisher(for: .saveDocument)) { _ in
                _ = viewModel.saveDocument()
            }
            .onReceive(NotificationCenter.default.publisher(for: .saveDocumentAs)) { _ in
                viewModel.saveDocumentAs()
            }
            .onReceive(NotificationCenter.default.publisher(for: .goToNextPage)) { _ in
                if viewModel.currentPageIndex < viewModel.pageCount - 1 {
                    requestedPageJump.wrappedValue = viewModel.currentPageIndex + 1
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .goToPreviousPage)) { _ in
                if viewModel.currentPageIndex > 0 {
                    requestedPageJump.wrappedValue = viewModel.currentPageIndex - 1
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .goToFirstPage)) { _ in
                requestedPageJump.wrappedValue = 0
            }
            .onReceive(NotificationCenter.default.publisher(for: .goToLastPage)) { _ in
                requestedPageJump.wrappedValue = viewModel.pageCount - 1
            }
    }
}

#Preview {
    ContentView()
}
