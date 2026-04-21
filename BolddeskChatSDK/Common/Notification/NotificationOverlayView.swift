import SwiftUI

struct NotificationOverlayView: View {
    @ObservedObject private var manager = NotificationManager.shared
    let onRetry: (() -> Void)?

    init(onRetry: (() -> Void)? = nil) {
        self.onRetry = onRetry
    }

    var body: some View {
        ZStack(alignment: .top) {
            if let type = manager.currentNotification {
                NotificationView(
                    type: type,
                    onRetry: type.canShowRetry ? {
                        // Forward retry to caller if provided; otherwise just hide
                        if let onRetry = onRetry { onRetry() } else { NotificationManager.shared.hide() }
                    } : nil
                )
                .zIndex(10)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: manager.currentNotification)
    }
}
