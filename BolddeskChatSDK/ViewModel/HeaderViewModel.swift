import SwiftUI

@MainActor
class HeaderViewModel: ObservableObject {
    @Published var onlineAgents: [AgentInfo] = []
    @Published var isLoadingAgents: Bool = false
    
    private let chatAPIClient: ChatAPIClient
    
    init(chatAPIClient: ChatAPIClient = ChatAPIClient()) {
        self.chatAPIClient = chatAPIClient
    }
    
    func fetchOnlineAgents(widgetId: String) async {
        isLoadingAgents = true
        
        do {
            let response = try await chatAPIClient.getOnlineAgents()
            self.onlineAgents = response.agents
            isLoadingAgents = false
        } catch {
            isLoadingAgents = false
        }
    }
}
