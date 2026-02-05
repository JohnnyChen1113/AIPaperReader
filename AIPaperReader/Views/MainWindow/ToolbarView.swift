//
//  ToolbarView.swift
//  AIPaperReader
//
//  Created by Claude on 2/4/26.
//

import SwiftUI

struct PDFToolbar: ToolbarContent {
    @ObservedObject var viewModel: PDFReaderViewModel
    @Binding var isShowingSearch: Bool
    @Binding var sidebarVisibility: NavigationSplitViewVisibility

    var body: some ToolbarContent {
        // Leading items
        ToolbarItemGroup(placement: .navigation) {
            Button(action: { sidebarVisibility = sidebarVisibility == .detailOnly ? .all : .detailOnly }) {
                Image(systemName: "sidebar.left")
            }
            .help("toolbar_toggle_sidebar")
        }

        // Title
        ToolbarItem(placement: .principal) {
            if viewModel.document != nil {
                VStack(spacing: 0) {
                    Text(viewModel.documentTitle)
                        .font(.headline)
                        .lineLimit(1)

                    Text(String(format: NSLocalizedString("toolbar_page_fmt", comment: ""), viewModel.currentPageIndex + 1, viewModel.pageCount))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }

        // Zoom controls
        ToolbarItemGroup(placement: .automatic) {
            Button(action: viewModel.zoomOut) {
                Image(systemName: "minus.magnifyingglass")
            }
            .help("toolbar_zoom_out")

            Text("\(Int(viewModel.scaleFactor * 100))%")
                .frame(width: 50)
                .font(.caption)

            Button(action: viewModel.zoomIn) {
                Image(systemName: "plus.magnifyingglass")
            }
            .help("toolbar_zoom_in")

            Button(action: viewModel.zoomToFit) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }
            .help("toolbar_zoom_fit")
        }

        // Page navigation
        ToolbarItemGroup(placement: .automatic) {
            Divider()

            Button(action: viewModel.previousPage) {
                Image(systemName: "chevron.up")
            }
            .disabled(viewModel.currentPageIndex <= 0)
            .help("toolbar_prev_page")

            Button(action: viewModel.nextPage) {
                Image(systemName: "chevron.down")
            }
            .disabled(viewModel.currentPageIndex >= viewModel.pageCount - 1)
            .help("toolbar_next_page")
        }

        // Search
        ToolbarItemGroup(placement: .automatic) {
            Divider()

            Button(action: { isShowingSearch.toggle() }) {
                Image(systemName: "magnifyingglass")
            }
            .help("toolbar_search_tooltip")
        }
    }
}

struct SearchBar: View {
    @Binding var searchText: String
    @Binding var isShowing: Bool
    var onSearch: (String) -> Void

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("toolbar_search_placeholder", text: $searchText)
                .textFieldStyle(.plain)
                .onSubmit {
                    onSearch(searchText)
                }

            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Button("toolbar_done") {
                isShowing = false
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
}
