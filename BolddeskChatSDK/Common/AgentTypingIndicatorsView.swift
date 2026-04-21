import SwiftUI

struct AiAgentThinkingIndicatorView: View {
    let agentInfo: AgentInfo

    var body: some View {
        AgentTypingIndicatorContainer(agentInfo: agentInfo) {
            HStack(spacing: 6) {
                Text(ResourceManager.localized("ai_agent_thinking"))
                    .font(FontFamily.customFont(size: FontSize.medium, weight: .regular))
                    .foregroundColor(.textSecondary)
                TypingBubbleView()
            }
            .lineSpacing(6)
        }
    }
}

struct AgentTypingIndicatorView: View {
    let agentInfo: AgentInfo

    var body: some View {
        AgentTypingIndicatorContainer(agentInfo: agentInfo) {
            TypingBubbleView()
        }
    }
}

private struct AgentTypingIndicatorContainer<Content: View>: View {
    let agentInfo: AgentInfo
    let content: Content

    init(agentInfo: AgentInfo, @ViewBuilder content: () -> Content) {
        self.agentInfo = agentInfo
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AgentAvatarSection(agentInfo: agentInfo)

            VStack(alignment: .leading, spacing: 4) {
                Text(agentInfo.displayName)
                    .font(FontFamily.customFont(size: FontSize.xsmall, weight: .regular))
                    .foregroundColor(.textTertiary)

                content
                    .padding(10)
                    .background(Color.bgSecondary)
                    .clipShape(CustomCorners(topLeft: 2, topRight: 12, bottomLeft: 12, bottomRight: 12))
                    .overlay(
                        CustomCorners(topLeft: 2, topRight: 12, bottomLeft: 12, bottomRight: 12)
                            .stroke(Color.borderSecondary, lineWidth: 1)
                    )
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.leading, 6)
        .padding(.top, 8)
    }
}

private struct TypingBubbleView: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        HStack(spacing: 4) {
            bubbleDot(delay: 0.3, color: .fgQuinary)
            bubbleDot(delay: 0.15, color: .fgTertiary)
            bubbleDot(delay: 0.0, color: .fgSecondary)
        }
        .frame(width: 40, height: 16)
        .onAppear {
            withAnimation(
                .linear(duration: 1.3).repeatForever(autoreverses: false)
            ) {
                phase = 1
            }
        }
    }

    private func bubbleDot(delay: Double, color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
            .modifier(BounceEffect(phase: phase, delay: delay))
    }
}

private struct BounceEffect: AnimatableModifier {
    var phase: CGFloat
    let delay: Double

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func body(content: Content) -> some View {
        let t = (phase + CGFloat(delay / 1.3)).truncatingRemainder(dividingBy: 1.0)
        let y: CGFloat

        switch t {
        case 0..<0.3:
            y = -6 * (t / 0.3) // move up
        case 0.3..<0.6:
            y = -6 * (1 - (t - 0.3) / 0.3) // move down
        default:
            y = 0
        }

        return content.offset(y: y)
    }
}

#Preview {
    AgentTypingIndicatorView(
        agentInfo: AgentInfo(
            id: 123,
            displayName: "Alice",
            colorCode: "#3498db",
            shortCode: "A",
            profileImageUrl: nil,
            isAIAgent: false
        )
    )
    
    AiAgentThinkingIndicatorView(
        agentInfo: AgentInfo(
            id: 123,
            displayName: "Alice",
            colorCode: "#3498db",
            shortCode: "A",
            profileImageUrl: nil,
            isAIAgent: false
        )
    )

}

