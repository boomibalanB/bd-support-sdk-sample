import SwiftUI

struct SettingsResponse: Decodable {
    let widgetId: String
    let toJid: String
    let api: String
    let chatServer: String
    let language: String
    let brandName: String
    let brandOptionId: Int
    let notificationAudioURL: String
    let isMultiLanguageEnabled: Bool
    let settings: String
    let generalSettings: GeneralSettings
    let isOffline: Bool
    let isAIEnabled: Bool
}

struct SettingsString: Decodable {
    let chatSettings: ChatSettings
    let widgetSettings: WidgetSettings
    let offlineSettings: OfflineSettings
    let chatPrivacyPolicySettings: ChatPrivacyPolicySettings
    let aiSettings: AISettings
}

struct ChatPrivacyPolicySettings: Decodable {
    let enablePrivacyPolicy: Bool
    let privacyPolicyMessage: String
}

struct Settings: Decodable {
    let chatSettings: ChatSettings
    let widgetSettings: WidgetSettings
    let generalSettings: GeneralSettings
    let chatPrivacyPolicySettings: ChatPrivacyPolicySettings
    let offlineSettings: OfflineSettings
    let aiSettings: AISettings
    let widgetId: String
    let toJid: String
    let api: String
    let chatServer: String
    var isOffline: Bool
    var isAIEnabled: Bool
    let notificationAudioURL: String
    let brandName: String
    let brandOptionId: Int
}

struct ChatSettings: Decodable {
    struct WelcomeMessage: Decodable {
        let id: Int
        let message: String
    }
    let displayOption: ChatValidation
    let welcomeMessages: [WelcomeMessage]
    // Optional to maintain backward compatibility if backend doesn't send suggestions
    let enableSuggestions: Bool?
    let suggestions: [SuggestionOption]?
    let suggestionType: SuggestionType?
    let enableStickyButtons: Bool
    let stickyButtons: [StickyButton]?
    let preChatFormDetails: PreChatFormDetails?
}

struct PreChatFormDetails: Decodable {
    struct PreChatFormField: Decodable {
        let apiName: String
        let fieldId: Int
        let fieldOrder: Int
    }
    let fields: [PreChatFormField]
    let preChatFormMessage: String
}

struct WidgetSettings: Decodable {
    let allowReopen: Bool
    let fileUploadOption: FileUploadOption
    let headerTitle: String
    let headerDescription: String
    let brandLogo: String
    let showBrandLogo: Bool
    let showAgents: Bool
    let colorPalette: [String: String]
    let enableNotificationSound: Bool
    let allowedFileExtensions: [String]
    let featuresSettings: FeaturesSettings?
    let theme: Int
}

struct FeaturesSettings: Decodable {
    let endChat: Bool
    let emailTranscript: Bool
    let enableMultipleConversations: Bool?
    let downloadTranscript: Bool?
}

struct GeneralSettings: Decodable {
    let allowedFileExtensions: String
    let includePoweredBy: Bool
    let uploadFileSize: Int
}

struct OfflineSettings: Decodable {
    let offlineMessage: String
    let headerDescription: String
    let createTicketButtonText: String?
}

struct SuggestionOption: Decodable, Identifiable, Hashable {
    let id: Int
    let text: String
    let value: String
}

struct OfflineStatusResponse: Decodable {
    let isOffline: Bool
    let aiAgentEnabled: Bool
}

struct StickyButton: Decodable, Hashable  {
    let id: Int
    let text: String
    let value: String
}

struct AISettings: Decodable {
    let handoverMode: Int?
    let enableAIAgent: Bool?
    let aiAgentUserId: Int?
}
