import SwiftUI

struct BcButton: View {
    let icon: AppIcons?
    let label: String
    let mainAction: () -> Void

    @State private var showActionSheet = false
    @State private var isProcessing = false
    @Environment(\.isEnabled) private var isControlEnabled

    var body: some View {
        HStack(spacing: 0) {
            Button(action: {
                mainAction()
            }) {
                ZStack {
                    // Normal content (always present to keep width)
                    HStack(spacing: 8) {
                        if let icon = icon {
                            AppIcon(
                                icon: icon,
                                size: FontSize.xlarge,
                                color: (isControlEnabled && !isProcessing) ? Color.actionColorPrimaryFg : Color.actionColorPrimaryFg.opacity(0.8)
                            )
                            .padding(.top, 2)
                        }
                        Text(ResourceManager.localized(label))
                            .font(FontFamily.customFont(size: FontSize.medium, weight: .semibold))
                    }
                    .opacity(isProcessing ? 0 : 1)

                    // Processing content (overlayed)
                    HStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color.actionColorPrimaryFg))
                            .scaleEffect(0.8)
                        Text(ResourceManager.localized("processing"))
                            .font(FontFamily.customFont(size: FontSize.medium, weight: .semibold))
                    }
                    .opacity(isProcessing ? 1 : 0)
                }
                .foregroundColor((isControlEnabled && !isProcessing) ? Color.actionColorPrimaryFg : Color.actionColorPrimaryFg.opacity(0.8))
            }
            .padding(.horizontal, 20)
            .frame(height: 44)
        }
        .background(Color.actionColorPrimaryBg)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.actionColorPrimaryBorder, lineWidth: 1)
        )
        .cornerRadius(8)
        .frame(height: 40)
        .disabled(isProcessing)
        .opacity((!isControlEnabled || isProcessing) ? 0.8 : 1.0)
        .padding(.vertical, 12)
    }
}

