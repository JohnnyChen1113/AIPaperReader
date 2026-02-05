# AIPaperReader

<img src="logo.png" alt="AIPaperReader Logo" width="128" height="128">

macOS 原生学术论文阅读器，核心功能：AI 驱动的论文问答 + PDF 阅读 + 轻量翻译

## 功能特性

- **PDF 阅读**: 原生 PDFKit 渲染，支持缩放、搜索、目录导航
- **AI 论文问答**: 与论文内容进行智能对话
- **多 LLM 后端**: 支持 OpenAI 兼容 API / Ollama 本地模型
- **选中文本翻译**: 一键翻译选中内容
- **对话历史管理**: 保存和回顾与每篇论文的问答记录
- **多语言支持**: 中文、英文、西班牙文

## 技术栈

- Swift + SwiftUI
- PDFKit (PDF 渲染)
- Core ML (未来支持)
- SwiftData (数据持久化)
- macOS 15+

## 系统要求

- macOS 15.0 或更高版本
- Apple Silicon (M 系列芯片) 或 Intel

## 开发文档

详细的开发计划和实现指南请查看 [AIPaperReader-Development-Plan.md](./AIPaperReader-Development-Plan.md)

## 许可证

MIT License
