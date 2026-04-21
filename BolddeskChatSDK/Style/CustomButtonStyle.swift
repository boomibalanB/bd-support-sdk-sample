import SwiftUI

struct CustomButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isControlEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(FontFamily.customFont(size: FontSize.medium, weight: .semibold))
            .foregroundColor(isControlEnabled ? .actionColorPrimaryFg : .actionColorPrimaryFg.opacity(0.8))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isControlEnabled ? Color.actionColorPrimaryBg : Color.actionColorPrimaryBg.opacity(0.6))
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}
