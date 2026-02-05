//
//  SetupGuideView.swift
//  AIPaperReader
//
//  Created by Claude on 2/4/26.
//

import SwiftUI

/// 设置向导视图 - 引导用户完成大模型配置
struct SetupGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = AppSettings.shared

    @State private var currentStep: Int = 1
    @State private var apiKey: String = ""
    @State private var isTestingConnection: Bool = false
    @State private var connectionSuccess: Bool? = nil
    @State private var errorMessage: String?
    @State private var showModelManager: Bool = false

    private let totalSteps = 3

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("配置大模型")
                    .font(.headline)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // 步骤指示器
            StepIndicator(currentStep: currentStep, totalSteps: totalSteps)
                .padding(.vertical)

            // 内容区域
            ScrollView {
                VStack(spacing: 24) {
                    switch currentStep {
                    case 1:
                        Step1ProviderView(selectedProvider: $settings.llmProvider)
                    case 2:
                        Step2APIKeyView(
                            provider: settings.llmProvider,
                            apiKey: $apiKey,
                            isTestingConnection: $isTestingConnection,
                            connectionSuccess: $connectionSuccess,
                            errorMessage: $errorMessage,
                            onTest: testConnection
                        )
                    case 3:
                        Step3ModelView(
                            settings: settings,
                            showModelManager: $showModelManager
                        )
                    default:
                        EmptyView()
                    }
                }
                .padding(24)
            }

            Divider()

            // 底部按钮
            HStack {
                if currentStep > 1 {
                    Button("上一步") {
                        withAnimation {
                            currentStep -= 1
                        }
                    }
                }

                Spacer()

                if currentStep < totalSteps {
                    Button("下一步") {
                        withAnimation {
                            if currentStep == 2 && !apiKey.isEmpty {
                                // Save API Key
                                settings.llmApiKey = apiKey
                            }
                            currentStep += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(currentStep == 2 && apiKey.isEmpty)
                } else {
                    Button("完成") {
                        // Save settings and dismiss
                        if !apiKey.isEmpty {
                            settings.llmApiKey = apiKey
                        }
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .frame(width: 500, height: 550)
        .onAppear {
            apiKey = settings.llmApiKey
        }
        .sheet(isPresented: $showModelManager) {
            ModelManagerView(
                provider: settings.llmProvider,
                apiKey: apiKey,
                baseURL: settings.llmBaseURL,
                enabledModels: $settings.enabledModels,
                selectedModel: $settings.llmModelName
            )
        }
    }

    private func testConnection() {
        isTestingConnection = true
        connectionSuccess = nil
        errorMessage = nil

        Task {
            do {
                let config = LLMConfig(
                    provider: settings.llmProvider,
                    baseURL: settings.llmBaseURL,
                    apiKey: apiKey,
                    modelName: settings.llmModelName
                )
                let service = LLMServiceFactory.create(config: config)
                let success = try await service.testConnection()

                await MainActor.run {
                    connectionSuccess = success
                    isTestingConnection = false
                    if success {
                        // Auto proceed
                        settings.llmApiKey = apiKey
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            withAnimation {
                                currentStep = 3
                            }
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    connectionSuccess = false
                    errorMessage = error.localizedDescription
                    isTestingConnection = false
                }
            }
        }
    }
}

// MARK: - 步骤指示器

struct StepIndicator: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(1...totalSteps, id: \.self) { step in
                HStack(spacing: 0) {
                    // 圆圈
                    ZStack {
                        Circle()
                            .fill(step <= currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: 32, height: 32)

                        if step < currentStep {
                            Image(systemName: "checkmark")
                                .foregroundColor(.white)
                                .font(.caption.bold())
                        } else {
                            Text("\(step)")
                                .foregroundColor(step <= currentStep ? .white : .secondary)
                                .font(.caption.bold())
                        }
                    }

                    // 连接线
                    if step < totalSteps {
                        Rectangle()
                            .fill(step < currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: 60, height: 2)
                    }
                }
            }
        }
    }
}

// MARK: - 步骤 1：选择服务商

struct Step1ProviderView: View {
    @Binding var selectedProvider: LLMProvider

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("第一步：选择大模型服务商")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("选择你要使用的 AI 大模型服务商。推荐使用硅基流动（SiliconFlow），有免费额度可用。")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 12) {
                ForEach(LLMProvider.allCases, id: \.self) { provider in
                    ProviderCard(
                        provider: provider,
                        isSelected: selectedProvider == provider,
                        onSelect: { selectedProvider = provider }
                    )
                }
            }
        }
    }
}

struct ProviderCard: View {
    let provider: LLMProvider
    let isSelected: Bool
    let onSelect: () -> Void

