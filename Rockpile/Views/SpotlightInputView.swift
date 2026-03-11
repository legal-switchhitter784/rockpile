import SwiftUI

/// 展开面板底部输入框 — 发送指令给 Rockpile
///
/// - 半透明暗色背景，monospaced 字体
/// - Enter 发送，Escape 取消
/// - 无会话时显示黄色"等待连接..."
/// - 发送失败显示红色提示
struct SpotlightInputView: View {
    let onSend: (String) -> Void

    @State private var inputText = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(DS.Surface.divider)

            HStack(spacing: DS.Space.sm) {
                // 🦞 Target indicator — commands go to crawfish via Gateway
                Text("\u{1F99E}")
                    .font(.system(size: 12))
                    .opacity(DS.Opacity.secondary)

                TextField(L10n.s("input.placeholder"), text: $inputText)
                    .textFieldStyle(.plain)
                    .font(DS.Font.monoBody)
                    .foregroundColor(DS.TextColor.primary)
                    .focused($isFocused)
                    .onSubmit {
                        sendMessage()
                    }
                    .onKeyPress(.escape) {
                        isFocused = false
                        inputText = ""
                        NotchPanel.returnFocusToPreviousApp()
                        return .handled
                    }

                if !inputText.isEmpty {
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(DS.Semantic.accent)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.s("input.send"))
                }
            }
            .padding(.horizontal, DS.Space.md)
            .padding(.vertical, DS.Space.sm)
            .background(Color.white.opacity(DS.Opacity.ghost))

            // Status feedback
            feedbackBar
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var feedbackBar: some View {
        let result = CommandSender.shared.lastResult
        switch result {
        case .idle, .sending:
            EmptyView()
        case .sent(let method):
            feedbackText("\(L10n.s("input.sent")) (\(method))", color: DS.Semantic.success)
        case .queued:
            feedbackText(L10n.s("input.waitingConnection"), color: DS.Semantic.warning)
        case .noSession:
            feedbackText(L10n.s("input.noSession"), color: DS.Semantic.warning)
        case .error(let msg):
            feedbackText(msg, color: DS.Semantic.danger)
        }
    }

    @ViewBuilder
    private func feedbackText(_ text: String, color: Color) -> some View {
        HStack {
            Text(text)
                .font(DS.Font.caption)
                .foregroundColor(color)
            Spacer()
        }
        .padding(.horizontal, DS.Space.md)
        .padding(.vertical, DS.Space.xxs)
        .background(color.opacity(0.1))
        .transition(.opacity)
    }

    // MARK: - Actions

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        onSend(text)
        inputText = ""
        isFocused = false
        NotchPanel.returnFocusToPreviousApp()
    }
}
