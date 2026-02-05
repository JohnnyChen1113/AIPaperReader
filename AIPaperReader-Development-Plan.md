# AIPaperReader 开发计划

> macOS 原生学术论文阅读器，核心功能：AI 驱动的论文问答 + PDF 阅读 + 轻量翻译
> 技术栈：Swift + SwiftUI + PDFKit + Core ML
> 目标平台：macOS 15+ (Apple Silicon)
> 开发环境：Xcode 16.3, M3 Mac

---

## 一、项目概览

### 1.1 产品定位

AIPaperReader 是一款面向科研工作者的 macOS 原生 PDF 论文阅读器。核心卖点是 **AI 文档问答**——用户打开论文后，可以直接与 AI 就论文内容进行对话。同时提供轻量翻译功能作为辅助。

### 1.2 核心功能（按优先级排序）

1. **PDF 阅读**：原生 PDFKit 渲染，支持缩放、搜索、目录导航、文本选中
2. **AI 论文问答**：提取 PDF 文本 → 构造 prompt → 调用 LLM API → 流式输出回答
3. **多 LLM 后端**：支持 OpenAI 兼容 API / Ollama 本地模型 / 自定义端点
4. **选中文本翻译**：选中文本后一键翻译（Apple Translation + LLM 翻译）
5. **对话历史管理**：保存和回顾与每篇论文的问答记录
6. **设置管理**：API Key、模型选择、system prompt 自定义

### 1.3 竞品对标

