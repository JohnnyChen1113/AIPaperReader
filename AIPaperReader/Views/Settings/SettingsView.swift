//
//  SettingsView.swift
//  AIPaperReader
//
//  Created by Claude on 2/4/26.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            ModelSettingsView()
                .tabItem {
                    Label("大模型", systemImage: "brain")
                }

            PromptSettingsView()
                .tabItem {
                    Label("提示词", systemImage: "text.bubble")
                }

            GeneralSettingsView()
                .tabItem {
                    Label("通用", systemImage: "gear")
                }
        }
        .frame(width: 600, height: 550)
    }
}

#Preview {
    SettingsView()
}
