import SwiftUI
import UIKit
internal import Sentry
internal import BoldDeskSupportSDK

// Helper class used only to locate this framework's bundle at runtime.
internal final class SDKBundleFinder {}

public struct BDChatSDK {
    private static var fontsRegistered = false
    private static var themeManager: ThemeManager { ThemeManager.shared }
    // Closure to clear the active chat session
    private static var clearSessionAction: (@MainActor () -> Void)?
    // Closure to navigate to a conversation when list is open
    private static var navigateToConversationAction: ((String) -> Void)?
    private static var chatSessionId = UUID()
    // Keep a single reusable hosting controller for all SDK screens.
    private static var hostingController: UIHostingController<AnyView>?
    static var isOpen = false

    public static var name: String?
    public static var email: String?
    public static var phoneNo: String?
    public static var userToken: String?
    public static var fields: [String: Any]?
    public static var fcmToken: String?
    public static var customFontName: String? = nil
    public static var applySystemFontSize = false
    public static var appKey: String = ""
    public static var brandUrl: String = ""
    internal static var isConversationListOpen: Bool = false
    public static var isSDKOpen: Bool = false
    internal static var isFromPushNotification: Bool = false

    public static func configure(appKey: String, brandUrl: String, _ culture: String? = nil) {
        // Persist core configuration for later retrieval
        self.appKey = appKey
        self.brandUrl = brandUrl
        resetChatSession()
        if (culture != "ar") {
            AppConstant.languageCode = culture == "en" ? "en-US" : culture ?? "en-US"
        }

        WidgetStorageManager.setGlobalConfig(appToken: appKey, brandUrl: brandUrl)
        
        // Capture app/device details along with provided brand URL
        getAppDetails(brandUrl: brandUrl)
        
        if AppConstant.environment != "development" {
            initializeSentry()
        }
    }
    
    public static func applyTheme(
        appbarColor: String? = nil,
        accentColor: String? = nil,
        backgroundColor: String? = nil,
        stickyButtonColor: String? = nil
    ) {
        if let value = appbarColor {
            AppConstant.appBarColor = value
        }
        if let value = backgroundColor {
            AppConstant.chatBackgroundColor = value
        }
        if let value = accentColor {
            AppConstant.buttonColor = value
        }
        if let value = stickyButtonColor {
            AppConstant.stickyButtonColor = value
        }
    }
    
    public static func setUserToken(_ userToken: String?) {
        BDChatSDK.userToken = userToken
    }
    
    public static func setPrefillFields(email: String? = nil, name: String? = nil, phoneNo: String? = nil, fields: [String: Any]? = nil) {
        resetChatSession()
        AppConstant.email = email ?? ""
        BDChatSDK.name = name
        BDChatSDK.phoneNo = phoneNo
        BDChatSDK.fields = fields
    }

    public static func setPlatform(sdkPlatform: String, sdkVersion: String) {
        AppConstant.platform = sdkPlatform
        AppConstant.sdkVersion = sdkVersion
    }

    public static func setup() {
        initializeDefaultItems()
    }
    
    public static var Theme: SDKTheme = .light {
        didSet {
            setPreferredTheme(Theme)
        }
    }
    
    public static func setPreferredTheme(_ theme: SDKTheme) {
        switch theme {
        case .light:
            themeManager.setTheme(.light)
            AppConstant.customTheme = "light"
        case .dark:
            themeManager.setTheme(.dark)
            AppConstant.customTheme = "dark"
        case .system:
            themeManager.setTheme(.system)
            AppConstant.customTheme = "system"
        }
    }
    
    internal static func setSDKPreferredTheme(_ theme: SDKTheme) {
        switch theme {
        case .light:
            themeManager.setTheme(.light)
        case .dark:
            themeManager.setTheme(.dark)
        case .system:
            themeManager.setTheme(.system)
        }
    }
    
