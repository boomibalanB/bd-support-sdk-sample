import SwiftUI

enum ThemePreference: String, CaseIterable {
    case light
    case dark
    case system
}

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var currentTheme: ThemePreference = .light
    private var systemThemeObserver: NSObjectProtocol?
    
    private init() {
        setupSystemThemeObserver()
        applyTheme()
    }
    
    deinit {
        if let observer = systemThemeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    func setTheme(_ theme: ThemePreference) {
        currentTheme = theme
        applyTheme()
    }
    
    private func setupSystemThemeObserver() {
        // Remove existing observer if any
        if let observer = systemThemeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        // Only observe system theme changes when user has selected "Follow System"
        systemThemeObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            if self?.currentTheme == .system {
                self?.applyTheme()
            }
        }
    }
    
    private func applyTheme() {
        let interfaceStyle: UIUserInterfaceStyle
        
        switch currentTheme {
        case .light:
            interfaceStyle = .light
        case .dark:
            interfaceStyle = .dark
        case .system:
            interfaceStyle = .unspecified
        }
        
        DispatchQueue.main.async {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .forEach { window in
                    window.overrideUserInterfaceStyle = interfaceStyle
                }
        }
    }
}
