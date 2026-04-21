import SwiftUI
import Combine

final class KeyboardObserver: ObservableObject {
    @Published var isKeyboardVisible: Bool = false
    @Published var keyboardHeight: CGFloat = 0
    private var cancellables: Set<AnyCancellable> = []

    init() {
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .merge(with: NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification))
            .sink { [weak self] notification in
                guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
                DispatchQueue.main.async {
                    self?.isKeyboardVisible = true
                    self?.keyboardHeight = frame.height
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.isKeyboardVisible = false
                    self?.keyboardHeight = 0
                }
            }
            .store(in: &cancellables)
    }
}

enum DeviceType {
    static var isTablet: Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }
    static var isPhone: Bool {
        return UIDevice.current.userInterfaceIdiom == .phone
    }
}
