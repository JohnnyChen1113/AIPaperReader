//
//  LibraryViewModel.swift
//  AIPaperReader
//
//  Created by Claude on 2/7/26.
//

import Foundation
import SwiftUI
import SwiftData
import PDFKit

/// 文献库 ViewModel
@MainActor
class LibraryViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var selectedFilter: LibraryFilter = .all
    @Published var sortOption: SortOption = .dateAdded
    @Published var viewStyle: ViewStyle = .table
    @Published var selectedPapers: Set<UUID> = []
    @Published var isImporting: Bool = false
    @Published var isGeneratingAI: Bool = false
    @Published var generationError: String?

    var modelContext: ModelContext?

    enum LibraryFilter: String, CaseIterable {
        case all = "全部"
        case unread = "未读"
        case reading = "在读"
        case read = "已读"
        case starred = "收藏"
    }

    enum SortOption: String, CaseIterable {
        case dateAdded = "添加日期"
        case lastRead = "最近阅读"
        case title = "标题"
        case author = "作者"
    }

    enum ViewStyle: String, CaseIterable {
        case table = "表格"
        case grid = "网格"
        case list = "列表"
    }

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    // MARK: - Fetch

    func fetchPapers() -> [PaperItem] {
        guard let context = modelContext else { return [] }

        var descriptor = FetchDescriptor<PaperItem>(
            sortBy: [sortDescriptor]
        )

        // Apply filter predicate
        switch selectedFilter {
        case .all:
            break
        case .unread:
            descriptor.predicate = #Predicate { $0.readingStatusRaw == "unread" }
        case .reading:
            descriptor.predicate = #Predicate { $0.readingStatusRaw == "reading" }
        case .read:
            descriptor.predicate = #Predicate { $0.readingStatusRaw == "read" }
        case .starred:
            descriptor.predicate = #Predicate { $0.isStarred == true }
        }

        do {
            var papers = try context.fetch(descriptor)

            // Apply search filter
            if !searchText.isEmpty {
                let query = searchText.lowercased()
                papers = papers.filter {
                    $0.title.lowercased().contains(query) ||
                    $0.authors.lowercased().contains(query) ||
                    $0.notes.lowercased().contains(query)
                }
            }

            return papers
        } catch {
            print("Failed to fetch papers: \(error)")
            return []
        }
    }

    private var sortDescriptor: SortDescriptor<PaperItem> {
        switch sortOption {
        case .dateAdded:
            return SortDescriptor(\.addedDate, order: .reverse)
        case .lastRead:
            return SortDescriptor(\.lastReadDate, order: .reverse)
        case .title:
            return SortDescriptor(\.title)
        case .author:
            return SortDescriptor(\.authors)
        }
    }

    func fetchCollections() -> [PaperCollection] {
        guard let context = modelContext else { return [] }
        let descriptor = FetchDescriptor<PaperCollection>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func fetchTags() -> [PaperTag] {
        guard let context = modelContext else { return [] }
        let descriptor = FetchDescriptor<PaperTag>(
            sortBy: [SortDescriptor(\.name)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func fetchPapers(in collection: PaperCollection) -> [PaperItem] {
        return collection.papers.sorted { ($0.addedDate) > ($1.addedDate) }
    }

    func fetchPapers(with tag: PaperTag) -> [PaperItem] {
        return tag.papers.sorted { ($0.addedDate) > ($1.addedDate) }
    }

    // MARK: - Import

    func importPDFs() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.message = "选择要导入的 PDF 文件"
        panel.prompt = "导入"

        panel.begin { [weak self] response in
            guard response == .OK else { return }
            Task { @MainActor in
                self?.isImporting = true
                for url in panel.urls {
                    self?.importPDF(from: url)
                }
                self?.isImporting = false
            }
        }
    }

    func importPDF(from url: URL) {
        guard let context = modelContext else { return }

        // 检查是否已导入
        let path = url.path
        let descriptor = FetchDescriptor<PaperItem>(
            predicate: #Predicate { $0.filePath == path }
        )
        if let existing = try? context.fetch(descriptor), !existing.isEmpty {
            return // 已存在
        }

        // 提取 PDF 信息
        var title = url.deletingPathExtension().lastPathComponent
        var authors = ""

        if let doc = PDFDocument(url: url) {
            if let attrs = doc.documentAttributes {
                if let pdfTitle = attrs[PDFDocumentAttribute.titleAttribute] as? String, !pdfTitle.isEmpty {
                    title = pdfTitle
                }
                if let pdfAuthor = attrs[PDFDocumentAttribute.authorAttribute] as? String {
                    authors = pdfAuthor
                }
            }

            // 生成缩略图
            let thumbnailData = generateThumbnail(from: doc)

            let paper = PaperItem(
                title: title,
                authors: authors,
                filePath: url.path
            )
            paper.thumbnailData = thumbnailData

            // 创建 security-scoped bookmark
            if let bookmark = try? url.bookmarkData(options: .withSecurityScope) {
                paper.fileBookmark = bookmark
            }

            context.insert(paper)
        } else {
            // PDF 无法打开，仍然添加条目
            let paper = PaperItem(title: title, filePath: url.path)
            context.insert(paper)
        }

        try? context.save()
    }

    // MARK: - CRUD

    func deletePaper(_ paper: PaperItem) {
        guard let context = modelContext else { return }
        context.delete(paper)
        try? context.save()
    }

    func deletePapers(_ papers: Set<UUID>) {
        guard let context = modelContext else { return }
        let allPapers = fetchPapers()
        for paper in allPapers where papers.contains(paper.id) {
            context.delete(paper)
        }
        try? context.save()
        selectedPapers.removeAll()
    }

    func toggleStar(_ paper: PaperItem) {
        paper.isStarred.toggle()
        try? modelContext?.save()
    }

    func updateReadingStatus(_ paper: PaperItem, status: ReadingStatus) {
        paper.readingStatus = status
        try? modelContext?.save()
    }

    func markAsReading(_ paper: PaperItem) {
        paper.readingStatus = .reading
        paper.lastReadDate = Date()
        try? modelContext?.save()
    }

    // MARK: - Collections

    func createCollection(name: String, icon: String = "folder") {
        guard let context = modelContext else { return }
        let collections = fetchCollections()
        let collection = PaperCollection(name: name, icon: icon, sortOrder: collections.count)
        context.insert(collection)
        try? context.save()
    }

    func deleteCollection(_ collection: PaperCollection) {
        guard let context = modelContext else { return }
        context.delete(collection)
        try? context.save()
    }

    func addPaper(_ paper: PaperItem, to collection: PaperCollection) {
        if !collection.papers.contains(where: { $0.id == paper.id }) {
            collection.papers.append(paper)
            try? modelContext?.save()
        }
    }

    func removePaper(_ paper: PaperItem, from collection: PaperCollection) {
        collection.papers.removeAll { $0.id == paper.id }
        try? modelContext?.save()
    }

    // MARK: - Tags

    func createTag(name: String, colorHex: String = "#007AFF") {
        guard let context = modelContext else { return }
        let tag = PaperTag(name: name, colorHex: colorHex)
        context.insert(tag)
        try? context.save()
    }

    func deleteTag(_ tag: PaperTag) {
        guard let context = modelContext else { return }
        context.delete(tag)
        try? context.save()
    }

    func addTag(_ tag: PaperTag, to paper: PaperItem) {
        if !paper.tags.contains(where: { $0.id == tag.id }) {
            paper.tags.append(tag)
            try? modelContext?.save()
        }
    }

    func removeTag(_ tag: PaperTag, from paper: PaperItem) {
        paper.tags.removeAll { $0.id == tag.id }
        try? modelContext?.save()
    }

    // MARK: - AI Generation

    /// 为论文生成 AI 摘要和标签
    func generateBriefAndTags(for paper: PaperItem, mode: PaperAIService.GenerationMode) {
        guard !isGeneratingAI else { return }
        isGeneratingAI = true
        generationError = nil

        Task {
            do {
                // 获取已有标签名称列表
                let existingTagNames = fetchTags().map { $0.name }

                // 调用 AI 服务
                let result = try await PaperAIService.generateBriefAndTags(
                    for: paper,
                    mode: mode,
                    existingTags: existingTagNames
                )

                // 保存摘要
                if let briefData = try? JSONEncoder().encode(result.brief) {
                    paper.briefData = briefData
                }

                // 处理标签
                processTags(result.tags, for: paper)

                try? modelContext?.save()

                isGeneratingAI = false
            } catch {
                isGeneratingAI = false
                generationError = error.localizedDescription
            }
        }
    }

    /// 处理 AI 返回的标签：匹配已有或创建新的
    private func processTags(_ tagNames: [String], for paper: PaperItem) {
        guard let context = modelContext else { return }

        let existingTags = fetchTags()

        // 随机颜色调色板
        let colors = ["#007AFF", "#34C759", "#FF9500", "#FF3B30", "#AF52DE",
                       "#5AC8FA", "#FF2D55", "#A2845E", "#00C7BE", "#5856D6"]

        for tagName in tagNames {
            let trimmedName = tagName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else { continue }

            // 不区分大小写匹配已有标签
            if let existingTag = existingTags.first(where: {
                $0.name.lowercased() == trimmedName.lowercased()
            }) {
                // 复用已有标签
                addTag(existingTag, to: paper)
            } else {
                // 创建新标签
                let randomColor = colors.randomElement() ?? "#007AFF"
                let newTag = PaperTag(name: trimmedName, colorHex: randomColor)
                context.insert(newTag)
                addTag(newTag, to: paper)
            }
        }
    }

    // MARK: - Thumbnail

    private func generateThumbnail(from document: PDFDocument) -> Data? {
        guard let page = document.page(at: 0) else { return nil }

        let pageRect = page.bounds(for: .mediaBox)
        let scale: CGFloat = 200.0 / pageRect.width
        let thumbnailSize = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)

        let image = NSImage(size: thumbnailSize, flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.setFillColor(NSColor.white.cgColor)
            context.fill(rect)

            page.draw(with: .mediaBox, to: context)
            return true
        }

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.6]) else {
            return nil
        }
        return jpegData
    }
}
