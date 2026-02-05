//
//  PDFToolbarView.swift
//  AIPaperReader
//
//  Created by Claude on 2/4/26.
//

import SwiftUI
import PDFKit

/// PDF 显示模式
enum PDFViewDisplayMode: String, CaseIterable {
    case singlePage = "单页"
    case singlePageContinuous = "单页连续"
    case twoUp = "双页"
    case twoUpContinuous = "双页连续"

    var pdfDisplayMode: PDFDisplayMode {
        switch self {
        case .singlePage: return .singlePage
        case .singlePageContinuous: return .singlePageContinuous
        case .twoUp: return .twoUp
        case .twoUpContinuous: return .twoUpContinuous
        }
    }

    var icon: String {
        switch self {
        case .singlePage: return "doc"
        case .singlePageContinuous: return "doc.text"
        case .twoUp: return "book"
        case .twoUpContinuous: return "book.pages"
        }
    }
}

/// 预设缩放比例
enum ZoomPreset: String, CaseIterable {
    case fitWidth = "适合宽度"
    case fitPage = "适合页面"
    case actual = "实际大小"
    case p50 = "50%"
    case p75 = "75%"
    case p100 = "100%"
    case p125 = "125%"
    case p150 = "150%"
    case p200 = "200%"
    case p300 = "300%"

    var scaleFactor: CGFloat? {
        switch self {
        case .fitWidth, .fitPage: return nil // 特殊处理
        case .actual, .p100: return 1.0
        case .p50: return 0.5
        case .p75: return 0.75
        case .p125: return 1.25
        case .p150: return 1.5
        case .p200: return 2.0
        case .p300: return 3.0
        }
    }
}

/// PDF 工具栏视图
struct PDFToolbarView: View {
    @Binding var scaleFactor: CGFloat
    @Binding var displayMode: PDFDisplayMode
    @Binding var currentPageIndex: Int
    let pageCount: Int
    var onGoToPage: ((Int) -> Void)?

    @State private var selectedDisplayMode: PDFViewDisplayMode = .singlePageContinuous
    @State private var pageInputText: String = ""
    @State private var isEditingPage: Bool = false

    var zoomPercentage: Int {
        Int(scaleFactor * 100)
    }

    var body: some View {
        HStack(spacing: 12) {
            // 页面导航
            HStack(spacing: 4) {
                Button(action: goToFirstPage) {
                    Image(systemName: "chevron.backward.to.line")
                }
                .buttonStyle(.plain)
                .disabled(currentPageIndex <= 0)
                .help("第一页")

                Button(action: goToPreviousPage) {
                    Image(systemName: "chevron.backward")
                }
                .buttonStyle(.plain)
                .disabled(currentPageIndex <= 0)
                .help("上一页")

                // 页码输入/显示
                HStack(spacing: 2) {
                    if isEditingPage {
                        TextField("", text: $pageInputText)
                            .textFieldStyle(.plain)
                            .frame(width: 40)
                            .multilineTextAlignment(.center)
                            .onSubmit {
                                if let page = Int(pageInputText), page >= 1, page <= pageCount {
                                    onGoToPage?(page - 1)
                                }
                                isEditingPage = false
                            }
                    } else {
                        Text("\(currentPageIndex + 1)")
                            .frame(minWidth: 30)
                            .onTapGesture {
                                pageInputText = "\(currentPageIndex + 1)"
                                isEditingPage = true
                            }
                    }
                    Text("/")
                    Text("\(pageCount)")
                }
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))

                Button(action: goToNextPage) {
                    Image(systemName: "chevron.forward")
                }
                .buttonStyle(.plain)
                .disabled(currentPageIndex >= pageCount - 1)
                .help("下一页")

                Button(action: goToLastPage) {
                    Image(systemName: "chevron.forward.to.line")
                }
                .buttonStyle(.plain)
                .disabled(currentPageIndex >= pageCount - 1)
                .help("最后一页")
            }

            Divider()
                .frame(height: 20)

