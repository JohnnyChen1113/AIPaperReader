//
//  PromptSettingsView.swift
//  AIPaperReader
//
//  Created by Claude on 2/4/26.
//

import SwiftUI

// MARK: - Built-in Actions Detail View (内置快捷操作)

struct BuiltInActionsDetailView: View {
    @ObservedObject var settings: AppSettings
    @State private var selectedAction: CustomQuickAction?

    var body: some View {
        HSplitView {
            // 左列：内置 action 列表
            List(selection: $selectedAction) {
                ForEach(CustomQuickAction.builtInActions) { action in
                    Label(action.name, systemImage: action.icon)
                        .tag(action)
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 160, idealWidth: 180, maxWidth: 220)

            // 右列：编辑器
            if let action = selectedAction {
                BuiltInActionEditor(action: action, settings: settings)
            } else {
                ContentUnavailableView(
                    "选择一个操作",
                    systemImage: "bolt.fill",
                    description: Text("从左侧选择一个内置快捷操作进行编辑")
                )
            }
        }
        .onAppear {
            if selectedAction == nil {
                selectedAction = CustomQuickAction.builtInActions.first
            }
        }
    }
}

// MARK: - Custom Actions Detail View (自定义快捷操作)

struct CustomActionsDetailView: View {
    @ObservedObject var settings: AppSettings
    @State private var selectedAction: CustomQuickAction?
    @State private var showAddActionSheet: Bool = false

    var body: some View {
        HSplitView {
            // 左列：自定义 action 列表 + 添加按钮
            VStack(spacing: 0) {
                List(selection: $selectedAction) {
                    ForEach(settings.customQuickActions) { action in
                        Label(action.name, systemImage: action.icon)
                            .tag(action)
                            .contextMenu {
                                Button(role: .destructive) {
                                    settings.removeCustomQuickAction(id: action.id)
                                    if selectedAction?.id == action.id {
                                        selectedAction = nil
                                    }
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let action = settings.customQuickActions[index]
                            settings.removeCustomQuickAction(id: action.id)
                        }
                        selectedAction = nil
                    }
                }
                .listStyle(.sidebar)

                Divider()

                Button(action: { showAddActionSheet = true }) {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("添加自定义操作")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
            }
            .frame(minWidth: 160, idealWidth: 180, maxWidth: 220)

            // 右列：编辑器
            if let action = selectedAction {
                CustomActionEditor(action: action, settings: settings)
            } else {
                ContentUnavailableView(
                    "选择或创建操作",
                    systemImage: "sparkles",
                    description: Text(settings.customQuickActions.isEmpty
                        ? "点击下方按钮添加自定义快捷操作"
                        : "从左侧选择一个操作进行编辑")
                )
            }
        }
        .sheet(isPresented: $showAddActionSheet) {
            AddQuickActionSheet(settings: settings)
        }
    }
}

// MARK: - System Prompt Editor

struct SystemPromptEditor: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("System Prompt")
                    .font(.headline)

                Spacer()

                Button("Reset to Default") {
                    settings.systemPrompt = AppSettings.defaultSystemPrompt
                }
            }

            Text("系统 Prompt 会在每次对话开始时发送给 AI，用于设定对话的上下文和行为。")
                .font(.caption)
                .foregroundColor(.secondary)

            TextEditor(text: $settings.systemPrompt)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )

            PlaceholderHintView(placeholder: "{pdf_content}", description: "会被替换为 PDF 内容")
        }
        .padding()
    }
}

// MARK: - Built-in Action Editor

struct BuiltInActionEditor: View {
    let action: CustomQuickAction
    @ObservedObject var settings: AppSettings

    private var promptBinding: Binding<String> {
        switch action.name {
        case "翻译":
            return $settings.promptTranslate
        case "解释":
            return $settings.promptExplain
        case "总结":
            return $settings.promptSummarize
        default:
            return .constant("")
        }
    }

