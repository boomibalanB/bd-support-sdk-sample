struct AgentInfo: Decodable, Equatable, Hashable {
    let id: Int
    let displayName: String
    let colorCode: String
    let shortCode: String
    let profileImageUrl: String?
    let isAIAgent: Bool?
    var isProfileImageLoaded: Bool?
}

struct OnlineAgentsResponse: Decodable {
    let agents: [AgentInfo]
    let count: Int
}
