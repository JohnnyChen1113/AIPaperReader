//
//  ModelManagerView.swift
//  AIPaperReader
//
//  Created by JohnnyChan on 2/4/26.
//

import SwiftUI

struct ModelManagerView: View {
    @Environment(\.dismiss) var dismiss
    
    let provider: LLMProvider
    let apiKey: String
    let baseURL: String
    @Binding var enabledModels: [String]
    @Binding var selectedModel: String
    
    @State private var availableModels: [String] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var searchText: String = ""
    
    var filteredModels: [String] {
        if searchText.isEmpty {
            return availableModels
        } else {
            return availableModels.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Manage Models")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    dismiss()
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Search & Content
            VStack {
                if isLoading {
                    ProgressView("Fetching models...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text("Failed to fetch models")
                            .font(.headline)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Retry") {
                            fetchModels()
                        }
                        .padding(.top)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search models...", text: $searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    .padding()
                    
                    // List
                    List {
                        ForEach(filteredModels, id: \.self) { model in
                            HStack(spacing: 8) {
                                Toggle("", isOn: Binding(
                                    get: { enabledModels.contains(model) },
                                    set: { isEnabled in
                                        if isEnabled {
                                            if !enabledModels.contains(model) {
                                                enabledModels.append(model)
                                            }
                                        } else {
                                            enabledModels.removeAll { $0 == model }
                                            if selectedModel == model, let first = enabledModels.first {
                                                selectedModel = first
                                            }
                                        }
                                    }
                                ))
                                .toggleStyle(.checkbox)

                                ModelCardView(
                                    modelId: model,
                                    provider: provider,
                                    isSelected: selectedModel == model,
                                    isCompact: true
                                ) {
                                    if enabledModels.contains(model) {
                                        selectedModel = model
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 500, height: 600)
        .onAppear {
            fetchModels()
        }
    }
    
    private func fetchModels() {
        guard !apiKey.isEmpty else {
            // Fallback to default free models if no API key (or provider defaults)
            availableModels = provider.defaultFreeModels
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let config = LLMConfig(
                    provider: provider,
                    baseURL: baseURL,
                    apiKey: apiKey,
                    modelName: "" // Not needed for fetching models
                )
                let service = LLMServiceFactory.create(config: config)
                let models = try await service.fetchAvailableModels()
                
                await MainActor.run {
                    self.availableModels = models.sorted()
                    self.isLoading = false
                    
                    // Ensure at least defaults are in if fetch returns empty? 
                    // Or trust the API.
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    // Fallback
                    if self.availableModels.isEmpty {
                        self.availableModels = self.provider.defaultFreeModels
                    }
                }
            }
        }
    }
}
