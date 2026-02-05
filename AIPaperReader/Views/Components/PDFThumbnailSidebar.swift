//
//  PDFThumbnailSidebar.swift
//  AIPaperReader
//
//  Created by Claude on 2/4/26.
//

import SwiftUI
import PDFKit

// MARK: - Helper Types

struct SendableImage: @unchecked Sendable {
    let image: NSImage
}

struct SendablePDFDocument: @unchecked Sendable {
    let document: PDFDocument
}

// MARK: - Thumbnail Cache (解决性能问题)

/// 全局缩略图缓存，避免重复生成
final class ThumbnailCache: @unchecked Sendable {
    static let shared = ThumbnailCache()
    private var cache = NSCache<NSString, NSImage>()
    private let lock = NSLock()

    private init() {
        cache.countLimit = 100 // 最多缓存100张
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }

    func thumbnail(for key: String) -> SendableImage? {
        lock.lock()
        defer { lock.unlock() }
        if let image = cache.object(forKey: key as NSString) {
            return SendableImage(image: image)
        }
        return nil
    }

    func setThumbnail(_ imageWrapper: SendableImage, for key: String) {
        lock.lock()
        defer { lock.unlock() }
        cache.setObject(imageWrapper.image, forKey: key as NSString)
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAllObjects()
    }
}

struct PDFThumbnailSidebar: View {
    let document: PDFDocument?
    @Binding var currentPageIndex: Int
    let thumbnailSize: CGSize

    init(document: PDFDocument?, currentPageIndex: Binding<Int>, thumbnailSize: CGSize = CGSize(width: 120, height: 160)) {
        self.document = document
        self._currentPageIndex = currentPageIndex
        self.thumbnailSize = thumbnailSize
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if let document = document {
                        ForEach(0..<document.pageCount, id: \.self) { index in
                            ThumbnailItemView(
                                document: document,
                                pageIndex: index,
                                isSelected: index == currentPageIndex,
                                size: thumbnailSize
                            )
                            .id(index)
                            .onTapGesture {
                                currentPageIndex = index
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .onChange(of: currentPageIndex) { _, newIndex in
                withAnimation {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }
}

struct ThumbnailItemView: View {
    let document: PDFDocument
    let pageIndex: Int
    let isSelected: Bool
    let size: CGSize

    var body: some View {
        VStack(spacing: 4) {
            // Thumbnail image
            ThumbnailImage(document: document, pageIndex: pageIndex, size: size)
                .frame(width: size.width, height: size.height)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                )
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)

            // Page number
            Text("\(pageIndex + 1)")
                .font(.caption)
                .foregroundColor(isSelected ? .accentColor : .secondary)
        }
        .padding(.horizontal, 8)
    }
}

struct ThumbnailImage: View {
    let document: PDFDocument
    let pageIndex: Int
    let size: CGSize

    @State private var image: NSImage?
    @State private var isLoading = false

    private var cacheKey: String {
        "\(document.documentURL?.absoluteString ?? "unknown")_\(pageIndex)_\(Int(size.width))x\(Int(size.height))"
    }

    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.5)
                    )
            }
        }
        .onAppear {
            loadThumbnailSync()
        }
    }

    /// 同步方式加载缩略图，避免 Sendable 问题
    private func loadThumbnailSync() {
        // 防止重复加载
        guard !isLoading else { return }

        // 先检查缓存
        if let cachedWrapper = ThumbnailCache.shared.thumbnail(for: cacheKey) {
            self.image = cachedWrapper.image
            return
        }

        isLoading = true

        // 捕获需要的值
        let key = cacheKey
        let thumbSize = size
        let sendableDoc = SendablePDFDocument(document: document)
        let idx = pageIndex

        // 在后台线程生成缩略图
        DispatchQueue.global(qos: .userInitiated).async {
            guard let page = sendableDoc.document.page(at: idx) else {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }

            // 生成缩略图
            let thumbnail = page.thumbnail(of: thumbSize, for: .mediaBox)
            let sendableThumbnail = SendableImage(image: thumbnail)

            // 缓存
            ThumbnailCache.shared.setThumbnail(sendableThumbnail, for: key)

            // 回到主线程更新 UI
            DispatchQueue.main.async {
                self.image = sendableThumbnail.image
                self.isLoading = false
            }
        }
    }
}

#Preview {
    PDFThumbnailSidebar(
        document: nil,
        currentPageIndex: .constant(0)
    )
    .frame(width: 150, height: 400)
}
