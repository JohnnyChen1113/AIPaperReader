//
//  PromptSettingsView.swift
//  AIPaperReader
//
//  Created by Claude on 2/4/26.
//

import SwiftUI

struct PromptSettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var selectedPrompt: PromptType = .system

    enum PromptType: String, CaseIterable, Identifiable {
        case system = "System Prompt"
        case translate = "Translate"
        case explain = "Explain"
        case summarize = "Summarize"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .system: return "gearshape.2"
            case .translate: return "character.book.closed"
            case .explain: return "questionmark.circle"
            case .summarize: return "doc.text"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(PromptType.allCases, selection: $selectedPrompt) { type in
                NavigationLink(value: type) {
                    Label(type.rawValue, systemImage: type.icon)
                }
            }
            .navigationTitle("Prompts")
        } detail: {
            PromptEditor(promptType: selectedPrompt, settings: settings)
        }
    }
}

struct PromptEditor: View {
    let promptType: PromptSettingsView.PromptType
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(promptType.rawValue)
                    .font(.headline)

                Spacer()

                Button("Reset to Default") {
                    resetToDefault()
                }
            }

            Text(descriptionForPrompt(type: promptType))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            TextEditor(text: bindingForPrompt(type: promptType))
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )

            // Placeholder hint
            VStack(alignment: .leading, spacing: 8) {
                Text("Available Placeholders:")
                    .font(.caption)
                    .fontWeight(.semibold)

                HStack {
                    Text(placeholderForPrompt(type: promptType))
                        .font(.system(.caption, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                    Text(placeholderDescriptionForPrompt(type: promptType))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.secondary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding()
    }
    
    private func bindingForPrompt(type: PromptSettingsView.PromptType) -> Binding<String> {
        switch type {
        case .system: return $settings.systemPrompt
        case .translate: return $settings.promptTranslate
        case .explain: return $settings.promptExplain
        case .summarize: return $settings.promptSummarize
        }
    }
    
    private func resetToDefault() {
        switch promptType {
        case .system: settings.systemPrompt = AppSettings.defaultSystemPrompt
        case .translate: settings.promptTranslate = AppSettings.defaultPromptTranslate
        case .explain: settings.promptExplain = AppSettings.defaultPromptExplain
        case .summarize: settings.promptSummarize = AppSettings.defaultPromptSummarize
        }
    }
    
    private func descriptionForPrompt(type: PromptSettingsView.PromptType) -> String {
        switch type {
        case .system: return "The system prompt is sent to the AI before each conversation."
        case .translate: return "Prompt used when 'Translate' is selected from the context menu."
        case .explain: return "Prompt used when 'Explain' is selected from the context menu."
        case .summarize: return "Prompt used when 'Summarize' is selected from the context menu."
        }
    }
    
    private func placeholderForPrompt(type: PromptSettingsView.PromptType) -> String {
        switch type {
        case .system: return "{pdf_content}"
        default: return "{selection}"
        }
    }
    
    private func placeholderDescriptionForPrompt(type: PromptSettingsView.PromptType) -> String {
        switch type {
        case .system: return "Replaced with extracted PDF content"
        default: return "Replaced with the selected text"
        }
    }
}

#Preview {
    PromptSettingsView()
        .frame(width: 500, height: 400)
}
