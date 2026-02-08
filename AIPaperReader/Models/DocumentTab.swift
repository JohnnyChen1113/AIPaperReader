//
//  DocumentTab.swift
//  AIPaperReader
//
//  Created by Claude on 2/7/26.
//

import Foundation
import SwiftUI
import PDFKit

/// 文档 Tab 数据模型
@MainActor
class DocumentTab: ObservableObject, Identifiable {
    let id: UUID
    let url: URL
    @Published var title: String
    @Published var viewModel: PDFReaderViewModel
    @Published var chatViewModel: ChatViewModel
    var lastAccessDate: Date

    init(url: URL, viewModel: PDFReaderViewModel, chatViewModel: ChatViewModel) {
        self.id = UUID()
        self.url = url
        self.title = url.deletingPathExtension().lastPathComponent
        self.viewModel = viewModel
        self.chatViewModel = chatViewModel
        self.lastAccessDate = Date()

        // 从 PDF metadata 中提取标题（如果有）
        if let doc = viewModel.document,
           let attrs = doc.documentAttributes,
           let pdfTitle = attrs[PDFDocumentAttribute.titleAttribute] as? String,
           !pdfTitle.isEmpty {
            self.title = pdfTitle
        }
    }
}
