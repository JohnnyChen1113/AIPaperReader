//
//  ModelCardView.swift
//  AIPaperReader
//
//  Created by Claude on 2/7/26.
//

import SwiftUI

/// 模型卡片组件 - 展示模型图标、名称、提供商和能力标签
struct ModelCardView: View {
    let modelId: String
    let provider: LLMProvider?
    let isSelected: Bool
    var isCompact: Bool = false
    var onSelect: (() -> Void)? = nil

    private var metadata: ModelMetadata {
        ModelMetadata.metadata(for: modelId, provider: provider)
    }

    var body: some View {
        Button(action: { onSelect?() }) {
            HStack(spacing: 12) {
                // 左侧：模型图标
                ModelIconView(
                    icon: metadata.icon,
                    color: provider?.brandColor ?? .gray,
                    size: isCompact ? 28 : 36
                )

                // 中间：名称 + 提供商 + 标签
                VStack(alignment: .leading, spacing: isCompact ? 2 : 4) {
                    Text(metadata.displayName)
                        .font(isCompact ? .subheadline : .body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if !isCompact {
                        HStack(spacing: 6) {
                            if !metadata.providerName.isEmpty {
                                Text(metadata.providerName)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            // 能力标签
                            ForEach(metadata.tags.prefix(3), id: \.self) { tag in
                                ModelTagView(tag: tag)
                            }
                        }
                    } else if !metadata.tags.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(metadata.tags.prefix(2), id: \.self) { tag in
                                ModelTagView(tag: tag, compact: true)
                            }
                        }
                    }
                }

                Spacer()

                // 右侧：选中标记
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(isCompact ? .body : .title3)
                }
            }
            .padding(isCompact ? 8 : 12)
            .background(
                RoundedRectangle(cornerRadius: isCompact ? 8 : 10)
                    .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: isCompact ? 8 : 10)
                    .stroke(isSelected ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

/// 模型图标视图 - 圆形背景 + SF Symbol
struct ModelIconView: View {
    let icon: String
    var color: Color = .accentColor
    var size: CGFloat = 36

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: size, height: size)

            Image(systemName: icon)
                .font(.system(size: size * 0.4))
                .foregroundColor(color)
        }
    }
}

/// 模型能力标签胶囊
struct ModelTagView: View {
    let tag: ModelTag
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 2) {
            if !compact {
                Image(systemName: tag.icon)
                    .font(.system(size: 8))
            }
            Text(tag.displayName)
                .font(.system(size: compact ? 9 : 10, weight: .medium))
        }
        .padding(.horizontal, compact ? 4 : 6)
        .padding(.vertical, compact ? 1 : 2)
        .background(tag.color.opacity(0.12))
        .foregroundColor(tag.color)
        .clipShape(Capsule())
    }
}

/// 聊天面板顶部的模型快速切换按钮
struct ModelQuickSwitchButton: View {
    @ObservedObject var settings: AppSettings
    @State private var showModelPopover: Bool = false

    private var currentMetadata: ModelMetadata {
        ModelMetadata.metadata(for: settings.llmModelName, provider: settings.llmProvider)
    }

    var body: some View {
        Button(action: { showModelPopover.toggle() }) {
            HStack(spacing: 6) {
                ModelIconView(
                    icon: currentMetadata.icon,
                    color: settings.llmProvider.brandColor,
                    size: 22
                )

                Text(currentMetadata.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.08))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showModelPopover) {
            ModelQuickSwitchPopover(settings: settings) {
                showModelPopover = false
            }
        }
    }
}

/// 模型快速切换弹出面板
struct ModelQuickSwitchPopover: View {
    @ObservedObject var settings: AppSettings
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("切换模型")
                    .font(.headline)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(12)

            Divider()

            // Model list
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(settings.enabledModels, id: \.self) { model in
                        ModelCardView(
                            modelId: model,
                            provider: settings.llmProvider,
                            isSelected: settings.llmModelName == model,
                            isCompact: true
                        ) {
                            settings.llmModelName = model
                            onDismiss()
                        }
                    }
                }
                .padding(8)
            }

            Divider()

            // Provider info
            HStack(spacing: 6) {
                Image(systemName: settings.llmProvider.providerIcon)
                    .foregroundColor(settings.llmProvider.brandColor)
                    .font(.caption)
                Text(settings.llmProvider.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(settings.enabledModels.count) 个模型")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(12)
        }
        .frame(width: 320, height: min(CGFloat(settings.enabledModels.count) * 52 + 120, 400))
    }
}

#Preview {
    VStack(spacing: 12) {
        ModelCardView(
            modelId: "Pro/deepseek-ai/DeepSeek-V3.2",
            provider: .siliconflow,
            isSelected: true
        )

        ModelCardView(
            modelId: "gpt-5",
            provider: .bioInfoArk,
            isSelected: false
        )

        ModelCardView(
            modelId: "claude-sonnet-4-5",
            provider: .bioInfoArk,
            isSelected: false,
            isCompact: true
        )
    }
    .padding()
    .frame(width: 350)
}
