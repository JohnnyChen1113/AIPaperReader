//
//  PDFDocumentModel.swift
//  AIPaperReader
//
//  Created by Claude on 2/4/26.
//

import Foundation
import PDFKit

/// Wrapper model for PDF document with metadata
class PDFDocumentModel: ObservableObject, Identifiable {
    let id = UUID()
    let url: URL
    let document: PDFDocument

    @Published var currentPageIndex: Int = 0
    @Published var scaleFactor: CGFloat = 1.0

    var title: String {
        // Try to get title from PDF metadata
        if let title = document.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String,
           !title.isEmpty {
            return title
        }
        // Fall back to filename
        return url.deletingPathExtension().lastPathComponent
    }

    var author: String? {
        document.documentAttributes?[PDFDocumentAttribute.authorAttribute] as? String
    }

    var pageCount: Int {
        document.pageCount
    }

    var currentPage: PDFPage? {
        document.page(at: currentPageIndex)
    }

    init?(url: URL) {
        guard let doc = PDFDocument(url: url) else {
            return nil
        }
        self.url = url
        self.document = doc
    }

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
}
