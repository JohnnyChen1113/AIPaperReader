//
//  PDFReaderView.swift
//  AIPaperReader
//
//  Created by Claude on 2/4/26.
//

import SwiftUI
import PDFKit

/// 右键菜单操作类型
enum PDFContextAction: String, CaseIterable {
    case translateToChinese = "ctx_translate"
    case explain = "ctx_explain"
    case summarize = "ctx_summarize"
    case searchWeb = "ctx_search"
    case copy = "ctx_copy"
    
    var localizedTitle: String {
        return NSLocalizedString(self.rawValue, comment: "")
    }

    var icon: String {
        switch self {
        case .translateToChinese: return "character.book.closed"
        case .explain: return "lightbulb"
        case .summarize: return "doc.text"
        case .searchWeb: return "magnifyingglass"
        case .copy: return "doc.on.doc"
        }
    }
}

/// 高亮颜色
enum HighlightColor: String, CaseIterable {
    case yellow = "color_yellow"
    case red = "color_red"
    case orange = "color_orange"
    case green = "color_green"
    case cyan = "color_cyan"
    case blue = "color_blue"
    case purple = "color_purple"
    case pink = "color_pink"
    
    var localizedTitle: String {
        return NSLocalizedString(self.rawValue, comment: "")
    }

    var nsColor: NSColor {
        switch self {
        case .yellow: return NSColor.systemYellow
        case .red: return NSColor.systemRed
        case .orange: return NSColor.systemOrange
        case .green: return NSColor.systemGreen
        case .cyan: return NSColor.systemTeal
        case .blue: return NSColor.systemBlue
        case .purple: return NSColor.systemPurple
        case .pink: return NSColor.systemPink
        }
    }

    var emoji: String {
        switch self {
        case .yellow: return "🟡"
        case .red: return "🔴"
        case .orange: return "🟠"
        case .green: return "🟢"
        case .cyan: return "🔵"
        case .blue: return "🔷"
        case .purple: return "🟣"
        case .pink: return "💗"
        }
    }
}

/// 下划线样式
enum UnderlineStyle: String, CaseIterable {
    case single = "style_single"
    case double = "style_double"
    case thick = "style_thick"
    case dashed = "style_dashed"
    case wavy = "style_wavy"
    
    var localizedTitle: String {
        return NSLocalizedString(self.rawValue, comment: "")
    }

    var borderStyle: PDFBorderStyle {
        switch self {
        case .single, .double, .thick: return .solid
        case .dashed: return .dashed
        case .wavy: return .solid // PDF 不原生支持波浪线，用粗线模拟
        }
    }

    var lineWidth: CGFloat {
        switch self {
        case .single: return 1.0
        case .double: return 1.0
        case .thick: return 2.5
        case .dashed: return 1.0
        case .wavy: return 1.5
        }
    }
}

/// 标注类型
enum AnnotationType: String, CaseIterable {
    case highlight = "ctx_highlight"
    case underline = "ctx_underline"
    case strikethrough = "ctx_strikethrough"
    
    var localizedTitle: String {
        return NSLocalizedString(self.rawValue, comment: "")
    }

    var icon: String {
        switch self {
        case .highlight: return "highlighter"
        case .underline: return "underline"
        case .strikethrough: return "strikethrough"
        }
    }

    var color: NSColor {
        switch self {
        case .highlight: return .yellow
        case .underline: return .blue
        case .strikethrough: return .red
        }
    }
}

/// SwiftUI wrapper for PDFKit's PDFView
struct PDFReaderView: NSViewRepresentable {
    let document: PDFDocument?
    @Binding var currentPageIndex: Int
    @Binding var scaleFactor: CGFloat
    @Binding var searchText: String
    @Binding var displayMode: PDFDisplayMode
    var onSelectionChanged: ((String?) -> Void)?
    var onContextAction: ((PDFContextAction, String) -> Void)?
    var onAnnotate: ((AnnotationType) -> Void)?

