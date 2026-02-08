//
//  LibraryView.swift
//  AIPaperReader
//
//  Created by Claude on 2/7/26.
//

import SwiftUI
import SwiftData

/// 文献库主视图
struct LibraryView: View {
    @ObservedObject var viewModel: LibraryViewModel
    var selectedSection: LibrarySection = .all
    var onOpenPaper: ((URL) -> Void)?

    @State private var papers: [PaperItem] = []
    @State private var showDeleteConfirmation: Bool = false
    @State private var paperToDelete: PaperItem?

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // 工具栏
                libraryToolbar

                Divider()

                // 内容
                if papers.isEmpty {
                    emptyStateView
                } else {
                    switch viewModel.viewStyle {
                    case .table:
                        tableView
                    case .grid:
                        gridView
                    case .list:
                        listView
                    }
                }
            }

            // AI 生成进度 overlay
            if viewModel.isGeneratingAI {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()

                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("AI 正在分析论文...")
                        .font(.headline)
                    Text("请稍候，正在生成摘要和标签")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.regularMaterial)
                )
                .shadow(radius: 8)
            }
        }
        .onAppear { refreshPapers() }
        .onChange(of: viewModel.searchText) { _, _ in refreshPapers() }
        .onChange(of: viewModel.selectedFilter) { _, _ in refreshPapers() }
        .onChange(of: viewModel.sortOption) { _, _ in refreshPapers() }
        .onChange(of: selectedSection) { _, _ in refreshPapers() }
        .onChange(of: viewModel.isGeneratingAI) { _, newValue in
            if !newValue {
                // AI 生成完成后刷新列表
                refreshPapers()
            }
        }
        .alert("删除文献", isPresented: $showDeleteConfirmation) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                if let paper = paperToDelete {
                    viewModel.deletePaper(paper)
                    refreshPapers()
                }
            }
        } message: {
            Text("确定要从文献库中移除「\(paperToDelete?.title ?? "")」吗？这不会删除原始文件。")
        }
        .alert("AI 生成失败", isPresented: Binding(
            get: { viewModel.generationError != nil },
            set: { if !$0 { viewModel.generationError = nil } }
        )) {
            Button("确定") { viewModel.generationError = nil }
        } message: {
            Text(viewModel.generationError ?? "")
        }
    }

    private func refreshPapers() {
        switch selectedSection {
        case .all:
            papers = viewModel.fetchPapers()
        case .recent:
            let savedFilter = viewModel.selectedFilter
            let savedSort = viewModel.sortOption
            viewModel.selectedFilter = .all
            viewModel.sortOption = .lastRead
            papers = viewModel.fetchPapers()
            viewModel.selectedFilter = savedFilter
            viewModel.sortOption = savedSort
        case .starred:
            let savedFilter = viewModel.selectedFilter
            viewModel.selectedFilter = .starred
            papers = viewModel.fetchPapers()
            viewModel.selectedFilter = savedFilter
        case .unread:
            let savedFilter = viewModel.selectedFilter
            viewModel.selectedFilter = .unread
            papers = viewModel.fetchPapers()
            viewModel.selectedFilter = savedFilter
        case .collection(let id):
            let collections = viewModel.fetchCollections()
            if let collection = collections.first(where: { $0.id == id }) {
                papers = viewModel.fetchPapers(in: collection)
            } else {
                papers = []
            }
        case .tag(let id):
            let tags = viewModel.fetchTags()
            if let tag = tags.first(where: { $0.id == id }) {
                papers = viewModel.fetchPapers(with: tag)
            } else {
                papers = []
            }
        }
    }

    // MARK: - Toolbar

    private var libraryToolbar: some View {
        HStack(spacing: 12) {
            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索文献...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                if !viewModel.searchText.isEmpty {
                    Button(action: { viewModel.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .frame(maxWidth: 250)

            Spacer()

            // 筛选
            Picker("", selection: $viewModel.selectedFilter) {
                ForEach(LibraryViewModel.LibraryFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 300)

            // 排序
            Menu {
                ForEach(LibraryViewModel.SortOption.allCases, id: \.self) { option in
                    Button(action: { viewModel.sortOption = option }) {
                        HStack {
                            Text(option.rawValue)
                            if viewModel.sortOption == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .foregroundColor(.secondary)
            }

            // 视图切换（表格 / 网格 / 列表）
            Picker("", selection: $viewModel.viewStyle) {
                Image(systemName: "tablecells").tag(LibraryViewModel.ViewStyle.table)
                Image(systemName: "square.grid.2x2").tag(LibraryViewModel.ViewStyle.grid)
                Image(systemName: "list.bullet").tag(LibraryViewModel.ViewStyle.list)
            }
            .pickerStyle(.segmented)
            .frame(width: 105)

            // 导入按钮（始终醒目显示）
            Button(action: {
                viewModel.importPDFs()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    refreshPapers()
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                    Text("导入")
                }
            }
            .buttonStyle(.bordered)
            .help("导入 PDF")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Table View

    private var tableView: some View {
        Table(papers, selection: $viewModel.selectedPapers) {
            TableColumn("⭐") { paper in
                Button(action: { viewModel.toggleStar(paper); refreshPapers() }) {
                    Image(systemName: paper.isStarred ? "star.fill" : "star")
                        .foregroundColor(paper.isStarred ? .yellow : .secondary)
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
            .width(30)

            TableColumn("标题") { paper in
                VStack(alignment: .leading, spacing: 2) {
                    Text(paper.title)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    if !paper.authors.isEmpty {
                        Text(paper.authors)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .width(min: 150, ideal: 250)

            TableColumn("摘要") { paper in
                if let brief = paper.cachedBrief {
                    Text(brief.keyFindings.isEmpty ? brief.methodology : brief.keyFindings)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                } else {
                    Text("—")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.4))
                }
            }
            .width(min: 100, ideal: 200)

            TableColumn("标签") { paper in
                HStack(spacing: 4) {
                    ForEach(paper.tags.prefix(3), id: \.id) { tag in
                        Text(tag.name)
                            .font(.system(size: 10))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background((Color(hex: tag.colorHex) ?? .accentColor).opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }
            .width(min: 80, ideal: 140)

            TableColumn("状态") { paper in
                HStack(spacing: 4) {
                    Image(systemName: paper.readingStatus.icon)
                        .font(.system(size: 10))
                        .foregroundColor(statusColor(paper.readingStatus))
                    Text(paper.readingStatus.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .width(60)

            TableColumn("添加日期") { paper in
                Text(paper.addedDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .width(min: 80, ideal: 100)
        }
        .contextMenu(forSelectionType: UUID.self) { selectedIds in
            if let id = selectedIds.first,
               let paper = papers.first(where: { $0.id == id }) {
                Button("打开") { openPaper(paper) }
                Divider()
                Menu("AI 生成") {
                    Button("基于摘要生成简报和标签") {
                        viewModel.generateBriefAndTags(for: paper, mode: .abstract)
                    }
                    Button("基于全文生成简报和标签") {
                        viewModel.generateBriefAndTags(for: paper, mode: .fullText)
                    }
                }
                Divider()
                Button(paper.isStarred ? "取消收藏" : "收藏") {
                    viewModel.toggleStar(paper)
                    refreshPapers()
                }
                Divider()
                Button("删除", role: .destructive) {
                    paperToDelete = paper
                    showDeleteConfirmation = true
                }
            }
        } primaryAction: { selectedIds in
            if let id = selectedIds.first,
               let paper = papers.first(where: { $0.id == id }) {
                openPaper(paper)
            }
        }
    }

    // MARK: - Grid View

    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 180, maximum: 220), spacing: 16)
            ], spacing: 16) {
                ForEach(papers, id: \.id) { paper in
                    PaperCardView(
                        paper: paper,
                        onOpen: { openPaper(paper) },
                        onToggleStar: { viewModel.toggleStar(paper); refreshPapers() },
                        onDelete: { paperToDelete = paper; showDeleteConfirmation = true },
                        onAIGenerate: { mode in
                            viewModel.generateBriefAndTags(for: paper, mode: mode)
                        }
                    )
                }
            }
            .padding(16)
        }
    }

    // MARK: - List View

    private var listView: some View {
        List {
            ForEach(papers, id: \.id) { paper in
                PaperListRow(
                    paper: paper,
                    onOpen: { openPaper(paper) },
                    onToggleStar: { viewModel.toggleStar(paper); refreshPapers() },
                    onDelete: { paperToDelete = paper; showDeleteConfirmation = true },
                    onAIGenerate: { mode in
                        viewModel.generateBriefAndTags(for: paper, mode: mode)
                    }
                )
            }
        }
        .listStyle(.inset)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "books.vertical")
                .font(.system(size: 56))
                .foregroundColor(.secondary.opacity(0.4))

            Text("文献库为空")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            Text("导入 PDF 文件来管理你的学术文献")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button(action: {
                viewModel.importPDFs()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    refreshPapers()
                }
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("导入 PDF")
                }
                .padding(.horizontal, 20)
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func openPaper(_ paper: PaperItem) {
        guard let url = paper.fileURL else { return }
        viewModel.markAsReading(paper)
        onOpenPaper?(url)
    }

    private func statusColor(_ status: ReadingStatus) -> Color {
        switch status {
        case .unread: return .secondary
        case .reading: return .blue
        case .read: return .green
        }
    }
}

// MARK: - Paper Card View (Grid)

struct PaperCardView: View {
    let paper: PaperItem
    var onOpen: () -> Void
    var onToggleStar: () -> Void
    var onDelete: () -> Void
    var onAIGenerate: ((PaperAIService.GenerationMode) -> Void)? = nil

    @State private var isHovered: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 缩略图
            ZStack(alignment: .topTrailing) {
                if let thumbnailData = paper.thumbnailData,
                   let nsImage = NSImage(data: thumbnailData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 140)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.1))
                        .frame(height: 140)
                        .overlay(
                            Image(systemName: "doc.text")
                                .font(.system(size: 32))
                                .foregroundColor(.secondary.opacity(0.3))
                        )
                }

                // 收藏按钮
                Button(action: onToggleStar) {
                    Image(systemName: paper.isStarred ? "star.fill" : "star")
                        .font(.caption)
                        .foregroundColor(paper.isStarred ? .yellow : .white)
                        .padding(6)
                        .background(Circle().fill(Color.black.opacity(0.4)))
                }
                .buttonStyle(.plain)
                .padding(6)
                .opacity(isHovered || paper.isStarred ? 1 : 0)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // 标题
            Text(paper.title)
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(2)
                .foregroundColor(.primary)

            // 作者
            if !paper.authors.isEmpty {
                Text(paper.authors)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            // 状态和标签
            HStack(spacing: 4) {
                Image(systemName: paper.readingStatus.icon)
                    .font(.system(size: 9))
                    .foregroundColor(statusColor(paper.readingStatus))

                Text(paper.readingStatus.displayName)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)

                Spacer()

                // 标签（最多2个）
                ForEach(paper.tags.prefix(2), id: \.id) { tag in
                    Text(tag.name)
                        .font(.system(size: 8))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHovered ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(isHovered ? 0.08 : 0.03), radius: isHovered ? 8 : 4, y: 2)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onTapGesture(count: 2) { onOpen() }
        .contextMenu {
            Button("打开") { onOpen() }
            Divider()
            if let aiGenerate = onAIGenerate {
                Menu("AI 生成") {
                    Button("基于摘要生成简报和标签") { aiGenerate(.abstract) }
                    Button("基于全文生成简报和标签") { aiGenerate(.fullText) }
                }
                Divider()
            }
            Button(paper.isStarred ? "取消收藏" : "收藏") { onToggleStar() }
            Divider()
            Button("删除", role: .destructive) { onDelete() }
        }
    }

    private func statusColor(_ status: ReadingStatus) -> Color {
        switch status {
        case .unread: return .secondary
        case .reading: return .blue
        case .read: return .green
        }
    }
}

// MARK: - Paper List Row

struct PaperListRow: View {
    let paper: PaperItem
    var onOpen: () -> Void
    var onToggleStar: () -> Void
    var onDelete: () -> Void
    var onAIGenerate: ((PaperAIService.GenerationMode) -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            // 收藏图标
            Button(action: onToggleStar) {
                Image(systemName: paper.isStarred ? "star.fill" : "star")
                    .foregroundColor(paper.isStarred ? .yellow : .secondary)
                    .font(.caption)
            }
            .buttonStyle(.plain)

            // 状态
            Image(systemName: paper.readingStatus.icon)
                .font(.caption)
                .foregroundColor(paper.readingStatus == .read ? .green : (paper.readingStatus == .reading ? .blue : .secondary))
                .frame(width: 16)

            // 标题和作者
            VStack(alignment: .leading, spacing: 2) {
                Text(paper.title)
                    .fontWeight(.medium)
                    .lineLimit(1)

                if !paper.authors.isEmpty {
                    Text(paper.authors)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // 标签
            ForEach(paper.tags.prefix(2), id: \.id) { tag in
                Text(tag.name)
                    .font(.system(size: 10))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(Capsule())
            }

            // 日期
            Text(paper.addedDate.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { onOpen() }
        .contextMenu {
            Button("打开") { onOpen() }
            Divider()
            if let aiGenerate = onAIGenerate {
                Menu("AI 生成") {
                    Button("基于摘要生成简报和标签") { aiGenerate(.abstract) }
                    Button("基于全文生成简报和标签") { aiGenerate(.fullText) }
                }
                Divider()
            }
            Button(paper.isStarred ? "取消收藏" : "收藏") { onToggleStar() }
            Divider()
            Button("删除", role: .destructive) { onDelete() }
        }
    }
}
