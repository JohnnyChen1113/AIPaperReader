//
//  PDFOutlineSidebar.swift
//  AIPaperReader
//
//  Created by Claude on 2/4/26.
//

import SwiftUI
import PDFKit

struct PDFOutlineSidebar: View {
    let document: PDFDocument?
    @Binding var currentPageIndex: Int
    var onPageSelected: ((Int) -> Void)?

    var body: some View {
        ScrollView {
            if let outline = document?.outlineRoot {
                OutlineTreeView(
                    outline: outline,
                    document: document,
                    currentPageIndex: $currentPageIndex,
                    level: 0,
                    onPageSelected: onPageSelected
                )
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No outline available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 40)
            }
        }
    }
}

struct OutlineTreeView: View {
    let outline: PDFOutline
    let document: PDFDocument?
    @Binding var currentPageIndex: Int
    let level: Int
    var onPageSelected: ((Int) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(0..<outline.numberOfChildren, id: \.self) { index in
                if let child = outline.child(at: index) {
                    OutlineItemView(
                        outline: child,
                        document: document,
                        currentPageIndex: $currentPageIndex,
                        level: level,
                        onPageSelected: onPageSelected
                    )
                }
            }
        }
    }
}

struct OutlineItemView: View {
    let outline: PDFOutline
    let document: PDFDocument?
    @Binding var currentPageIndex: Int
    let level: Int
    var onPageSelected: ((Int) -> Void)?

    @State private var isExpanded: Bool = true

    private var pageIndex: Int? {
        guard let destination = outline.destination,
              let page = destination.page,
              let doc = document else { return nil }
        return doc.index(for: page)
    }

    private var isCurrentPage: Bool {
        guard let index = pageIndex else { return false }
        return index == currentPageIndex
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Item row
            HStack(spacing: 4) {
                // Expand/collapse button
                if outline.numberOfChildren > 0 {
                    Button(action: { isExpanded.toggle() }) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer()
                        .frame(width: 16)
                }

                // Label
                Button(action: navigateToOutline) {
                    HStack {
                        Text(outline.label ?? "Untitled")
                            .font(.callout)
                            .foregroundColor(isCurrentPage ? .accentColor : .primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Spacer()

                        if let index = pageIndex {
                            Text("\(index + 1)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, CGFloat(level) * 16)
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(isCurrentPage ? Color.accentColor.opacity(0.1) : Color.clear)
            .contentShape(Rectangle())

            // Children
            if isExpanded && outline.numberOfChildren > 0 {
                OutlineTreeView(
                    outline: outline,
                    document: document,
                    currentPageIndex: $currentPageIndex,
                    level: level + 1,
                    onPageSelected: onPageSelected
                )
            }
        }
    }

    private func navigateToOutline() {
        if let index = pageIndex {
            onPageSelected?(index)
        }
    }
}

#Preview {
    PDFOutlineSidebar(
        document: nil,
        currentPageIndex: .constant(0)
    )
    .frame(width: 250, height: 400)
}
