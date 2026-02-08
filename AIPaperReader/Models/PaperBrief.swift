//
//  PaperBrief.swift
//  AIPaperReader
//
//  Created by Claude on 2/7/26.
//

import Foundation

/// 论文简报数据模型
struct PaperBrief: Codable, Identifiable {
    var id: UUID = UUID()
    var title: String = ""
    var authors: String = ""
    var researchQuestion: String = ""
    var methodology: String = ""
    var keyFindings: String = ""
    var contributions: String = ""
    var limitations: String = ""
    var keywords: [String] = []
    var generatedAt: Date = Date()
    var isComplete: Bool = false

    /// 简报各字段定义
    enum Field: String, CaseIterable {
        case title
        case authors
        case researchQuestion
        case methodology
        case keyFindings
        case contributions
        case limitations
        case keywords

        var displayName: String {
            switch self {
            case .title: return "标题"
            case .authors: return "作者"
            case .researchQuestion: return "研究问题"
            case .methodology: return "研究方法"
            case .keyFindings: return "主要发现"
            case .contributions: return "主要贡献"
            case .limitations: return "局限性"
            case .keywords: return "关键词"
            }
        }

        var icon: String {
            switch self {
            case .title: return "doc.text"
            case .authors: return "person.2"
            case .researchQuestion: return "questionmark.circle"
            case .methodology: return "testtube.2"
            case .keyFindings: return "lightbulb.fill"
            case .contributions: return "star.fill"
            case .limitations: return "exclamationmark.triangle"
            case .keywords: return "tag"
            }
        }

        var color: String {
            switch self {
            case .title: return "primary"
            case .authors: return "secondary"
            case .researchQuestion: return "blue"
            case .methodology: return "purple"
            case .keyFindings: return "yellow"
            case .contributions: return "green"
            case .limitations: return "orange"
            case .keywords: return "teal"
            }
        }
    }

    /// 导出为 Markdown 格式
    func toMarkdown() -> String {
        var md = "# \(title)\n\n"

        if !authors.isEmpty {
            md += "**Authors:** \(authors)\n\n"
        }

        if !researchQuestion.isEmpty {
            md += "## Research Question\n\n\(researchQuestion)\n\n"
        }

        if !methodology.isEmpty {
            md += "## Methodology\n\n\(methodology)\n\n"
        }

        if !keyFindings.isEmpty {
            md += "## Key Findings\n\n\(keyFindings)\n\n"
        }

        if !contributions.isEmpty {
            md += "## Contributions\n\n\(contributions)\n\n"
        }

        if !limitations.isEmpty {
            md += "## Limitations\n\n\(limitations)\n\n"
        }

        if !keywords.isEmpty {
            md += "## Keywords\n\n\(keywords.joined(separator: ", "))\n\n"
        }

        md += "---\n*Generated on \(generatedAt.formatted(date: .long, time: .shortened))*\n"
        return md
    }
}
