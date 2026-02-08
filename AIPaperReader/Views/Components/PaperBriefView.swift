//
//  PaperBriefView.swift
//  AIPaperReader
//
//  Created by Claude on 2/7/26.
//

import SwiftUI
import PDFKit

/// 论文简报展示视图
struct PaperBriefView: View {
    @ObservedObject var briefingService: BriefingService
    let document: PDFDocument?
    var onDismiss: () -> Void

    @State private var expandedSections: Set<PaperBrief.Field> = Set(PaperBrief.Field.allCases)

    private var brief: PaperBrief { briefingService.brief }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            briefHeader

            Divider()

            if briefingService.isGenerating {
                generatingView
            } else if brief.isComplete {
                briefContent
            } else {
                emptyStateView
            }
        }
    }

    // MARK: - Header

    private var briefHeader: some View {
        HStack {
            Image(systemName: "doc.text.magnifyingglass")
                .foregroundColor(.accentColor)
            Text("论文简报")
                .font(.headline)

            Spacer()

            if brief.isComplete {
                // 复制按钮
                Button(action: copyToClipboard) {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("复制为 Markdown")

                // 重新生成按钮
                if let doc = document {
                    Button(action: {
                        let settings = AppSettings.shared
                        let service = LLMServiceFactory.create(config: settings.llmConfig)
                        briefingService.regenerate(document: doc, service: service)
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("重新生成")
                }
            }

            // 关闭/返回按钮
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("返回聊天")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Generating View

    private var generatingView: some View {
        VStack(spacing: 20) {
            Spacer()

            // 动画图标
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.accentColor.opacity(0.6))
                .symbolEffect(.pulse)

            Text("正在生成论文简报...")
                .font(.headline)
                .foregroundColor(.secondary)

            if !briefingService.currentField.isEmpty {
                Text("正在分析: \(briefingService.currentField)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ProgressView(value: briefingService.progress)
                .progressViewStyle(.linear)
                .frame(width: 200)
                .tint(.accentColor)

            Text("\(Int(briefingService.progress * 100))%")
                .font(.caption2)
                .foregroundColor(.secondary)

            Button("取消") {
                briefingService.cancel()
            }
            .buttonStyle(.bordered)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: - Brief Content

    private var briefContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 标题和作者（头部卡片）
                titleCard

                // 各 Section
                ForEach(contentFields, id: \.self) { field in
                    briefSection(field: field)
                }

                // 关键词
                if !brief.keywords.isEmpty {
                    keywordsSection
                }

                // 生成时间
                HStack {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text("生成于 \(brief.generatedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
                .padding(.top, 8)
            }
            .padding(16)
        }
    }

    // MARK: - Title Card

    private var titleCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !brief.title.isEmpty {
                Text(brief.title)
                    .font(.title3)
                    .fontWeight(.bold)
            }

            if !brief.authors.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "person.2")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(brief.authors)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Brief Section

    private var contentFields: [PaperBrief.Field] {
        [.researchQuestion, .methodology, .keyFindings, .contributions, .limitations]
    }

    private func briefSection(field: PaperBrief.Field) -> some View {
        let content = fieldContent(for: field)
        return Group {
            if !content.isEmpty {
                DisclosureGroup(
                    isExpanded: Binding(
                        get: { expandedSections.contains(field) },
                        set: { isExpanded in
                            if isExpanded {
                                expandedSections.insert(field)
                            } else {
                                expandedSections.remove(field)
                            }
                        }
                    )
                ) {
                    Text(content)
                        .font(.body)
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                        .padding(.top, 8)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: field.icon)
                            .font(.subheadline)
                            .foregroundColor(fieldColor(for: field))
                            .frame(width: 20)

                        Text(field.displayName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }
                .padding(12)
                .background(Color.secondary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // MARK: - Keywords Section

    private var keywordsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "tag")
                    .font(.subheadline)
                    .foregroundColor(.teal)
                    .frame(width: 20)
                Text("关键词")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            FlowLayout(spacing: 6) {
                ForEach(brief.keywords, id: \.self) { keyword in
                    Text(keyword)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.teal.opacity(0.12))
                        .foregroundColor(.teal)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))

            Text("生成论文简报")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("AI 将快速分析论文内容，提取研究问题、方法、发现等关键信息")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            if let doc = document {
                Button(action: {
                    let settings = AppSettings.shared
                    let service = LLMServiceFactory.create(config: settings.llmConfig)
                    briefingService.generateBrief(document: doc, service: service)
                }) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("生成简报")
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
            }

            if let error = briefingService.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 24)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: - Helpers

    private func fieldContent(for field: PaperBrief.Field) -> String {
        switch field {
        case .title: return brief.title
        case .authors: return brief.authors
        case .researchQuestion: return brief.researchQuestion
        case .methodology: return brief.methodology
        case .keyFindings: return brief.keyFindings
        case .contributions: return brief.contributions
        case .limitations: return brief.limitations
        case .keywords: return brief.keywords.joined(separator: ", ")
        }
    }

    private func fieldColor(for field: PaperBrief.Field) -> Color {
        switch field {
        case .title: return .primary
        case .authors: return .secondary
        case .researchQuestion: return .blue
        case .methodology: return .purple
        case .keyFindings: return .yellow
        case .contributions: return .green
        case .limitations: return .orange
        case .keywords: return .teal
        }
    }

    private func copyToClipboard() {
        let markdown = brief.toMarkdown()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(markdown, forType: .string)
    }
}

// MARK: - Flow Layout (用于关键词标签排列)

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}