            // 缩放控制
            HStack(spacing: 4) {
                Button(action: zoomOut) {
                    Image(systemName: "minus.magnifyingglass")
                }
                .buttonStyle(.plain)
                .disabled(scaleFactor <= 0.25)
                .help("缩小")

                // 缩放比例选择器
                Menu {
                    ForEach(ZoomPreset.allCases, id: \.self) { preset in
                        Button(preset.rawValue) {
                            applyZoomPreset(preset)
                        }
                    }
                } label: {
                    HStack(spacing: 2) {
                        Text("\(zoomPercentage)%")
                            .frame(minWidth: 45)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .menuStyle(.borderlessButton)
                .frame(width: 80)

                Button(action: zoomIn) {
                    Image(systemName: "plus.magnifyingglass")
                }
                .buttonStyle(.plain)
                .disabled(scaleFactor >= 5.0)
                .help("放大")
            }

            Divider()
                .frame(height: 20)

            // 显示模式选择
            Menu {
                ForEach(PDFViewDisplayMode.allCases, id: \.self) { mode in
                    Button(action: { applyDisplayMode(mode) }) {
                        Label(mode.rawValue, systemImage: mode.icon)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: selectedDisplayMode.icon)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .menuStyle(.borderlessButton)
            .help("显示模式")

            Divider()
                .frame(height: 20)

            // 旋转按钮
            HStack(spacing: 4) {
                Button(action: {}) {
                    Image(systemName: "rotate.left")
                }
                .buttonStyle(.plain)
                .help("逆时针旋转")

                Button(action: {}) {
                    Image(systemName: "rotate.right")
                }
                .buttonStyle(.plain)
                .help("顺时针旋转")
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            updateSelectedDisplayMode()
        }
        .onChange(of: displayMode) { _, _ in
            updateSelectedDisplayMode()
        }
    }

    // MARK: - Page Navigation

    private func goToFirstPage() {
        onGoToPage?(0)
    }

    private func goToPreviousPage() {
        if currentPageIndex > 0 {
            onGoToPage?(currentPageIndex - 1)
        }
    }

    private func goToNextPage() {
        if currentPageIndex < pageCount - 1 {
            onGoToPage?(currentPageIndex + 1)
        }
    }

    private func goToLastPage() {
        onGoToPage?(pageCount - 1)
    }

    // MARK: - Zoom Control

    private func zoomIn() {
        scaleFactor = min(scaleFactor * 1.25, 5.0)
    }

    private func zoomOut() {
        scaleFactor = max(scaleFactor / 1.25, 0.25)
    }

    private func applyZoomPreset(_ preset: ZoomPreset) {
        if let factor = preset.scaleFactor {
            scaleFactor = factor
        } else {
            // 适合宽度/页面需要特殊处理
            // 这里简单设置一个合理的值
            switch preset {
            case .fitWidth:
                scaleFactor = 1.0 // 实际应该根据视图宽度计算
            case .fitPage:
                scaleFactor = 0.85 // 实际应该根据视图大小计算
            default:
                break
            }
        }
    }

    // MARK: - Display Mode

    private func updateSelectedDisplayMode() {
        switch displayMode {
        case .singlePage:
            selectedDisplayMode = .singlePage
        case .singlePageContinuous:
            selectedDisplayMode = .singlePageContinuous
        case .twoUp:
            selectedDisplayMode = .twoUp
        case .twoUpContinuous:
            selectedDisplayMode = .twoUpContinuous
        @unknown default:
            selectedDisplayMode = .singlePageContinuous
        }
    }

    private func applyDisplayMode(_ mode: PDFViewDisplayMode) {
        selectedDisplayMode = mode
        displayMode = mode.pdfDisplayMode
    }
}

#Preview {
    VStack {
        PDFToolbarView(
            scaleFactor: .constant(1.0),
            displayMode: .constant(.singlePageContinuous),
            currentPageIndex: .constant(0),
            pageCount: 20
        )

        Spacer()
    }
}
