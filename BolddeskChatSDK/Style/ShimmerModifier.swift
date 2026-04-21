import SwiftUI

// Shimmer Effect Modifier
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(gradient: Gradient(colors: [Color.gray.opacity(0.1), Color.gray, Color.gray.opacity(0.1)]), startPoint: .leading, endPoint: .trailing)
                    .offset(x: -5 + phase)
                    .mask(content)
            )
            .onAppear {
                withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 400
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        self.modifier(ShimmerModifier())
    }
}
