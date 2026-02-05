//
//  ModelSettingsView.swift (Updated)
//  AIPaperReader
//
//  Created by Claude on 2/4/26.
//

import SwiftUI

struct ModelSettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var showingAPIKeyInfo: Bool = false
    @State private var showingEmbeddingInfo: Bool = false

    var body: some View {
        Form {
            // LLM Settings
            Section {
                Picker("llm_provider", selection: $settings.llmProvider) {
                    ForEach(LLMProvider.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: settings.llmProvider) { _, newValue in
                     settings.llmBaseURL = newValue.defaultBaseURL
                }

                VStack(alignment: .leading, spacing: 4) {
                    TextField("llm_base_url", text: $settings.llmBaseURL)
                        .textFieldStyle(.roundedBorder)
                    
                    // Smart URL Preview
                    if !settings.llmBaseURL.isEmpty {
                        Text("Preview: \(computedFullURL)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                }

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
                        Text("llm_api_key_desc")
                            .padding()
                            .frame(width: 250)
                    }
                }

                TextField("llm_model_name", text: $settings.llmModelName)
                    .textFieldStyle(.roundedBorder)
                
            } header: {
                Text("llm_settings_title")
            } footer: {
               dynamicFooter
            }

            // Embedding Settings
            Section {
                TextField("embedding_base_url", text: $settings.embeddingBaseURL)
                    .textFieldStyle(.roundedBorder)
                
                HStack {
                    if !settings.embeddingApiKey.isEmpty {
                        SecureField("embedding_api_key", text: Binding(
                            get: { settings.embeddingApiKey },
                            set: { settings.embeddingApiKey = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField("embedding_api_key_placeholder", text: Binding(
                            get: { "" },
                            set: { settings.embeddingApiKey = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                    }
                    
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
                    
            } header: {
                Text("embedding_settings_title")
            } footer: {
                Text("embedding_settings_desc")
            }
            
            // Parameters
            Section {
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
            } header: {
                Text("llm_parameters_title")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var computedFullURL: String {
        var url = settings.llmBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if url.isEmpty { return "" }
        if !url.hasSuffix("/") { url += "/" }
        
        if !url.contains("/v1/") && !url.hasSuffix("/v1/") {
            url += "v1/"
        }
        return url + "chat/completions"
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

            if let url = URL(string: settings.llmProvider.helpURL), !settings.llmProvider.helpURL.isEmpty {
                Link("获取 \(settings.llmProvider.displayName) API Key", destination: url)
                    .font(.caption)
            }
        }
    }
}
