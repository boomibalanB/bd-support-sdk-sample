import SwiftUI
import Combine

final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published var currentNotification: NotificationType?

    // Retry tap event publisher
    private let retryTappedSubject = PassthroughSubject<NotificationType, Never>()
    var onRetryTapped: AnyPublisher<NotificationType, Never> {
        retryTappedSubject.eraseToAnyPublisher()
    }

    private init() {}

    // Convenience to show a simple custom message with default style
    func show(_ message: String, style: NotificationType.Style = .info, shouldAutoHide: Bool = true) {
        show(.custom(message, style), shouldAutoHide: shouldAutoHide)
    }

    func show(_ type: NotificationType, shouldAutoHide: Bool = false) {
        guard currentNotification != type else { return } // prevent duplicate

        withAnimation(.easeInOut) {
            currentNotification = type
        }

        if type.shouldAutoHide || shouldAutoHide {
            let expectedType = type
            DispatchQueue.main.asyncAfter(deadline: .now() + AppConstant.notificationAutoHideDelay) { [weak self] in
                guard let self = self else { return }
                // Hide only if we're still showing the same type
                if self.currentNotification == expectedType {
                    self.hide()
                }
            }
        }
    }

    func hide() {
        withAnimation(.easeInOut) {
            currentNotification = nil
        }
    }
}
