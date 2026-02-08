//
//  DocumentTabBar.swift
//  AIPaperReader
//
//  Created by Claude on 2/7/26.
//

import SwiftUI

/// 文档 Tab 栏
struct DocumentTabBar: View {
    @ObservedObject var tabManager: TabManager

    var body: some View {
        HStack(spacing: 0) {
            // Tab 列表
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(tabManager.tabs) { tab in
                        DocumentTabItem(
                            tab: tab,
                            isActive: tabManager.activeTabId == tab.id,
                            onSelect: {
                                tabManager.switchTab(id: tab.id)
                            },
                            onClose: {
                                tabManager.closeTab(id: tab.id)
                            }
                        )
                        .contextMenu {
                            Button("关闭") {
                                tabManager.closeTab(id: tab.id)
                            }
                            Button("关闭其他") {
                                tabManager.closeOtherTabs(keepId: tab.id)
                            }
                            Button("关闭所有") {
                                tabManager.closeAllTabs()
                            }
                        }

                        if tab.id != tabManager.tabs.last?.id {
                            Divider()
                                .frame(height: 16)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }

            Spacer()

            // 添加 Tab 按钮
            Button(action: {
                tabManager.openDocumentFromPanel()
            }) {
                Image(systemName: "plus")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)
            .help("打开新文档")
        }
        .frame(height: 32)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

/// 单个 Tab Item
struct DocumentTabItem: View {
    @ObservedObject var tab: DocumentTab
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 10))
                .foregroundColor(isActive ? .accentColor : .secondary)

            Text(tab.title)
                .font(.system(size: 11))
                .lineLimit(1)
                .foregroundColor(isActive ? .primary : .secondary)
                .frame(maxWidth: 140)

            // 关闭按钮（hover 时显示）
            if isHovered || isActive {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 14, height: 14)
                        .background(
                            Circle()
                                .fill(Color.secondary.opacity(isHovered ? 0.2 : 0))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isActive ? Color.accentColor.opacity(0.1) : (isHovered ? Color.secondary.opacity(0.06) : Color.clear))
        )
        .overlay(
            VStack {
                Spacer()
                if isActive {
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(height: 2)
                        .clipShape(Capsule())
                        .padding(.horizontal, 4)
                }
            }
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