    var providerDescription: String {
        switch provider {
        case .siliconflow:
            return "国内服务，有免费额度，支持多种开源模型"
        case .deepseek:
            return "DeepSeek 官方 API，性价比高"
        case .openaiCompatible:
            return "OpenAI 或其他兼容 API"
        case .ollama:
            return "本地运行，完全免费，需要自行部署"
        case .bioInfoArk:
            return "国内直连，支持 GPT-4/Claude-3.5 等顶尖模型"
        }
    }

    var providerIcon: String {
        switch provider {
        case .siliconflow: return "cpu"
        case .deepseek: return "brain.head.profile"
        case .openaiCompatible: return "globe"
        case .ollama: return "desktopcomputer"
        case .bioInfoArk: return "server.rack"
        }
    }

    var isRecommended: Bool {
        provider == .siliconflow
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                Image(systemName: providerIcon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(provider.displayName)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        if isRecommended {
                            Text("推荐")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.2))
                                .foregroundColor(.green)
                                .clipShape(Capsule())
                        }
                    }

                    Text(providerDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 步骤 2：填写 API Key

struct Step2APIKeyView: View {
    let provider: LLMProvider
    @Binding var apiKey: String
    @Binding var isTestingConnection: Bool
    @Binding var connectionSuccess: Bool?
    @Binding var errorMessage: String?
    let onTest: () -> Void

    var apiKeyHelpURL: String {
        provider.helpURL
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("第二步：填写 API Key")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("请输入你的 \(provider.displayName) API Key。如果没有，请先到官网注册获取。")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            if provider == .ollama {
                // Ollama 不需要 API Key
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.green)

                    Text("Ollama 本地部署无需 API Key")
                        .font(.headline)

                    Text("请确保 Ollama 已在本地启动并运行")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("API Key")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    SecureField("请输入 API Key", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))

                    if !apiKeyHelpURL.isEmpty {
                        Link(destination: URL(string: apiKeyHelpURL)!) {
                            HStack(spacing: 4) {
                                Image(systemName: "questionmark.circle")
                                Text("如何获取 API Key？")
                            }
                            .font(.caption)
                        }
                    }
                }

                // 测试连接按钮
                VStack(spacing: 12) {
                    Button(action: onTest) {
                        HStack {
                            if isTestingConnection {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "network")
                            }
                            Text(isTestingConnection ? "正在测试..." : "测试连接")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(apiKey.isEmpty || isTestingConnection)

                    // 连接结果
                    if let success = connectionSuccess {
                        HStack {
                            Image(systemName: success ? "checkmark.circle.fill" : "xmark.circle.fill")
                            Text(success ? "连接成功！" : "连接失败")
                        }
                        .foregroundColor(success ? .green : .red)
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 8)
            }

            // 安全提示
            HStack(spacing: 8) {
                Image(systemName: "lock.shield")
                    .foregroundColor(.green)
                Text("API Key 将安全存储在 macOS 钥匙串中")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - 步骤 3：选择模型

struct Step3ModelView: View {
    @ObservedObject var settings: AppSettings
    @Binding var showModelManager: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("第三步：选择模型")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("选择你要使用的 AI 模型。已为你预选了几个免费且效果不错的模型。")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // 当前选中的模型
            VStack(alignment: .leading, spacing: 12) {
                Text("当前使用的模型")
                    .font(.subheadline)
                    .fontWeight(.medium)

                if settings.enabledModels.isEmpty {
                    Text("未选择任何模型")
                        .foregroundColor(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Picker("", selection: $settings.llmModelName) {
                        ForEach(settings.enabledModels, id: \.self) { model in
                            Text(formatModelName(model))
                                .tag(model)
                        }
                    }
                    .labelsHidden()
                }
            }

            // 已启用的模型列表
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("已启用的模型 (\(settings.enabledModels.count))")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Spacer()

                    Button(action: { showModelManager = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.grid.2x2")
                            Text("管理模型")
                        }
                        .font(.caption)
                    }
                }

                VStack(spacing: 4) {
                    ForEach(settings.enabledModels, id: \.self) { model in
                        HStack {
                            Image(systemName: settings.llmModelName == model ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(settings.llmModelName == model ? .accentColor : .secondary)

                            Text(formatModelName(model))

                            Spacer()

                            if settings.llmModelName != model {
                                Button("使用") {
                                    settings.llmModelName = model
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(settings.llmModelName == model ? Color.accentColor.opacity(0.1) : Color.clear)
                        )
                    }
                }
            }

            // 完成提示
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.green)

                VStack(alignment: .leading, spacing: 4) {
                    Text("配置完成！")
                        .fontWeight(.semibold)
                    Text("点击「完成」开始使用 AI 论文阅读助手")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.green.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func formatModelName(_ model: String) -> String {
        let parts = model.components(separatedBy: "/")
        return parts.last ?? model
    }
}

#Preview {
    SetupGuideView()
}
