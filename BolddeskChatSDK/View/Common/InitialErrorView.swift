import SwiftUI

struct InitialErrorView: View {
    let title: String
    let message: String
    let tryAgainTitle: String
    let cancelTitle: String
    let onTryAgain: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.utilityError50)
                    .frame(width: 56, height: 56)
                AppIcon(icon: .infoCircle, size: FontSize.xxlarge, color: .fgErrorPrimary)
            }
            VStack(spacing: 8) {
                Text(title)
                    .font(FontFamily.customFont(size: FontSize.xlarge, weight: .semibold))
                    .foregroundColor(Color.textSecondary)
                Text(message)
                    .font(FontFamily.customFont(size: FontSize.medium, weight: .regular))
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color.textTertiary)
                    .padding(.horizontal, 24)
            }
            VStack(spacing: 12) {
                Button(action: onTryAgain) {
                    HStack(spacing: 8) {
                        AppIcon(icon: .refresh01, size: FontSize.xlarge, color: .actionColorPrimaryFg)
                        Text(tryAgainTitle)
                            .font(FontFamily.customFont(size: FontSize.medium, weight: .semibold))
                            .foregroundColor(.actionColorPrimaryFg)
                    }
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                }
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.actionColorPrimaryBg))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.actionColorPrimaryBorder, lineWidth: 1)
                )

                Button(action: onCancel) {
                    Text(cancelTitle)
                        .font(FontFamily.customFont(size: FontSize.medium, weight: .semibold))
                        .foregroundColor(Color.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.bgSecondary))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.borderPrimary, lineWidth: 1)
                )
            }
            .padding(.horizontal, 24)
            Spacer()
        }
        .background(Color.bgPrimary)
    }
}

#Preview {
    InitialErrorView(
        title: "Error starting chat",
        message: "We could not connect to the chat. Try again now, or later.",
        tryAgainTitle: "Try again",
        cancelTitle: "Cancel",
        onTryAgain: {},
        onCancel: {}
    )
}
