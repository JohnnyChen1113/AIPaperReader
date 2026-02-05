//
//  ChatInputView.swift
//  AIPaperReader
//
//  Created by Claude on 2/4/26.
//

import SwiftUI

struct ChatInputView: View {
    @Binding var inputText: String
    var isGenerating: Bool
    var onSend: () -> Void
    var onStop: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Text input
            TextField("输入你的问题...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .lineLimit(1...5)
                .focused($isFocused)
                .onSubmit {
                    if !isGenerating && !inputText.isEmpty {
                        onSend()
                    }
                }

            // Send/Stop button
            Button(action: {
                if isGenerating {
                    onStop()
                } else {
                    onSend()
                }
            }) {
                Image(systemName: isGenerating ? "stop.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(isGenerating ? .red : (inputText.isEmpty ? .secondary : .accentColor))
            }
            .buttonStyle(.plain)
            .disabled(!isGenerating && inputText.isEmpty)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Page Range Selector

struct PageRangeSelectorView: View {
    @Binding var pageRangeOption: PageRangeOption
    @Binding var customPageRange: String
    var estimatedTokens: Int
    var pageCount: Int

    var body: some View {
        HStack(spacing: 12) {
            Text("范围:")
                .font(.caption)
                .foregroundColor(.secondary)

            // Range picker
            Picker("", selection: $pageRangeOption) {
                ForEach(PageRangeOption.allCases, id: \.self) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: 100)

            // Custom range input
            if pageRangeOption == .custom {
                TextField("如: 1-5,8", text: $customPageRange)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
            }

            Spacer()

            // Token estimate
            HStack(spacing: 4) {
                Image(systemName: "number")
                    .font(.caption)
                Text("约 \(estimatedTokens) tokens")
                    .font(.caption)
            }
            .foregroundColor(.secondary)
            .help("所选页面范围的预估 token 数量")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.05))
    }
}

#Preview {
    VStack {
        PageRangeSelectorView(
            pageRangeOption: .constant(.all),
            customPageRange: .constant(""),
            estimatedTokens: 5000,
            pageCount: 20
        )

        ChatInputView(
            inputText: .constant(""),
            isGenerating: false,
            onSend: {},
            onStop: {}
        )
    }
}