    private var defaultPrompt: String {
        switch action.name {
        case "翻译":
            return AppSettings.defaultPromptTranslate
        case "解释":
            return AppSettings.defaultPromptExplain
        case "总结":
            return AppSettings.defaultPromptSummarize
        default:
            return ""
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label(action.name, systemImage: action.icon)
                    .font(.headline)

                Spacer()

                Button("Reset to Default") {
                    promptBinding.wrappedValue = defaultPrompt
                }
            }

            Text("选中文本后右键菜单中使用此操作时发送的 Prompt。")
                .font(.caption)
                .foregroundColor(.secondary)

            TextEditor(text: promptBinding)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )

            PlaceholderHintView(placeholder: "{selection}", description: "会被替换为选中的文本")
        }
        .padding()
    }
}

// MARK: - Custom Action Editor

struct CustomActionEditor: View {
    let action: CustomQuickAction
    @ObservedObject var settings: AppSettings

    @State private var name: String = ""
    @State private var icon: String = ""
    @State private var prompt: String = ""
    @State private var isEnabled: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("编辑自定义操作")
                    .font(.headline)

                Spacer()

                Button("保存更改") {
                    saveChanges()
                }
                .buttonStyle(.borderedProminent)

                Button(role: .destructive) {
                    settings.removeCustomQuickAction(id: action.id)
                } label: {
                    Text("删除")
                }
            }

            Form {
                Section("基本信息") {
                    TextField("名称", text: $name)

                    Picker("图标", selection: $icon) {
                        ForEach(CustomQuickAction.availableIcons, id: \.self) { iconName in
                            Label(iconName, systemImage: iconName).tag(iconName)
                        }
                    }

                    Toggle("启用", isOn: $isEnabled)
                }

                Section("Prompt 模板") {
                    TextEditor(text: $prompt)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 200)

                    PlaceholderHintView(placeholder: "{selection}", description: "会被替换为选中的文本")
                }
            }
            .formStyle(.grouped)
        }
        .padding()
        .onAppear {
            name = action.name
            icon = action.icon
            prompt = action.prompt
            isEnabled = action.isEnabled
        }
    }

    private func saveChanges() {
        var updated = action
        updated.name = name
        updated.icon = icon
        updated.prompt = prompt
        updated.isEnabled = isEnabled
        settings.updateCustomQuickAction(updated)
    }
}

// MARK: - Add Quick Action Sheet

struct AddQuickActionSheet: View {
    @ObservedObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var icon: String = "sparkles"
    @State private var prompt: String = "请对以下内容进行处理：\n\n{selection}"

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("名称", text: $name)
                        .textFieldStyle(.roundedBorder)

                    Picker("图标", selection: $icon) {
                        ForEach(CustomQuickAction.availableIcons, id: \.self) { iconName in
                            HStack {
                                Image(systemName: iconName)
                                Text(iconName)
                            }
                            .tag(iconName)
                        }
                    }

                    // 图标预览
                    HStack {
                        Text("预览:")
                        Label(name.isEmpty ? "新操作" : name, systemImage: icon)
                            .padding(8)
                            .background(Color.accentColor.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }

                Section {
                    TextEditor(text: $prompt)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 150)
                } header: {
                    Text("Prompt 模板")
                } footer: {
                    Text("使用 {selection} 作为选中文本的占位符")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("添加自定义操作")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        addAction()
                        dismiss()
                    }
                    .disabled(name.isEmpty || prompt.isEmpty)
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }

    private func addAction() {
        let action = CustomQuickAction(
            name: name,
            icon: icon,
            prompt: prompt,
            isBuiltIn: false,
            isEnabled: true
        )
        settings.addCustomQuickAction(action)
    }
}

// MARK: - Placeholder Hint View

struct PlaceholderHintView: View {
    let placeholder: String
    let description: String

    var body: some View {
        HStack {
            Text("可用占位符:")
                .font(.caption)
                .fontWeight(.semibold)

            Text(placeholder)
                .font(.system(.caption, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 4))

            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    BuiltInActionsDetailView(settings: AppSettings.shared)
        .frame(width: 600, height: 500)
}
