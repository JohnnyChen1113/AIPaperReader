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

    var document: PDFDocument? {
        documentModel?.document
    }

    var pageCount: Int {
        documentModel?.pageCount ?? 0
    }

    var documentTitle: String {
        documentModel?.title ?? "No Document"
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
        guard let model = PDFDocumentModel(url: url) else {
            errorMessage = "Failed to open PDF file: \(url.lastPathComponent)"
            return
        }
        documentModel = model
        currentPageIndex = 0
        scaleFactor = 1.0
        searchText = ""
        selectedText = nil
        errorMessage = nil

        // Add to recent documents
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
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