    public static func enablePushNotification(fcmToken: String) {
        AppConstant.fcmToken = fcmToken
        self.fcmToken = fcmToken
        
        // Get app token from storage (this is the validated token)
        guard let appToken = WidgetStorageManager.getAppToken(), !appToken.isEmpty else {
            NetworkLogger.log("Failed to enable push: appToken not configured", level: .error)
            return
        }
        
        // Check if user exists
        guard WidgetStorageManager.isUserExistAlready(
            appKey: self.appKey,
            emailId: self.email
        ) else {
            NetworkLogger.log("Failed to enable push: user doesn't exist yet", level: .error)
            return
        }
        
        guard let requesterId = WidgetStorageManager.getSetting(
            for: "rId",
            appKey: self.appKey,
            emailId: self.email
        ) else {
            NetworkLogger.log("Failed to enable push: requesterId not found", level: .error)
            return
        }
        
        let requesterType = WidgetStorageManager.getSetting(
            for: "rType",
            appKey: self.appKey,
            emailId: self.email
        ) ?? "0"
        
        // Build AdditionalConfig
        let additionalConfig = AdditionalConfig(
            deviceName: AppConstant.deviceName
        )
        
        // Prepare variables - IMPORTANT: Only one should be set, the other must be nil
        var visitorId: String? = nil
        var userId: Int? = nil
        
        if requesterType == "0" {
            // Visitor: set visitorId, leave userId as nil
            visitorId = requesterId
            userId = nil  // Must be nil for visitors
        } else {
            // User: set userId, leave visitorId as nil
            visitorId = nil  // Must be nil for users
            userId = Int(requesterId) ?? 0
        }
        
        // Create Codable Payload
        let requestPayload = DeviceTokenRequest(
            appTypeId: 2,  // iOS app type
            deviceToken: fcmToken,
            appId: appToken,  // Use validated token from storage
            additionalConfig: additionalConfig,
            visitorId: visitorId,
            userId: userId
        )
        
        NetworkLogger.log("Enabling push notification with appId: \(appToken), requesterType: \(requesterType), visitorId: \(visitorId ?? "nil"), userId: \(userId?.description ?? "nil")", level: .response)
        
        // Call API
        Task {
            do {
                let response = try await ChatAPIClient().updateDeviceToken(payload: requestPayload)
                
                if response.isSuccess {
                    NetworkLogger.log("✅ Push notification enabled successfully", level: .response)
                } else {
                    NetworkLogger.log("❌ Failed to update device token", level: .error)
                }
                
            } catch {
                NetworkLogger.log("❌ Failed to update device token: \(error.localizedDescription)", level: .error)
            }
        }
    }
    
    public static func disablePushNotification() {
        guard !AppConstant.fcmToken.isEmpty else { return }
        Task {
            do {
                let response = try await ChatAPIClient().deleteDeviceToken(deviceToken: AppConstant.fcmToken)
                if !response.isSuccess {
                    NetworkLogger.log("Failed to delete push token", level: .error)
                }
            } catch {
                NetworkLogger.log("Failed to delete push token: \(error.localizedDescription)", level: .error)
            }
        }
    }
    
    public static func enableLogging() {
        NetworkLogger.isEnabled = true
    }
    
    public static func isChatOpen() -> Bool {
        return isSDKOpen || isOpen
    }
    
    /// Shows the main Chat screen using the SDK’s reusable hosting controller.
    public static func showChat() {
        BDChatSDK.email = AppConstant.email
        guard BDChatSDK.isOpen == false else { return }
        let view = AnyView(
            ConversationListView(initialConversationId: "")
                .id(chatSessionId)
        )
        presentOrReplaceRoot(view)
    }
    
    private static func getThreadId(from userInfo: [AnyHashable: Any]) -> String? {
        guard let aps = userInfo[AnyHashable("aps")] as? [String: Any],
              let threadId = aps["thread-id"] as? String else {
            return nil
        }
        return threadId
    }
    
    private static func removePrefixTillSecondUnderscore(_ threadId: String) -> String? {
        let parts = threadId.split(separator: "_", maxSplits: 2)
        return parts.count == 3 ? String(parts[2]) : nil
    }
    /// Opens the chat SDK directly to a specific conversation (for push notification handling).
    /// - Parameter conversationId: The conversation/thread ID from the notification payload
    public static func handlePushNotification(userInfo: [AnyHashable: Any]) {
        resetChatSession()
        enableLogging()
        BDChatSDK.email = AppConstant.email
        let conversationId = removePrefixTillSecondUnderscore(getThreadId(from: userInfo) ?? "")
        isFromPushNotification = true
        let view = AnyView(
            ConversationListView(initialConversationId: conversationId ?? "")
                .id(chatSessionId)
        )
        presentOrReplaceRoot(view)
    }
    
    /// Closes the currently presented Chat screen (if it was presented by this SDK).
    public static func closeChat() {
        DispatchQueue.main.async {
            hostingController?.dismiss(animated: true) {
                hostingController = nil
            }
        }
        isSDKOpen = false
        BDChatSDK.isOpen = false
    }
    
    /// Sets the action that should be performed to clear the chat session.
    /// This is typically called by the ChatView to provide its specific clear logic.
    @MainActor internal static func setClearSessionAction(_ action: @escaping @MainActor () -> Void) {
        BDChatSDK.clearSessionAction = action
    }
    
