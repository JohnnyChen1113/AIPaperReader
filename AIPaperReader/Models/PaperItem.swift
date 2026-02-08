//
//  PaperItem.swift
//  AIPaperReader
//
//  Created by Claude on 2/7/26.
//

import Foundation
import SwiftData

/// 阅读状态
enum ReadingStatus: String, Codable, CaseIterable {
    case unread = "unread"
    case reading = "reading"
    case read = "read"

    var displayName: String {
        switch self {
        case .unread: return "未读"
        case .reading: return "在读"
        case .read: return "已读"
        }
    }

    var icon: String {
        switch self {
        case .unread: return "circle"
        case .reading: return "book.fill"
        case .read: return "checkmark.circle.fill"
        }
    }
}

/// 文献项数据模型
@Model
class PaperItem {
    var id: UUID
    var title: String
    var authors: String
    var filePath: String
    var fileBookmark: Data?
    var addedDate: Date
    var lastReadDate: Date?
    var readingProgress: Double
    var readingStatusRaw: String
    var isStarred: Bool
    var thumbnailData: Data?
    @Relationship var tags: [PaperTag]
    @Relationship var collections: [PaperCollection]
    var briefData: Data?
    var notes: String

    var readingStatus: ReadingStatus {
        get { ReadingStatus(rawValue: readingStatusRaw) ?? .unread }
        set { readingStatusRaw = newValue.rawValue }
    }

    /// 解码缓存的简报
    var cachedBrief: PaperBrief? {
        guard let data = briefData else { return nil }
        return try? JSONDecoder().decode(PaperBrief.self, from: data)
    }

    /// 获取文件 URL
    var fileURL: URL? {
        // 优先使用 bookmark
        if let bookmark = fileBookmark {
            var isStale = false
            if let url = try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, bookmarkDataIsStale: &isStale) {
                if isStale {
                    // 尝试更新 bookmark
                    if let newBookmark = try? url.bookmarkData(options: .withSecurityScope) {
                        self.fileBookmark = newBookmark
                    }
                }
                return url
            }
        }
        // 降级使用 filePath
        return URL(fileURLWithPath: filePath)
    }

    init(
        title: String,
        authors: String = "",
        filePath: String,
        fileBookmark: Data? = nil,
        addedDate: Date = Date(),
        isStarred: Bool = false,
        notes: String = ""
    ) {
        self.id = UUID()
        self.title = title
        self.authors = authors
        self.filePath = filePath
        self.fileBookmark = fileBookmark
        self.addedDate = addedDate
        self.lastReadDate = nil
        self.readingProgress = 0.0
        self.readingStatusRaw = ReadingStatus.unread.rawValue
        self.isStarred = isStarred
        self.thumbnailData = nil
        self.tags = []
        self.collections = []
        self.briefData = nil
        self.notes = notes
    }
}

/// 标签
@Model
class PaperTag {
    var id: UUID
    var name: String
    var colorHex: String
    @Relationship(inverse: \PaperItem.tags) var papers: [PaperItem]

    init(name: String, colorHex: String = "#007AFF") {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.papers = []
    }
}

/// 文件夹/集合
@Model
class PaperCollection {
    var id: UUID
    var name: String
    var icon: String
    var sortOrder: Int
    @Relationship(inverse: \PaperItem.collections) var papers: [PaperItem]
    var createdDate: Date

    init(name: String, icon: String = "folder", sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.sortOrder = sortOrder
        self.papers = []
        self.createdDate = Date()
    }
}
