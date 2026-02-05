//
//  ChatBubbleView.swift
//  AIPaperReader
//
//  Created by Claude on 2/4/26.
//

import SwiftUI
import WebKit

struct ChatBubbleView: View {
    let message: ChatMessage
    let isStreaming: Bool

    @State private var isHovered: Bool = false
    @State private var showCopiedToast: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.role == .assistant {
                // AI avatar
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.purple)
                    .frame(width: 28, height: 28)
                    .background(Color.purple.opacity(0.1))
                    .clipShape(Circle())
            } else {
                Spacer(minLength: 48)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                // Message content with copy buttons
                ZStack(alignment: .topTrailing) {
                    MessageContentView(content: message.content, role: message.role)

                    // Copy buttons (show on hover)
                    if isHovered && !isStreaming {
                        CopyButtonsView(
                            content: message.content,
                            onCopied: {
                                showCopiedToast = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    showCopiedToast = false
                                }
                            }
                        )
                        .padding(4)
                    }
                }
                .onHover { hovering in
                    isHovered = hovering
                }

                // Timestamp, streaming indicator, and copied toast
                HStack(spacing: 4) {
                    if showCopiedToast {
                        Label("已复制", systemImage: "checkmark")
                            .font(.caption2)
                            .foregroundColor(.green)
                            .transition(.opacity)
                    }

                    if isStreaming {
                        ProgressView()
                            .controlSize(.small)
                    }

                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .animation(.easeInOut(duration: 0.2), value: showCopiedToast)
            }

            if message.role == .user {
                // User avatar
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            } else {
                Spacer(minLength: 48)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - Copy Buttons View

struct CopyButtonsView: View {
    let content: String
    var onCopied: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            // Copy as Markdown
            Button(action: { copyAsMarkdown() }) {
                Image(systemName: "doc.on.doc")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .padding(4)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .help("复制 (保留 Markdown 格式)")

            // Copy as plain text
            Button(action: { copyAsPlainText() }) {
                Image(systemName: "doc.plaintext")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .padding(4)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .help("复制纯文本 (去除 Markdown 格式)")
        }
    }

    private func copyAsMarkdown() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        onCopied()
    }

    private func copyAsPlainText() {
        let plainText = removeMarkdown(from: content)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(plainText, forType: .string)
        onCopied()
    }

    /// 移除 Markdown 标记，返回纯文本
    private func removeMarkdown(from text: String) -> String {
        var result = text

        // 移除代码块
        result = result.replacingOccurrences(of: "```[\\s\\S]*?```", with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "`([^`]+)`", with: "$1", options: .regularExpression)

        // 移除标题标记
        result = result.replacingOccurrences(of: "^#{1,6}\\s+", with: "", options: .regularExpression)

        // 移除粗体和斜体
        result = result.replacingOccurrences(of: "\\*\\*([^*]+)\\*\\*", with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: "\\*([^*]+)\\*", with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: "__([^_]+)__", with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: "_([^_]+)_", with: "$1", options: .regularExpression)

        // 移除链接
        result = result.replacingOccurrences(of: "\\[([^\\]]+)\\]\\([^)]+\\)", with: "$1", options: .regularExpression)

        // 移除列表标记
        result = result.replacingOccurrences(of: "^[\\s]*[-*+]\\s+", with: "• ", options: .regularExpression)
        result = result.replacingOccurrences(of: "^[\\s]*\\d+\\.\\s+", with: "", options: .regularExpression)

        // 移除引用
        result = result.replacingOccurrences(of: "^>\\s*", with: "", options: .regularExpression)

        // 移除多余空行
        result = result.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct MessageContentView: View {
    let content: String
    let role: MessageRole

    var body: some View {
        if role == .assistant {
            // Render rich markdown for assistant messages
            RichMarkdownView(content: content)
                .textSelection(.enabled)
                .padding(12)
                .background(Color.secondary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            // Plain text for user messages
            Text(content)
                .textSelection(.enabled)
                .padding(12)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Rich Markdown View (支持更多格式)

struct RichMarkdownView: View {
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(parseBlocks(content).enumerated()), id: \.offset) { _, block in
                renderBlock(block)
            }
        }
    }

    private func parseBlocks(_ text: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var currentText = ""
        var inCodeBlock = false
        var codeBlockLanguage = ""
        var codeBlockContent = ""
        var inMathBlock = false
        var mathBlockContent = ""

        let lines = text.components(separatedBy: "\n")

        for line in lines {
            // Handle Code Blocks
            if line.hasPrefix("```") && !inMathBlock {
                if inCodeBlock {
                    // End code block
                    blocks.append(.codeBlock(language: codeBlockLanguage, code: codeBlockContent.trimmingCharacters(in: .newlines)))
                    codeBlockContent = ""
                    codeBlockLanguage = ""
                    inCodeBlock = false
                } else {
                    // Start code block - save current text first
                    if !currentText.isEmpty {
                        blocks.append(.text(currentText.trimmingCharacters(in: .newlines)))
                        currentText = ""
                    }
                    inCodeBlock = true
                    codeBlockLanguage = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                }
            } 
            // Handle Math Blocks
            else if line.trimmingCharacters(in: .whitespaces) == "$$" && !inCodeBlock {
                if inMathBlock {
                    // End math block
                    blocks.append(.latex(mathBlockContent.trimmingCharacters(in: .newlines)))
                    mathBlockContent = ""
                    inMathBlock = false
                } else {
                    // Start math block
                    if !currentText.isEmpty {
                        blocks.append(.text(currentText.trimmingCharacters(in: .newlines)))
                        currentText = ""
                    }
                    inMathBlock = true
                }
            }
            else if inCodeBlock {
                codeBlockContent += line + "\n"
            } else if inMathBlock {
                mathBlockContent += line + "\n"
            } else {
                currentText += line + "\n"
            }
        }

        // Add remaining text
        if !currentText.isEmpty {
            blocks.append(.text(currentText.trimmingCharacters(in: .newlines)))
        }

        return blocks
    }

    @ViewBuilder
    private func renderBlock(_ block: MarkdownBlock) -> some View {
        switch block {
        case .text(let text):
            if let attributed = try? AttributedString(
                markdown: text,
                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            ) {
                Text(attributed)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(text)
                    .fixedSize(horizontal: false, vertical: true)
            }

        case .codeBlock(let language, let code):
            CodeBlockView(language: language, code: code)
        case .latex(let latex):
            LatexView(latex: latex)
                .frame(height: 100) // Fixed height for now, dynamic height is complex
        }
    }
}

struct LatexView: NSViewRepresentable {
    let latex: String
    
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.setValue(false, forKey: "drawsBackground") // Transparent
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <script src="https://polyfill.io/v3/polyfill.min.js?features=es6"></script>
            <script id="MathJax-script" async src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js"></script>
            <style>
                body {
                    background-color: transparent;
                    color: black;
                    font-size: 14px;
                    font-family: -apple-system, system-ui;
                    margin: 0;
                    padding: 8px;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                }
                @media (prefers-color-scheme: dark) {
                    body { color: white; }
                }
            </style>
        </head>
        <body>
        $$ \(latex) $$
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }
}

enum MarkdownBlock {
    case text(String)
    case codeBlock(language: String, code: String)
    case latex(String)
}

// MARK: - Code Block View

struct CodeBlockView: View {
    let language: String
    let code: String

    @State private var isCopied: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with language and copy button
            HStack {
                Text(language.isEmpty ? "Code" : language)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: copyCode) {
                    HStack(spacing: 4) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        Text(isCopied ? "已复制" : "复制")
                    }
                    .font(.caption)
                    .foregroundColor(isCopied ? .green : .secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.3))

            // Code content
            ScrollView(.horizontal, showsIndicators: true) {
                Text(code)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white)
                    .textSelection(.enabled)
                    .padding(12)
            }
        }
        .background(Color(red: 0.15, green: 0.15, blue: 0.15))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func copyCode() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        isCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isCopied = false
        }
    }
}