    /// Sets the action to navigate to a conversation from the conversation list.
    /// This is called by ConversationListView when it appears.
    internal static func setNavigateToConversationAction(_ action: @escaping (String) -> Void) {
        BDChatSDK.navigateToConversationAction = action
    }

    /// Clears the chat session and resets all chat-related data for the active ChatViewModel.
    /// This will execute the action set by `setClearSessionAction`.
    public static func clearSession() {
        Task { @MainActor in
            // Execute the clear session action first so the ChatViewModel
            // can perform its cleanup while the action is still available.
            BDChatSDK.clearSessionAction?()
            // Then reset SDK-level session state which clears the stored action.
            resetChatSession()
        }
    }
    
    private static func initializeDefaultItems() {
        guard !fontsRegistered else { return }
        ResourceManager.registerFonts([
            "Inter-Regular.ttf",
            "Inter-Medium.ttf",
            "Inter-SemiBold.ttf",
            "Inter-Bold.ttf",
            "CustomIcons.ttf"
        ])
        fontsRegistered = true
    }
    
    private static func resetChatSession() {
        chatSessionId = UUID()        // forces SwiftUI reload
        clearSessionAction = nil
        navigateToConversationAction = nil
        isOpen = false
        isSDKOpen = false
        ChatUtils.shared.clearCache()  // Clear agent avatar cache
        NotificationManager.shared.hide()  // Clear any active notifications
    }
    
    internal static func initializeSentry() {
        DispatchQueue.main.async {
            SentrySDK.start { options in
                options.dsn = AppConstant.sentryDSN
                options.sendDefaultPii = true
                options.environment = AppConstant.environment
            }
        }
    }
    
    private static func getAppDetails(brandUrl: String) {
        let device = UIDevice.current
        AppConstant.deviceName = device.name
        AppConstant.osVersion = device.systemVersion
        AppConstant.clientAppName =
            Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "UnknownApp"
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"

        let appDetails: [String: Any] = [
                "deviceName": device.name,
                "version": device.systemVersion,
                "platform": AppConstant.platform,
                "appName": AppConstant.clientAppName,
                "appVersion": appVersion,
                "sdkVersion": "\(AppConstant.sdkVersion) (\(AppConstant.platform))",
                "brandUrl": brandUrl
            ]
        AppConstant.applicationInfo = appDetails
    }
    
    public static func isFromChatSDK(userInfo: [AnyHashable: Any]) -> Bool {
        guard let value = userInfo["isFromChatSDK"] else { return false }
        
        if let boolValue = value as? Bool {
            return boolValue
        }
        if let stringValue = value as? String {
            return stringValue.lowercased() == "true" || stringValue == "1"
        }
        
        return false
    }
    
    /// Presents or replaces the root SwiftUI view using a single reusable hosting controller.
    private static func presentOrReplaceRoot(_ view: AnyView, retryCount: Int = 0) {
        setup()
        
        let presentBlock = {
            if let hc = hostingController, hc.presentingViewController != nil {
                // Case 1: Already presented — just replace the rootView.
                hc.rootView = view
                BDChatSDK.isSDKOpen = true
            } else if let hc = hostingController {
                // Case 2: Exists but not currently presented — present it again.
                hc.rootView = view
                hc.modalPresentationStyle = .fullScreen
                if let topVC = topViewController() {
                    topVC.present(hc, animated: true)
                    BDChatSDK.isSDKOpen = true
                }
            } else {
                // Case 3: Create a new hosting controller and present it.
                let hc = UIHostingController(rootView: view)
                hc.modalPresentationStyle = .fullScreen
                hostingController = hc
                if let topVC = topViewController() {
                    topVC.present(hc, animated: true)
                    BDChatSDK.isSDKOpen = true
                }
            }
        }
        
        // Retry logic — wait until a top view controller is available.
        if topViewController() == nil {
            if retryCount < 2 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    presentOrReplaceRoot(view, retryCount: retryCount + 1)
                }
            }
            return
        }
        
        DispatchQueue.main.async {
            presentBlock()
        }
    }
    
    /// Finds the top-most view controller to present from.
    private static func topViewController(base: UIViewController? = nil) -> UIViewController? {
        let windowScene = UIApplication.shared
            .connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }

        let keyWindow = windowScene?
            .windows
            .first(where: { $0.isKeyWindow })

        let root = base ?? keyWindow?.rootViewController

        if let nav = root as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = root as? UITabBarController {
            return topViewController(base: tab.selectedViewController)
        }
        if let presented = root?.presentedViewController {
            return topViewController(base: presented)
        }
        return root
    }
}

// MARK: - SDK Theme Enum

public enum SDKTheme {
    case light
    case dark
    case system
}

