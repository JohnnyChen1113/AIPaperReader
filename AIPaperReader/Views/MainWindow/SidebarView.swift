//
//  SidebarView.swift
//  AIPaperReader
//
//  Created by Claude on 2/4/26.
//

import SwiftUI
import PDFKit

enum SidebarTab: String, CaseIterable {
    case thumbnails = "sidebar_thumbnails"
    case outline = "sidebar_outline"

    var icon: String {
        switch self {
        case .thumbnails: return "square.grid.2x2"
        case .outline: return "list.bullet.indent"
        }
    }
}

struct SidebarView: View {
    let document: PDFDocument?
    @Binding var currentPageIndex: Int
    @Binding var selectedTab: SidebarTab

    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("", selection: $selectedTab) {
                ForEach(SidebarTab.allCases, id: \.self) { tab in
                    Image(systemName: tab.icon)
                        .help(LocalizedStringKey(tab.rawValue))
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Tab content
            Group {
                switch selectedTab {
                case .thumbnails:
                    PDFThumbnailSidebar(
                        document: document,
                        currentPageIndex: $currentPageIndex
                    )

                case .outline:
                    PDFOutlineSidebar(
                        document: document,
                        currentPageIndex: $currentPageIndex
                    )
                }
            }
        }
        .frame(minWidth: 180, idealWidth: 220, maxWidth: 300)
    }
}

#Preview {
    SidebarView(
        document: nil,
        currentPageIndex: .constant(0),
        selectedTab: .constant(.thumbnails)
    )
}