/// Simple Markdown text view using AttributedString (保留兼容)
struct MarkdownTextView: View {
    let content: String

    var body: some View {
        RichMarkdownView(content: content)
    }
}

// MARK: - Streaming Message View

struct StreamingMessageView: View {
    let content: String
    var isSearching: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // AI avatar
            Image(systemName: "sparkles")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.purple)
                .frame(width: 28, height: 28)
                .background(Color.purple.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                if isSearching {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Searching context...")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .background(Color.secondary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    // Content
                    if !content.isEmpty {
                         Text(content)
                            .textSelection(.enabled)
                            .padding(12)
                            .background(Color.secondary.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Footer
                    HStack(spacing: 4) {
                        ProgressView()
                            .controlSize(.small)

                        Text("Generating...")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                        .fixedSize(horizontal: false, vertical: true)
                }

            }

            Spacer(minLength: 48)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

#Preview {
    VStack {
        ChatBubbleView(
            message: ChatMessage.user("What is the main contribution of this paper?"),
            isStreaming: false
        )

        ChatBubbleView(
            message: ChatMessage.assistant("""
            The paper presents a **novel approach** to machine learning:

            1. First point
            2. Second point

            ```python
            def hello():
                print("Hello World")
            ```

            This is `inline code` example.
            """),
            isStreaming: false
        )

        StreamingMessageView(content: "Analyzing the document...")
    }
    .frame(width: 400)
}
