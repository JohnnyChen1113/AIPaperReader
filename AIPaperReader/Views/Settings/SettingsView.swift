//
//  SettingsView.swift
//  AIPaperReader
//
//  Created by Claude on 2/4/26.
//

import SwiftUI

/// 设置页面分区
enum SettingsSection: Hashable {
    case model          // 大模型
    case general        // 通用
    case systemPrompt   // System Prompt
    case builtInActions  // 内置快捷操作
    case customActions   // 自定义快捷操作
}

struct SettingsView: View {
    @State private var selectedSection: SettingsSection? = .model
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSection) {
                Section("设置") {
                    Label("大模型", systemImage: "brain")
                        .tag(SettingsSection.model)

                    Label("通用", systemImage: "gear")
                        .tag(SettingsSection.general)
                }

                Section("提示词") {
                    Label("System Prompt", systemImage: "gearshape.2")
                        .tag(SettingsSection.systemPrompt)

                    Label("内置快捷操作", systemImage: "bolt.fill")
                        .tag(SettingsSection.builtInActions)

                    Label("自定义快捷操作", systemImage: "sparkles")
                        .tag(SettingsSection.customActions)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("设置")
        } detail: {
            Group {
                switch selectedSection {
                case .model:
                    ModelSettingsView()
                case .general:
                    GeneralSettingsView()
                case .systemPrompt:
                    SystemPromptEditor(settings: settings)
                case .builtInActions:
                    BuiltInActionsDetailView(settings: settings)
                case .customActions:
                    CustomActionsDetailView(settings: settings)
                case .none:
                    ContentUnavailableView(
                        "选择一个设置项",
                        systemImage: "gear",
                        description: Text("从左侧列表选择一个设置项")
                    )
                }
            }
        }
        .frame(width: 720, height: 580)
    }
}

#Preview {
    SettingsView()
}
