//
//  PDFReaderViewModel.swift
//  AIPaperReader
//
//  Created by Claude on 2/4/26.
//

import SwiftUI
import PDFKit
import UniformTypeIdentifiers

@MainActor
class PDFReaderViewModel: ObservableObject {
    @Published var documentModel: PDFDocumentModel?
    @Published var currentPageIndex: Int = 0
    @Published var scaleFactor: CGFloat = 1.0
    @Published var searchText: String = ""
    @Published var selectedText: String?
    @Published var isShowingOpenPanel: Bool = false
    @Published var errorMessage: String?
    @Published var hasUnsavedAnnotations: Bool = false
    @Published var isLoading: Bool = false
    @Published var loadingMessage: String = ""

    var document: PDFDocument? {
        documentModel?.document
    }

    var pageCount: Int {
        documentModel?.pageCount ?? 0
    }

    var documentTitle: String {
        documentModel?.title ?? "No Document"
    }

    var documentURL: URL? {
        documentModel?.url
    }

    // MARK: - Document Operations

    func openDocument() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Select a PDF file to open"
        panel.prompt = "Open"

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                self?.loadDocument(from: url)
            }
        }
    }

    func loadDocument(from url: URL) {
        isLoading = true
        loadingMessage = "正在加载 \(url.lastPathComponent)..."

        guard let model = PDFDocumentModel(url: url) else {
            isLoading = false
            loadingMessage = ""
            errorMessage = "Failed to open PDF file: \(url.lastPathComponent)"
            return
        }
        documentModel = model
        currentPageIndex = 0
        scaleFactor = 1.0
        searchText = ""
        selectedText = nil
        errorMessage = nil
        hasUnsavedAnnotations = false

        // 恢复阅读进度
        restoreReadingProgress(for: url)

        // Add to recent documents
        NSDocumentController.shared.noteNewRecentDocumentURL(url)

        // 完成加载
        isLoading = false
        loadingMessage = ""
    }

    // MARK: - Save Document (with annotations)

    /// 保存文档（包含标注）
    func saveDocument() -> Bool {
        guard let document = document, let url = documentURL else {
            errorMessage = "No document to save"
            return false
        }

        // 检查文件是否可写
        let fileManager = FileManager.default
        if fileManager.isWritableFile(atPath: url.path) {
            // 尝试直接保存
            if let data = document.dataRepresentation() {
                do {
                    try data.write(to: url)
                    hasUnsavedAnnotations = false
                    return true
                } catch {
                    print("Save error: \(error)")
                    // 直接保存失败，弹出另存为对话框
                    saveDocumentAs()
                    return false
                }
            }
        }

        // 原文件不可写或位于受保护位置，弹出另存为对话框
        saveDocumentAs()
        return false
    }

    /// 另存为
    func saveDocumentAs() {
        guard let document = document else {
            errorMessage = "No document to save"
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.pdf]
        panel.nameFieldStringValue = documentModel?.title ?? "document.pdf"
        panel.message = "Save PDF with annotations"
        panel.prompt = "Save"

        // 设置初始目录为桌面或文档
        if let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first {
            panel.directoryURL = desktopURL
        }

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                if let data = document.dataRepresentation() {
                    do {
                        try data.write(to: url)
                        self?.hasUnsavedAnnotations = false
                    } catch {
                        self?.errorMessage = "Failed to save: \(error.localizedDescription)"
                    }
                } else {
                    self?.errorMessage = "Failed to generate PDF data"
                }
            }
        }
    }

    /// 标记有未保存的标注
    func markAnnotationChanged() {
        hasUnsavedAnnotations = true
    }

    // MARK: - Navigation

    func goToPage(_ index: Int) {
        guard index >= 0 && index < pageCount else { return }
        currentPageIndex = index
    }

    func nextPage() {
        goToPage(currentPageIndex + 1)
    }

    func previousPage() {
        goToPage(currentPageIndex - 1)
    }

    // MARK: - Zoom

    func zoomIn() {
        scaleFactor = min(scaleFactor * 1.25, 5.0)
    }

    func zoomOut() {
        scaleFactor = max(scaleFactor / 1.25, 0.25)
    }

    func zoomToFit() {
        scaleFactor = 1.0
    }

    // MARK: - Search

    func search(for text: String) {
        searchText = text
    }

    func clearSearch() {
        searchText = ""
    }

    // MARK: - Selection

    func handleSelectionChanged(_ text: String?) {
        selectedText = text
    }

    // MARK: - Reading Progress

    private static let readingProgressKey = "com.bioinfoark.aipaperreader.readingProgress"

    /// 保存阅读进度
    func saveReadingProgress() {
        guard let url = documentURL else { return }
        var progress = Self.loadAllReadingProgress()
        progress[url.absoluteString] = ReadingProgress(
            pageIndex: currentPageIndex,
            scaleFactor: scaleFactor,
            lastReadDate: Date()
        )
        Self.saveAllReadingProgress(progress)
    }

    /// 恢复阅读进度
    private func restoreReadingProgress(for url: URL) {
        let progress = Self.loadAllReadingProgress()
        if let saved = progress[url.absoluteString] {
            currentPageIndex = saved.pageIndex
            scaleFactor = saved.scaleFactor
        }
    }

    /// 从 UserDefaults 加载所有阅读进度
    private static func loadAllReadingProgress() -> [String: ReadingProgress] {
        guard let data = UserDefaults.standard.data(forKey: readingProgressKey),
              let progress = try? JSONDecoder().decode([String: ReadingProgress].self, from: data) else {
            return [:]
        }
        return progress
    }

    /// 保存所有阅读进度到 UserDefaults
    private static func saveAllReadingProgress(_ progress: [String: ReadingProgress]) {
        // 只保留最近 50 个文档的进度
        var sortedProgress = progress
        if sortedProgress.count > 50 {
            let sorted = sortedProgress.sorted { $0.value.lastReadDate > $1.value.lastReadDate }
            sortedProgress = Dictionary(uniqueKeysWithValues: sorted.prefix(50).map { ($0.key, $0.value) })
        }

        if let data = try? JSONEncoder().encode(sortedProgress) {
            UserDefaults.standard.set(data, forKey: readingProgressKey)
        }
    }
}

/// 阅读进度数据结构
struct ReadingProgress: Codable {
    let pageIndex: Int
    let scaleFactor: CGFloat
    let lastReadDate: Date
}

// MARK: - Drop Delegate for PDF files
extension PDFReaderViewModel {
    func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        if provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.pdf.identifier, options: nil) { [weak self] item, error in
                guard let url = item as? URL else { return }
                Task { @MainActor in
                    self?.loadDocument(from: url)
                }
            }
            return true
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] item, error in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil),
                      url.pathExtension.lowercased() == "pdf" else { return }
                Task { @MainActor in
                    self?.loadDocument(from: url)
                }
            }
            return true
        }

        return false
    }
}
