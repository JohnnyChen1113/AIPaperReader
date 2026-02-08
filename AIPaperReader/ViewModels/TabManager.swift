//
//  TabManager.swift
//  AIPaperReader
//
//  Created by Claude on 2/7/26.
//

import Foundation
import SwiftUI
import SwiftData
import PDFKit

/// Tab 管理器 - 管理多文档 Tab
@MainActor
class TabManager: ObservableObject {
    @Published var tabs: [DocumentTab] = []
    @Published var activeTabId: UUID?

    /// SwiftData 上下文，用于初始化 ChatViewModel 的持久化
    var modelContext: ModelContext?

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        // 为已有 Tab 补充 modelContext（防御性）
        for tab in tabs {
            if tab.chatViewModel.modelContext == nil {
                tab.chatViewModel.setModelContext(context)
            }
        }
    }

    /// 当前活跃的 Tab
    var activeTab: DocumentTab? {
        guard let id = activeTabId else { return nil }
        return tabs.first { $0.id == id }
    }

    /// 打开文档（创建新 Tab 或激活已有 Tab）
    @discardableResult
    func openDocument(url: URL) -> DocumentTab {
        // 检查是否已有相同 URL 的 Tab
        if let existing = tabs.first(where: { $0.url == url }) {
            switchTab(id: existing.id)
            existing.lastAccessDate = Date()
            return existing
        }

        // 创建新的 ViewModel
        let pdfViewModel = PDFReaderViewModel()
        pdfViewModel.loadDocument(from: url)

        let chatVM = ChatViewModel()

        // 立即注入 modelContext 并加载 session，确保导航后聊天记录不丢失
        if let context = modelContext {
            chatVM.setModelContext(context)
            chatVM.loadSession(for: url.absoluteString)
        }

        let tab = DocumentTab(url: url, viewModel: pdfViewModel, chatViewModel: chatVM)

        // Ingest document for RAG
        if let doc = pdfViewModel.document {
            chatVM.ingestDocument(doc)
        }

        tabs.append(tab)
        activeTabId = tab.id

        return tab
    }

    /// 关闭 Tab
    func closeTab(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }

        let wasActive = activeTabId == id
        tabs.remove(at: index)

        if wasActive {
            // 切换到相邻 Tab
            if tabs.isEmpty {
                activeTabId = nil
            } else if index < tabs.count {
                activeTabId = tabs[index].id
            } else {
                activeTabId = tabs.last?.id
            }
        }
    }

    /// 切换到指定 Tab
    func switchTab(id: UUID) {
        guard tabs.contains(where: { $0.id == id }) else { return }
        activeTabId = id
        if let tab = tabs.first(where: { $0.id == id }) {
            tab.lastAccessDate = Date()
        }
    }

    /// 关闭所有 Tab
    func closeAllTabs() {
        tabs.removeAll()
        activeTabId = nil
    }

    /// 关闭除指定 Tab 外的所有 Tab
    func closeOtherTabs(keepId: UUID) {
        tabs.removeAll { $0.id != keepId }
        activeTabId = keepId
    }

    /// 移动 Tab（拖拽排序）
    func moveTab(from source: IndexSet, to destination: Int) {
        tabs.move(fromOffsets: source, toOffset: destination)
    }

    /// 通过 NSOpenPanel 打开文档
    func openDocumentFromPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.message = "Select PDF files to open"
        panel.prompt = "Open"

        panel.begin { [weak self] response in
            guard response == .OK else { return }
            Task { @MainActor in
                for url in panel.urls {
                    self?.openDocument(url: url)
                }
            }
        }
    }

    /// 处理拖放
    func handleDrop(providers: [NSItemProvider]) -> Bool {
        var handled = false

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("com.adobe.pdf") {
                provider.loadItem(forTypeIdentifier: "com.adobe.pdf", options: nil) { [weak self] item, error in
                    guard let url = item as? URL else { return }
                    Task { @MainActor in
                        self?.openDocument(url: url)
                    }
                }
                handled = true
            } else if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { [weak self] item, error in
                    guard let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil),
                          url.pathExtension.lowercased() == "pdf" else { return }
                    Task { @MainActor in
                        self?.openDocument(url: url)
                    }
                }
                handled = true
            }
        }

        return handled
    }
}