    func makeNSView(context: Context) -> CustomPDFView {
        let pdfView = CustomPDFView()
        pdfView.autoScales = false // 禁用自动缩放，防止缩放重置
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .textBackgroundColor
        pdfView.delegate = context.coordinator
        pdfView.coordinator = context.coordinator

        // Enable text selection
        pdfView.displaysPageBreaks = true

        // Register for notifications
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.selectionChanged(_:)),
            name: .PDFViewSelectionChanged,
            object: pdfView
        )

        return pdfView
    }

    func updateNSView(_ pdfView: CustomPDFView, context: Context) {
        // Update document if changed
        if pdfView.document !== document {
            pdfView.document = document
            if let doc = document, doc.pageCount > 0 {
                pdfView.go(to: doc.page(at: 0)!)
                // 设置初始缩放
                pdfView.scaleFactor = scaleFactor
                // 记录当前页面索引
                context.coordinator.lastPageIndex = 0
            }
        }

        // Update scale factor only if significantly different
        if abs(pdfView.scaleFactor - scaleFactor) > 0.01 {
            pdfView.scaleFactor = scaleFactor
        }

        // Update display mode
        pdfView.displayMode = displayMode

        // 处理页面跳转（当 currentPageIndex 从外部改变时）
        if context.coordinator.lastPageIndex != currentPageIndex {
            context.coordinator.lastPageIndex = currentPageIndex
            if let doc = pdfView.document, currentPageIndex >= 0 && currentPageIndex < doc.pageCount {
                if let page = doc.page(at: currentPageIndex) {
                    pdfView.go(to: page)
                }
            }
        }

        // Handle search
        if !searchText.isEmpty && context.coordinator.lastSearchText != searchText {
            context.coordinator.lastSearchText = searchText
            performSearch(pdfView: pdfView, text: searchText)
        }
    }

    private func performSearch(pdfView: PDFView, text: String) {
        guard let document = pdfView.document else { return }
        let selections = document.findString(text, withOptions: .caseInsensitive)
        if let firstSelection = selections.first {
            pdfView.go(to: firstSelection)
            pdfView.setCurrentSelection(firstSelection, animate: true)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PDFViewDelegate {
        var parent: PDFReaderView
        var lastSearchText: String = ""
        var lastPageIndex: Int = -1  // 用于追踪页面变化，避免循环

        init(_ parent: PDFReaderView) {
            self.parent = parent
        }

        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let currentPage = pdfView.currentPage,
                  let document = pdfView.document,
                  let pageIndex = document.index(for: currentPage) as Int? else {
                return
            }
            DispatchQueue.main.async {
                self.parent.currentPageIndex = pageIndex
            }
        }

        @objc func selectionChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView else { return }
            let selectedText = pdfView.currentSelection?.string
            DispatchQueue.main.async {
                self.parent.onSelectionChanged?(selectedText)
            }
        }

        func handleContextAction(_ action: PDFContextAction, text: String) {
            DispatchQueue.main.async {
                self.parent.onContextAction?(action, text)
            }
        }

        func handleAnnotation(_ type: AnnotationType) {
            DispatchQueue.main.async {
                self.parent.onAnnotate?(type)
            }
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}

// MARK: - Custom PDFView with Context Menu

class CustomPDFView: PDFView {
    weak var coordinator: PDFReaderView.Coordinator?

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()

        // 获取选中的文本
        let selectedText = currentSelection?.string ?? ""

        // 检查点击位置是否有标注
        let clickPoint = convert(event.locationInWindow, from: nil)
        let clickedAnnotation = findAnnotationAt(point: clickPoint)

        if let annotation = clickedAnnotation {
            // 点击在标注上 - 显示删除选项
            let deleteItem = NSMenuItem(
                title: "🗑️ " + NSLocalizedString("ctx_delete_annotation", comment: ""),
                action: #selector(deleteAnnotation(_:)),
                keyEquivalent: ""
            )
            deleteItem.target = self
            deleteItem.representedObject = annotation
            menu.addItem(deleteItem)

            menu.addItem(NSMenuItem.separator())
        }

        if !selectedText.isEmpty {
            // 高亮菜单（多颜色）
            // 高亮菜单（多颜色）
            let highlightMenuItem = NSMenuItem(title: "🖍️ " + NSLocalizedString("ctx_highlight", comment: ""), action: nil, keyEquivalent: "")
            let highlightSubmenu = NSMenu()
            
            for color in HighlightColor.allCases {
                let item = NSMenuItem(
                    title: "\(color.emoji) \(color.localizedTitle)",
                    action: #selector(addHighlightWithColor(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = color
                highlightSubmenu.addItem(item)
            }

            highlightMenuItem.submenu = highlightSubmenu
            menu.addItem(highlightMenuItem)

            // 下划线菜单（多样式多颜色）
            // 下划线菜单（多样式多颜色）
            let underlineMenuItem = NSMenuItem(title: "📏 " + NSLocalizedString("ctx_underline", comment: ""), action: nil, keyEquivalent: "")
            let underlineSubmenu = NSMenu()

            // 样式子菜单
            for style in UnderlineStyle.allCases {
                let styleItem = NSMenuItem(title: style.localizedTitle, action: nil, keyEquivalent: "")
                let colorSubmenu = NSMenu()
                
                for color in [HighlightColor.blue, .red, .green, .purple, .orange] {
                    let colorItem = NSMenuItem(
                        title: "\(color.emoji) \(color.localizedTitle)",
                        action: #selector(addUnderlineWithStyleAndColor(_:)),
                        keyEquivalent: ""
                    )
                    colorItem.target = self
                    colorItem.representedObject = ["style": style, "color": color]
                    colorSubmenu.addItem(colorItem)
                }

                styleItem.submenu = colorSubmenu
                underlineSubmenu.addItem(styleItem)
            }

            underlineMenuItem.submenu = underlineSubmenu
            menu.addItem(underlineMenuItem)

            // 删除线
            // 删除线
            let strikethroughItem = NSMenuItem(
                title: "〰️ " + NSLocalizedString("ctx_strikethrough", comment: ""),
                action: #selector(addStrikethrough(_:)),
                keyEquivalent: ""
            )
            strikethroughItem.target = self
            menu.addItem(strikethroughItem)

            menu.addItem(NSMenuItem.separator())

            // AI 功能菜单项
            // AI 功能菜单项
            let aiMenuItem = NSMenuItem(title: "🤖 " + NSLocalizedString("ctx_ai_assist", comment: ""), action: nil, keyEquivalent: "")
            let aiSubmenu = NSMenu()
            
            let translateItem = NSMenuItem(
                title: "🌐 " + NSLocalizedString("ctx_translate", comment: ""),
                action: #selector(translateToChinese(_:)),
                keyEquivalent: ""
            )
            translateItem.target = self
            aiSubmenu.addItem(translateItem)

            let explainItem = NSMenuItem(
                title: "💡 " + NSLocalizedString("ctx_explain", comment: ""),
                action: #selector(explainContent(_:)),
                keyEquivalent: ""
            )
            explainItem.target = self
            aiSubmenu.addItem(explainItem)

            let summarizeItem = NSMenuItem(
                title: "📝 " + NSLocalizedString("ctx_summarize", comment: ""),
                action: #selector(summarizeContent(_:)),
                keyEquivalent: ""
            )
            summarizeItem.target = self
            aiSubmenu.addItem(summarizeItem)

            aiMenuItem.submenu = aiSubmenu
            menu.addItem(aiMenuItem)

            menu.addItem(NSMenuItem.separator())

            // 搜索菜单项（使用 Bing）
            // 搜索菜单项（使用 Bing）
            let searchItem = NSMenuItem(
                title: "🔍 " + String(format: "%@「%@%@」", NSLocalizedString("ctx_search_prefix", comment: ""), String(selectedText.prefix(20)), selectedText.count > 20 ? "..." : ""),
                action: #selector(searchWeb(_:)),
                keyEquivalent: ""
            )
            searchItem.target = self
            menu.addItem(searchItem)

            menu.addItem(NSMenuItem.separator())

            // 复制
            // 复制
            let copyItem = NSMenuItem(
                title: NSLocalizedString("ctx_copy", comment: ""),
                action: #selector(copyText(_:)),
                keyEquivalent: "c"
            )
            copyItem.target = self
            menu.addItem(copyItem)
        } else if clickedAnnotation == nil {
            // 没有选中文本且没有点击标注时的菜单
            let selectAllItem = NSMenuItem(
                title: NSLocalizedString("ctx_select_all", comment: ""),
                action: #selector(selectAllText(_:)),
                keyEquivalent: "a"
            )
            selectAllItem.target = self
            menu.addItem(selectAllItem)

            // 清除所有标注
            if hasAnnotations() {
                menu.addItem(NSMenuItem.separator())

                let clearAllItem = NSMenuItem(
                    title: "🗑️ " + NSLocalizedString("ctx_clear_annotations", comment: ""),
                    action: #selector(clearAllAnnotations(_:)),
                    keyEquivalent: ""
                )
                clearAllItem.target = self
                menu.addItem(clearAllItem)
            }
        }

        return menu
    }

    // MARK: - Helper Methods

    private func findAnnotationAt(point: NSPoint) -> PDFAnnotation? {
        guard let page = currentPage else { return nil }
        let pagePoint = convert(point, to: page)

        for annotation in page.annotations {
            if annotation.bounds.contains(pagePoint) &&
               (annotation.type == "Highlight" || annotation.type == "Underline" || annotation.type == "StrikeOut") {
                return annotation
            }
        }
        return nil
    }

    private func hasAnnotations() -> Bool {
        guard let document = document else { return false }
        for i in 0..<document.pageCount {
            if let page = document.page(at: i), !page.annotations.isEmpty {
                for annotation in page.annotations {
                    if annotation.type == "Highlight" || annotation.type == "Underline" || annotation.type == "StrikeOut" {
                        return true
                    }
                }
            }
        }
        return false
    }

    // MARK: - Annotation Actions

    @objc private func deleteAnnotation(_ sender: NSMenuItem) {
        guard let annotation = sender.representedObject as? PDFAnnotation else { return }

        // 获取 groupID
        if let groupID = annotation.value(forAnnotationKey: PDFAnnotationKey(rawValue: "GroupID")) as? String {
            // 删除所有具有相同 groupID 的标注（可能跨页）
            deleteAnnotationGroup(groupID: groupID)
        } else {
            // 没有 groupID，只删除单个标注
            if let page = annotation.page {
                page.removeAnnotation(annotation)
            }
        }
    }

    /// 删除具有相同 groupID 的所有标注
    private func deleteAnnotationGroup(groupID: String) {
        guard let document = document else { return }

        for i in 0..<document.pageCount {
            if let page = document.page(at: i) {
                let annotationsToRemove = page.annotations.filter { annotation in
                    if let annotationGroupID = annotation.value(forAnnotationKey: PDFAnnotationKey(rawValue: "GroupID")) as? String {
                        return annotationGroupID == groupID
                    }
                    return false
                }
                for annotation in annotationsToRemove {
                    page.removeAnnotation(annotation)
                }
            }
        }
    }

    @objc private func clearAllAnnotations(_ sender: Any?) {
        guard let document = document else { return }
        for i in 0..<document.pageCount {
            if let page = document.page(at: i) {
                let annotationsToRemove = page.annotations.filter {
                    $0.type == "Highlight" || $0.type == "Underline" || $0.type == "StrikeOut"
                }
                for annotation in annotationsToRemove {
                    page.removeAnnotation(annotation)
                }
            }
        }
    }

    @objc private func addHighlightWithColor(_ sender: NSMenuItem) {
        guard let color = sender.representedObject as? HighlightColor else { return }
        addAnnotation(type: .highlight, color: color.nsColor.withAlphaComponent(0.4))
    }

    @objc private func addUnderlineWithStyleAndColor(_ sender: NSMenuItem) {
        guard let params = sender.representedObject as? [String: Any],
              let style = params["style"] as? UnderlineStyle,
              let color = params["color"] as? HighlightColor else { return }
        addAnnotation(type: .underline, color: color.nsColor, underlineStyle: style)
    }

    @objc private func addStrikethrough(_ sender: Any?) {
        addAnnotation(type: .strikethrough, color: NSColor.red)
    }

    private func addAnnotation(type: AnnotationType, color: NSColor, underlineStyle: UnderlineStyle? = nil) {
        guard let selection = currentSelection else { return }

        // 为整组标注生成唯一的 groupID
        let groupID = UUID().uuidString

        // 为选中的每一行添加标注
        for pageSelection in selection.selectionsByLine() {
            guard let page = pageSelection.pages.first else { continue }
            let bounds = pageSelection.bounds(for: page)

            let annotation: PDFAnnotation
            switch type {
            case .highlight:
                annotation = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
                annotation.color = color
            case .underline:
                annotation = PDFAnnotation(bounds: bounds, forType: .underline, withProperties: nil)
                annotation.color = color
                if let style = underlineStyle {
                    let border = PDFBorder()
                    border.lineWidth = style.lineWidth
                    border.style = style.borderStyle
                    annotation.border = border
                }
            case .strikethrough:
                annotation = PDFAnnotation(bounds: bounds, forType: .strikeOut, withProperties: nil)
                annotation.color = color
            }

            // 设置 groupID，用于整体删除
            annotation.setValue(groupID, forAnnotationKey: PDFAnnotationKey(rawValue: "GroupID"))

            page.addAnnotation(annotation)
        }

        // 清除选择
        clearSelection()

        // 通知 coordinator
        coordinator?.handleAnnotation(type)
    }

    // MARK: - AI Actions

    @objc private func translateToChinese(_ sender: Any?) {
        guard let text = currentSelection?.string, !text.isEmpty else { return }
        coordinator?.handleContextAction(.translateToChinese, text: text)
    }

    @objc private func explainContent(_ sender: Any?) {
        guard let text = currentSelection?.string, !text.isEmpty else { return }
        coordinator?.handleContextAction(.explain, text: text)
    }

    @objc private func summarizeContent(_ sender: Any?) {
        guard let text = currentSelection?.string, !text.isEmpty else { return }
        coordinator?.handleContextAction(.summarize, text: text)
    }

    @objc private func searchWeb(_ sender: Any?) {
        guard let text = currentSelection?.string, !text.isEmpty else { return }
        // 使用 Bing 搜索
        let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
        if let url = URL(string: "https://www.bing.com/search?q=\(encodedText)") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func copyText(_ sender: Any?) {
        guard let text = currentSelection?.string, !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    @objc private func selectAllText(_ sender: Any?) {
        selectAll(nil)
    }
}

// MARK: - PDFView Extensions for zoom control
extension PDFView {
    func zoomIn() {
        scaleFactor = min(scaleFactor * 1.25, 5.0)
    }

    func zoomOut() {
        scaleFactor = max(scaleFactor / 1.25, 0.25)
    }

    func zoomToFit() {
        autoScales = true
    }
}
