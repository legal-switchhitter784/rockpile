import SwiftUI

/// 像素风气泡对话 — 参考 Star-Office-UI 的 BUBBLE_TEXTS + 打字机效果
///
/// 在龙虾精灵上方显示，按当前状态随机选择台词，逐字显示后淡出。

// MARK: - Bubble Texts

@MainActor
enum BubbleTexts {
    static func texts(for task: ClawTask) -> [String] {
        switch task {
        case .idle:       return L10n.a("bubble.idle")
        case .thinking:   return L10n.a("bubble.thinking")
        case .working:    return L10n.a("bubble.working")
        case .waiting:    return L10n.a("bubble.waiting")
        case .error:      return L10n.a("bubble.error")
        case .sleeping:   return L10n.a("bubble.sleeping")
        case .compacting: return L10n.a("bubble.compacting")
        }
    }

    static var dead: [String] { L10n.a("bubble.dead") }
}

// MARK: - Bubble View

struct PixelBubbleView: View {
    let task: ClawTask
    let isDead: Bool
    let spriteSize: CGFloat

    @State private var currentText = ""
    @State private var displayedText = ""
    @State private var opacity: Double = 0
    @State private var bubbleId = UUID()

    /// Interval between bubble appearances
    private let interval: TimeInterval = 10.0
    /// How long the bubble stays fully visible
    private let stayDuration: TimeInterval = 3.5
    /// Typewriter speed: seconds per character
    private let charDelay: TimeInterval = 0.06

    var body: some View {
        ZStack {
            if !displayedText.isEmpty {
                bubbleShape
                    .opacity(opacity)
                    .id(bubbleId)
            }
        }
        .frame(width: spriteSize * 2, height: 28)
        .offset(y: -spriteSize * 0.45)
        .onAppear { scheduleBubble() }
        .onChange(of: task) { _, _ in
            // Show a new bubble immediately on state change
            showNewBubble()
        }
        .onChange(of: isDead) { _, dead in
            if dead { showDeadBubble() }
        }
    }

    @ViewBuilder
    private var bubbleShape: some View {
        HStack(spacing: 0) {
            Text(displayedText)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.black.opacity(0.75))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private func scheduleBubble() {
        let delay = Double.random(in: 5...interval)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            showNewBubble()
        }
    }

    private func showNewBubble() {
        let texts = isDead ? BubbleTexts.dead : BubbleTexts.texts(for: task)
        guard let text = texts.randomElement() else { return }

        currentText = text
        displayedText = ""
        opacity = 1.0
        bubbleId = UUID()

        // Typewriter effect
        typewriteText(text, index: 0)
    }

    private func showDeadBubble() {
        guard let text = BubbleTexts.dead.randomElement() else { return }
        currentText = text
        displayedText = ""
        opacity = 1.0
        bubbleId = UUID()
        typewriteText(text, index: 0)
    }

    private func typewriteText(_ text: String, index: Int) {
        guard index < text.count else {
            // Typewriter complete — stay, then fade
            DispatchQueue.main.asyncAfter(deadline: .now() + stayDuration) {
                withAnimation(.easeOut(duration: 0.5)) {
                    opacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    displayedText = ""
                    scheduleBubble()
                }
            }
            return
        }

        let charIndex = text.index(text.startIndex, offsetBy: index)
        displayedText = String(text[text.startIndex...charIndex])

        DispatchQueue.main.asyncAfter(deadline: .now() + charDelay) {
            typewriteText(text, index: index + 1)
        }
    }
}
