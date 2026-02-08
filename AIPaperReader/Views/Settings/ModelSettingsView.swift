//
//  ModelSettingsView.swift
//  AIPaperReader
//
//  Created by Claude on 2/4/26.
//

import SwiftUI

struct ModelSettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var showingAPIKeyInfo: Bool = false
    @State private var showingEmbeddingInfo: Bool = false

    // 连接测试状态
    @State private var llmConnectionStatus: ConnectionStatus = .idle
    @State private var embeddingConnectionStatus: ConnectionStatus = .idle
    @State private var llmConnectionMessage: String = ""
    @State private var embeddingConnectionMessage: String = ""

    enum ConnectionStatus {
        case idle, testing, success, failed
    }

    var body: some View {
        Form {
            // LLM Settings - 供应商选择
            Section {
                providerSelectionView
            } header: {
                Text("llm_settings_title")
            } footer: {
                dynamicFooter
            }

            // LLM - API Key 和 Connect
            Section {
                apiKeyAndConnectView
            } header: {
                Text("API Key")
            }

            // LLM - 模型选择
            Section {
                modelSelectionView
            } header: {
                Text("模型设置")
            }

            // Embedding Settings
            Section {
                embeddingSettingsView
            } header: {
                Text("embedding_settings_title")
            } footer: {
                Text("embedding_settings_desc")
            }

            // Parameters
            Section {
                parametersView
            } header: {
                Text("llm_parameters_title")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Provider Selection

    @ViewBuilder
    private var providerSelectionView: some View {
        Picker("llm_provider", selection: $settings.llmProvider) {
            ForEach(LLMProvider.allCases) { provider in
                Text(provider.displayName).tag(provider)
            }
        }
        .pickerStyle(.menu)
        .onChange(of: settings.llmProvider) { _, newValue in
            settings.llmBaseURL = newValue.defaultBaseURL
            // 切换供应商时重置连接状态和 embedding 模型选择
            llmConnectionStatus = .idle
            llmConnectionMessage = ""
            settings.embeddingSelectedModel = ""
        }

        VStack(alignment: .leading, spacing: 4) {
            TextField("llm_base_url", text: $settings.llmBaseURL)
                .textFieldStyle(.roundedBorder)

            if !settings.llmBaseURL.isEmpty {
                Text("Endpoint: \(computedFullURL)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    // MARK: - API Key and Connect

    @ViewBuilder
    private var apiKeyAndConnectView: some View {
        HStack {
            SecureField("llm_api_key", text: Binding(
                get: { settings.llmApiKey },
                set: { settings.llmApiKey = $0 }
            ))
            .textFieldStyle(.roundedBorder)

            Button(action: { showingAPIKeyInfo.toggle() }) {
                Image(systemName: "info.circle")
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingAPIKeyInfo) {
                apiKeyInfoPopover
            }
        }

        // Connect 测试按钮
        HStack {
            Button(action: testLLMConnection) {
                HStack(spacing: 6) {
                    if llmConnectionStatus == .testing {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: connectionIcon(for: llmConnectionStatus))
                    }
                    Text(connectionButtonText(for: llmConnectionStatus))
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(llmConnectionStatus == .testing || (settings.llmProvider.requiresAPIKey && settings.llmApiKey.isEmpty))

            if !llmConnectionMessage.isEmpty {
                Text(llmConnectionMessage)
                    .font(.caption)
                    .foregroundColor(llmConnectionStatus == .success ? .green : .red)
            }

            Spacer()
        }
    }

    // MARK: - Model Selection

    @ViewBuilder
    private var modelSelectionView: some View {
        // 当前选中的模型
        Picker("当前模型", selection: $settings.llmModelName) {
            ForEach(settings.enabledModels, id: \.self) { model in
                Text(formatModelName(model)).tag(model)
            }
        }
        .pickerStyle(.menu)

        // 显示可用模型列表
        DisclosureGroup("可用模型") {
            ForEach(settings.llmProvider.defaultFreeModels, id: \.self) { model in
                ModelCardView(
                    modelId: model,
                    provider: settings.llmProvider,
                    isSelected: settings.enabledModels.contains(model),
                    isCompact: true
                ) {
                    toggleModel(model)
                }
            }
        }

        // 自定义模型输入
        HStack {
            TextField("自定义模型名称", text: $settings.llmModelName)
                .textFieldStyle(.roundedBorder)
        }
    }

    // MARK: - Embedding Settings

    @ViewBuilder
    private var embeddingSettingsView: some View {
        if settings.llmProvider.supportsEmbedding {
            // 当前 Provider 支持 Embedding
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
                Text("\(settings.llmProvider.displayName) 支持 Embedding")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Toggle("使用与大模型相同的 API Key", isOn: $settings.embeddingUseSharedKey)

            if settings.embeddingUseSharedKey {
                // 自动配置模式 — 显示只读信息 + 模型选择
                VStack(alignment: .leading, spacing: 6) {
                    LabeledContent("URL") {
                        Text(settings.llmProvider.defaultEmbeddingBaseURL)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    LabeledContent("模型") {
                        Picker("", selection: Binding(
                            get: {
                                settings.embeddingSelectedModel.isEmpty
                                    ? settings.llmProvider.defaultEmbeddingModel
                                    : settings.embeddingSelectedModel
                            },
                            set: { settings.embeddingSelectedModel = $0 }
                        )) {
                            ForEach(settings.llmProvider.availableEmbeddingModels, id: \.self) { model in
                                Text(model).tag(model)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: 250)
                    }
                    LabeledContent("API Key") {
                        Text("与大模型共用")
                            .foregroundColor(.secondary)
                    }
                }
                .font(.caption)
                .padding(8)
                .background(Color.green.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                // 手动配置模式
                manualEmbeddingFields
            }
        } else {
            // Provider 不支持 Embedding
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.circle")
                    .foregroundColor(.orange)
                    .font(.caption)
                Text("\(settings.llmProvider.displayName) 不支持 Embedding，请手动配置")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            manualEmbeddingFields
        }

        // Embedding 连接测试
        embeddingConnectionTestView
    }

    @ViewBuilder
    private var manualEmbeddingFields: some View {
        TextField("embedding_base_url", text: $settings.embeddingBaseURL)
            .textFieldStyle(.roundedBorder)

        HStack {
            SecureField("embedding_api_key", text: Binding(
                get: { settings.embeddingApiKey },
                set: { settings.embeddingApiKey = $0 }
            ))
            .textFieldStyle(.roundedBorder)

            Button(action: { showingEmbeddingInfo.toggle() }) {
                Image(systemName: "info.circle")
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingEmbeddingInfo) {
                Text("embedding_api_key_desc")
                    .padding()
                    .frame(width: 250)
            }
        }

        TextField("embedding_model_name", text: $settings.embeddingModelName)
            .textFieldStyle(.roundedBorder)
    }

    @ViewBuilder
    private var embeddingConnectionTestView: some View {
        HStack {
            Button(action: testEmbeddingConnection) {
                HStack(spacing: 6) {
                    if embeddingConnectionStatus == .testing {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: connectionIcon(for: embeddingConnectionStatus))
                    }
                    Text(connectionButtonText(for: embeddingConnectionStatus))
                }
            }
            .buttonStyle(.bordered)
            .disabled(embeddingConnectionStatus == .testing || settings.effectiveEmbeddingConfig.apiKey.isEmpty)

            if !embeddingConnectionMessage.isEmpty {
                Text(embeddingConnectionMessage)
                    .font(.caption)
                    .foregroundColor(embeddingConnectionStatus == .success ? .green : .red)
            }

            Spacer()
        }
    }

    // MARK: - Parameters

    @ViewBuilder
    private var parametersView: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("llm_temperature")
                Spacer()
                Text(String(format: "%.1f", settings.llmTemperature))
                    .foregroundColor(.secondary)
            }
            Slider(value: $settings.llmTemperature, in: 0...1, step: 0.1)
        }

        VStack(alignment: .leading) {
            HStack {
                Text("llm_context_budget")
                Spacer()
                Text("\(settings.llmContextTokenBudget)")
                    .foregroundColor(.secondary)
            }
            Slider(value: Binding(
                get: { Double(settings.llmContextTokenBudget) },
                set: { settings.llmContextTokenBudget = Int($0) }
            ), in: 1000...32000, step: 1000)
        }
    }

    // MARK: - Helper Views

    @ViewBuilder
    private var apiKeyInfoPopover: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("llm_api_key_desc")
            if let url = URL(string: settings.llmProvider.helpURL), !settings.llmProvider.helpURL.isEmpty {
                Link("获取 \(settings.llmProvider.displayName) API Key", destination: url)
                    .font(.caption)
            }
        }
        .padding()
        .frame(width: 280)
    }

    @ViewBuilder
    private var dynamicFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            if settings.llmProvider == .bioInfoArk {
                VStack(alignment: .leading, spacing: 4) {
                    Text("BioInfoArk 是中国国内领先的高性能 AI 服务平台。")
                    Text("稳定、高速、支持全球顶尖大模型。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Link("访问官网: www.bioinfoark.com", destination: URL(string: "https://www.bioinfoark.com")!)
                        .font(.caption)
                        .foregroundColor(.accentColor)
                }
                .padding(8)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(8)
            } else {
                Text("llm_settings_desc")
            }
        }
    }

    // MARK: - Helper Functions

    private var computedFullURL: String {
        var url = settings.llmBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if url.isEmpty { return "" }
        if !url.hasSuffix("/") { url += "/" }

        if !url.contains("/v1/") && !url.hasSuffix("/v1/") {
            url += "v1/"
        }
        return url + "chat/completions"
    }

    private func formatModelName(_ name: String) -> String {
        let parts = name.components(separatedBy: "/")
        return parts.last ?? name
    }

    private func toggleModel(_ model: String) {
        var models = settings.enabledModels
        if models.contains(model) {
            models.removeAll { $0 == model }
        } else {
            models.append(model)
        }
        settings.enabledModels = models
    }

    private func connectionIcon(for status: ConnectionStatus) -> String {
        switch status {
        case .idle: return "bolt.fill"
        case .testing: return "bolt.fill"
        case .success: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }

    private func connectionButtonText(for status: ConnectionStatus) -> String {
        switch status {
        case .idle: return "Connect"
        case .testing: return "Testing..."
        case .success: return "Connected"
        case .failed: return "Retry"
        }
    }

    // MARK: - Connection Tests

    private func testLLMConnection() {
        llmConnectionStatus = .testing
        llmConnectionMessage = ""

        Task {
            do {
                let service = LLMServiceFactory.create(config: settings.llmConfig)
                let success = try await service.testConnection()

                await MainActor.run {
                    if success {
                        llmConnectionStatus = .success
                        llmConnectionMessage = "连接成功!"
                    } else {
                        llmConnectionStatus = .failed
                        llmConnectionMessage = "连接失败"
                    }
                }
            } catch {
                await MainActor.run {
                    llmConnectionStatus = .failed
                    llmConnectionMessage = error.localizedDescription
                }
            }
        }
    }

    private func testEmbeddingConnection() {
        embeddingConnectionStatus = .testing
        embeddingConnectionMessage = ""

        Task {
            do {
                let config = settings.effectiveEmbeddingConfig
                let service = EmbeddingService(config: config)

                let _ = try await service.embed(text: "test")

                await MainActor.run {
                    embeddingConnectionStatus = .success
                    embeddingConnectionMessage = "连接成功!"
                }
            } catch {
                await MainActor.run {
                    embeddingConnectionStatus = .failed
                    embeddingConnectionMessage = error.localizedDescription
                }
            }
        }
    }
}
