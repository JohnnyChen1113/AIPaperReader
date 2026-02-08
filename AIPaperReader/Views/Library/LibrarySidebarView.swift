//
//  LibrarySidebarView.swift
//  AIPaperReader
//
//  Created by Claude on 2/7/26.
//

import SwiftUI

/// 文献库侧边栏
struct LibrarySidebarView: View {
    @ObservedObject var viewModel: LibraryViewModel
    @Binding var selectedSection: LibrarySection
    var onOpenPaper: ((URL) -> Void)?

    @State private var collections: [PaperCollection] = []
    @State private var tags: [PaperTag] = []
    @State private var showNewCollectionSheet: Bool = false
    @State private var newCollectionName: String = ""
    @State private var showNewTagSheet: Bool = false
    @State private var newTagName: String = ""
    @State private var editingCollection: PaperCollection? = nil

    var body: some View {
        List(selection: $selectedSection) {
            // 智能列表
            Section("文献库") {
                Label("所有文献", systemImage: "books.vertical")
                    .tag(LibrarySection.all)

                Label("最近阅读", systemImage: "clock")
                    .tag(LibrarySection.recent)

                Label("收藏", systemImage: "star.fill")
                    .tag(LibrarySection.starred)

                Label("未读", systemImage: "circle")
                    .tag(LibrarySection.unread)
            }

            // 文件夹
            Section {
                ForEach(collections, id: \.id) { collection in
                    Label(collection.name, systemImage: collection.icon)
                        .tag(LibrarySection.collection(collection.id))
                        .contextMenu {
                            Button("重命名") {
                                editingCollection = collection
                                newCollectionName = collection.name
                                showNewCollectionSheet = true
                            }
                            Divider()
                            Button("删除", role: .destructive) {
                                viewModel.deleteCollection(collection)
                                refreshData()
                            }
                        }
                }
            } header: {
                HStack {
                    Text("文件夹")
                    Spacer()
                    Button(action: {
                        editingCollection = nil
                        newCollectionName = ""
                        showNewCollectionSheet = true
                    }) {
                        Image(systemName: "plus.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }

            // 标签
            Section {
                ForEach(tags, id: \.id) { tag in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(hex: tag.colorHex) ?? .accentColor)
                            .frame(width: 8, height: 8)

                        Text(tag.name)

                        Spacer()

                        Text("\(tag.papers.count)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .tag(LibrarySection.tag(tag.id))
                    .contextMenu {
                        Button("删除", role: .destructive) {
                            viewModel.deleteTag(tag)
                            refreshData()
                        }
                    }
                }
            } header: {
                HStack {
                    Text("标签")
                    Spacer()
                    Button(action: {
                        newTagName = ""
                        showNewTagSheet = true
                    }) {
                        Image(systemName: "plus.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listStyle(.sidebar)
        .onAppear { refreshData() }
        .onChange(of: viewModel.isGeneratingAI) { _, newValue in
            if !newValue {
                // AI 生成完成后刷新标签列表
                refreshData()
            }
        }
        .sheet(isPresented: $showNewCollectionSheet) {
            newCollectionSheet
        }
        .sheet(isPresented: $showNewTagSheet) {
            newTagSheet
        }
    }

    private func refreshData() {
        collections = viewModel.fetchCollections()
        tags = viewModel.fetchTags()
    }

    // MARK: - Sheets

    private var newCollectionSheet: some View {
        VStack(spacing: 16) {
            Text(editingCollection != nil ? "重命名文件夹" : "新建文件夹")
                .font(.headline)

            TextField("文件夹名称", text: $newCollectionName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 250)

            HStack {
                Button("取消") { showNewCollectionSheet = false }
                    .keyboardShortcut(.cancelAction)

                Button(editingCollection != nil ? "保存" : "创建") {
                    if let existing = editingCollection {
                        existing.name = newCollectionName
                        try? viewModel.modelContext?.save()
                    } else if !newCollectionName.isEmpty {
                        viewModel.createCollection(name: newCollectionName)
                    }
                    showNewCollectionSheet = false
                    refreshData()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newCollectionName.isEmpty)
            }
        }
        .padding(24)
    }

    private var newTagSheet: some View {
        VStack(spacing: 16) {
            Text("新建标签")
                .font(.headline)

            TextField("标签名称", text: $newTagName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 250)

            HStack {
                Button("取消") { showNewTagSheet = false }
                    .keyboardShortcut(.cancelAction)

                Button("创建") {
                    if !newTagName.isEmpty {
                        viewModel.createTag(name: newTagName)
                    }
                    showNewTagSheet = false
                    refreshData()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newTagName.isEmpty)
            }
        }
        .padding(24)
    }
}

// MARK: - Library Section

enum LibrarySection: Hashable {
    case all
    case recent
    case starred
    case unread
    case collection(UUID)
    case tag(UUID)
}

// MARK: - Color from Hex

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        guard hexSanitized.count == 6 else { return nil }

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        self.init(
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0
        )
    }
}
