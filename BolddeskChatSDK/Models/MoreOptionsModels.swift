struct EndChatPayload: Codable {
    let appToken: String
    let conversationId: String
    let requesterId: String
}

struct EndChatResponse: Codable {
    let message: String
}

struct EmailTranscriptPayload: Codable {
    let appToken: String
    let conversationId: String
    let requesterId: String
}

struct EmailTranscriptResponse: Codable {
    let message: String
}

struct DeleteDeviceTokenResponse: Codable {
    let isSuccess: Bool
}

struct DeviceTokenRequest: Encodable {
    let appTypeId: Int?
    let deviceToken: String?
    let appId: String?
    let additionalConfig: AdditionalConfig?
    let visitorId: String?
    let userId: Int?
}

