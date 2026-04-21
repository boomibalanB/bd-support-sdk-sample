import SwiftUI

struct NotificationView: View {
    let type: NotificationType
    let onRetry: (() -> Void)?

    var body: some View {
        HStack {
            Group {
                if type.style == .error {
                    CircleIcon(iconColor: .fgErrorPrimary)
                } else if type.style == .success {
                    CircleIcon(iconColor: .fgSuccessSecondary)
                } else if type == .reconnecting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .bgBrandSolid))
                        .frame(width: 24, height: 24)
                }
            }
            .padding(.leading, 16)

            Text(type.message)
                .font(FontFamily.customFont(size: FontSize.xsmall, weight: .medium))
                .foregroundColor(Color.textSecondary)
                .multilineTextAlignment(.leading)
                .padding(.vertical, 12)
                .padding(.leading, 10)

            Spacer(minLength: 8)

            if type.canShowRetry, let onRetry = onRetry {
                Button(ResourceManager.localized("retry")) {
                    onRetry()
                }
                .font(FontFamily.customFont(size: FontSize.medium, weight: .semibold))
                .foregroundColor(Color.actionColorPrimaryBg)
                .padding(.trailing, 16)
            } else if type.style == .success {
                AppIcon(icon: .close)
                    .onTapGesture {
                        NotificationManager.shared.hide()
                    }
                    .padding(.trailing, 16)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 52)
        .background(backgroundColor)
        .transition(.move(edge: .top).combined(with: .opacity))
        .zIndex(1)
    }

    private var backgroundColor: Color {
        switch type.style {
        case .success:
            return Color.utilitySuccess50
        case .error:
            return Color.utilityError50
        case .info:
            return Color.bgWarningPrimary
        }
    }

    private func CircleIcon(iconColor: Color) -> some View {
        ZStack {
            Circle()
                .stroke(iconColor.opacity(0.25), lineWidth: 2)
                .frame(width: 36, height: 36)
            Circle()
                .stroke(iconColor.opacity(0.55), lineWidth: 2)
                .frame(width: 24, height: 24)
            AppIcon(icon: .alertCircle, size: FontSize.large, color: iconColor)
        }
    }
}

#Preview {
    NotificationView(type: .serverDisconnected, onRetry: nil)
    NotificationView(type: .reconnecting, onRetry: nil)
    
    NotificationView(type: .serverOnline, onRetry: nil)
}
