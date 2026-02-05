//
//  AppSettings.swift
//  AIPaperReader
//
//  Created by Claude on 2/4/26.
//

import Foundation
import SwiftUI

/// Application settings model
class AppSettings: ObservableObject {
    static let shared = AppSettings()

    // MARK: - LLM Configuration

    @AppStorage("llm.provider") var llmProviderRaw: String = LLMProvider.siliconflow.rawValue
    @AppStorage("llm.baseURL") var llmBaseURL: String = LLMProvider.siliconflow.defaultBaseURL
    @AppStorage("llm.modelName") var llmModelName: String = "Qwen/Qwen2.5-7B-Instruct"
    @AppStorage("llm.temperature") var llmTemperature: Double = 0.7
    @AppStorage("llm.maxTokens") var llmMaxTokens: Int = 4096
    @AppStorage("llm.contextTokenBudget") var llmContextTokenBudget: Int = 16000
    @AppStorage("llm.enabledModels") var enabledModelsData: Data = Data()

    var llmProvider: LLMProvider {
        get { LLMProvider(rawValue: llmProviderRaw) ?? .siliconflow }
        set { llmProviderRaw = newValue.rawValue }
    }

    var llmApiKey: String {
        get { SecureStorage.read(key: "llm.apiKey") ?? "" }
        set { SecureStorage.save(key: "llm.apiKey", value: newValue) }
    }

