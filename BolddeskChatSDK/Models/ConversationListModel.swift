import Foundation

/// Represents a parsed message preview for conversation list
struct MessagePreview {
    let senderName: String
    let text: String
    let icon: AppIcons?

    init(_ text: String, icon: AppIcons? = nil) {
        self.senderName = ""
        self.text = text
        self.icon = icon
    }
    
    init(senderName: String, text: String, icon: AppIcons? = nil) {
        self.senderName = senderName
        self.text = text
        self.icon = icon
    }
}

struct ConversationListResponse: Codable {
    let isShowStartNewConversation: Bool?
    let conversationList: [Conversation]
    let token: Token?
    let requesterId: String?
    let isRequesterUser: Bool?
}

struct Token: Codable {
    let jid: String?
    let token: String?
    let expiresOn: String?
}

struct Conversation: Codable, Identifiable {

    // MARK: - API fields
    let conversationId: String?
    var lastMessage: LastMessage?
    var assignedAgent: AssignedAgent?
    let status: ConversationStatus?
    var unReadMessage: Bool?
    // MARK: - Identifiable
    // 🔑 ID must be STABLE for NavigationLink to work properly
    var id: String {
        UUID().uuidString.lowercased()
    }

    // MARK: - Coding keys (IMPORTANT)
    enum CodingKeys: String, CodingKey {
        case conversationId
        case lastMessage
        case assignedAgent
        case status
        case unReadMessage
    }
}

struct LastMessage: Codable {
    var message: String?
    var statusId: Int?
    var createdAt: String?
    var agentId: Int?
    var visibilityId: Int?
    var senderName: String?
}

struct AssignedAgent: Codable {
    var id: Int?
    var guid: String?
    var name: String?
    var displayName: String?
    var email: String?
    var shortCode: String?
    var colorCode: String?
    var profileImageUrl: String?
}

struct ConversationListPayload: Encodable {
    var requesterId: String?
    var appToken: String?
    var email: String?
    var userToken: String?
    var jid: String?
    var jidType: Int?
    var sessionId: String?
    var page: Int?
    var perPage: Int?
    var requiresCount: Int?
}

struct ConversationInitiationStatusPayload: Encodable {
    let widgetId: String
    let requesterId: String
    let appToken: String
    let sessionId: String?
    let email: String?
    let userToken: String?
}

struct ConversationInitiationStatusResponse: Codable {
    let isShowStartNewConversation: Bool
}

struct ConversationStatus: Codable {
    let id: Int?
    let statusCategory: StatusCategory?
}

struct StatusCategory: Codable {
    let id: Int?
}
