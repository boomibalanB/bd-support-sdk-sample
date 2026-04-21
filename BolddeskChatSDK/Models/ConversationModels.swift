struct OpenConversationRequest: Encodable {
    let requesterId: String?
    let appToken: String
    let conversationId: String?
    let requestedBy: RequestedBy?
    let requesterType: RequesterType
    let requiresToken: Bool?
    let requesterMessage: RequesterMessage?
    let chatWelcomeMessageIds: [ChatWelcomeMessageId]?
    let suggestionValue: String?
    let stickyButtonValue: String?
    let formMessageId: String?
    let fields: [String: AnyCodable]?
    let userToken: String?
    let confirmationMessage: String?
    let considerSuggestionAsFAQ: Bool?
    var userDeviceToken: UserDeviceToken?
    var sessionId: String?
}

struct RequestedBy: Encodable {
    let name: String
    let email: String
    let phoneNo: String
    let category: String?
    let timeZone: String?
}

struct ConversationInfo: Decodable {
    let guid: String
    let isOpen: Bool
    let token: TokenInfo?
    let requesterType: RequesterType
    let requesterId: String
    let isAssignedToAIAgent: Bool?
    let sessionId: String?
}

struct TokenInfo: Decodable {
    let jid: String
    let token: String
    let expiresOn: String
}

struct VersionInfo: Codable {
    let dateTime: String
    let version: String
}

struct ConversationStatusInfo: Codable {
    struct Status: Codable {
        let id: Int
        let statusCategory: StatusCategory

        struct StatusCategory: Codable {
            // 1 - Open 2 - Closed 3 - Snoozed
            let id: Int
        }
    }

    struct State: Codable {
        // 1 - Active 2 - Spam 3 - Deleted
        let id: Int
    }

    let status: Status
    let state: State
    // Returns true if conversation is not blocked or deleted, else returns false
    let isActive: Bool
    // Returns true if user is not blocked or deleted, else returns false
    let canStartNew: Bool
    let isAssignedToAIAgent: Bool?
    var canReopen: Bool?
    var requestedByUserId: Int?
    var requesterType: Int?
}

struct RequesterMessage: Encodable {
    let guid: String
    let message: String
}

struct ChatWelcomeMessageId: Encodable {
    let id: Int
    let guid: String
}

struct UserDeviceToken: Encodable {
    let appTypeId: Int
    let deviceToken: String
    let appId: String
    let additionalConfig: AdditionalConfig?
}

struct AdditionalConfig: Encodable {
    let deviceName: String?
}

struct AnyCodable: Codable {
    let value: Any?

    init(_ value: Any?) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = nil
        } else if let intVal = try? container.decode(Int.self) {
            value = intVal
        } else if let doubleVal = try? container.decode(Double.self) {
            value = doubleVal
        } else if let boolVal = try? container.decode(Bool.self) {
            value = boolVal
        } else if let strVal = try? container.decode(String.self) {
            value = strVal
        } else if let dictVal = try? container.decode([String: AnyCodable].self) {
            value = dictVal
        } else if let arrayVal = try? container.decode([AnyCodable].self) {
            value = arrayVal
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case nil:
            try container.encodeNil()
        case let intVal as Int:
            try container.encode(intVal)
        case let doubleVal as Double:
            try container.encode(doubleVal)
        case let boolVal as Bool:
            try container.encode(boolVal)
        case let strVal as String:
            try container.encode(strVal)
        case let dictVal as [String: AnyCodable]:
            try container.encode(dictVal)
        case let arrayVal as [AnyCodable]:
            try container.encode(arrayVal)
        default:
            throw EncodingError.invalidValue(value as Any, .init(codingPath: encoder.codingPath, debugDescription: "Unsupported value"))
        }
    }
}