本项目参考 [FreePDF](https://github.com/zstar1003/FreePDF) 的产品思路，但：
- FreePDF 用 Python + PyQt6 + pdf.js，我们用 Swift + SwiftUI + PDFKit（更原生更轻量）
- FreePDF 以翻译为核心，我们以 **AI 问答** 为核心
- FreePDF 打包后数百 MB，我们目标 < 50MB

### 1.4 项目结构

```
AIPaperReader/
├── AIPaperReaderApp.swift          # App 入口
├── Models/                          # 数据模型
│   ├── PDFDocumentModel.swift       # PDF 文档模型
│   ├── ChatMessage.swift            # 聊天消息模型
│   ├── LLMProvider.swift            # LLM 提供商枚举
│   └── AppSettings.swift            # 应用设置模型
├── Services/                        # 服务层
│   ├── LLMService/                  # LLM 服务
│   │   ├── LLMServiceProtocol.swift # LLM 服务协议
│   │   ├── OpenAIService.swift      # OpenAI 兼容 API
│   │   ├── OllamaService.swift      # Ollama 本地服务
│   │   └── LLMServiceFactory.swift  # 服务工厂
│   ├── PDFTextExtractor.swift       # PDF 文本提取
│   ├── TranslationService.swift     # 翻译服务
│   └── ChatHistoryStore.swift       # 对话历史持久化
├── ViewModels/                      # ViewModel 层
│   ├── PDFReaderViewModel.swift     # PDF 阅读 VM
│   ├── ChatViewModel.swift          # 聊天 VM
│   └── SettingsViewModel.swift      # 设置 VM
├── Views/                           # 视图层
│   ├── MainWindow/
│   │   ├── ContentView.swift        # 主内容视图（左右分栏）
│   │   ├── PDFReaderView.swift      # PDF 阅读区
│   │   ├── SidebarView.swift        # 侧边栏（目录/问答切换）
│   │   └── ToolbarView.swift        # 顶部工具栏
│   ├── Chat/
│   │   ├── ChatPanelView.swift      # 聊天面板
│   │   ├── ChatBubbleView.swift     # 聊天气泡
│   │   ├── ChatInputView.swift      # 输入框
│   │   └── MarkdownRendererView.swift # Markdown 渲染
│   ├── Settings/
│   │   ├── SettingsView.swift       # 设置主视图
│   │   ├── LLMSettingsView.swift    # LLM 配置
│   │   └── GeneralSettingsView.swift # 通用设置
│   └── Components/
│       ├── PDFThumbnailSidebar.swift # PDF 缩略图
│       └── TranslationPopover.swift  # 翻译弹出框
├── Resources/
│   ├── Assets.xcassets               # 图标和颜色
│   └── Localizable.xcstrings         # 国际化
└── Info.plist
```

---

## 二、分阶段开发计划

每个阶段都是一个完整的、可运行的里程碑。请严格按顺序执行。

---

### 阶段 1：项目骨架与 PDF 阅读器

**目标**：创建 Xcode 项目，实现基本的 PDF 打开和阅读功能。

#### 任务清单

1. **创建 Xcode 项目**
   - 项目名：AIPaperReader
   - 类型：macOS App
   - 界面：SwiftUI
   - 语言：Swift
   - 最低部署目标：macOS 15.0
   - Bundle Identifier: `com.bioinfoark.aipaperreader`

2. **实现 PDFReaderView**
   - 用 `NSViewRepresentable` 包装 PDFKit 的 `PDFView`
   - 支持功能：
     - 打开 PDF 文件（File > Open 和拖拽）
     - 页面缩放（pinch、快捷键 ⌘+ / ⌘-）
     - 页面滚动和翻页
     - 文本搜索（⌘F）
     - 文本选中和复制
     - 自动适应宽度

3. **实现主窗口布局**
   - 使用 `NavigationSplitView` 或 `HSplitView` 做左右分栏
   - 左侧：侧边栏（后续放目录和聊天，此阶段先放 PDF 缩略图列表）
   - 右侧：PDF 阅读区
   - 侧边栏可折叠

4. **实现 PDF 缩略图侧边栏**
   - 显示所有页面缩略图
   - 点击缩略图跳转到对应页面
   - 高亮当前页面

5. **实现 PDF 目录导航**
   - 读取 PDF 的 `outlineRoot`（目录/书签）
   - 在侧边栏显示可折叠的目录树
   - 点击目录项跳转到对应位置

6. **菜单和快捷键**
   - File > Open (⌘O)
   - 最近打开的文件列表
   - View > Zoom In/Out
   - 注册为 PDF 文件的可选打开方式

#### 关键代码指引

```swift
// PDFReaderView.swift - PDFView 的 SwiftUI 包装
import SwiftUI
import PDFKit

struct PDFReaderView: NSViewRepresentable {
    let document: PDFDocument?
    @Binding var currentPage: Int

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        if pdfView.document !== document {
            pdfView.document = document
        }
    }
}
```

```swift
// ContentView.swift - 主窗口布局
struct ContentView: View {
    @State private var document: PDFDocument?

    var body: some View {
        NavigationSplitView {
            SidebarView(document: document)
        } detail: {
            PDFReaderView(document: document, currentPage: $currentPage)
        }
        .onDrop(of: [.pdf], isTargeted: nil) { providers in
            // 处理拖拽
        }
    }
}
```

#### 验收标准
- [ ] 能通过菜单和拖拽打开 PDF
- [ ] PDF 渲染清晰，支持缩放和滚动
- [ ] 侧边栏显示缩略图和目录
- [ ] 文本搜索可用
- [ ] 整体 UI 风格符合 macOS 设计语言

---

### 阶段 2：PDF 文本提取服务

**目标**：实现从 PDF 中提取文本的核心服务，为 AI 问答提供数据基础。

#### 任务清单

1. **实现 PDFTextExtractor 服务**
   - 逐页提取文本（`PDFPage.string`）
   - 支持指定页面范围提取（如 "1-5,8,10-15"）
   - 处理提取文本的清洗：去除多余空白、合并断行
   - 估算 token 数量（简单按字符数 / 4 估算英文，中文按字符数估算）

2. **实现选中文本提取**
   - 监听 `PDFView` 的选中变化通知
   - 获取当前选中的文本内容
   - 获取选中文本所在的页码

3. **Token 预算管理**
   - 设置最大 context token 数（如 8000, 16000, 32000 等可配置）
   - 当全文超过 token 预算时，支持：
     - 截断策略：只取前 N 页
     - 摘要策略：每页取前 K 句话
   - 在 UI 上显示当前文档的估算 token 数

#### 关键代码指引

```swift
// PDFTextExtractor.swift
class PDFTextExtractor {
    func extractText(from document: PDFDocument, pages: Range<Int>? = nil) -> String {
        let range = pages ?? 0..<document.pageCount
        return range.compactMap { index in
            document.page(at: index)?.string
        }.joined(separator: "\n\n--- Page \(index + 1) ---\n\n")
    }

    func extractSelectedText(from pdfView: PDFView) -> String? {
        return pdfView.currentSelection?.string
    }

    func estimateTokenCount(_ text: String) -> Int {
        // 粗略估算：英文 ~4 chars/token，中文 ~1.5 chars/token
        let englishChars = text.unicodeScalars.filter { $0.isASCII }.count
        let cjkChars = text.count - englishChars
        return englishChars / 4 + Int(Double(cjkChars) / 1.5)
    }
}
```

#### 验收标准
- [ ] 能提取完整 PDF 文本
- [ ] 支持按页面范围提取
- [ ] token 估算基本准确
- [ ] 选中文本可正确获取

---

### 阶段 3：LLM 服务层

**目标**：实现可扩展的 LLM 服务抽象层，支持多个后端。

#### 任务清单

1. **定义 LLM 服务协议**

```swift
// LLMServiceProtocol.swift
protocol LLMServiceProtocol {
    /// 发送消息并获取流式响应
    func sendMessage(
        messages: [ChatMessage],
        systemPrompt: String,
        onToken: @escaping (String) -> Void,
        onComplete: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) async throws

    /// 测试连接是否可用
    func testConnection() async throws -> Bool

    /// 获取可用模型列表
    func availableModels() async throws -> [String]
}
```

2. **实现 OpenAI 兼容服务**（覆盖 OpenAI / 硅基流动 / DeepSeek / 其它兼容 API）
   - 支持自定义 base URL
   - 支持流式响应（SSE: Server-Sent Events）
   - 正确处理 `data: [DONE]` 结束标记
   - 错误处理：网络错误、API 限流、token 超限等
   - 支持配置 temperature、max_tokens 等参数

3. **实现 Ollama 服务**
   - 调用 `http://localhost:11434/api/chat` 端点
   - 支持流式响应
   - 自动检测 Ollama 是否运行
   - 获取本地已安装的模型列表（`/api/tags`）

4. **实现服务工厂**

```swift
// LLMServiceFactory.swift
class LLMServiceFactory {
    static func create(provider: LLMProvider, config: LLMConfig) -> LLMServiceProtocol {
        switch provider {
        case .openai:
            return OpenAIService(config: config)
        case .ollama:
            return OllamaService(config: config)
        case .custom:
            return OpenAIService(config: config) // OpenAI 兼容
        }
    }
}
```

5. **数据模型**

```swift
// LLMProvider.swift
enum LLMProvider: String, Codable, CaseIterable {
    case openai = "OpenAI 兼容"
    case ollama = "Ollama"
    case custom = "自定义"
}

struct LLMConfig: Codable {
    var provider: LLMProvider
    var baseURL: String
    var apiKey: String
    var modelName: String
    var temperature: Double = 0.7
    var maxTokens: Int = 4096
    var contextTokenBudget: Int = 16000
}
```

#### OpenAI 兼容 API 流式调用的关键实现

```swift
// OpenAIService.swift 核心片段
func sendMessage(messages: [ChatMessage], systemPrompt: String,
                 onToken: @escaping (String) -> Void,
                 onComplete: @escaping () -> Void,
                 onError: @escaping (Error) -> Void) async throws {

    var request = URLRequest(url: URL(string: "\(config.baseURL)/v1/chat/completions")!)
    request.httpMethod = "POST"
    request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let body: [String: Any] = [
        "model": config.modelName,
        "stream": true,
        "temperature": config.temperature,
        "max_tokens": config.maxTokens,
        "messages": [
            ["role": "system", "content": systemPrompt]
        ] + messages.map { ["role": $0.role, "content": $0.content] }
    ]
    request.httpBody = try JSONSerialization.data(withJSONObject: body)

    let (bytes, response) = try await URLSession.shared.bytes(for: request)

    guard let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode == 200 else {
        throw LLMError.apiError("HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
    }

    for try await line in bytes.lines {
        guard line.hasPrefix("data: ") else { continue }
        let data = String(line.dropFirst(6))
        if data == "[DONE]" { onComplete(); return }
        if let json = try? JSONSerialization.jsonObject(with: Data(data.utf8)) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let delta = choices.first?["delta"] as? [String: Any],
           let content = delta["content"] as? String {
            onToken(content)
        }
    }
}
```

#### 验收标准
- [ ] OpenAI 兼容 API 可正常对话（流式输出）
- [ ] Ollama 可正常对话
- [ ] 可自动获取 Ollama 本地模型列表
- [ ] 连接测试功能正常
- [ ] 错误信息清晰可读

---

### 阶段 4：AI 问答聊天界面

**目标**：实现完整的论文问答交互界面。

#### 任务清单

1. **聊天面板 UI**
   - 在主窗口右侧（或侧边栏）添加聊天面板
   - 消息列表：支持用户消息和 AI 回复的气泡样式
   - AI 回复支持 Markdown 渲染（标题、代码块、列表、粗体斜体）
   - 输入框：支持多行输入，Enter 发送，Shift+Enter 换行
   - 发送按钮和停止生成按钮
   - 打字机效果（流式输出时逐字显示）

2. **聊天 ViewModel**

```swift
// ChatViewModel.swift
@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isGenerating: Bool = false
    @Published var currentStreamingText: String = ""

    private let llmService: LLMServiceProtocol
    private let textExtractor: PDFTextExtractor
    private var currentTask: Task<Void, Never>?

    func sendMessage(document: PDFDocument?, pageRange: String?) {
        let userMessage = ChatMessage(role: .user, content: inputText)
        messages.append(userMessage)
        inputText = ""
        isGenerating = true

        currentTask = Task {
            let pdfContent = extractRelevantText(from: document, pageRange: pageRange)
            let systemPrompt = buildSystemPrompt(pdfContent: pdfContent)

            do {
                try await llmService.sendMessage(
                    messages: messages,
                    systemPrompt: systemPrompt,
                    onToken: { [weak self] token in
                        Task { @MainActor in
                            self?.currentStreamingText += token
                        }
                    },
                    onComplete: { [weak self] in
                        Task { @MainActor in
                            self?.finalizeResponse()
                        }
                    },
                    onError: { [weak self] error in
                        Task { @MainActor in
                            self?.handleError(error)
                        }
                    }
                )
            } catch {
                handleError(error)
            }
        }
    }

    func stopGenerating() {
        currentTask?.cancel()
        finalizeResponse()
    }
}
```

3. **System Prompt 构建**
   - 默认 prompt 模板（可自定义）：
   ```
   你是一个专业的学术论文分析助手。用户正在阅读一篇学术论文，请基于论文内容回答问题。

   论文内容如下：
   {pdf_content}

   要求：
   1. 仅基于论文内容回答，不要编造内容
   2. 引用时注明页码
   3. 如果问题超出论文范围，请明确说明
   4. 使用与用户相同的语言回答
   ```

4. **页面范围选择 UI**
   - 在聊天面板顶部显示"分析范围"控件
   - 选项：全文 / 当前页 / 自定义页面范围
   - 显示选定范围的估算 token 数

5. **Markdown 渲染**
   - 使用 `AttributedString` 或第三方库渲染 Markdown
   - 支持：标题、代码块（带语法高亮）、列表、粗体/斜体、链接
   - 代码块支持一键复制

6. **预设问题/快捷操作**
   - 提供常用学术问题按钮：
     - "总结这篇论文的主要贡献"
     - "这篇论文的研究方法是什么？"
     - "列出论文的主要结论"
     - "这篇论文的局限性有哪些？"
     - "解释 [选中文本]"

#### 聊天气泡 UI 参考

```swift
// ChatBubbleView.swift
struct ChatBubbleView: View {
    let message: ChatMessage
    let isStreaming: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.role == .assistant {
                Image(systemName: "sparkles")
                    .foregroundStyle(.purple)
                    .frame(width: 28, height: 28)
            }

            VStack(alignment: .leading, spacing: 4) {
                // Markdown 渲染的消息内容
                MarkdownRendererView(text: message.content)
                    .textSelection(.enabled)

                if isStreaming {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }
            .padding(12)
            .background(message.role == .user ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if message.role == .user {
                Image(systemName: "person.circle.fill")
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }
        }
        .padding(.horizontal)
    }
}
```

#### 验收标准
- [ ] 能与 AI 正常对话，流式输出
- [ ] Markdown 渲染正确
- [ ] 页面范围选择功能正常
- [ ] 停止生成功能正常
- [ ] 预设问题按钮可用
- [ ] 聊天面板与 PDF 阅读器左右布局协调

---

### 阶段 5：设置与配置管理

**目标**：实现完整的设置界面和配置持久化。

#### 任务清单

1. **设置窗口**（macOS Settings scene）
   - 通用设置 Tab：
     - 外观：跟随系统 / 浅色 / 深色
     - 默认分析页面范围
     - 语言偏好
   - LLM 设置 Tab：
     - 服务提供商选择（Picker）
     - API Base URL 输入
     - API Key 输入（SecureField，存入 Keychain）
     - 模型名称（手动输入或从列表选择）
     - Temperature 滑块 (0-2)
     - Max Tokens 输入
     - Context Token Budget 选择
     - 连接测试按钮
   - 问答设置 Tab：
     - 自定义 System Prompt（TextEditor）
     - 恢复默认按钮
   - 翻译设置 Tab（后续阶段）

2. **配置持久化**
   - 使用 `@AppStorage` 存储普通设置
   - 使用 macOS Keychain 存储 API Key（安全）
   - 支持导出/导入配置

3. **API Key 安全存储**

```swift
// KeychainHelper.swift
class KeychainHelper {
    static func save(key: String, value: String) throws { ... }
    static func read(key: String) throws -> String? { ... }
    static func delete(key: String) throws { ... }
}
```

4. **多配置 Profile 支持**（可选进阶）
   - 允许保存多个 LLM 配置（如"OpenAI GPT-4"、"本地 Ollama"）
   - 快速切换

#### 验收标准
- [ ] 设置窗口可正常打开和保存
- [ ] API Key 安全存储在 Keychain
- [ ] 切换 LLM 后端后问答功能正常
- [ ] 连接测试反馈清晰

---

### 阶段 6：选中文本翻译

**目标**：实现轻量级的选中文本翻译功能。

#### 任务清单

1. **翻译服务协议与实现**

```swift
protocol TranslationServiceProtocol {
    func translate(text: String, from: Language, to: Language) async throws -> String
}

// 实现 1：Apple Translation（macOS 15+，免费离线）
class AppleTranslationService: TranslationServiceProtocol { ... }

// 实现 2：LLM 翻译（复用现有 LLM 服务）
class LLMTranslationService: TranslationServiceProtocol { ... }
```

2. **翻译交互方式**
   - 选中文本后，右键菜单出现"翻译"选项
   - 或使用快捷键 ⌘T 触发翻译
   - 翻译结果以 Popover 形式显示在选中文本附近
   - Popover 中显示原文和译文对照
   - 可一键复制译文

3. **翻译 Popover UI**

```swift
struct TranslationPopover: View {
    let originalText: String
    let translatedText: String
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("原文").font(.caption).foregroundStyle(.secondary)
            Text(originalText).font(.body).textSelection(.enabled)
            Divider()
            Text("译文").font(.caption).foregroundStyle(.secondary)
            if isLoading {
                ProgressView()
            } else {
                Text(translatedText).font(.body).textSelection(.enabled)
            }
        }
        .padding()
        .frame(maxWidth: 400)
    }
}
```

4. **语言设置**
   - 源语言：自动检测 / 手动选择
   - 目标语言：默认中文，可切换

#### 验收标准
- [ ] 选中文本后可触发翻译
- [ ] Popover 正确显示在选中位置附近
- [ ] Apple Translation 离线可用
- [ ] LLM 翻译可用

---

### 阶段 7：对话历史与数据持久化

**目标**：保存每篇论文的问答历史，下次打开时可回顾。

#### 任务清单

1. **数据模型（SwiftData）**

```swift
import SwiftData

@Model
class PaperSession {
    var id: UUID
    var pdfPath: String          // PDF 文件路径
    var pdfTitle: String         // 论文标题（从 PDF metadata 提取）
    var createdAt: Date
    var lastAccessedAt: Date
    var messages: [ChatMessageRecord]

    init(pdfPath: String, pdfTitle: String) { ... }
}

@Model
class ChatMessageRecord {
    var id: UUID
    var role: String             // "user" / "assistant"
    var content: String
    var timestamp: Date
    var session: PaperSession?
}
```

2. **历史面板 UI**
   - 在侧边栏添加"历史"tab
   - 显示所有论文的问答会话列表
   - 按最近访问排序
   - 搜索历史会话
   - 点击恢复对话上下文
   - 滑动删除会话

3. **自动关联**
   - 打开 PDF 时，自动检查是否有历史会话
   - 如有，提示"是否继续上次的对话？"
   - 基于文件路径 + 文件 hash 做匹配

#### 验收标准
- [ ] 对话历史正确持久化
- [ ] 重新打开同一 PDF 时可恢复历史
- [ ] 历史搜索功能正常
- [ ] 删除会话功能正常

---

### 阶段 8：UI 打磨与体验优化

**目标**：提升整体视觉和交互体验，达到上架品质。

#### 任务清单

1. **视觉优化**
   - 设计 App Icon（学术感 + AI 元素，可用 SF Symbols 组合先占位）
   - 深色模式完美适配
   - 侧边栏和聊天面板的动画过渡
   - 空状态引导（未打开 PDF 时显示欢迎页）
   - 加载状态动画

2. **交互优化**
   - 完整的键盘快捷键支持：
     - ⌘O：打开文件
     - ⌘T：翻译选中文本
     - ⌘Return：发送消息
     - ⌘L：聚焦聊天输入框
     - ⌘1/2/3：切换侧边栏 tab
     - Esc：停止生成
   - 多窗口支持（不同论文在不同窗口）
   - 窗口状态恢复（关闭后重新打开恢复上次的 PDF）

3. **性能优化**
   - 大 PDF 的懒加载
   - 聊天消息列表的虚拟滚动
   - 文本提取的后台线程处理
   - 合理的内存管理

4. **错误处理与用户反馈**
   - 网络错误的友好提示
   - API Key 无效的明确提示
   - Ollama 未运行的检测和引导
   - 操作成功/失败的 toast 提示

5. **onboarding 引导**
   - 首次启动的设置引导
   - 功能介绍卡片

#### 验收标准
- [ ] 深色模式无视觉问题
- [ ] 所有快捷键正常工作
- [ ] 空状态和错误状态有良好的 UI
- [ ] 无明显卡顿
- [ ] 首次使用体验流畅

---

## 三、技术要点与注意事项

### 3.1 PDFKit 关键 API

```swift
import PDFKit

// 打开 PDF
let document = PDFDocument(url: fileURL)

// 获取页数
document.pageCount

// 获取某页文本
document.page(at: 0)?.string

// 获取目录
document.outlineRoot

// PDF 元数据（标题、作者等）
document.documentAttributes?[PDFDocumentAttribute.titleAttribute]

// 搜索
document.findString("keyword", withOptions: .caseInsensitive)

// 当前选中文本
pdfView.currentSelection?.string
```

### 3.2 流式 HTTP 请求（SSE）

Swift 原生的 `URLSession.bytes(for:)` 可以处理流式响应，不需要第三方库。关键是逐行解析 SSE 格式：

```
data: {"choices":[{"delta":{"content":"Hello"}}]}
data: {"choices":[{"delta":{"content":" world"}}]}
data: [DONE]
```

### 3.3 Keychain 存储 API Key

不要用 `UserDefaults` 存 API Key！使用 Security framework：

```swift
import Security

func saveToKeychain(service: String, account: String, password: String) throws {
    let data = password.data(using: .utf8)!
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: account,
        kSecValueData as String: data
    ]
    SecItemDelete(query as CFDictionary)
    let status = SecItemAdd(query as CFDictionary, nil)
    guard status == errSecSuccess else { throw KeychainError.saveFailed }
}
```

### 3.4 Apple Translation Framework（macOS 15+）

```swift
import Translation

// 在 SwiftUI 中使用
struct TranslationView: View {
    @State private var showTranslation = false

    var body: some View {
        Text(selectedText)
            .translationPresentation(isPresented: $showTranslation,
                                     text: selectedText)
    }
}
```

### 3.5 SwiftData 使用注意

```swift
// App 入口配置
@main
struct AIPaperReaderApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [PaperSession.self, ChatMessageRecord.self])

        Settings {
            SettingsView()
        }
    }
}
```

---

## 四、第三方依赖建议

**原则：尽量少用第三方库，优先用 Apple 原生框架。**

| 需求 | 推荐方案 | 备注 |
|------|---------|------|
| PDF 渲染 | PDFKit（系统自带） | 无需依赖 |
| HTTP 请求 | URLSession（系统自带） | 无需依赖 |
| JSON 解析 | Codable（系统自带） | 无需依赖 |
| 数据持久化 | SwiftData（系统自带） | 无需依赖 |
| 翻译 | Translation（系统自带） | macOS 15+ |
| Keychain | Security（系统自带） | 无需依赖 |
| Markdown 渲染 | [swift-markdown-ui](https://github.com/gonzalezreal/swift-markdown-ui) | 唯一建议的第三方库，SPM 安装 |
| 语法高亮 | [Splash](https://github.com/JohnSundell/Splash) | 可选，用于代码块高亮 |

通过 Swift Package Manager 添加依赖，在 Xcode 中：File > Add Package Dependencies。

---

## 五、给 Claude Code 的执行指令

以下是你在本地使用 Claude Code 时，可以逐步发出的指令：

### 启动项目

```
请在当前目录创建一个 macOS SwiftUI 项目 "AIPaperReader"，使用 Swift、SwiftUI，
最低部署目标 macOS 15.0，Bundle ID: com.bioinfoark.aipaperreader。
按照以下项目结构创建所有文件夹和占位文件：
[粘贴上面 1.4 的项目结构]
先创建项目骨架，每个文件写上基本的 import 和空的 struct/class 定义。
```

### 阶段 1 指令

```
现在实现阶段 1：PDF 阅读器。
1. 实现 PDFReaderView（NSViewRepresentable 包装 PDFView）
2. 实现 ContentView（NavigationSplitView，左侧侧边栏，右侧 PDF）
3. 实现 PDF 缩略图侧边栏
4. 实现 PDF 目录导航
5. 支持 File > Open 和拖拽打开 PDF
6. 添加快捷键 ⌘O 打开文件，⌘+/⌘- 缩放
参考技术要点中的 PDFKit API。确保 UI 符合 macOS 原生设计风格。
```

### 阶段 2 指令

```
现在实现阶段 2：PDF 文本提取服务。
创建 PDFTextExtractor 类，实现：
1. 全文提取（逐页，带页码标记）
2. 按页面范围提取（支持 "1-5,8,10-15" 格式）
3. 选中文本提取（监听 PDFView 选中变化）
4. Token 数估算
5. 文本清洗（合并断行、去除多余空白）
```

### 阶段 3 指令

```
现在实现阶段 3：LLM 服务层。
1. 定义 LLMServiceProtocol 协议（流式输出）
2. 实现 OpenAIService（支持自定义 base URL，SSE 流式解析）
3. 实现 OllamaService（localhost:11434，获取模型列表）
4. 实现 LLMServiceFactory
5. 所有服务要有完善的错误处理
参考计划中的代码指引，使用原生 URLSession.bytes 处理流式响应。
```

### 阶段 4 指令

```
现在实现阶段 4：AI 问答聊天界面。
1. 实现 ChatPanelView（消息列表 + 输入框）
2. 实现 ChatBubbleView（区分用户/AI，AI 回复支持 Markdown）
3. 实现 ChatViewModel（管理消息、调用 LLM、流式输出）
4. 在主窗口右侧添加聊天面板
5. 实现页面范围选择 UI
6. 添加预设问题按钮
7. 实现停止生成功能
使用 swift-markdown-ui (SPM: https://github.com/gonzalezreal/swift-markdown-ui) 渲染 Markdown。
```

### 阶段 5-8 依次类推，每个阶段完成后先测试验收再进入下一阶段。

---

## 六、注意事项

1. **每完成一个阶段就测试**，不要跳阶段。确保当前功能正常再继续。
2. **先跑通最小可用版本**，再优化。阶段 1-4 完成后就是一个可用的 MVP。
3. **Xcode 项目不能纯靠 CLI 创建**。Claude Code 可以生成所有 Swift 源文件，但 .xcodeproj 最好在 Xcode 中创建然后把文件拖进去。或者使用 Swift Package 方式（Package.swift）管理项目。
4. **签名问题**：本地开发测试不需要付费开发者账号。Xcode 会自动使用个人团队签名。
5. **SPM 依赖**：通过 Xcode 的 File > Add Package Dependencies 添加，或在 Package.swift 中声明。
6. **测试 LLM 时**，建议先用 Ollama 本地模型测试（免费），确认流程通后再接线上 API。

---

## 七、未来扩展方向（V2+）

- [ ] 论文批注和标记（PDFKit 原生支持 Annotation）
- [ ] 多论文对比问答（同时导入多篇论文）
- [ ] RAG 增强（向量化存储论文，更精准的上下文召回）
- [ ] 论文引用格式提取和管理
- [ ] 与 Zotero 集成
- [ ] 全文档翻译（参考 pdf2zh 的思路）
- [ ] 论文笔记导出（Markdown / Notion）
- [ ] Core ML 本地推理（小模型直接在设备上运行）
