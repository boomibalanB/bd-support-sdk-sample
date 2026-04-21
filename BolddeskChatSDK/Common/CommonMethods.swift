import SwiftUI
import UIKit

func openFile(_ url: URL) {
    DispatchQueue.main.async {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)

        if let presenter = topMostViewController() {
            
            // iPad (Tablet)
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = presenter.view
                popover.sourceRect = CGRect(
                    x: presenter.view.bounds.midX,
                    y: presenter.view.bounds.midY,
                    width: 0,
                    height: 0
                )
                popover.permittedArrowDirections = [] // No arrow → center dialog style
            }

            presenter.present(activityVC, animated: true)
        }
    }
}

// MARK: - Helper to get top view controller
func topMostViewController(base: UIViewController? = nil) -> UIViewController? {
    let baseVC: UIViewController? = {
        if let base = base { return base }
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else { return nil }
        if let key = windowScene.windows.first(where: { $0.isKeyWindow }) {
            return key.rootViewController
        }
        return windowScene.windows.first?.rootViewController
    }()
    guard let vc = baseVC else { return nil }
    
    if let nav = vc as? UINavigationController {
        return topMostViewController(base: nav.visibleViewController)
    }
    if let tab = vc as? UITabBarController, let selected = tab.selectedViewController {
        return topMostViewController(base: selected)
    }
    if let presented = vc.presentedViewController {
        return topMostViewController(base: presented)
    }
    return vc
}