    var enabledModels: [String] {
        get {
            if let models = try? JSONDecoder().decode([String].self, from: enabledModelsData), !models.isEmpty {
                return models
            }
            return llmProvider.defaultFreeModels
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                enabledModelsData = data
            }
        }
    }

    // MARK: - Embedding Configuration

    @AppStorage("embedding.baseURL") var embeddingBaseURL: String = "https://api.siliconflow.cn/v1"
    @AppStorage("embedding.modelName") var embeddingModelName: String = "BAAI/bge-m3"

    var embeddingApiKey: String {
        get { SecureStorage.read(key: "embedding.apiKey") ?? "" }
        set { SecureStorage.save(key: "embedding.apiKey", value: newValue) }
    }

    // MARK: - System Prompt

    @AppStorage("chat.systemPrompt") var systemPrompt: String = AppSettings.defaultSystemPrompt
    @AppStorage("chat.prompt.translate") var promptTranslate: String = AppSettings.defaultPromptTranslate
    @AppStorage("chat.prompt.explain") var promptExplain: String = AppSettings.defaultPromptExplain
    @AppStorage("chat.prompt.summarize") var promptSummarize: String = AppSettings.defaultPromptSummarize

    static let defaultSystemPrompt = """
    You are a professional academic paper analysis assistant. The user is reading an academic paper and may ask questions about its content.

    Paper content:
    {pdf_content}

    Requirements:
    1. Answer questions based only on the paper content, do not make up information
    2. Cite page numbers when referencing specific content
    3. Clearly state if a question is beyond the scope of the paper
    4. Respond in the same language as the user's question
    """

    static let defaultPromptTranslate = """
    请将以下内容翻译成中文，保持原文的格式和专业术语的准确性：

    {selection}
    """

    static let defaultPromptExplain = """
    请详细解释以下内容，包括其中的专业术语、概念和含义：

    {selection}
    """

    static let defaultPromptSummarize = """
    请总结以下内容的主旨要点，用简洁的语言概括：

    {selection}
    """

    // MARK: - General Settings

    @AppStorage("general.defaultPageRange") var defaultPageRange: String = "all"
    @AppStorage("general.appearance") var appearanceRaw: String = "system"

    var appearance: Appearance {
        get { Appearance(rawValue: appearanceRaw) ?? .system }
        set { appearanceRaw = newValue.rawValue }
    }

    enum Appearance: String, CaseIterable {
        case system = "System"
        case light = "Light"
        case dark = "Dark"

        var displayName: String {
            switch self {
            case .system: return "跟随系统"
            case .light: return "浅色"
            case .dark: return "深色"
            }
        }
    }

    // MARK: - App Language

    @AppStorage("general.language") var languageRaw: String = "system"

    var language: AppLanguage {
        get { AppLanguage(rawValue: languageRaw) ?? .system }
        set { languageRaw = newValue.rawValue }
    }
    
    var locale: Locale? {
        switch language {
        case .system: return nil
        case .english: return Locale(identifier: "en")
        case .chinese: return Locale(identifier: "zh-Hans")
        case .spanish: return Locale(identifier: "es")
        }
    }

    enum AppLanguage: String, CaseIterable {
        case system = "system"
        case english = "en"
        case chinese = "zh-Hans"
        case spanish = "es"

        var displayName: String {
            switch self {
            case .system: return NSLocalizedString("lang_system", comment: "System Default")
            case .english: return "English"
            case .chinese: return "简体中文"
            case .spanish: return "Español"
            }
        }
    }

    var colorScheme: ColorScheme? {
        switch appearance {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    // MARK: - Custom Quick Actions (用户自定义快捷操作)

    @AppStorage("chat.customQuickActions") var customQuickActionsData: Data = Data()

    var customQuickActions: [PresetQuestion] {
        get {
            if let actions = try? JSONDecoder().decode([PresetQuestion].self, from: customQuickActionsData) {
                return actions
            }
            return []
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                customQuickActionsData = data
            }
        }
    }

    func addCustomQuickAction(_ question: String) {
        var actions = customQuickActions
        actions.append(PresetQuestion.custom(chinese: question))
        customQuickActions = actions
    }

    func removeCustomQuickAction(at index: Int) {
        var actions = customQuickActions
        guard index >= 0 && index < actions.count else { return }
        actions.remove(at: index)
        customQuickActions = actions
    }

    // MARK: - LLM Config Helper

    var llmConfig: LLMConfig {
        LLMConfig(
            provider: llmProvider,
            baseURL: llmBaseURL,
            apiKey: SecureStorage.read(key: "llm.apiKey") ?? "",
            modelName: llmModelName,
            temperature: llmTemperature,
            maxTokens: llmMaxTokens,
            contextTokenBudget: llmContextTokenBudget,
            enabledModels: enabledModels
        )
    }

    func updateLLMConfig(_ config: LLMConfig) {
        llmProvider = config.provider
        llmBaseURL = config.baseURL
        llmModelName = config.modelName
        llmTemperature = config.temperature
        llmMaxTokens = config.maxTokens
        llmContextTokenBudget = config.contextTokenBudget
        enabledModels = config.enabledModels

        if !config.apiKey.isEmpty {
            SecureStorage.save(key: "llm.apiKey", value: config.apiKey)
        }
    }

    private init() {}
}

// MARK: - Secure Storage Helper (Obfuscated UserDefaults)

class SecureStorage {
    private static let storageKey = "com.bioinfoark.aipaperreader.secure"
    private static let obfuscationKey: UInt8 = 0x42 // Simple obfuscation key

    static func save(key: String, value: String) {
        guard !value.isEmpty else {
            delete(key: key)
            return
        }
        
        let data = value.data(using: .utf8)!
        let obfuscatedData = obfuscate(data: data)
        UserDefaults.standard.set(obfuscatedData, forKey: storageKey + "." + key)
    }

    static func read(key: String) -> String? {
        guard let data = UserDefaults.standard.data(forKey: storageKey + "." + key) else {
            return nil
        }
        
        let deobfuscatedData = obfuscate(data: data) // XOR is symmetric
        return String(data: deobfuscatedData, encoding: .utf8)
    }

    static func delete(key: String) {
        UserDefaults.standard.removeObject(forKey: storageKey + "." + key)
    }
    
    // Simple XOR obfuscation to prevent plain text storage
    private static func obfuscate(data: Data) -> Data {
        var output = Data(count: data.count)
        for (index, byte) in data.enumerated() {
            output[index] = byte ^ obfuscationKey
        }
        return output
    }
}
