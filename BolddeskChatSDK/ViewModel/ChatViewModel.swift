import SwiftUI
import UIKit
internal import SWXMLHash

// MARK: - ChatViewModel (The ViewModel Class)

/// Manages the state and business logic for the Main view.
/// It interacts with the API client and provides observable properties to the view.
@MainActor // Ensures all @Published changes are on the main actor, safe for UI updates
class ChatViewModel: ObservableObject {
    // Indicates the initial settings fetch has failed
    @Published var settingsLoadFailed: Bool = false
    // Observable properties that the View will bind to
    @Published var settings: Settings?
    @Published var isChatConnected = false
    @Published var messages: [Message] = []
    @Published var isXMPPServerConnected = false
    @Published var isConvClosed = false
    // True is conversation has not been deleted or spammed, else false.
    @Published var isActive = true
    // True if user has been deleted or blocked, else false
    @Published var isUserBlocked = false
    @Published var isMsgFooterDisabled = false
    @Published var canShowMsgFooter = false
    @Published var isFetchingArchivedMessages = false
    @Published var scrollTrigger: Int = 0
    @Published var firstVisibleMsg: Message?
    @Published var showSuggestionOptions = false
    @Published var lastMsgAgentInfo: AgentInfo?
    @Published var typingAgentInfo: AgentInfo?
    @Published var thinkingAiAgentInfo: AgentInfo?
    // True is the conversation is currently assigned to an AI agent, else false
    @Published var isConvAssignedToAIAgent: Bool?
    @Published var canShowOfflineForm: Bool = false
    @Published var offlineAgentInfo: AgentInfo?
    @Published var canShowMsgListShimmer: Bool = false
    // Show shimmer in top app bar (avatar + name) while conversation details load
    @Published var isLoadingHeaderInfo: Bool = false
    @Published var canReopen: Bool? = nil
    @Published var canShowPrivacyPolicyNotice = false
    // Composer text binding for footer input
    @Published var messageText: String = ""
    @Published var isLoading: Bool = false
    @Published var preChatFormSessionId = UUID()
    @Published var conversationList: [Conversation] = []
    // True while initial API calls (settings + conversation list) are in progress
    @Published var isInitialLoading: Bool = false
    @Published var isLoadingMoreConversations = false
    @Published var hasMoreConversations = true
    @Published var canShowStartNewConversationButton = true
    @Published var canshowCreateTicketWebView = false
    @Published var conversationId: String = ""
    private var threadId: String = ""
    private var requesterId: String = ""
    private var requesterType: Int = 0
    private var userJID: String = ""
    private var authToken: String = ""
    private var authStep = 0
    private var isChatCleared = false
    var isDisconnected = false
    private var webSocketTask: URLSessionWebSocketTask?
    private let chatAPIClient: ChatAPIClient
    private var chatWelomeMessageIds: [ChatWelcomeMessageId] = []
    private var lastMsgAgentId: Int?
    private var typingIndicatorTimer: Timer? = nil
    private var agentTypingIndicatorTimer: Timer? = nil
    private var aiThinkingTimeoutTimer: Timer? = nil
    // Global token refresh timer – ensures only one scheduled refresh at a time
    private var tokenRefreshTimer: Timer?
    // One-flag silent reconnect controller: if true, next disconnect will be handled silently
    private var allowSilentReconnect: Bool = true
    // Streaming context map for incremental agent messages
    private var streamingContextMap: [String: StreamingContext] = [:]
    private var audioPlayer = AudioPlayer()
    @Published var isNotificationSoundEnabled = false
    var preChatFormFields: [PreChatFormField] = []
    // Network monitor
    private let networkMonitor = NetworkMonitor()
    private var isOnline = true
    var page: Int = 1
    var perPage = 20
    var sessionId: String = ""
    
    /// Initializes the ViewModel with a ChatAPIClient.
    /// - Parameter chatAPIClient: The client to use for API interactions. Defaults to a new instance.
    init(chatAPIClient: ChatAPIClient = ChatAPIClient()) {
        self.chatAPIClient = chatAPIClient
    }
    
    func getConversationListItems(isLoadMore: Bool = false) async {
        guard !isLoadingMoreConversations,
              hasMoreConversations || !isLoadMore else { return }

        if isLoadMore {
            isLoadingMoreConversations = true
        }

        if isLoadMore {
            page += 1
        } else {
            page = 1
            hasMoreConversations = true
        }

        do {
            var sessionId = WidgetStorageManager.getSetting(for: "sessionId", appKey: BDChatSDK.appKey, emailId: BDChatSDK.email) ?? UUID().uuidString.lowercased()
            WidgetStorageManager.updateSetting(key: "sessionId", value: sessionId, appKey: BDChatSDK.appKey, emailId: BDChatSDK.email)
            let userJID = WidgetStorageManager.getSetting(
                for: "userJid",
                appKey: BDChatSDK.appKey,
                emailId: BDChatSDK.email
            )

            let requesterType = WidgetStorageManager.getSetting(
                for: "rType",
                appKey: BDChatSDK.appKey,
                emailId: BDChatSDK.email
            ).flatMap { Int($0) }

            let requesterId = WidgetStorageManager.getSetting(
                for: "rId",
                appKey: BDChatSDK.appKey,
                emailId: BDChatSDK.email
            ) ?? ""

            let appToken = WidgetStorageManager.getAppToken()
            let email = AppConstant.email
            let userToken = BDChatSDK.userToken

            var payload = ConversationListPayload(
                appToken: appToken,
                sessionId: sessionId,
                page: page,
                perPage: perPage
            )

            // --- requester logic (UNCHANGED) ---
            if !requesterId.isEmpty,
               !email.isEmpty,
               let token = userToken,
               !token.isEmpty {

                payload.email = email
                payload.userToken = token
            }
            else if !requesterId.isEmpty, !email.isEmpty {
                payload.email = email
            }
            else if !requesterId.isEmpty {
                payload.requesterId = requesterId
            }
            else if !email.isEmpty {
                payload.email = email
                if let token = userToken, !token.isEmpty {
                    payload.userToken = token
                }
            }

            if let jid = userJID, !jid.isEmpty {
                payload.jid = jid
            }

            if let jidType = requesterType {
                payload.jidType = jidType
            }

            // --- API CALL ---
            let response = try await chatAPIClient.getConversationList(payload: payload)

            // --- Normalize unread state ---
            let updatedList = response.conversationList.map { conversation -> Conversation in
                var updated = conversation
                updated.unReadMessage = conversation.lastMessage?.statusId != 3
                return updated
            }

            // --- Token updates (ONLY on initial load, not on load more) ---
            if !isLoadMore {
                if let jid = response.token?.jid, !jid.isEmpty {
                    WidgetStorageManager.updateSetting(key: "userJid", value: jid,
                                                       appKey: BDChatSDK.appKey, emailId: BDChatSDK.email)
                }

                if let token = response.token?.token, !token.isEmpty {
                    WidgetStorageManager.updateSetting(key: "token", value: token,
                                                       appKey: BDChatSDK.appKey, emailId: BDChatSDK.email)
                }

                if let expiresOn = response.token?.expiresOn,
                   let token = response.token?.token, !token.isEmpty {
                    WidgetStorageManager.updateSetting(key: "tokenExpiry", value: expiresOn,
                                                       appKey: BDChatSDK.appKey, emailId: BDChatSDK.email)
                }

                if let rId = response.requesterId, !rId.isEmpty {
                    WidgetStorageManager.updateSetting(key: "rId", value: rId,
                                                       appKey: BDChatSDK.appKey, emailId: BDChatSDK.email)
                }

                if let userType = (response.isRequesterUser ?? false) ? "1" : "0" {
                    WidgetStorageManager.updateSetting(key: "rType", value: userType,
                                                       appKey: BDChatSDK.appKey, emailId: BDChatSDK.email)
                }
            }

            // --- 🔑 PAGINATION FIX ---
            await MainActor.run {
                if isLoadMore {
                    self.conversationList = mergeLoadMore(
                        existing: self.conversationList,
                        incoming: updatedList
                    )
                } else {
                    self.conversationList = updatedList
                }

                // stop pagination when API returns less than page size
                if updatedList.count < perPage {
                    self.hasMoreConversations = false
                }

                if !updatedList.isEmpty {
                    handlePolicyNoticeClose()
                }
                
                // Only update conversation ID and connect on initial load
                if !isLoadMore {
                    if !updatedList.isEmpty {
                        let cId = updatedList[0].conversationId
                        self.conversationId = cId ?? ""
                        WidgetStorageManager.updateSetting(key: "cId", value: self.conversationId, appKey: BDChatSDK.appKey, emailId: BDChatSDK.email)
                    }

                    if let rId = response.requesterId,
                       !rId.isEmpty {
                        if (connectToServerUsingCache()){
                            isChatConnected = true
                        }
                    }
                }

                if isLoadMore {
                    self.isLoadingMoreConversations = false
                }
                canShowStartNewConversationButton = response.isShowStartNewConversation ?? false
                if conversationList.isEmpty && !isLoadMore {
                    WidgetStorageManager.clearConversationDataInStorage(appKey: BDChatSDK.appKey, emailId: BDChatSDK.email)
                    self.clearChatSession()
                }
            }

        } catch {
            await MainActor.run {
                if isLoadMore {
                    isLoadingMoreConversations = false
                }
                APIErrorHandler.shared.handleAPIError(
                    error,
                    shouldAutoHide: true,
                    onUnauthorized: { [weak self] in
                        self?.canShowStartNewConversationButton = false
                    }
                )
            }
        }
    }
    
    private func mergeLoadMore(
        existing: [Conversation],
        incoming: [Conversation]
    ) -> [Conversation] {

        let incomingIds = Set(incoming.compactMap { $0.conversationId })

        // 1️⃣ Remove existing items that will be replaced
        let filteredExisting = existing.filter {
            guard let id = $0.conversationId else { return true }
            return !incomingIds.contains(id)
        }

        // 2️⃣ Append incoming items
        return filteredExisting + incoming
    }
    
    func parseLastMessage(
        raw: String?,
        senderName: String,
        agentName: String
    ) -> MessagePreview {

        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return MessagePreview(senderName: "", text: "")
        }

        let xml = XMLHash.parse(raw)
        let root = xml["message"]

        // Resolve forwarded / archived message
        let messageNode: XMLIndexer
        if !root["result"]["forwarded"]["message"].all.isEmpty {
            messageNode = root["result"]["forwarded"]["message"]
        } else if !root["forwarded"]["message"].all.isEmpty {
            messageNode = root["forwarded"]["message"]
        } else {
            messageNode = root
        }

        // Sender
        let fromJid = messageNode.element?.attribute(by: "from")?.text ?? ""
        let isAgent = fromJid.starts(with: "useragent_")
        let senderDisplayName = isAgent ? agentName : ResourceManager.localized("you_text")
        let direction = isAgent ? ResourceManager.localized("received_text") : ResourceManager.localized("sent_text")

        // Message type
        let msgTypeStr = messageNode["chatdata"].element?.attribute(by: "type")?.text
        let msgType = msgTypeStr.flatMap(MessageType.init) ?? .text

        // Content extraction
        var content =
            messageNode["body"].element?.text ??
            messageNode["desc"].element?.text ??
            messageNode["x"]["field"]["desc"].element?.text ??
            ""

        if content.isEmpty,
           let fieldValue = messageNode["fieldvalues"]["field"]["value"].element {
            content = fieldValue.attribute(by: "label")?.text
                   ?? fieldValue.text
        }

        let unescaped = content
        let plainText = content.stripHTML()

        // Message-type–specific previews (IMPORTANT)
        switch msgType {

        case .image:
            return MessagePreview(senderName: senderDisplayName, text: "\(ResourceManager.localized("image_text")) \(direction)", icon: AppIcons.jpg)

        case .attachment:
            return MessagePreview(senderName: senderDisplayName, text: "\(ResourceManager.localized("sent_a_file")) \(direction)", icon: AppIcons.attachment1)

        case .audio:
            return MessagePreview(senderName: senderDisplayName, text: "\(ResourceManager.localized("sent_an_audio")) \(direction)")

        case .video:
            return MessagePreview(senderName: senderDisplayName, text: "\(ResourceManager.localized("sent_a_video")) \(direction)", icon: AppIcons.jpg)

        case .form:
            return MessagePreview(
                senderName: senderDisplayName,
                text: plainText.isEmpty
                ? "\(ResourceManager.localized("sent_a_form")) \(direction)"
                : plainText
            )

        case .csat:
            return MessagePreview(senderName: "", text: ResourceManager.localized("rating_survey_sent"))

        case .fieldValues:

            guard let field = messageNode["fieldvalues"]["field"].element else {
                return MessagePreview(senderName: senderDisplayName, text: "")
            }

            let typeString = field.attribute(by: "type")?.text ?? ""
            let fieldType = FieldValueType(rawValue: typeString)

            let valueElement = messageNode["fieldvalues"]["field"]["value"].element

            let label = valueElement?
                .attribute(by: "label")?
                .text
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let text = valueElement?
                .text
                .trimmingCharacters(in: .whitespacesAndNewlines)

            switch fieldType {

            // 1️⃣ Skipped
            case .skipped:
                return MessagePreview(senderName: senderDisplayName, text: ResourceManager.localized("skipped"))

            // 2️⃣ File
            case .file:
                return MessagePreview(senderName: senderDisplayName, text: "\(ResourceManager.localized("sent_a_file")) \(direction)", icon: AppIcons.attachment1)

            // 3️⃣ Date
            case .date:
                if let iso = label ?? text {
                    let formatted = convertISOToDisplayString(iso, type: .date)
                    return MessagePreview(senderName: senderDisplayName, text: formatted)
                }
                return MessagePreview(senderName: senderDisplayName, text: "")

            // 4️⃣ DateTime
            case .datetime:
                if let iso = label ?? text {
                    let formatted = convertISOToDisplayString(iso, type: .dateTime)
                    return MessagePreview(senderName: senderDisplayName, text: formatted)
                }
                return MessagePreview(senderName: senderDisplayName, text: "")

            // 5️⃣ Text Array (comma separated)
            case .textarray:
                if let value = label ?? text {
                    return MessagePreview(senderName: senderDisplayName, text: value)
                }
                return MessagePreview(senderName: senderDisplayName, text: "")

            // 6️⃣ Normal text
            case .text:
                if let value = label ?? text, !value.isEmpty {
                    return MessagePreview(senderName: senderDisplayName, text: value)
                }
                return MessagePreview(senderName: senderDisplayName, text: "")

            // Fallback
            default:
                let fallback = label ?? text ?? ""
                return MessagePreview(senderName: senderDisplayName, text: fallback)
            }

        default:
            // Fallback (text / rich text)
            if unescaped.contains("<img") {
                return MessagePreview(senderName: senderDisplayName, text: "\(ResourceManager.localized("image_text")) \(direction)", icon: AppIcons.jpg)
            }
            guard !plainText.isEmpty else {
                return MessagePreview(senderName: "", text: "")
            }
            return MessagePreview(senderName: senderDisplayName, text: plainText)
        }
    }



    /// Checks if a new conversation can be initiated
    /// - Returns: `true` if new conversation is allowed, `false` otherwise
    func checkConversationInitiationStatus(isFromReOpen: Bool = false) async -> Bool {
        do {
            guard let widgetId = settings?.widgetId else { return false }
            guard !requesterId.isEmpty else { return true }
            guard let appToken = WidgetStorageManager.getAppToken() else { return false }
            let sessionId = WidgetStorageManager.getSetting(for: "sessionId", appKey: BDChatSDK.appKey, emailId: BDChatSDK.email)

            let payload = ConversationInitiationStatusPayload(
                widgetId: widgetId,
                requesterId: requesterId,
                appToken: appToken,
                sessionId: sessionId?.isEmpty == true ? nil : sessionId,
                email: BDChatSDK.email?.isEmpty == true ? nil : BDChatSDK.email,
                userToken: BDChatSDK.userToken?.isEmpty == true ? nil : BDChatSDK.userToken
            )
            
            let response = try await chatAPIClient.getConversationInitiationStatus(payload: payload)
            canShowStartNewConversationButton = response.isShowStartNewConversation
            return canShowStartNewConversationButton
        } catch {
            APIErrorHandler.shared.handleAPIError(
                error,
                shouldAutoHide: true,
                onUnauthorized: { [weak self] in
                    self?.canShowStartNewConversationButton = false
                }
            )
            canShowStartNewConversationButton = false
            return false
        }
    }
    /// Fetches conversation details and updates the conversation list
    /// - Parameter conversationId: The ID of the conversation to fetch
    func fetchConversationDetails(conversationId: String, changeToUnread: Bool = false) async {
        do {
            guard !conversationId.isEmpty else {
                return
            }
            let conversation = try await chatAPIClient.getConversationDetails(conversationId: conversationId)
            
            // Parse the last message preview
            var updatedConversation = conversation
            // Update conversation list - insert at the first index
            if let index = conversationList.firstIndex(where: { $0.conversationId == conversationId }) {
                // If conversation already exists, update it
                conversationList[index] = updatedConversation
            } else {
                updatedConversation.unReadMessage = changeToUnread
                // Insert at the beginning if it's a new conversation
                conversationList.insert(updatedConversation, at: 0)
            }
        } catch {
            // Silently fail - conversation list will be updated on next refresh
            print("Failed to fetch conversation details: \(error)")
        }
    }
    
    func resetUnread(for conversationId: String) {
        // Update conversation list and trigger UI refresh by reassigning the array
        var updatedList = conversationList
        for index in updatedList.indices {
            guard updatedList[index].conversationId == conversationId else {
                continue   // ⏭ skips THIS iteration only
            }

            updatedList[index].unReadMessage = false
        }
        // Reassign to trigger @Published notification
        self.conversationList = updatedList
        
        // 🔑 CRITICAL: Force explicit change notification to guarantee UI updates
        objectWillChange.send()
    }

    /// Opens a conversation by clearing related state and preparing to load its messages
    /// - Parameter conversationId: The ID of the conversation to open
    func openConversation(conversationId: String) async{

        canShowMsgListShimmer = true
        isLoadingHeaderInfo = true
        // Clear messages from previous conversation
        self.messages = []
        self.lastMsgAgentInfo = nil
        self.lastMsgAgentId = nil
        isConvClosed = false
        // Set the new conversation ID and thread
        self.conversationId = conversationId
        self.threadId = conversationId
        resetUnread(for: conversationId)
        // Clear streaming context from previous conversation
        self.streamingContextMap.removeAll()
        // Reset typing/thinking indicators
        self.typingAgentInfo = nil
        self.thinkingAiAgentInfo = nil
        
        // Fetch last message agent details
        Task {
            do {
                let lastMessageAgentInfo = try await self.chatAPIClient.getLastMsgAgentDetails(conversationId: self.conversationId)
                await MainActor.run {
                    self.lastMsgAgentId = lastMessageAgentInfo.id
                    self.lastMsgAgentInfo = lastMessageAgentInfo
                    self.isLoadingHeaderInfo = false
                }
            } catch {
                // silently ignore; previous behavior set these to nil on failure
                await MainActor.run {
                    self.lastMsgAgentId = nil
                    self.lastMsgAgentInfo = nil
                    self.isLoadingHeaderInfo = false
                }
            }
        }
        
        // Load archived messages for this conversation
        handleConversationReconnection(){ canReconnect in
            self.updateFooterVisibility()
        }
        self.isFetchingArchivedMessages = true
        self.getArchivedMessages()
    }
    /// Handles the creation and sending of a user message.
    /// - Parameter text: The message text input by the user.
    func createAndSendMessages(text: String, selectedActionButtonValue: String? = nil, selectedActionButtonType: ActionButtonType? = nil) {
        // Create a new message object with user details
        let deliveryStatus: DeliveryStatus = self.isDisconnected || !self.isOnline ? .notSent : .toSent
        var message = Message(from: userJID, userType: .customer, type: .text, deliveryStatus: deliveryStatus, isReceiptRequested: true, text: text)
        if let selectedActionButtonValue = selectedActionButtonValue {
          message.actionButtonValue = selectedActionButtonValue
        }
        if let selectedActionButttonType = selectedActionButtonType  {
          message.actionButtonType = selectedActionButttonType;
        } else if let _ = selectedActionButtonValue {
          message.actionButtonType = ActionButtonType.none;
        }
        self.manageUserTypingIndicator(shouldClearTimeout: true)
        
        guard let displayOption = settings?.chatSettings.displayOption, let widgetId = settings?.widgetId else { return }
        
        // Close the policy notice once user sends a message.
        if message.userType == .customer, let isPolicyNoticeClosed = WidgetStorageManager.getSetting(for: "isPolicyNoticeClosed", appKey: BDChatSDK.appKey, emailId: BDChatSDK.email), isPolicyNoticeClosed != "true" {
            self.handlePolicyNoticeClose()
        }
        
        let isUserExists = WidgetStorageManager.isUserExistAlready(appKey: BDChatSDK.appKey, emailId: BDChatSDK.email)
        
        // Check if we need to create a conversation with existing requester details (after 'Start new conversation' was clicked)
        if  WidgetStorageManager.isRequesterDetailsAvailableInStorage(appKey: BDChatSDK.appKey, emailId: BDChatSDK.email) && conversationId.isEmpty  {
            self.messages.append(message)
            self.triggerScrollToBottom()
            createNewConversationWithExistingRequesterDetails(message)
            return
        }
        
        // Send message directly for connected connections
        if isUserExists && self.isChatConnected {
            self.messages.append(message)
            self.triggerScrollToBottom()
            sendMessage(message: message)
            return
        }
        
        // Send message directly for non-anonymous, non-email prefilled conversations
        if displayOption != .none && !isOnlyUserFieldsAndPrefilled() {
            self.messages.append(message)
            self.triggerScrollToBottom()
            sendMessage(message: message)
            return
        }
        
        // At this point: new user (!isUserExistAlready()) with anonymous or prechat form pre-filled
        guard areClientAPIUserInfoValid() else { return }

        self.messages.append(message)
        self.triggerScrollToBottom()
        self.createConversationOfConfiguredOrAnonymousUser(message: message)
    }
    
    private func createConversationOfConfiguredOrAnonymousUser(message: Message, confirmationMessage: String? = nil) {
        self.isMsgFooterDisabled = true
        self.showSuggestionOptions = false
        
        let email = escapeHTML(BDChatSDK.email ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let name = escapeHTML(BDChatSDK.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let phoneNo = escapeHTML(BDChatSDK.phoneNo ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        
        let requestedBy = RequestedBy(name: name, email: email, phoneNo: phoneNo, category: resolvedCategoryId(), timeZone: TimeZone.current.identifier)

        Task {
            let requesterMessage = RequesterMessage(guid: message.id, message: message.text ?? "")
            let isConvStarted = await self.createNewConversation(requestedBy: requestedBy, requesterType: BDChatSDK.email != nil ? .user : .visitor, requesterMessage: requesterMessage, chatWelcomeMessageIds: self.chatWelomeMessageIds, selectedActionButtonValue: message.actionButtonValue, confirmationMessage: confirmationMessage, selectedActionButtonType: message.actionButtonType, fields: BDChatSDK.fields)
            if !isConvStarted {
                isMsgFooterDisabled = false
            } else {
                isChatConnected = true
            }
        }
    }
    
    private func sendMessage(message: Message) {
        guard message.deliveryStatus != .notSent else { return }
        self.manageAIMessages()
        if message.actionButtonType == .footer {
            self.sendStickyButtonValueStanza(message: message) { self.handleStanzaSendResult(for: message.id, isSent: $0) }
        } else {
            sendMessageToServer(message: message) { self.handleStanzaSendResult(for: message.id, isSent: $0)}
        }
    }
    
    private func sendMessageToServer(
        message: Message,
        completion: ((Bool) -> Void)? = nil
    ) {
        guard
            let toJid = settings?.toJid,
            let msgText = message.text,
            !self.userJID.isEmpty
        else { return }

        let escaped = escapeHTML(msgText)

        let normalStanza = """
        <message from='\(self.userJID)' id='\(message.id)' to='\(toJid)' type='chat' xmlns='jabber:client'>
            <body>\(escaped)</body>
            <thread>\(self.conversationId)</thread>
            <chatdata xmlns='https://www.bolddesk.com/chat-data'
                      format='none'
                      type='1'
                      requesterId='\(self.requesterId)'/>
            <request xmlns='urn:xmpp:receipts'/>
        </message>
        """

        let carbonStanza = """
        <message from='\(self.userJID)' to='\(self.userJID)' type='chat' xmlns='jabber:client'>
            <forwarded xmlns='urn:xmpp:forward:0'>
                <message from='\(self.userJID)' id='\(message.id)' to='\(toJid)' type='chat' xmlns='jabber:client'>
                    <body>\(escaped)</body>
                    <thread>\(self.conversationId)</thread>
                    <chatdata xmlns='https://www.bolddesk.com/chat-data'
                              format='none'
                              type='1'
                              requesterId='\(self.requesterId)'/>
                    <request xmlns='urn:xmpp:receipts'/>
                </message>
            </forwarded>
        </message>
        """

        // ✅ Send normal FIRST, then carbon
        self.send(carbonStanza, completion: nil)
        self.send(normalStanza, completion: completion)
    }

    
    /// Fetches the widget settings from the API.
    func fetchWidgetSettings() async {
        // reset error state before attempting
        await MainActor.run { self.settingsLoadFailed = false }
        do {
            let widgetSettingsResponse = try await chatAPIClient.getWidgetSettings()
            
            // Apply theme from widget settings (handles string or numeric values)
            let themeString = widgetSettingsResponse.widgetSettings.theme
            if AppConstant.customTheme.isEmpty {
                switch themeString {
                case 1:
                    BDChatSDK.setSDKPreferredTheme(.light)
                case 2:
                    BDChatSDK.setSDKPreferredTheme(.dark)
                default:
                    // Fallback to system if an unknown value is received
                    BDChatSDK.setSDKPreferredTheme(.system)
                }
            }
            
            if WidgetStorageManager.getSetting(for: "isPolicyNoticeClosed", appKey: BDChatSDK.appKey, emailId: BDChatSDK.email) == nil {
                WidgetStorageManager.updateSetting(key: "isPolicyNoticeClosed", value: "false", appKey: BDChatSDK.appKey, emailId: BDChatSDK.email)
            }
            
            self.preChatFormFields = try await chatAPIClient.getPreChatFormDetails()
            if let preChatFormDetails = widgetSettingsResponse.chatSettings.preChatFormDetails {
                sortPreChatFormFields(preChatFormDetails: preChatFormDetails)
            }
            
            self.isNotificationSoundEnabled = widgetSettingsResponse.widgetSettings.enableNotificationSound

            Task {
                await ChatUtils.shared.getAgentAvatarDetailsById(agentId: getSystemUserId())
            }
            
            // Check if we can connect to an existing conversation using storage data.
            if (WidgetStorageManager.isUserExistAlready(appKey: BDChatSDK.appKey, emailId: BDChatSDK.email)) {
                settings = widgetSettingsResponse
            } else {
                settings = widgetSettingsResponse
                
                if WidgetStorageManager.isRequesterDetailsAvailableInStorage(appKey: BDChatSDK.appKey, emailId: BDChatSDK.email) {
                    self.requesterId = WidgetStorageManager.getSetting(for: "rId", appKey: BDChatSDK.appKey, emailId: BDChatSDK.email)!
                    self.requesterType = Int(WidgetStorageManager.getSetting(for: "rType", appKey: BDChatSDK.appKey, emailId: BDChatSDK.email)!)!
                    if (self.isPreChatFormContainsNonUserFields()) {
                        self.preChatFormFields = self.preChatFormFields.filter { !AppConstant.userDetailsFieldApi.contains($0.apiName) }
                    } else {
                        canShowMsgFooter = true
                    }
                    
                } else if isOfflineAndAiNotEnabled() {
                    canShowOfflineForm = true
                    self.offlineAgentInfo = await ChatUtils.shared.getAgentAvatarDetailsById(agentId: getSystemUserId())
                    return
                }
                
                if widgetSettingsResponse.chatSettings.displayOption == .none || isOnlyUserFieldsAndPrefilled() {
                    await MainActor.run { canShowMsgFooter = true }
                    
                    if let enableSuggestions = settings?.chatSettings.enableSuggestions, enableSuggestions == true, let suggestions = settings?.chatSettings.suggestions, !suggestions.isEmpty {
                        self.showSuggestionOptions = true
                    }
                }
                // For anonymous/email-prefilled widget, show the policy notice before the conversation has been started by the user.
                if let isPolicyNoticeClosed = WidgetStorageManager.getSetting(for: "isPolicyNoticeClosed", appKey: BDChatSDK.appKey, emailId: BDChatSDK.email), isPolicyNoticeClosed == "false" {
                    DispatchQueue.main.async { self.canShowPrivacyPolicyNotice = true }
                }
                
                let welcomeMessages = widgetSettingsResponse.chatSettings.welcomeMessages
                if !welcomeMessages.isEmpty {
                    await MainActor.run {
                        for welcomeMsg in welcomeMessages {
                            let message = Message(from: "", userType: .agent, type: .text, deliveryStatus: .undelivered, isReceiptRequested: true, isArchived: false, text: welcomeMsg.message, textFormat: .html)
                            let welcomeMsgId = ChatWelcomeMessageId(id: welcomeMsg.id, guid: message.id)
                            self.chatWelomeMessageIds.append(welcomeMsgId)
                            self.messages.append(message)
                            Task {
                                let systemUserInfo = await ChatUtils.shared.getAgentAvatarDetailsById(agentId: getSystemUserId())
                                if let messageIndex = self.messages.firstIndex(where: { $0.id == message.id }) {
                                    self.messages[messageIndex].agentInfo = systemUserInfo
                                }
                            }
                        }
                    }
                }
            }
            if isOfflineAndAiNotEnabled() {
                canShowOfflineForm = true
                self.offlineAgentInfo = await ChatUtils.shared.getAgentAvatarDetailsById(agentId: getSystemUserId())
                return
            }
        } catch {
            await MainActor.run {
                self.settingsLoadFailed = true
            }
        }
    }
    
    /// Connects to the server using the provided token credentials.
    /// - Parameter token: The `TokenInfo` object containing user credentials and JID.
    private func connectToServerusingCredentials(_ token: TokenInfo) {
        self.userJID = token.jid
        WidgetStorageManager.updateSetting(key: "userJid", value: userJID, appKey: BDChatSDK.appKey, emailId: BDChatSDK.email)
        isChatConnected = true
        Task {
            do {
                try await refreshTokenAndUpdateExpiry(tokenInfo: token)
                if !self.isXMPPServerConnected {
                    await connect(canCheckAuthToken: false) { status in
                        if status == .connected {
                            self.getArchivedMessagesOnSync(queryValue: "", canSendTime: false, direction: "before")
                        }
                    }
                }
                else {
                    self.getArchivedMessages()
                }
            } catch {
                isDisconnected = true
                NotificationManager.shared.show(.serverDisconnected)
            }
        }
    }
    
    /// Connects to the server using cached data for the given widget ID.
    /// - Parameter widgetId: The ID used to retrieve cached chat data.
    /// - Returns: `true` if cache exists and connection is started; otherwise `false`.
    func connectToServerUsingCache() -> Bool {
        // Early return if data needed to connect to existing chat is not present in storage.
        if (!WidgetStorageManager.isUserExistAlready(appKey: BDChatSDK.appKey, emailId: BDChatSDK.email)) {
            return false
        }
        
        userJID = WidgetStorageManager.getSetting(for: "userJid", appKey: BDChatSDK.appKey, emailId: BDChatSDK.email)!
        requesterId = WidgetStorageManager.getSetting(for: "rId", appKey: BDChatSDK.appKey, emailId: BDChatSDK.email)!
        sessionId = WidgetStorageManager.getSetting(for: "sessionId", appKey: BDChatSDK.appKey, emailId: BDChatSDK.email)!
        requesterType = Int(WidgetStorageManager.getSetting(for: "rType", appKey: BDChatSDK.appKey, emailId: BDChatSDK.email)!)!
            self.authToken = WidgetStorageManager.getSetting(for: "token", appKey: BDChatSDK.appKey, emailId: BDChatSDK.email) ?? ""
            Task {
                await self.connect(canSetTimeout: true) { status in
                    if status == .connected {
                        self.isChatConnected = true
                        self.getArchivedMessages()
                    }
                }
            }
        return true
    }
    
    
    /// Checks the current conversation status and updates internal state accordingly.
    /// - Parameter completion: A closure that returns `true` once the status check is complete.
    private func handleConversationReconnection(canReconnectToConv: @escaping (Bool) -> Void) {
        Task {
            do {
                // Fetch the current status of the conversation
                canShowMsgListShimmer = true
                let statusInfo = try await chatAPIClient.getConversationStatusInfo(conversationId: self.conversationId)
                isActive = statusInfo.isActive
                canReopen = statusInfo.canReopen
                if isActive {
                    self.canShowMsgFooter = true
                }
                else{
                    self.canShowMsgFooter = false
                }
                isConvAssignedToAIAgent = statusInfo.isAssignedToAIAgent
                // If the user is not allowed to start a new conversation, mark as blocked
                if !statusInfo.canStartNew {
                    isUserBlocked = true
                    canShowMsgListShimmer = false
                    NotificationManager.shared.show(.accessDenied)
                    return
                }
                
                // For email widgets - render policy notice on reload if it has not yet been closed before
                if let settings = self.settings, settings.chatSettings.displayOption == .email, let isPolicyNoticeClosed = WidgetStorageManager.getSetting(for: "isPolicyNoticeClosed", appKey: BDChatSDK.appKey, emailId: BDChatSDK.email), isPolicyNoticeClosed == "false" {
                    DispatchQueue.main.async { self.canShowPrivacyPolicyNotice = true }
                }
                
                // Determine if the conversation is closed based on status category
                self.isConvClosed = statusInfo.status.statusCategory.id == 2 ? true : false
                canReconnectToConv(true)
            } catch {
                canShowMsgListShimmer = false
                NotificationManager.shared.show(.somethingWentWrong)
            }
        }
    }
    
    /// Creates a conversation with the provided email and widget ID.
    /// - Parameters:
    ///   - email: The email address to use for the conversation.
    func createNewConversation(requiresToken: Bool = true, requestedBy: RequestedBy, requesterId: String? = nil, requesterType: RequesterType? = nil, requesterMessage: RequesterMessage? = nil, chatWelcomeMessageIds: [ChatWelcomeMessageId]? = nil, selectedActionButtonValue: String?, formMessageId: String? = nil, confirmationMessage: String? = nil, selectedActionButtonType: ActionButtonType?, fields: [String: Any]? = nil) async -> Bool {
        guard let widgetId = settings?.widgetId, let rType = requesterType ?? RequesterType(rawValue: self.requesterType) else { return false }
        
        do {
            // Convert fields to typed FieldValue, supporting arrays for multiselect
            let typedFields: [String: AnyCodable]? = fields?.compactMapValues { value in
                switch value {
                case let arr as [String]:
                    return AnyCodable(arr.map { AnyCodable($0) })
                case let arr as [Int]:
                    return AnyCodable(arr.map { AnyCodable($0) })
                case let arr as [Double]:
                    return AnyCodable(arr.map { AnyCodable($0) })
                case let arr as [Bool]:
                    return AnyCodable(arr.map { AnyCodable($0) })
                case let str as String:
                    return AnyCodable(str)
                case let num as NSNumber:
                    return AnyCodable(num)
                case let bool as Bool:
                    return AnyCodable(bool)
                case let dict as [String: Any]:
                    // recursively wrap dictionary
                    let wrappedDict = dict.mapValues { AnyCodable($0) }
                    return AnyCodable(wrappedDict)
                default:
                    return nil // ignore unsupported types
                }
            }
            
            // Construct the request payload using the provided data
            let payload = OpenConversationRequest(
                requesterId: requesterId,
                appToken: ChatWidgetAPIPaths.appToken,
                conversationId: nil,
                requestedBy: requestedBy,
                requesterType: rType,
                requiresToken: requiresToken,
                requesterMessage: requesterMessage,
                chatWelcomeMessageIds: chatWelcomeMessageIds,
                suggestionValue: selectedActionButtonValue != nil && settings?.chatSettings.enableSuggestions == true && settings?.chatSettings.suggestionType == .actionButton ? selectedActionButtonValue : nil,
                stickyButtonValue: (self.settings?.chatSettings.enableStickyButtons == true && selectedActionButtonValue != nil) ? selectedActionButtonValue : nil,
                formMessageId: formMessageId,
                fields: typedFields,
                userToken: BDChatSDK.userToken,
                confirmationMessage: confirmationMessage,
                considerSuggestionAsFAQ: settings?.chatSettings.enableSuggestions == true && settings?.chatSettings.suggestionType == .frequentlyAskedQuestion && selectedActionButtonType == .suggestionFAQ,
                userDeviceToken: (BDChatSDK.fcmToken?.isEmpty == false) ? UserDeviceToken(appTypeId: 2, deviceToken: BDChatSDK.fcmToken ?? "", appId: ChatWidgetAPIPaths.appToken, additionalConfig: AdditionalConfig(deviceName: UIDevice.current.name)) : nil,
                sessionId: sessionId.isEmpty ? UUID().uuidString.lowercased() : sessionId
            )
                                                                        
            let conversationInfo = try await chatAPIClient.createConversation(requestPayload: payload)
            isActive = true
            isConvClosed = false
            isConvAssignedToAIAgent = conversationInfo.isAssignedToAIAgent
            hideNotification()
            self.conversationId = conversationInfo.guid
            self.requesterId = conversationInfo.requesterId
            WidgetStorageManager.updateSetting(key: "cId", value: self.conversationId, appKey: BDChatSDK.appKey, emailId: BDChatSDK.email)
            WidgetStorageManager.updateSetting(key: "rId", value: self.requesterId, appKey: BDChatSDK.appKey, emailId: BDChatSDK.email)
            self.requesterType = conversationInfo.requesterType.rawValue
            WidgetStorageManager.updateSetting(key: "rType", value: String(self.requesterType), appKey: BDChatSDK.appKey, emailId: BDChatSDK.email)
            self.sessionId = conversationInfo.sessionId ?? ""
            WidgetStorageManager.updateSetting(key: "sessionId", value: sessionId, appKey: BDChatSDK.appKey, emailId: BDChatSDK.email)
            if let cMsg = confirmationMessage {
                WidgetStorageManager.updateSetting(key: "cMsg", value: cMsg, appKey: BDChatSDK.appKey, emailId: BDChatSDK.email)
            }
            
            // Fetch conversation details in background without blocking
            Task{
                await checkConversationInitiationStatus()
            }
            if let tokenInfo = conversationInfo.token {
                connectToServerusingCredentials(tokenInfo)
            }
            return true
        } catch {
            canShowMsgFooter = false
            APIErrorHandler.shared.handleAPIError(
                error,
                shouldAutoHide: true,
                onUnauthorized: { [weak self] in
                    self?.canShowStartNewConversationButton = false
                }
            )
            return false
        }
    }
    
    /// Connects to the chat server via WebSocket. Optionally ensures the auth token is valid before connecting.
    /// - Parameter canCheckAuthToken: A Boolean indicating whether token validity should be checked before connection.
    private func connect(canCheckAuthToken: Bool = true, canSetTimeout: Bool = false, connectionStatusCallback: ((ConnectionStatus) -> Void)? = nil) async {
        if canCheckAuthToken, !(await ensureValidAuthToken(canSetTimeout: canSetTimeout)) {
            return
        }
        
        guard let chatServer = URL(string: settings?.chatServer ?? "") else {
            return
        }
        
        connectionStatusCallback?(.connecting)
        
        var request = URLRequest(url: chatServer)
        request.addValue("xmpp", forHTTPHeaderField: "Sec-WebSocket-Protocol")
        
        webSocketTask = URLSession(configuration: .default).webSocketTask(with: request)
        webSocketTask?.resume()
        listenForWebSocketMessages(statusCallback: connectionStatusCallback)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.openStream()
        }
    }
    
    /// Cancels the current WebSocket connection and resets related state.
    private func reset() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        authStep = 0
        isXMPPServerConnected = false
        isDisconnected = true
    }
    
    /// Attempts to reconnect to the chat server by resetting and re-establishing the connection.
    private func reconnect() {
        reset()
        Task {
            await connect()
        }
    }
    
    
    /// Listens for incoming WebSocket messages and processes them accordingly.
    private func listenForWebSocketMessages(statusCallback: ((ConnectionStatus) -> Void)? = nil) {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .failure(let error):
                Task { @MainActor in
                    self?.canShowMsgListShimmer = false
                    if WidgetStorageManager.isUserExistAlready(appKey: BDChatSDK.appKey, emailId: BDChatSDK.email) {
                        guard let self = self else { return }
                        self.isDisconnected = true
                        if self.isUserBlocked == true {
                            NotificationManager.shared.show(.accessDenied)
                        } else if self.isOnline {
                            // First disconnect → attempt a silent reconnect without notifying the user
                            if self.allowSilentReconnect {
                                self.allowSilentReconnect = false
                                self.reconnect()
                            } else {
                                // Subsequent failure after a silent attempt → notify the user
                                self.isDisconnected = true
                                NotificationManager.shared.show(.serverDisconnected)
                            }
                        }
                    }
                }
                statusCallback?(.disconnected)
                let nsError = error as NSError

                print("""
                ❌ ERROR
                Domain : \(nsError.domain)
                Code   : \(nsError.code)
                Message: \(nsError.localizedDescription)
                Info   : \(nsError.userInfo)
                """)
            case .success(let message):
                switch message {
                case .string(let text):
                    Task { @MainActor in
                        self?.processIncomingStanza(text, statusCallback: statusCallback)
                    }
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        Task { @MainActor in
                            self?.processIncomingStanza(text, statusCallback: statusCallback)
                        }
                    }
                @unknown default:
                    break
                }
                Task { @MainActor in
                    // Re-register the listener after each message to maintain a continuous stream.
                    self?.listenForWebSocketMessages(statusCallback: statusCallback)
                }
            }
        }
    }
    
    private func send(_ text: String, completion: ((Bool) -> Void)? = nil) {
        webSocketTask?.send(.string(text)) { [weak self] error in
            if let error = error {
                print("Send error: \(error)")
                if let self = self, self.isChatConnected {
                    DispatchQueue.main.async {
                        if NotificationManager.shared.currentNotification == nil {
                            self.isDisconnected = true
                            NotificationManager.shared.show(.serverDisconnected)
                        }
                    }
                }
                completion?(false)
            } else {
                completion?(true)
            }
        }
    }
    
    private func openStream() {
        guard let domain = settings?.toJid.split(separator: "@").last else {
            return
        }
        let openXML = "<open xmlns='urn:ietf:params:xml:ns:xmpp-framing' to='\(domain)' version='1.0'/>"
        send(openXML)
    }
    
    private func buildPlainAuth(jid: String, password: String) -> String {
        let user = jid.components(separatedBy: "@").first ?? ""
        let authStr = "\u{0}\(user)\u{0}\(password)"
        return Data(authStr.utf8).base64EncodedString()
    }
    
    private func enableCarbons() {
        let presenceStanza = """
                <presence xmlns='jabber:client'>
                    <enable xmlns='urn:xmpp:carbons:2'/>
                    <thread>\(conversationId)</thread>
                </presence>
                """
        send(presenceStanza)
    }
    
    
    /// Processes incoming XMPP XML stanzas and routes them based on their root tag.
    /// - Parameter xmlString: The raw XML string received from the XMPP server.
    private func processIncomingStanza(_ xmlString: String, statusCallback: ((ConnectionStatus) -> Void)? = nil) {
        guard let tag = extractRootTagName(xmlString: xmlString) else { return }
        switch tag {
        case "open":
            // Send authentication credentials only if authentication has not yet started (authStep == 0)
            if authStep == 0 {
                let auth = buildPlainAuth(jid: userJID, password: authToken)
                let authXML = "<auth xmlns='urn:ietf:params:xml:ns:xmpp-sasl' mechanism='PLAIN'>\(auth)</auth>"
                send(authXML)
                authStep += 1
            }
        case "success":
            guard let domain = settings?.toJid.split(separator: "@").last else { return }
            handleAuthSuccess(domain: domain, connectionStatusCallback: statusCallback)
        case "message":
            onMessageEventHandler(xmlString)
        case "iq":
            IQEventHandler(xmlString)
        case "stream:error":
            streamErrorHandler(xmlString)
        case "failure":
            WidgetStorageManager.updateSetting(key: "tokenExpiry", value: "", appKey: BDChatSDK.appKey, emailId: BDChatSDK.email)
            self.reconnect()
        default:
            break
        }
    }
    
    /// Handles successful XMPP authentication including reconnection sync, requester ID updates, and JID reconciliation.
       /// - Parameters:
       ///   - domain: The XMPP domain to connect to
       ///   - connectionStatusCallback: Optional callback to report connection status
       private func handleAuthSuccess(domain: String.SubSequence, connectionStatusCallback: ((ConnectionStatus) -> Void)? = nil) {
           // Send XMPP protocol stanzas to complete authentication
           send("<open xmlns='urn:ietf:params:xml:ns:xmpp-framing' to='\(domain)' version='1.0'/>")
           send("<iq id='_bind_auth_2' type='set' xmlns='jabber:client'><bind xmlns='urn:ietf:params:xml:ns:xmpp-bind'/></iq>")
           send("<iq id='_session_auth_2' type='set' xmlns='jabber:client'><session xmlns='urn:ietf:params:xml:ns:xmpp-session'/></iq>")
           enableCarbons()
           
           Task { @MainActor in
               isXMPPServerConnected = true
               if BDChatSDK.isOpen {
                   updateFooterVisibility()
               }
               
               // Handle reconnection logic
               if isDisconnected {
                   isDisconnected = false
                   
                   // Always show server online notification
                   if NotificationManager.shared.currentNotification == .serverDisconnected ||  NotificationManager.shared.currentNotification == .reconnecting {
                       NotificationManager.shared.show(.serverOnline)
                   }
                   
                   // Reset silent reconnect flag if needed
                   if !allowSilentReconnect {
                       allowSilentReconnect = true
                   }
                   
                   // Perform reconnection sync in background
                   Task.detached(priority: .userInitiated) { [weak self] in
                       guard let self = self else { return }
                       
                       do {
                           // Determine which conversation to check
                           var conversationToCheck = await self.conversationId
                           if conversationToCheck.isEmpty {
                               conversationToCheck = await self.conversationList.first?.conversationId ?? ""
                           }
                           
                           // Fetch conversation status if we have a conversation
                           if !conversationToCheck.isEmpty {
                               let statusInfo = try await self.chatAPIClient.getConversationStatusInfo(conversationId: conversationToCheck)
                               
                               // Update requester ID if available
                               if let requestedByUserId = statusInfo.requestedByUserId {
                                   let newRequesterId = String(requestedByUserId)
                                   await MainActor.run {
                                       self.requesterId = newRequesterId
                                   }
                                   WidgetStorageManager.updateSetting(
                                       key: "rId",
                                       value: newRequesterId,
                                       appKey: BDChatSDK.appKey,
                                       emailId: BDChatSDK.email
                                   )
                                   
                                   // Check if JID local-part matches requester ID
                                   let currentJID = await self.userJID
                                   if currentJID.contains("@") {
                                       let parts = currentJID.split(separator: "@", maxSplits: 1)
                                       let localPart = String(parts[0])
                                       let domainPart = String(parts[1])
                                       
                                       // If JID doesn't match, reconnect with corrected JID
                                       if localPart != newRequesterId {
                                           let updatedJID = "\(newRequesterId)@\(domainPart)"
                                           await MainActor.run {
                                               self.userJID = updatedJID
                                           }
                                           WidgetStorageManager.updateSetting(
                                               key: "userJid",
                                               value: updatedJID,
                                               appKey: BDChatSDK.appKey,
                                               emailId: BDChatSDK.email
                                           )
                                           
                                           // Disconnect and reconnect with correct JID
                                           await MainActor.run {
                                               self.reset()
                                           }
                                           await self.connect(canSetTimeout: true) { status in
                                               if status == .connected {
                                                   Task { @MainActor in
                                                       self.getArchivedMessagesOnSync(
                                                           queryValue: "",
                                                           canSendTime: false,
                                                           direction: "before"
                                                       )
                                                   }
                                               }
                                           }
                                           return // Exit early after reconnect
                                       }
                                   }
                               }
                               
                               // Update requester type if available
                               if let requesterType = statusInfo.requesterType {
                                   await MainActor.run {
                                       self.requesterType = requesterType
                                   }
                                   WidgetStorageManager.updateSetting(
                                       key: "rType",
                                       value: String(requesterType),
                                       appKey: BDChatSDK.appKey,
                                       emailId: BDChatSDK.email
                                   )
                               }
                           }
                       } catch {
                           print("❌ [handleAuthSuccess] Error fetching conversation status: \(error)")
                       }
                       
                       // Sync archived messages based on last message
                       await MainActor.run {
                           let lastMessage = self.messages.last(where: {
                               $0.deliveryStatus != .notSent && $0.type != .chatStates
                           })
                           
                           if let lastMsg = lastMessage {
                               // Use archive ID if available, otherwise use timestamp
                               if let archiveId = lastMsg.archiveId, !archiveId.isEmpty {
                                   self.getArchivedMessagesOnSync(
                                       queryValue: archiveId,
                                       canSendTime: false,
                                       direction: "after"
                                   )
                               } else {
                                   self.getArchivedMessagesOnSync(
                                       queryValue: lastMsg.time,
                                       canSendTime: true
                                   )
                               }
                           } else {
                               // No valid messages, fetch initial archive if list is empty
                               if self.messages.isEmpty {
                                   self.getArchivedMessages()
                               }
                           }
                       }
                   }
               } else {
                   // First connection (not a reconnect)
                   self.canShowMsgListShimmer = false
               }
               
               // Clear disconnect notification if showing
               if NotificationManager.shared.currentNotification == .serverDisconnected {
                   NotificationManager.shared.show(.serverOnline)
               }
               
               // Report connection success
               connectionStatusCallback?(.connected)
           }
       }

    
    private func extractRootTagName(xmlString: String) -> String? {
        guard let start = xmlString.firstIndex(of: "<"),
              let end = xmlString[start...].firstIndex(where: { $0 == " " || $0 == ">" }) else {
            return nil
        }
        
        let tagName = xmlString[xmlString.index(after: start)..<end]
        return String(tagName.replacingOccurrences(of: "/", with: ""))
    }
    
    func extractChatCreatedByUserIdAndToUserId(from msgXML: XMLIndexer) {

        var chatCreatedByUserId: String?
        var chatConversationToId: String?

        let fields = msgXML["fieldvalues"]["field"].all

        for field in fields {
            let fieldVar = field.element?.attribute(by: "var")?.text
            let values = field["value"].all

            let newValue = values.first {
                $0.element?.attribute(by: "label")?.text == "NewValue"
            }?.element?.text

            let oldValue = values.first {
                $0.element?.attribute(by: "label")?.text == "OldValue"
            }?.element?.text

            // requesterId → no comparison
            if fieldVar == "chatCreatedByUserId",
               let newValue,
               !newValue.isEmpty {
                chatCreatedByUserId = newValue
            }

            // userJID source → compare New vs Old
            if fieldVar == "chatConversationToId",
               let newValue,
               !newValue.isEmpty,
               newValue != oldValue {
                chatConversationToId = newValue
            }
        }

        guard
            let finalRequesterId = chatCreatedByUserId,
            let newLocalPart = chatConversationToId,
            !finalRequesterId.isEmpty,
            !newLocalPart.isEmpty
        else {
            return
        }
        
        let updatedUserJID: String
        let existingUserJID = self.userJID   // ✅ no optional binding

        if let atIndex = existingUserJID.firstIndex(of: "@") {
            let domainPart = existingUserJID[atIndex...]   // includes '@'
            updatedUserJID = newLocalPart + domainPart
        } else {
            updatedUserJID = newLocalPart
        }

        // Apply userJID
        self.userJID = updatedUserJID
        WidgetStorageManager.updateSetting(
            key: "userJid",
            value: updatedUserJID,
            appKey: BDChatSDK.appKey,
            emailId: BDChatSDK.email
        )

        // Apply requesterId
        self.requesterId = finalRequesterId
        WidgetStorageManager.updateSetting(
            key: "rId",
            value: finalRequesterId,
            appKey: BDChatSDK.appKey,
            emailId: BDChatSDK.email
        )
        self.requesterType = 1
        WidgetStorageManager.updateSetting(key: "rType", value: String(self.requesterType), appKey: BDChatSDK.appKey, emailId: BDChatSDK.email)
        self.reset()
        if !self.isXMPPServerConnected {
            Task{
                await connect(canCheckAuthToken: false) { status in
                    if status == .connected {
                        self.getArchivedMessagesOnSync(queryValue: "", canSendTime: false, direction: "before")
                    }
                }
            }
        }
    }
    
    /// Handles incoming `<message>` stanzas and updates the chat UI with new messages.
    /// - Parameter xmlString: The incoming message stanza as an XML string.
    func onMessageEventHandler(_ xmlString: String) {
    let xml = XMLHash.config { $0.shouldProcessNamespaces = true }.parse(xmlString)
    let msgXML = xml["message"]
    // Ignore if message is missing or is an error type
    guard msgXML.element != nil, msgXML.element?.attribute(by: "type")?.text != "error" else {
        return
    }
    // Determine if the message is forwarded and extract the actual message
    var msgElement = msgXML
    let hasForwarded = !msgXML["result"]["forwarded"].all.isEmpty || !msgXML["forwarded"].all.isEmpty
    if !msgXML["result"]["forwarded"].all.isEmpty {
        msgElement = msgXML["result"]["forwarded"]["message"]
    } else if !msgXML["forwarded"].all.isEmpty {
        msgElement = msgXML["forwarded"]["message"]
    }
    
    // Handle RTT streaming stanza (only for live, non-forwarded messages without delay)
    let hasDelay = msgElement["delay"].element != nil
    let isResult = !msgXML["result"].all.isEmpty
    if !hasForwarded && !isResult && !hasDelay, let rttTag = msgElement["rtt"].element {
        handleRTTStanza(msgXML: msgXML, msgElement: msgElement, rttTag: rttTag)
        return
    }
    
    // Extract common metadata early
    let threadId = msgElement["thread"].element?.text
    let fromAttr = msgElement.element?.attribute(by: "from")?.text
    let fromBareJid = fromAttr?.split(separator: "/").first.map(String.init)
    
        
    let userType: UserType = {
        let from = fromBareJid
        let localPart = from?.split(separator: "@").first.map(String.init) ?? ""

        let isAgent = localPart.range(
            of: #"^useragent_\d+$"#,
            options: .regularExpression
        ) != nil

        return !isAgent ? .customer : .agent
    }()
    
    let earlyAgentId: Int? = {
        if let agentId = msgElement["chatdata"].element?.attribute(by: "agentId")?.text {
            return Int(agentId)
        }
        if let caid = msgElement["chatdata"].element?.attribute(by: "caid")?.text {
            return Int(caid)
        }
        return nil
    }()
    
    let earlyMsgTime: String = {
        msgXML["result"]["forwarded"]["delay"]
            .element?
            .attribute(by: "stamp")?.text
        ?? isoDateFormatter.string(from: Date())
    }()
    
    // Extract message type early to determine if it should update conversation list
        let msgTypeString: String? = msgElement["chatdata"].element?.attribute(by: "type")?.text
        let msgtypeForListUpdate = msgTypeString.flatMap(MessageType.init)
        let msgType = msgtypeForListUpdate ?? .text
    // Check chat state early (for filtering)
    let chatStateValue: ChatStates? = {
        if msgType == .chatStates,
           let state = msgElement["chatstates"].element?.attribute(by: "state")?.text {
            return ChatStates(rawValue: state)
        }
        return nil
    }()
    let isArchivedMessageForListUpdate = !msgXML["result"].all.isEmpty && !msgElement["archived"].all.isEmpty
    let msgIdForUpdateStatus = msgElement.element?.attribute(by: "id")?.text
    let isForwarded: Bool = msgXML["result"]["forwarded"].element != nil || msgXML["forwarded"].element != nil
//    // If this is for a different conversation, only update conversation list if it's a real message
        extractChatCreatedByUserIdAndToUserId(from: msgXML)
        guard let threadId, threadId == self.conversationId else {
        // Only update conversation list
            if shouldUpdateConversationList(msgType: msgtypeForListUpdate, chatState: chatStateValue, threadId: threadId ?? "", shouldUpdate: true), !isArchivedMessageForListUpdate {
            Task {
                let agentId = getAssigneeFieldId(msgElement)
                sendDeliveredStatus(for: msgIdForUpdateStatus ?? "", cId: threadId)
                await updateConversationList(
                    threadId: threadId ?? "",
                    rawXML: xmlString,
                    createdAt: earlyMsgTime,
                    userType: userType,
                    agentAvatarId: agentId ?? earlyAgentId,
                    msgType: msgType,
                    isUpdateMessage: true,
                    isForwarded: isForwarded
                )
            }
        }
        return
    }
    
    self.threadId = threadId
    
    let requestElements = msgElement["request"].all
    var isReceiptRequested = false
    if requestElements.count > 0 {
        isReceiptRequested = true
    }
    
    let receivedTags = msgElement["received"].all
    if !receivedTags.isEmpty, let receivedTag = receivedTags.first?.element {
        onDeliveryReceiptReceived(receivedTag)
    }
    
    guard
        msgElement.element != nil, // Ensure the XML element exists
        let chatData = msgElement["chatdata"].element, // Extract and validate the <chatdata> element
        let msgId = msgElement.element?.attribute(by: "id")?.text, // Extract the message ID
        let fromAttr = msgElement.element?.attribute(by: "from")?.text, // Extract the "from" attribute
        let from = fromAttr.split(separator: "/").first.map(String.init)
    else {
        // Exit early if any of the above conditions fail
        return
    }
    var msgAgentId: Int?
    if let agentId = chatData.attribute(by: "agentId")?.text, let agentIdValue = Int(agentId) {
        msgAgentId = agentIdValue
    } else if let caid = chatData.attribute(by: "caid")?.text, let caidValue = Int(caid) {
        msgAgentId = caidValue
    }
    // Final body for a streaming message
    if let streamState = chatData.attribute(by: "streamState")?.text, streamState == "1" {
        if let idx = self.messages.firstIndex(where: { $0.id == msgId }) {
            var updated = self.messages[idx]
            let format: String? = chatData.attribute(by: "format")?.text
            let msgFormat = format.flatMap(TextFormat.init) ?? .none
            var text = msgElement["body"].element?.text
            let files = getFilesFromStanza(msgElement, messageText: &text)
            updated.text = text
            updated.textFormat = msgFormat
            updated.files = files
            // Also attach form details (e.g., AI options) for final streamed messages
            var finalMsgType: MessageType = .text
            if let modStr = chatData.attribute(by: "mod")?.text, let mod = ChatFormsModuleEnum(rawValue: modStr) {
                let typeStr = chatData.attribute(by: "type")?.text
                finalMsgType = typeStr.flatMap(MessageType.init) ?? .text
                if finalMsgType != .fieldValues {
                    let isArchived = !xml["message"]["result"].all.isEmpty && !msgElement["archived"].all.isEmpty
                    let formDetails = getFormDetails(from: msgElement, mod: mod, chatData: chatData, isArchived: isArchived)
                    updated.formDetails = formDetails ?? FormDetails(mod: mod)
                }
            }
            updated.isStreaming = false
            self.messages[idx] = updated
            // Always scroll to bottom on final body
            self.triggerScrollToBottom()
            
            // Update conversation list for final AI messages
            let userType: UserType = self.userJID == from ? .customer : .agent

            // Additional effects: clear typing, AI thinking, play notification, update seen
            if updated.userType == .agent {
                if (!updated.isArchived || updated.isUnsyncMessage) && finalMsgType == .text {
                    self.manageAgentTypingIndicator(isComposing: false)
                    if self.isConvAssignedToAIAgent == true && updated.formDetails?.mod == .ai {
                        Task {
                            await updateConversationList(
                                threadId: threadId,
                                rawXML: xmlString,
                                createdAt: earlyMsgTime,
                                userType: userType,
                                agentAvatarId: msgAgentId,
                                msgType: finalMsgType,
                                isForwarded: isForwarded
                            )
                        }
                        self.manageAiAgentThinkingIndicator(isAiAgentThinking: false)
                    }
                    if self.isNotificationSoundEnabled, let audioURL = self.settings?.notificationAudioURL, BDChatSDK.isChatOpen() {
                        self.audioPlayer.playSound(from: audioURL)
                    }
                }
                self.updateDeliverySeenStatus(for: updated)
            }
            return
        }
        // If not found, fall through to normal handling to create the archived message
    }

    if msgType == .form {
        // Toggle message footer visibility during workflow based on 'cansendmessage' value.
        let canSendMessage = chatData.attribute(by: "cansendmessage")?.text
        if let canSendMsg = canSendMessage, !canSendMsg.isEmpty {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if canSendMsg == "true" && !self.isUserBlocked && !self.isConvClosed && self.isActive {
                    self.canShowMsgFooter = true
                } else if canSendMsg == "false" {
                    self.canShowMsgFooter = false
                }
            }
            return
        }
    }
    
    let isArchived = !msgXML["result"].all.isEmpty && !msgElement["archived"].all.isEmpty
    
    var isUnsyncMessage: Bool = false
    var deliveryStatus: DeliveryStatus?
    
    // For archived messages, the delivery status will be received in the "message_status" tag.
    if isArchived {
        // Check if the archived message is an unsync message.
        let resultElement = msgXML["result"].element
        if resultElement?.attribute(by: "queryid")?.text == "unsync-message" {
            isUnsyncMessage = true
        }
        // For archived messages, the delivery status will be received in the "message_status" tag.
        let statusTag = msgXML["result"]["forwarded"]["message_status"].element
        
        if statusTag != nil, let deliveryStatusText = statusTag?.attribute(by: "status")?.text, let deliveryStatusValue = DeliveryStatus(rawValue: deliveryStatusText) {
            deliveryStatus = userType == .customer ? .sent : deliveryStatusValue
        }
    }
    
    // Messages deleted by agent contain retract tag
    if !msgElement["retract"].all.isEmpty, let retractTag = msgElement["retract"].element {
        guard !isArchived else { return } // Return archived deleted messages
        if let retractedMsgId = retractTag.attribute(by: "id")?.text,
           let retractedMsgIndex = self.messages.firstIndex(where: { $0.id == retractedMsgId }) {
            self.messages[retractedMsgIndex].text = msgElement["body"].element?.text
            self.messages[retractedMsgIndex].isRetracted = true
            return
        }
    }
    
    // Messages edited by agent will have the replace tag
    let isReplaced = !msgElement["replace"].all.isEmpty
    if isReplaced {
        if let replacedMessageIndex = self.messages.firstIndex(where: { $0.id == msgId }) {
            let format: String? = chatData.attribute(by: "format")?.text
            let msgFormat = format.flatMap(TextFormat.init) ?? .none
            self.messages[replacedMessageIndex].textFormat = msgFormat
            var text = msgElement["body"].element?.text
            let files = getFilesFromStanza(msgElement, messageText: &text)
            self.messages[replacedMessageIndex].files = files
            self.messages[replacedMessageIndex].text = text
            self.messages[replacedMessageIndex].isReplaced = true
            return
        }
    }
    
    // Extract timestamp from delay or use current time with fractional seconds
    let delayData = msgXML["result"]["forwarded"]["delay"]
    
    // Return offline storage messages.
    if msgElement["delay"].element != nil, !isArchived { return }
    
    let msgTime = delayData.element?.attribute(by: "stamp")?.text ?? isoDateFormatter.string(from: Date())
    
    // Convert UTC timestamp to local time label (e.g., "3:45 PM")
    let timeLabel: String = {
        let date = convertISOStringToDate(from: msgTime) ?? Date()
        return getChatMessageTime(for: date)
    }()
    
    var archiveId: String?
    if let archivedData = msgElement["archived"].all.first {
        archiveId = archivedData.element?.attribute(by: "id")?.text
    }
    
    var text = msgElement["body"].element?.text
    let format: String? = chatData.attribute(by: "format")?.text
    let msgFormat = format.flatMap(TextFormat.init) ?? .none
    let files = getFilesFromStanza(msgElement, messageText: &text)
    
    var chatStates: ChatStates? = nil
    if msgType == .chatStates {
        let state = msgElement["chatstates"].element?.attribute(by: "state")?.text ?? ""
        chatStates = ChatStates(rawValue: state) ?? nil
        deliveryStatus = userType == .customer ? .sent : .delivered
    }
    // Check if a message with the same ID already exists in the messages array to prevent duplicate rendering.
    if let index = self.messages.firstIndex(where: { $0.id == msgId }) {
        // Update delivery status for first customer message in anonymous chat.
        if isArchived, self.messages[index].deliveryStatus != deliveryStatus, self.messages[index].userType == .customer {
            self.messages[index].deliveryStatus = deliveryStatus ?? .sent
        }
        // Send the seen receipt for welcomeMessages, FormMessage and RequesterMessage.
        if (self.messages[index].isReceiptRequested) {
            self.messages[index].deliveryStatus = deliveryStatus ?? .sent
            if self.messages[index].userType == .agent {
                self.updateDeliverySeenStatus(for: self.messages[index]);
            }
        }
        // Update live chat last messaege update
        if isForwarded && !isArchived && shouldUpdateConversationList(msgType: msgType, chatState: chatStates) {
            Task{
                await updateConversationList(
                    threadId: threadId,
                    rawXML: xmlString,
                    createdAt: msgTime,
                    userType: userType,
                    agentAvatarId: msgAgentId,
                    msgType: msgType,
                    isForwarded: isForwarded
                )
            }
        }
        return
    }
    
    let mod = ChatFormsModuleEnum(rawValue: chatData.attribute(by: "mod")?.text ?? "")
    var formDetails: FormDetails? = nil
    var fieldValueDetails: FieldValueDetails? = nil
    
    if let modValue = mod {
        if msgType != .fieldValues {
            formDetails =  getFormDetails(from: msgElement, mod: modValue, chatData: chatData, isArchived: isArchived && !isUnsyncMessage)
            if formDetails == nil { formDetails = FormDetails(mod: modValue) }
        } else if msgType == .fieldValues {
            fieldValueDetails = getFieldValue(from: msgElement, chatData: chatData, mod: modValue)
            if let fieldValue = fieldValueDetails {
                text = convertFieldValuesToText(fieldValueDetails: fieldValue)
                DispatchQueue.main.async { [weak self] in
                    if let index = self?.messages.firstIndex(where: { $0.id == fieldValue.formMsgId }) {
                        self?.messages[index].formDetails?.isSubmitted = true
                    }
                }
            }
        }
    }
    
    let message = Message(id: msgId, from: from, userType: userType, type: msgType, deliveryStatus: deliveryStatus ?? .toSent, time: msgTime, timeLabel: timeLabel, isReceiptRequested: isReceiptRequested, isArchived: isArchived, text: text, textFormat: msgFormat, files: files, chatStates: chatStates, isReplaced: isReplaced, formDetails: formDetails, fieldValueDetails: fieldValueDetails, archiveId: archiveId, isUnsyncMessage: isUnsyncMessage)
    if message.type == .chatStates && message.chatStates != nil {
        handleChatStateMessages(message: message, agentId: msgAgentId)
        // Don't add transient chat states to message list or update conversation list
        if message.chatStates == .thinking || message.chatStates == .composing || message.chatStates == .typingStopped { 
            return 
        }
    }
    
    if message.type == .assigneeFieldUpdate {
        let display = chatData.attribute(by: "display")?.text
        if display != "1" {
            self.handleAssigneeFieldUpdateNotification(msgElement, message)
        }
    }
    
    if message.userType == .agent, let agentAvatarId = msgAgentId {
        if !message.isArchived && message.type == .text && agentAvatarId != AppConstant.systemUserId {
            self.lastMsgAgentId = msgAgentId
        }
        Task {
            let agentAvatar = await ChatUtils.shared.getAgentAvatarDetailsById(agentId: agentAvatarId)
            if agentAvatar.id == self.lastMsgAgentId {
                DispatchQueue.main.async { self.lastMsgAgentInfo = agentAvatar }
            }
            await MainActor.run {
                if let messageIndex = self.messages.firstIndex(where: { $0.id == msgId }) {
                    self.messages[messageIndex].agentInfo = agentAvatar
                }
            }
        }
    }
    
    // Update conversation list for new live messages (not archived), but only for actual messages
    // this method used for when chat view is open update other list items last message
    if !isArchived && shouldUpdateConversationList(msgType: message.type, chatState: message.chatStates) {
        Task{
            var newAssignedAgentId: Int? = nil
            if message.type == .assigneeFieldUpdate {
                newAssignedAgentId = getAssigneeFieldId(msgElement)
            }
            sendDeliveredStatus(for: msgId ?? "", cId: threadId)
            await updateConversationList(
                threadId: threadId,
                rawXML: xmlString,
                createdAt: msgTime,
                userType: userType,
                agentAvatarId: newAssignedAgentId ?? msgAgentId,
                msgType: message.type,
                isForwarded: isForwarded
            )
        }
    }
    
    if message.isArchived && !message.isUnsyncMessage  {
        self.messages.insert(message, at: 0)
    } else {
        manageAIMessages()
        self.messages.append(message)
        self.triggerScrollToBottom()
    }
    
    if message.userType == .agent {
        // Handle live agent messages
        if (!message.isArchived || message.isUnsyncMessage) && (message.type == .text || message.type == .attachment) {
            // Clear agent typing indicator
            self.manageAgentTypingIndicator(isComposing: false)
            // Clear AI agent thinking indicator if an AI response message is received
            if isConvAssignedToAIAgent == true && message.formDetails?.mod == .ai { 
                self.manageAiAgentThinkingIndicator(isAiAgentThinking: false)
            }
            if self.isNotificationSoundEnabled, let audioURL = settings?.notificationAudioURL { 
                audioPlayer.playSound(from: audioURL) 
            }
        }
        self.updateDeliverySeenStatus(for: message)
    }
}
    
    
    /// Determines if a message should trigger a conversation list update
    /// - Parameters:
    ///   - msgType: The type of message
    ///   - chatState: The chat state (if applicable)
    /// - Returns: true if the message should update the conversation list
    private func shouldUpdateConversationList(msgType: MessageType?, chatState: ChatStates?, threadId: String = "", shouldUpdate: Bool = false) -> Bool {
        // Exclude transient chat states (typing indicators, thinking indicators)
        if let type = msgType, type == .chatStates {
            if let state = chatState {
                // Only update for permanent state changes, not transient ones
                switch state {
                case .composing, .thinking, .typingStopped:
                    return false
                case .open, .hold, .closed, .deleted, .spam, .restored:
                    Task{
                        await checkConversationInitiationStatus()
                    }
                    return false
                case .startMessaging:
                    Task{
                        if !conversationList.contains(where: { $0.conversationId == threadId }) {
                            await fetchConversationDetails(conversationId: threadId)
                        }
                    }
                    return false
                case .clearChatSession:
                    if shouldUpdate {
                        clearChatSession()
                    }
                    return false
                @unknown default:
                    return false
                }
            }
            return false
        }
        
        // Exclude internal state messages that shouldn't show in conversation list
        switch msgType {
        case .deliveryReceipt, .readReceipt, .csat:
            return false
        case .fieldUpdate:
            return false
        case .assigneeFieldUpdate:
            return true
        case .text, .image, .attachment, .audio, .video, .contact, .location,
             .whatsappTemplate, .visitedPages, .form, .fieldValues:
            return true
        @unknown default:
            return false
        }
    }
    
    func updateConversationList(
        threadId: String,
        rawXML: String,
        createdAt: String,
        userType: UserType,
        agentAvatarId: Int? = nil,
        msgType: MessageType,
        isUpdateMessage: Bool = false,
        isForwarded: Bool = false
    ) async {

        guard let index = conversationList.firstIndex(where: {
            $0.conversationId == threadId
        }) else {
            if self.conversationId != threadId {
                await fetchConversationDetails(conversationId: threadId, changeToUnread: !(msgType == .assigneeFieldUpdate))
            }
            return
        }


        // ✅ Async work FIRST (outside MainActor)
        var agentDetails: AgentInfo?

        if userType == .agent, let agentId = agentAvatarId {
            agentDetails = await ChatUtils.shared
                .getAgentAvatarDetailsById(agentId: agentId)
        }

        // ✅ UI updates on MainActor only
        await MainActor.run {
            var updatedConversation = conversationList[index]

            // 🔑 KEY FIX: Initialize nil optionals before updating (otherwise updates fail silently)
            if updatedConversation.lastMessage == nil {
                updatedConversation.lastMessage = LastMessage()
            }

            if let agent = agentDetails, msgType == .assigneeFieldUpdate {
                if updatedConversation.assignedAgent == nil {
                    updatedConversation.assignedAgent = AssignedAgent()
                }
                
                updatedConversation.assignedAgent?.displayName = agent.displayName
                updatedConversation.assignedAgent?.shortCode = agent.shortCode
                updatedConversation.assignedAgent?.colorCode = agent.colorCode
                updatedConversation.assignedAgent?.profileImageUrl = agent.profileImageUrl
                updatedConversation.assignedAgent?.id = agent.id
            }
            else{
                updatedConversation.lastMessage?.message = rawXML
                updatedConversation.lastMessage?.createdAt = createdAt
                updatedConversation.lastMessage?.senderName = userType == .customer ? "You" : agentDetails?.displayName ?? ""
                if isUpdateMessage && !isForwarded && userType != .customer {
                    updatedConversation.unReadMessage = true
                }
            }

            // Atomic update - single assignment triggers @Published properly
            var newList = conversationList
            newList.remove(at: index)
            newList.insert(updatedConversation, at: 0)
            conversationList = newList
            
            // 🔑 CRITICAL: Force explicit change notification to guarantee UI updates
            objectWillChange.send()
        }
    }

    
    /// Extracts file attachments from XML message stanza and processes inline image references.
    /// - Parameters:
    ///   - msgElement: XML element containing the message data
    ///   - messageText: Message text that may contain cid: references to be replaced with URLs
    /// - Returns: Array of File objects representing attachments
    private func getFilesFromStanza(_ msgElement: XMLIndexer, messageText: inout String?) -> [File] {
        var attachments: [File] = []
        
        let attachmentsElement = msgElement["attachments"]
        // Process attachments format
        if !attachmentsElement.all.isEmpty {
            for fileElement in attachmentsElement["file"].all {
                let disposition = fileElement.element?.attribute(by: "disposition")?.text ?? ""
                let mediaType = fileElement["media-type"].element?.text ?? ""
                let name = fileElement["name"].element?.text ?? ""
                let size = fileElement["size"].element?.text ?? ""
                
                var url = ""
                var cid: String?
                
                cid = fileElement["source-id"].element?.text.replacingOccurrences(of: "cid:", with: "") ?? ""
                let target = fileElement["target"].element?.text ?? ""
                if !target.isEmpty {
                    url = disposition == "inline"
                    ? "\(self.settings!.api)attachment/inline/\(target)"
                    : "\(self.settings!.api)attachment/download/\(target)"
                }
                
                let file = File(url: url, size: size, name: name, mediaType: mediaType, disposition: disposition, rawFile: nil, cID: cid)
                attachments.append(file)
            }
        }
        
        // Replace cid: references in HTML with actual URLs
        // Only include files that actually have a non-empty CID
        let cidMap = Dictionary(uniqueKeysWithValues: attachments.compactMap { file in
            if let cid = file.cID, !cid.isEmpty {
                return (cid, file)
            }
            return nil
        })
        
        if var text = messageText {
            let regexPattern = "<img[^>]+src=['\"]cid:([^'\"]+)['\"][^>]*>"
            if let regex = try? NSRegularExpression(pattern: regexPattern) {
                let nsText = text as NSString
                let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
                
                for match in matches.reversed() {
                    if let cidRange = Range(match.range(at: 1), in: text) {
                        let cid = String(text[cidRange])
                        if let file = cidMap[cid] {
                            text = text.replacingOccurrences(of: "cid:\(cid)", with: file.url)
                        }
                    }
                }
                messageText = text
            }
        }
        
        return attachments
    }
    
    private func getFormDetails(from msgElement: XMLIndexer, mod: ChatFormsModuleEnum, chatData: XMLElement, isArchived: Bool) -> FormDetails? {
        // Parse options from XML
        var options: [DropdownItemModel]? = nil
        let optionElements = msgElement["x"]["field"]["option"].all
        if !optionElements.isEmpty {
            options = optionElements.compactMap { optionElement in
                guard let label = optionElement.element?.attribute(by: "label")?.text,
                      let value = optionElement["value"].element?.text else {
                    return nil
                }
                return DropdownItemModel(id: value, displayName: label)
            }
        }
        
        var field: XMLElement?
        if let fieldElement = msgElement["x"]["field"].element {
            field = fieldElement
        }
        
        if mod == .ai {
            return FormDetails(
                apiName: field?.attribute(by: "var")?.text ?? "",
                mod: mod,
                isSubmitted: self.messages.contains { $0.type != .chatStates && $0.type != .csat } ? isArchived : false,
                options: options,
                fieldValueType: field?.attribute(by: "type")?.text ?? ""
            )
        }
        
        guard let fieldTag = field else { return nil }
        
        
        var validate: FormDetails.Validate?
        if msgElement["x"]["field"]["validate"].element != nil {
            validate = FormDetails.Validate(
                min: msgElement["x"]["field"]["validate"]["range"].element?.attribute(by: "min")?.text ?? nil,
                max: msgElement["x"]["field"]["validate"]["range"].element?.attribute(by: "max")?.text ?? nil,
                regex: msgElement["x"]["field"]["validate"]["regex"].element?.text ?? nil
            )
        }
        
        // Determine block type
        let typeRaw = msgElement["x"]["field"]["chatfielddata"].element?.attribute(by: "type")?.text ?? ""
        let type = ChatWorkflowBlockType(rawValue: typeRaw)
        
        // MARK: - Scheduler Handling (Simple & Direct)
        var scheduler: FormDetails.Scheduler? = nil
        
        if type == .scheduler {
            let schedulerTag = msgElement["x"]["field"]["chatscheduler"].element
            let buttonText = schedulerTag?.attribute(by: "btntxt")?.text ?? "Schedule Now"
            let url = schedulerTag?.attribute(by: "url")?.text ?? ""
            
            // Build query params: embed_type=Inline & embed_domain + payload data
            var params: [String: String] = [
                "embed_type": "Inline",
                "embed_domain": ChatWidgetAPIPaths.base
            ]
            
            // Parse <payload> JSON if exists
            if let payloadText = msgElement["x"]["payload"].element?.text.trimmingCharacters(in: .whitespacesAndNewlines),
               !payloadText.isEmpty,
               let data = payloadText.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                
                for (key, value) in json {
                    params[key.lowercased()] = String(describing: value)
                }
            }
            
            // Build query string
            let query = params
                .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
                .joined(separator: "&")
            
            // Final URL
            let finalUrl = url.isEmpty ? "" : (url + (url.contains("?") ? "&" : "?") + query)
            
            scheduler = FormDetails.Scheduler(buttonText: buttonText, calendlyUrl: finalUrl)
        }
        
        var allowedFileTypes: [String] = []

        if type == .getFileInput {
            let fileInputTag = msgElement["x"]["field"]["chatfielddata"].element

            allowedFileTypes =
                    fileInputTag?
                    .attribute(by: "allowedfiletype")?
                    .text
                    .split(separator: ",")
                    .map {
                        $0
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            .lowercased()
                    } ?? []
        }

        
        let isFormSubmitted = type == .scheduler ? self.messages.contains { $0.type != .chatStates && $0.type != .csat } ? isArchived : false : self.messages.contains { $0.type == .fieldValues && $0.fieldValueDetails?.formMsgId == msgElement.element?.attribute(by: "id")?.text }

        return FormDetails(
            apiName: fieldTag.attribute(by: "var")?.text ?? "",
            isRequired: !msgElement["x"]["field"]["required"].all.isEmpty,
            description: msgElement["x"]["field"]["desc"].element?.text ?? "",
            type: ChatWorkflowBlockType(rawValue: msgElement["x"]["field"]["chatfielddata"].element?.attribute(by: "type")?.text ?? ""),
            subType: ChatWorkflowBlockSubType(rawValue: msgElement["x"]["field"]["chatfielddata"].element?.attribute(by: "sub_type")?.text ?? ""),
            placeholder: msgElement["x"]["field"]["chatfielddata"].element?.attribute(by: "placeholder")?.text ?? "",
            ruleId: chatData.attribute(by: "ruleId")?.text ?? "",
            workflowId: chatData.attribute(by: "workflowId")?.text ?? "",
            mod: mod,
            errorMessage: msgElement["error"]["text"].element?.text ?? "",
            isMasked: chatData.attribute(by: "masked")?.text == "true" ? true : false,
            isSubmitted: isFormSubmitted,
            validate: validate,
            options: options,
            apiUrl: ChatWidgetAPIPaths.getDropdownOptions(conversationId: conversationId, apiName: fieldTag.attribute(by: "var")?.text ?? ""),
            scheduler: scheduler,
            allowedFileTypes: allowedFileTypes
        )
    }
    
    private func getFieldValue(from msgElement: XMLIndexer, chatData: XMLElement, mod: ChatFormsModuleEnum) -> FieldValueDetails? {
        guard let fieldValueTag = msgElement["fieldvalues"].element,
              let fieldTag = msgElement["fieldvalues"]["field"].element else { return nil }
        
        let fieldType = fieldTag.attribute(by: "type")?.text ?? ""
        let value = msgElement["fieldvalues"]["field"]["value"].element?.text ?? ""
        
        // Extract picker values if type matches picker input types
        var pickerValues: [DropdownItemModel]? = nil
        // Look for all value elements that might have labels
        let valueElements = msgElement["fieldvalues"]["field"]["value"].all
        
        if !valueElements.isEmpty {
            pickerValues = valueElements.compactMap { valueElem in
                if let element = valueElem.element {
                    let id = element.text
                    let label = element.attribute(by: "label")?.text ?? id
                    return DropdownItemModel(id: id, displayName: label)
                }
                return nil
            }
        }
        
        return FieldValueDetails(
            apiName: msgElement["fieldvalues"]["field"].element?.attribute(by: "var")?.text ?? "",
            fieldValueType: fieldType,
            ruleId: chatData.attribute(by: "ruleId")?.text ?? "",
            id: chatData.attribute(by: "workflowId")?.text ?? "",
            value: value,
            isMasked: fieldTag.attribute(by: "masked")?.text == "true" ? true : false,
            formMsgId: fieldValueTag.attribute(by: "formMsgId")?.text ?? "",
            mod: mod,
            pickerValue: (fieldType == "date" || fieldType == "datetime") ? [] : pickerValues
        )
    }
    
    /// Handles a delivery receipt update by updating the message's delivery status if needed.
    /// - Parameter receivedTag: XML element containing the message ID and new delivery status.
    private func onDeliveryReceiptReceived(_ receivedTag: XMLElement) {
        guard
            let id = receivedTag.attribute(by: "id")?.text,
            let statusText = receivedTag.attribute(by: "status")?.text,
            let status = DeliveryStatus(rawValue: statusText),
            ![.delivered, .seen].contains(status),
            let index = messages.firstIndex(where: { $0.id == id })
        else {
            return
        }
        
        DispatchQueue.main.async {
            self.messages[index].deliveryStatus = status
        }
    }
    
    /// Updates the delivery status of a live message to `delivered` or `seen`.
    /// - Parameter message: The message to update.
    private func updateDeliverySeenStatus(for message: Message) {
        guard let index = messages.firstIndex(where: { $0.id == message.id }),
              !messages[index].isArchived,
              messages[index].isReceiptRequested else { return }
        
        var updatedMessage = messages[index]
        
        let updateMessage = {
            DispatchQueue.main.async {
                self.messages[index] = updatedMessage
            }
        }
        
        if ![.delivered, .seen].contains(updatedMessage.deliveryStatus) {
            sendDeliveredStatus(for: updatedMessage.id) { isDeliveredStatusStanzaSent in
                guard isDeliveredStatusStanzaSent else { return }
                updatedMessage.deliveryStatus = .delivered
                
                if BDChatSDK.isOpen {
                    self.sendSeenStatus(for: updatedMessage.id) { isSeenStatusStanzaSent in
                        if isSeenStatusStanzaSent {
                            updatedMessage.deliveryStatus = .seen
                        }
                        updateMessage()
                    }
                } else {
                    updateMessage()
                }
            }
        } else if updatedMessage.deliveryStatus != .seen && BDChatSDK.isOpen {
            sendSeenStatus(for: updatedMessage.id) { success in
                if success {
                    updatedMessage.deliveryStatus = .seen
                }
                updateMessage()
            }
        }
    }
    
    /// This function is used to send the delivered receipt to the server acknowledging the receipt of message.
    /// - Parameter ids - A string containing the message IDs.
    /// - Parameter completion - An optional closure that returns `true` if the message was sent successfully, `false` otherwise.
    private func sendDeliveredStatus(for ids: String, completion: ((Bool) -> Void)? = nil, cId: String? = nil) {
        let messageId = UUID().uuidString.lowercased()
        let xml = """
        <message id="\(messageId)" to="\(settings!.toJid)" from="\(userJID)" type="chat">
            <received xmlns="urn:xmpp:receipts" ids="\(ids)" status="\(DeliveryStatus.delivered.rawValue)" caid="\(ChatAppID.chatWidget.rawValue)" />
            <thread>\(cId ?? conversationId)</thread>
        </message>
        """
        send(xml, completion: completion)
    }
    
    /// This function is used to send the 'seen' read receipt to the server.
    /// - Parameter ids - A string containing the message IDs.
    /// - Parameter completion - An optional closure that returns `true` if the message was sent successfully, `false` otherwise.
    private func sendSeenStatus(for ids: String, completion: ((Bool) -> Void)? = nil) {
        let messageId = UUID().uuidString.lowercased()
        let xml = """
        <message id="\(messageId)" to="\(settings!.toJid)" from="\(userJID)" type="chat">
            <received xmlns="urn:xmpp:receipts" ids="\(ids)" status="\(DeliveryStatus.seen.rawValue)" caid="\(ChatAppID.chatWidget.rawValue)" />
            <thread>\(conversationId)</thread>
        </message>
        """
        send(xml, completion: completion)
    }
    
    /// Sends delivery status for all undelivered agent messages and updates their status.
    private func bulkSendDeliveryStatus() {
        let undeliveredMessages = messages.filter {
            $0.userType == .agent &&
            $0.isReceiptRequested &&
            ![.delivered, .seen].contains($0.deliveryStatus)
        }
        
        guard !undeliveredMessages.isEmpty else { return }
        
        let ids = undeliveredMessages
            .map(\.id)
            .filter { !$0.isEmpty }
            .joined(separator: ",")
        
        guard !ids.isEmpty else { return }
        
        sendDeliveredStatus(for: ids)
        
        // Update delivery status on the main thread
        DispatchQueue.main.async { [self] in
            for i in 0..<messages.count {
                if undeliveredMessages.contains(where: { $0.id == messages[i].id }) {
                    messages[i].deliveryStatus = .delivered
                }
            }
        }
    }
    
    /// Sends seen status for all unseen agent messages and updates their status.
    func updateSeenStatus() {
        let unseenAgentMessages = messages.filter {
            $0.userType == .agent &&
            $0.isReceiptRequested &&
            $0.deliveryStatus != .seen
        }
        
        guard !unseenAgentMessages.isEmpty else { return }
        
        let ids = unseenAgentMessages
            .map(\.id)
            .filter { !$0.isEmpty }
            .joined(separator: ",")
        
        guard !ids.isEmpty else { return }
        
        sendSeenStatus(for: ids) { isStanzaSent in
            guard isStanzaSent else { return }
            // Update seen status on the main thread
            DispatchQueue.main.async { [self] in
                for i in 0..<messages.count {
                    if unseenAgentMessages.contains(where: { $0.id == messages[i].id }) {
                        messages[i].deliveryStatus = .seen
                    }
                }
            }
        }
    }
    
    /**
     * Handles incoming IQ stanzas and responds to "ping" requests.
     * @param xmlString The incoming IQ stanza as an XML string.
     */
    private func IQEventHandler(_ xmlString: String) {
        let xml = XMLHash.config { $0.shouldProcessNamespaces = true }.parse(xmlString)
        
        // An iq stanza containing a 'fin' tag will be received after requested archived messages are received.
        if xml["iq"]["fin"].element != nil {
            DispatchQueue.main.async { [weak self] in
                if self?.isFetchingArchivedMessages == true {
                    self?.isFetchingArchivedMessages = false
                    self?.canShowMsgListShimmer = false
                    self?.triggerScrollToBottom()
                }
            }
            bulkSendDeliveryStatus()
            updateSeenStatus()
        }
        
        guard let iqElement = xml["iq"].element,
              let _ = xml["iq"]["ping"].element,
              let from = iqElement.attribute(by: "from")?.text,
              let id = iqElement.attribute(by: "id")?.text else {
            return
        }
        
        // Construct and send a "pong" IQ stanza in response to a "ping".
        let pongXML = "<iq from='\(userJID)' to='\(from)' id='\(id)' type='result'><pong xmlns='urn:xmpp:pong'/></iq>"
        send(pongXML)
    }
    
    func getArchivedMessages(msgArchiveId: String = "") {
        let iqId = UUID().uuidString.lowercased()
        let mamIQ = """
        <iq id="\(iqId):sendIQ" type="set" xmlns="jabber:client">
            <query xmlns="urn:xmpp:mam:2">
                <x type="submit" xmlns="jabber:x:data">
                    <field type="hidden" var="FORM_TYPE">
                        <value>urn:xmpp:mam:2</value>
                    </field>
                    <field var="thread">
                        <value>\(self.conversationId)</value>
                    </field>
                </x>
                <set xmlns="http://jabber.org/protocol/rsm">
                    <max>\(AppConstant.maxArchivedMessageLimit)</max>
                    <before>\(msgArchiveId)</before>
                </set>
                <flip-page/>
            </query>
        </iq>
        """
        send(mamIQ)
    }
    
    /// Parses the XML error string and updates the user block status if applicable.
    /// - Parameter xmlString: The raw XML string received from the stream.
    private func streamErrorHandler(_ xmlString: String) {
        let xml = XMLHash.config { $0.shouldProcessNamespaces = true }.parse(xmlString)
        
        guard let errorMsg = xml["error"]["text"].element?.text, let reason = CloseChatSessionReason(rawValue: errorMsg) else {
            return
        }
        
        if reason == .deleted || reason == .blocked {
            isUserBlocked = true
        }
    }
    
    func uploadFiles(_ urls: [URL], forWorkflowFileInput: Bool = false, message: Message? = nil) {
        let filesData: [FileInfo] = urls.compactMap { url in
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            defer { if didStartAccessing { url.stopAccessingSecurityScopedResource() } }
            do {
                // Create a temp copy so we can read outside the security-scope lifecycle reliably
                let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                let tmpFile = tmpDir.appendingPathComponent(UUID().uuidString).appendingPathExtension(url.pathExtension)
                if FileManager.default.fileExists(atPath: tmpFile.path) {
                    try? FileManager.default.removeItem(at: tmpFile)
                }
                try FileManager.default.copyItem(at: url, to: tmpFile)
                let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey, .contentTypeKey, .nameKey])
                let fileSize = resourceValues.fileSize ?? (try? Data(contentsOf: tmpFile).count) ?? 0
                let mime = resourceValues.contentType?.preferredMIMEType ?? "application/octet-stream"
                let displayName = resourceValues.name ?? url.lastPathComponent
                return FileInfo(
                    id: UUID().uuidString.lowercased(),
                    name: displayName,
                    size: fileSize,
                    type: mime,
                    url: tmpFile
                )
            } catch {
                return nil
            }
        }
        handlePickedFiles(filesData, forWorkflowFileInput: forWorkflowFileInput, message: message)
    }
    
    func handlePickedFiles(_ files: [FileInfo], forWorkflowFileInput: Bool, message: Message? = nil) {
        var allowedExtensions: [String] = []
        if forWorkflowFileInput {
            allowedExtensions = message?.formDetails?.allowedFileTypes ?? []
        }
        else {
            allowedExtensions = (settings?.widgetSettings.allowedFileExtensions ?? []).map { $0.lowercased() }
        }
        let hasExtensionRestrictions = !allowedExtensions.isEmpty
        let fileMaxSize = settings?.generalSettings.uploadFileSize
        
        for file in files {
            let isImage = file.type.contains("image")
            // Use the actual file URL extension; display name may not contain extension on real devices
            let pathExtension = file.url.pathExtension.lowercased()
            let normalizedExtension = pathExtension.isEmpty ? nil : ".\(pathExtension)"
            
            if hasExtensionRestrictions {
                guard let normalizedExtension, allowedExtensions.contains(normalizedExtension) else {
                    let notif = getUploadExtensionErrorNotification(allowedExtensions: allowedExtensions)
                    NotificationManager.shared.show(notif, shouldAutoHide: true)
                    continue
                }
            }
            
            if isImage {
                guard file.size <= AppConstant.imgMaxSize else {
                    NotificationManager.shared.show(.imageMaxSizeExceeded(convertToFormattedSize(AppConstant.imgMaxSize)))
                    continue
                }
            } else if let maxSize = fileMaxSize, file.size > maxSize {
                NotificationManager.shared.show(.fileMaxSizeExceeded(convertToFormattedSize(maxSize)))
                continue
            }
            
            let uploadUrl = isImage ? ChatWidgetAPIPaths.uploadInlineImage(isWorkflow: forWorkflowFileInput) : ChatWidgetAPIPaths.uploadAttachment(isWorkflow: forWorkflowFileInput)
            prepareMessageForUpload(file: file, urlString: uploadUrl, isImage: isImage, forWorkflowFileInput: forWorkflowFileInput, message: message)
        }
    }
    
    private func getUploadExtensionErrorNotification(allowedExtensions: [String]) -> NotificationType {
        if allowedExtensions.count == 1 {
            return .uploadExtensionNotAllowedWithSingleAllowedFile(allowedExtensions[0])
        } else {
            let list = allowedExtensions.dropLast().joined(separator: ", ")
            let last = allowedExtensions.last ?? ""
            return .uploadExtensionNotAllowedWithMultipleAllowedFile(list, last)
        }
    }
    
    func prepareMessageForUpload(file: FileInfo, urlString: String, isImage: Bool, forWorkflowFileInput: Bool, message: Message? = nil) {
        guard let uploadURL = URL(string: urlString) else {
            NotificationManager.shared.show(.somethingWentWrong, shouldAutoHide: true)
            return
        }
        
        let msgFile = [File(url: "", size: String(file.size), name: file.name, mediaType: file.type, disposition: isImage ? "inline" : "attachment", rawFile: file, cID: "1")]
        
        if forWorkflowFileInput {
            if let index = self.messages.firstIndex(where: { $0.id == message?.id }) {
                self.messages[index].files = msgFile
                self.messages[index].deliveryStatus = self.isDisconnected ? .notSent : .uploading
                DispatchQueue.main.async { [weak self] in
                    self?.triggerScrollToBottom()
                }
                Task {
                    await handleFileUploadForWorkflowFileInput(
                        index: index,
                        fileInfo: file,
                        uploadURL: uploadURL
                    )
                }
            }
        }
        else{
            let message = Message(from: userJID, userType: .customer, type: isImage ? .image : .attachment, deliveryStatus: isDisconnected ? .notSent : .uploading, uploaderFileId: file.id, files: msgFile)
            
            DispatchQueue.main.async { [weak self] in
                self?.messages.append(message)
                self?.triggerScrollToBottom()
            }
            
            guard message.deliveryStatus != .notSent else { return }
            
            Task {
                await handleFileUpload(message: message, fileInfo: file, uploadURL: uploadURL)
            }
        }
    }
    
    private func handleFileUploadForWorkflowFileInput(index: Int, fileInfo: FileInfo, uploadURL: URL) async{
        do {
            let response = try await chatAPIClient.uploadFile(
                to: uploadURL,
                file: fileInfo,
                conversationId: conversationId,
                requesterId: requesterId,
                requesterType: requesterType
            )
            DispatchQueue.main.async {
                self.messages[index].attachmentInfo = response
                if var files = self.messages[index].files {
                    files[0].url = response.url
                    self.messages[index].files = files
                }
                self.messages[index].deliveryStatus = self.isDisconnected || !self.isOnline ? .notSent : .toSent
            }
            manageAIMessages()
        } catch {
            DispatchQueue.main.async {
                self.messages[index].attachmentInfo = nil
                self.messages[index].deliveryStatus = .notSent
                NotificationManager.shared.show(.somethingWentWrong, shouldAutoHide: true)
            }
        }
    }

    /// Handles the file upload process and updates the message with the uploaded file URL.
    /// Also sends the file stanza after a successful upload.
    /// - Parameters:
    ///   - message: The message containing the file to upload.
    ///   - fileInfo: The raw file information to be uploaded.
    ///   - uploadURL: The endpoint URL to which the file should be uploaded.
    private func handleFileUpload(message: Message, fileInfo: FileInfo, uploadURL: URL) async {
        do {
            let response = try await chatAPIClient.uploadFile(
                to: uploadURL,
                file: fileInfo,
                conversationId: conversationId,
                requesterId: requesterId,
                requesterType: requesterType
            )
            
            guard var messageFiles = message.files else { return }
            
            messageFiles[0].url = response.url
            
            let updatedMessage = Message(
                id: message.id,
                from: message.from,
                userType: message.userType,
                type: message.type,
                deliveryStatus: isDisconnected || !isOnline ? .notSent : .toSent,
                text: message.text,
                uploaderFileId: message.uploaderFileId,
                files: messageFiles
            )
            
            DispatchQueue.main.async {
                if let index = self.messages.firstIndex(where: { $0.id == message.id }) {
                    self.messages[index] = updatedMessage
                }
            }
            
            guard message.deliveryStatus != .notSent else { return }
            
            manageAIMessages()
            
            let file = messageFiles[0]
            
            sendFileStanza(
                mediaType: file.mediaType,
                name: file.name,
                size: file.size,
                token: response.token,
                messageId: message.id,
                disposition: file.disposition,
                type: message.type,
                cid: file.cID ?? "1"
            ) { self.handleStanzaSendResult(for: message.id, isSent: $0) }
        } catch {
            DispatchQueue.main.async {
                if let index = self.messages.firstIndex(where: { $0.id == message.id }) {
                    self.messages.remove(at: index)
                }
                NotificationManager.shared.show(.somethingWentWrong, shouldAutoHide: true)
            }
        }
    }
    
    func deleteFileAttachment(messageId: String){
        if let index = self.messages.firstIndex(where: { $0.id == messageId }) {
            self.messages[index].files = nil
            self.messages[index].attachmentInfo = nil
            self.messages[index].deliveryStatus = .notSent
        }
    }
    
    func sendFileStanza(mediaType: String, name: String, size: String, token: String, messageId: String, disposition: String, type: MessageType, cid: String, completion: ((Bool) -> Void)? = nil) {
        
        let toJid = settings?.toJid ?? ""
        
        let normalStanza = """
        <message to="\(toJid)" from="\(userJID)" id="\(messageId)" type="chat">
            <attachments xmlns="https://www.bolddesk.com/attachments">
                <file xmlns="https://www.bolddesk.com/attachments" disposition="\(disposition)">
                    <media-type>\(mediaType)</media-type>
                    <name>\(name)</name>
                    <size>\(size)</size>
                    <source-id>\(cid)</source-id>
                    <target>\(token)</target>
                </file>
            </attachments>
            <store xmlns="urn:xmpp:hints"/>
            <thread>\(conversationId)</thread>
            <chatdata xmlns="https://www.bolddesk.com/chat-data" type="\(type.rawValue)" requesterId="\(self.requesterId)"/>
            <request xmlns="urn:xmpp:receipts"/>
        </message>
        """
        
        let carbonStanza = """
        <message from="\(userJID)" to="\(userJID)" type="chat" xmlns="jabber:client">
            <forwarded xmlns='urn:xmpp:forward:0'>
                <message to="\(toJid)" from="\(userJID)" id="\(messageId)" type="chat" xmlns="jabber:client">
                    <attachments xmlns="https://www.bolddesk.com/attachments">
                        <file xmlns="https://www.bolddesk.com/attachments" disposition="\(disposition)">
                            <media-type>\(mediaType)</media-type>
                            <name>\(name)</name>
                            <size>\(size)</size>
                            <source-id>\(cid)</source-id>
                            <target>\(token)</target>
                        </file>
                    </attachments>
                    <store xmlns="urn:xmpp:hints"/>
                    <thread>\(conversationId)</thread>
                    <chatdata xmlns="https://www.bolddesk.com/chat-data" type="\(type.rawValue)" requesterId="\(self.requesterId)"/>
                    <request xmlns="urn:xmpp:receipts"/>
                </message>
            </forwarded>
        </message>
        """
        
        // ✅ Send normal FIRST, then carbon
        send(carbonStanza, completion: nil)
        send(normalStanza, completion: completion)
    }

    func hideNotification() {
        NotificationManager.shared.hide()
    }
    
    // MARK: - Online/Offline handling
    func handleOnline() {
        guard !isUserBlocked else { return }
        isOnline = true
        NotificationManager.shared.show(.internetOnline)
        guard let widgetId = settings?.widgetId else { return }
        if WidgetStorageManager.isUserExistAlready(appKey: BDChatSDK.appKey, emailId: BDChatSDK.email) && isChatConnected {
            retryConnection()
        }
    }
    
    func handleOffline() {
        guard !isUserBlocked else { return }
        isOnline = false
        NotificationManager.shared.show(.internetOffline)
        isDisconnected = isChatConnected
    }
    
    func startNetworkMonitoring() {
        // Start monitoring network changes for online/offline notifications and reconnection
        networkMonitor.start { [weak self] isConnected in
            guard let self = self else { return }
            guard isConnected != self.isOnline else { return }
            if isConnected { self.handleOnline() } else { self.handleOffline() }
        }
    }
     
    func stopNetworkMonitoring() {
        networkMonitor.stop()
    }
    
    /// Triggers a retry mechanism by showing a reconnecting notification and attempting to reconnect if disconnected.
    func retryConnection() {
        if isDisconnected {
            NotificationManager.shared.show(.reconnecting)
            reconnect()
        } else if NotificationManager.shared.currentNotification == .serverDisconnected {
            NotificationManager.shared.show(.serverOnline)
        }
    }
    
    /// A shared ISO8601 date formatter for parsing and formatting date strings.
    private let isoDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    /// Ensures the current authentication token is valid and not expiring soon.
    /// If it's near expiry or invalid, attempts to refresh it.
    /// - Returns: `true` if the token is valid or was successfully refreshed; otherwise, `false`.
    private func ensureValidAuthToken(canSetTimeout: Bool) async -> Bool {
        do {
            // Update the auth token if token expiry is not present in storage, or if less than 2 minutes are left for expiry.
            guard let tokenExpiry = WidgetStorageManager.getSetting(for: "tokenExpiry", appKey: BDChatSDK.appKey, emailId: BDChatSDK.email), let remainingMinutes = try await remainingTokenValidityInMinutes(tokenExpiry: tokenExpiry), remainingMinutes > AppConstant.tokenRefreshBufferMinutes else {
                return await updateAuthToken()
            }
            if canSetTimeout {
                let delayInSeconds = (remainingMinutes - AppConstant.tokenRefreshBufferMinutes) * 60
                self.scheduleTokenRefresh(after: TimeInterval(delayInSeconds))
            }
            return true
        } catch {
            isDisconnected = true
            print("❌ Error:", error.localizedDescription)
            NotificationManager.shared.show(.serverDisconnected)
            return false
        }
    }
    
    /// Calculates the remaining validity duration of the current auth token in minutes by comparing it to the server's current time.
    /// - Returns: The number of minutes until the token expires, or `nil` if the date parsing fails.
    /// - Throws: An error if the server time cannot be fetched.
    private func remainingTokenValidityInMinutes(tokenExpiry: String) async throws -> Int? {
        let versionResponse = try await chatAPIClient.getVersion()
        guard let serverTime = isoDateFormatter.date(from: versionResponse.dateTime),
              let expiryTime = isoDateFormatter.date(from: tokenExpiry) else {
            return nil
        }
        return Int((expiryTime.timeIntervalSince(serverTime) / 60).rounded(.up))
    }
    
    /// Fetches a new authentication token from the server and updates the local `authToken` and `tokenExpiry`.
    /// - Returns: `true` if the token was successfully updated; otherwise, `false`.
    private func updateAuthToken() async -> Bool {
        do {
            let cId = WidgetStorageManager.getSetting(for: "cId", appKey: BDChatSDK.appKey, emailId: BDChatSDK.email) ?? ""

            let tokenInfo = try await chatAPIClient.getToken(
                requesterId: requesterId,
                requesterType: requesterType,
                conversationId: conversationId.isEmpty ? cId : conversationId,
                sessionId: sessionId
                    .sanitizedOptional
                    .isEmpty == true ? nil : sessionId.sanitizedOptional,
                email: BDChatSDK.email?
                    .sanitizedOptional
                    .isEmpty == true ? nil : BDChatSDK.email?.sanitizedOptional,
                userToken: BDChatSDK.userToken?
                    .sanitizedOptional
                    .isEmpty == true ? nil : BDChatSDK.userToken?.sanitizedOptional
            )
            try await refreshTokenAndUpdateExpiry(tokenInfo: tokenInfo)
            return true
        } catch {
            isDisconnected = true
            APIErrorHandler.shared.handleAPIError(
                error,
                shouldAutoHide: false,
                defaultNotification: .serverDisconnected,
                onUnauthorized: { [weak self] in
                    self?.canShowStartNewConversationButton = false
                }
            )
            return false
        }
    }
    
    
    /// Updates the local authentication token and schedules the next refresh based on token expiry.
    /// - Parameter tokenInfo: The new token information received from the server.
    private func refreshTokenAndUpdateExpiry(tokenInfo: TokenInfo) async throws {
        authToken = tokenInfo.token
        WidgetStorageManager.updateSetting(key: "token", value: authToken, appKey: BDChatSDK.appKey, emailId: BDChatSDK.email)
        WidgetStorageManager.updateSetting(key: "tokenExpiry", value: tokenInfo.expiresOn, appKey: BDChatSDK.appKey, emailId: BDChatSDK.email)
        
        guard let remainingMinutes = try await remainingTokenValidityInMinutes(tokenExpiry: tokenInfo.expiresOn) else {
            return
        }
        
        let delayInSeconds = (remainingMinutes - AppConstant.tokenRefreshBufferMinutes) * 60
        self.scheduleTokenRefresh(after: TimeInterval(delayInSeconds))
    }
    
    /// Handles chat state changes based on the incoming message and updates conversation status flags accordingly.
    /// - Parameter message: The incoming `Message` object containing chat state info.
    private func handleChatStateMessages(message: Message, agentId: Int?) {
        guard !message.isArchived || message.isUnsyncMessage else { return }
        // Update conversation state based on the chat state
        switch message.chatStates {
        case .closed:
            Task {
                    await checkConversationInitiationStatus()
                    let statusInfo = try await chatAPIClient.getConversationStatusInfo(conversationId: self.conversationId)
                if !isChatCleared {
                    canReopen = statusInfo.canReopen
                    manageAiAgentThinkingIndicator(isAiAgentThinking: false)
                    isConvClosed = true
                } else{
                    isChatCleared = false
                }
                
            }
        case .open:
            isConvClosed = false
            Task{
                await checkConversationInitiationStatus()
            }
            if BDChatSDK.isOpen {
                self.updateFooterVisibility()
            }
        case .deleted, .spam:
            isActive = false
            Task{
                await checkConversationInitiationStatus()
            }
            manageAiAgentThinkingIndicator(isAiAgentThinking: false)
        case .restored:
            isActive = true
            if BDChatSDK.isOpen {
                self.updateFooterVisibility()
            }
        case .composing, .typingStopped:
            self.manageAgentTypingIndicator(isComposing: message.chatStates == .composing, agentId: agentId)
        case .thinking:
            self.manageAiAgentThinkingIndicator(isAiAgentThinking: true, agentId: agentId)
        case .startMessaging:
            if !conversationList.contains(where: { $0.conversationId == self.threadId }) {
                Task {
                    await fetchConversationDetails(conversationId: self.threadId)
                }
            }
            self.isMsgFooterDisabled = false

        case .clearChatSession:
            self.clearChatSession()
        default:
            break
        }
    }
    
    /// Attempts to reopen a previously closed conversation using the current conversation ID and requester info.
    func reopenConversation(completion: ((Bool) -> Void)? = nil) {
        Task {
            let canReopenConversation = await checkConversationInitiationStatus()
                    guard canReopenConversation else {
                        // Only show reopenNotAllowedText if no other notification is currently displayed
                        // (e.g., if API error already showed a specific error notification)
                        if NotificationManager.shared.currentNotification == nil {
                            NotificationManager.shared.show(.reopenNotAllowedText, shouldAutoHide: true)
                        }
                        completion?(false)
                        return
                    }
            let email = escapeHTML(BDChatSDK.email ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            
            let requestedBy = RequestedBy(name: "", email: email, phoneNo: "", category: resolvedCategoryId(), timeZone: TimeZone.current.identifier)
        let openConversationRequest = OpenConversationRequest(
            requesterId: self.requesterId,
            appToken: ChatWidgetAPIPaths.appToken,
            conversationId: self.conversationId,
            requestedBy: requestedBy,
            requesterType: RequesterType(rawValue: self.requesterType)!,
            requiresToken: nil,
            requesterMessage: nil,
            chatWelcomeMessageIds: nil,
            suggestionValue: nil,
            stickyButtonValue: nil,
            formMessageId: nil,
            fields: nil,
            userToken: BDChatSDK.userToken,
            confirmationMessage: nil,
            considerSuggestionAsFAQ: false,
            userDeviceToken: (BDChatSDK.fcmToken?.isEmpty == false) ? UserDeviceToken(appTypeId: 2, deviceToken: BDChatSDK.fcmToken ?? "", appId: ChatWidgetAPIPaths.appToken, additionalConfig: AdditionalConfig(deviceName: UIDevice.current.name)) : nil,
            sessionId: self.sessionId
        )
            do {
                let _ = try await chatAPIClient.createConversation(requestPayload: openConversationRequest)
            } catch {
                APIErrorHandler.shared.handleAPIError(
                    error,
                    shouldAutoHide: false,
                    defaultNotification: .intervalLimitExceeded,
                    onBadRequest: { [weak self] in
                        self?.canReopen = false
                    },
                    onUnauthorized: { [weak self] in
                        self?.canShowStartNewConversationButton = false
                    }
                )
                completion?(true)
            }
        }
    }
    
    /// Resets the current chat state and initiates a new conversation.
    func resetAndCreateNewConversation() {
        guard let settings = self.settings else { return }
//        WidgetStorageManager.clearConversationDataInStorage(appKey: BDChatSDK.appKey, emailId: BDChatSDK.email)
        
        // Reset chat connection states
        preChatFormSessionId = UUID()
        isOnline = true
        // Clear conversation data
        conversationId = ""
        // Reset chat state flags
        isConvClosed = false
        isActive = true
        isUserBlocked = false
        isMsgFooterDisabled = false
        canShowMsgFooter = true
        lastMsgAgentId = nil
        lastMsgAgentInfo = nil
        isFetchingArchivedMessages = false
        firstVisibleMsg = nil
        scrollTrigger = 0
        // Reset AI/assignee and typing indicators
        isConvAssignedToAIAgent = nil
        typingAgentInfo = nil
        thinkingAiAgentInfo = nil
        showSuggestionOptions = false
        // Invalidate any running timers
        typingIndicatorTimer?.invalidate()
        typingIndicatorTimer = nil
        agentTypingIndicatorTimer?.invalidate()
        agentTypingIndicatorTimer = nil
        aiThinkingTimeoutTimer?.invalidate()
        aiThinkingTimeoutTimer = nil

//        cancelTokenRefresh()

        // Ensure next disconnect is handled silently again
        allowSilentReconnect = true
        
        canReopen = nil
        
        // Clear messages
        messages = []
        chatWelomeMessageIds = []
        
        // Reset notifications
        NotificationManager.shared.hide()
        
        // Clear composer text directly
        self.messageText = ""
        
        // Close WebSocket connection if it exists
//        webSocketTask?.cancel(with: .goingAway, reason: nil)
//        webSocketTask = nil
        
        Task {
            // Clear and refetch Pre-chat form fields for a fresh session
            self.preChatFormFields = []
            do {
                let preChatFields = try await self.chatAPIClient.getPreChatFormDetails()
                self.preChatFormFields = preChatFields.filter { !AppConstant.userDetailsFieldApi.contains($0.apiName) }
                
                if self.preChatFormFields.count > 0 { self.canShowMsgFooter = false }

                if let preDetails = settings.chatSettings.preChatFormDetails {
                    self.sortPreChatFormFields(preChatFormDetails: preDetails)
                }
            } catch {
                // Silently ignore; pre-chat will fallback to existing config
                print(error)
            }
            
            // Re-evaluate footer visibility and suggestions based on settings for a new session
            if settings.chatSettings.displayOption == .none || isOnlyUserFieldsAndPrefilled() {
                DispatchQueue.main.async { self.canShowMsgFooter = true }
                
                if let enableSuggestions = settings.chatSettings.enableSuggestions, enableSuggestions == true, let suggestions = settings.chatSettings.suggestions, !suggestions.isEmpty {
                    DispatchQueue.main.async { self.showSuggestionOptions = true }
                }
            }

            // Re-add welcome messages if they exist in settings
            let welcomeMessages = settings.chatSettings.welcomeMessages
            if !welcomeMessages.isEmpty {
                DispatchQueue.main.async {
                    for welcomeMsg in welcomeMessages {
                        let message = Message(from: "", userType: .agent, type: .text, deliveryStatus: .undelivered, isReceiptRequested: true, isArchived: false, text: welcomeMsg.message, textFormat: .html)
                        let welcomeMsgId = ChatWelcomeMessageId(id: welcomeMsg.id, guid: message.id)
                        self.chatWelomeMessageIds.append(welcomeMsgId)
                        self.messages.append(message)
                        Task {
                            let systemUserInfo = await ChatUtils.shared.getAgentAvatarDetailsById(agentId: self.getSystemUserId())
                            if let messageIndex = self.messages.firstIndex(where: { $0.id == message.id }) {
                                self.messages[messageIndex].agentInfo = systemUserInfo
                            }
                        }
                    }
                }
            }
        }
    }
    
    /// Retries sending a message with the given ID.
    /// If the message contains a file, it triggers a file upload; otherwise, it resends the text message.
    /// - Parameter id: The ID of the message to retry.
    func retryMessage(withId id: String) {
        guard let index = messages.firstIndex(where: { $0.id == id }),
              messages[index].deliveryStatus == .notSent else { return }
        
        var message = messages[index]
        
        if let _ = message.files?.first {
            retryFileUpload(for: message, at: index)
        } else {
            message.deliveryStatus =  isDisconnected || !isOnline ? .notSent : .toSent
            updateMessagePositionToLast(message, at: index)
            message.type == .fieldValues ? sendFieldValueMessage(with: message) : sendMessage(message: message)
        }
    }
    
    /// Retries uploading a file associated with a message.
    /// Updates the message's delivery status and initiates the upload process.
    /// - Parameters:
    ///   - message: The message containing the file to be uploaded.
    ///   - index: The index of the message in the messages array.
    private func retryFileUpload(for message: Message, at index: Int) {
        guard let file = message.files?.first,
              let fileInfo = file.rawFile else { return }
        
        var updatedMessage = message
        updatedMessage.deliveryStatus = isDisconnected || !isOnline ? .notSent : .uploading
        
        guard let uploadURL = URL(string: file.disposition == "inline" ? ChatWidgetAPIPaths.uploadInlineImage() : ChatWidgetAPIPaths.uploadAttachment()) else { return }
        
        updateMessagePositionToLast(updatedMessage, at: index)
        
        guard updatedMessage.deliveryStatus != .notSent else { return }
        
        Task {
            await handleFileUpload(message: updatedMessage, fileInfo: fileInfo, uploadURL: uploadURL)
        }
    }
    
    /// Moves the message to the end if it's not last; otherwise updates it in place.
    /// - Parameters:
    ///   - message: The message to update.
    ///   - index: Current index of the message.
    private func updateMessagePositionToLast(_ message: Message, at index: Int) {
        DispatchQueue.main.async {
            if index != self.messages.count - 1 {
                self.messages.remove(at: index)
                self.messages.append(message)
            } else {
                self.messages[index] = message
            }
            self.triggerScrollToBottom()
        }
    }
    
    /// Handles the result of sending a message or file stanza by updating the message's delivery status.
    /// - Parameters:
    ///   - messageId: The ID of the message to update.
    ///   - isSent: A Boolean indicating whether the stanza was successfully sent (`true`) or not (`false`).
    private func handleStanzaSendResult(for messageId: String, isSent: Bool) {
        if !isSent {
            // If trying to send the message stanza throws error (occurs when websocket connection is broken but not yet detected) - mark the message as 'notSent'.
            DispatchQueue.main.async {
                if let index = self.messages.firstIndex(where: { $0.id == messageId }) {
                    self.messages[index].deliveryStatus = .notSent
                }
            }
        } else {
            // If trying to send message stanza did not throw an error, start a 30-second timeout.
            // If the message is still in `toSent` state after 30 seconds, mark it as `notSent`.
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                if let index = self.messages.firstIndex(where: { $0.id == messageId }),
                   self.messages[index].deliveryStatus == .toSent {
                    self.messages[index].deliveryStatus = .notSent
                }
            }
        }
    }
    
    /// Method to retrieve unsynced archived messages in the conversation on reconnecting to server
    /// - Parameters:
    ///   - queryValue: Contains archive ID of the last message if present, else contains the time of the last message
    ///   - canSendTime: if true, then messages are retrieved in the time period between last message time and current time, else retrieved using archive ID
    ///   - direction: Whether to retrieve the messages before or after the archive ID ("before" or "after")
    private func getArchivedMessagesOnSync(queryValue: String, canSendTime: Bool, direction: String? = nil) {
        let iqId = UUID().uuidString.lowercased()
        
        var mamIQ = """
    <iq id="\(iqId):sendIQ" type="set" xmlns="jabber:client">
        <query xmlns="urn:xmpp:mam:2" queryid="unsync-message">
            <x type="submit" xmlns="jabber:x:data">
                <field type="hidden" var="FORM_TYPE">
                    <value>urn:xmpp:mam:2</value>
                </field>
                <field var="thread">
                    <value>\(conversationId)</value>
                </field>
    """
        
        if canSendTime {
            // Use the existing isoDateFormatter from ChatViewModel
            let currentTime = isoDateFormatter.string(from: Date())
            mamIQ += """
                <field var="start">
                    <value>\(queryValue)</value>
                </field>
                <field var="end">
                    <value>\(currentTime)</value>
                </field>
            </x>
        </query>
    </iq>
    """
        } else if let direction = direction {
            mamIQ += """
            </x>
            <set xmlns="http://jabber.org/protocol/rsm">
                <max>\(AppConstant.maxUnsyncedMessageLimit)</max>
                <\(direction)>\(queryValue)</\(direction)>
            </set>
        </query>
    </iq>
    """
        }
        
        send(mamIQ)
    }
    
    /// Syncs messages after reconnection by fetching from archive using the last valid message.
    private func handleReconnectionSync() {
        // Get last valid message (sent/delivered, not chat state)
        guard let lastMessage = messages.last(where: {
            $0.deliveryStatus != .notSent && $0.deliveryStatus != .toSent && $0.type != .chatStates
        }) else {
            // If no valid message and list is empty, fetch initial archive
            if messages.isEmpty { getArchivedMessages() }
            return
        }
        
        // Fetch using archive ID if present
        if let archiveId = lastMessage.archiveId, !archiveId.isEmpty {
            getArchivedMessagesOnSync(queryValue: archiveId, canSendTime: false, direction: "after")
        } else {
            // Otherwise, fetch using timestamp
            getArchivedMessagesOnSync(queryValue: lastMessage.time, canSendTime: true)
        }
    }
    
    func triggerScrollToBottom() {
        self.scrollTrigger += 1
    }
    
    // MARK: - Streaming (RTT) Helpers
    private func handleRTTStanza(msgXML: XMLIndexer, msgElement: XMLIndexer, rttTag: XMLElement) {
        // Ensure the message belongs to the same conversation
        guard let threadId = msgElement["thread"].element?.text, threadId == self.conversationId else { return }
        guard let msgId = msgElement.element?.attribute(by: "id")?.text else { return }
        let fromAttr = msgElement.element?.attribute(by: "from")?.text ?? ""
        let from = fromAttr.split(separator: "/").first.map(String.init) ?? ""
        // seq and event
        let seq = Int(rttTag.attribute(by: "seq")?.text ?? "0") ?? 0
        let event = rttTag.attribute(by: "event")?.text ?? ""
        // Collect text fragments from <t>
        let textFragments = msgElement["rtt"]["t"].all.compactMap { $0.element?.text }
        let deltaText = textFragments.joined()
        // chatdata for format and agent info
        let chatData = msgElement["chatdata"].element
        let formatStr = chatData?.attribute(by: "format")?.text
        let msgFormat = formatStr.flatMap(TextFormat.init) ?? .none
        let userType: UserType = from == self.userJID ? .customer : .agent
        
        // Extract agent id if present
        var msgAgentId: Int?
        if let agentIdText = chatData?.attribute(by: "agentId")?.text, let agentId = Int(agentIdText) {
            msgAgentId = agentId
        } else if let caidText = chatData?.attribute(by: "caid")?.text, let caid = Int(caidText) {
            msgAgentId = caid
        }
        
        // If agent AI streaming chunk arrives: hide thinking but keep footer disabled
        if userType == .agent {
            self.manageAiAgentThinkingIndicator(isAiAgentThinking: false, agentId: nil)
        }
        
        // Manage streaming context
        var context = streamingContextMap[msgId] ?? StreamingContext()
        if event == "new" {
            context.accumulatedText = ""
            context.lastSequenceNumber = -1
        }
        if event == "new" || seq == context.lastSequenceNumber + 1 {
            context.accumulatedText += deltaText
            context.lastSequenceNumber = seq
        }
        streamingContextMap[msgId] = context
        
        // Update or create message
        if let index = self.messages.firstIndex(where: { $0.id == msgId }) {
            self.messages[index].text = context.accumulatedText
            self.messages[index].textFormat = msgFormat
            self.messages[index].isStreaming = true
            self.messages[index].deliveryStatus = userType == .customer ? .sent : .delivered
            // Always scroll to bottom on each chunk
            self.triggerScrollToBottom()
        } else {
            let time = isoDateFormatter.string(from: Date())
            let timeLabel = getChatMessageTime(for: Date())
            let message = Message(
                id: msgId,
                from: from,
                userType: userType,
                type: .text,
                deliveryStatus: userType == .customer ? .sent : .delivered,
                time: time,
                timeLabel: timeLabel,
                isReceiptRequested: true,
                isArchived: false,
                text: context.accumulatedText,
                textFormat: msgFormat,
                files: [],
                isRetracted: false,
                isReplaced: false,
                formDetails: nil,
                fieldValueDetails: nil,
                archiveId: nil,
                isUnsyncMessage: false,
                actionButtonValue: nil,
                actionButtonType: nil,
                isStreaming: true,
                currentSeq: seq
            )
            self.messages.append(message)
            self.triggerScrollToBottom()
            
            // Set agent info for newly appended streaming message
            if message.userType == .agent, let agentAvatarId = msgAgentId {
                if !message.isArchived && message.type == .text && agentAvatarId != AppConstant.systemUserId { self.lastMsgAgentId = msgAgentId }
                Task {
                    let agentAvatar = await ChatUtils.shared.getAgentAvatarDetailsById(agentId: agentAvatarId)
                    if agentAvatar.id == self.lastMsgAgentId { DispatchQueue.main.async { self.lastMsgAgentInfo = agentAvatar } }
                    if let messageIndex = self.messages.firstIndex(where: { $0.id == msgId }) { self.messages[messageIndex].agentInfo = agentAvatar }
                }
            }
        }
    }
    
    func createAndSendFieldValueMessage(with formDetails: FormDetails, formMsgId: String, value: String, pickerValue: [DropdownItemModel]?, files: [File]?) {
        var value = value
        if formDetails.mod == .ai, let selectedItem = pickerValue?.first {
            createAndSendAIResponseMessage(with: formDetails, formMsgId: formMsgId, value: selectedItem)
            return
        }
        if formDetails.subType == .decimal {
            if let number = Double(value) {
                value = String(format: "%.2f", number)
            }
        }
        var fieldValueType: String;
        if value.isEmpty && (pickerValue == nil || pickerValue?.count == 0) {
            fieldValueType = "skipped"
        }
        else if formDetails.type == .getFileInput {
            fieldValueType = "file"
        }
        else {
            switch formDetails.subType {
            case .date:
                fieldValueType = "date"
            case .dateTime:
                fieldValueType = "datetime"
            case .multiSelect:
                fieldValueType = "textarray"
            default :
                fieldValueType = "text"
            }
        }
        let fieldValueDetails = FieldValueDetails(fieldValueType: fieldValueType, ruleId: formDetails.ruleId, id: formDetails.workflowId, value: value, isMasked: false, formMsgId: formMsgId, mod: formDetails.mod, pickerValue: pickerValue)
        var fieldValueMessage: Message
        if formDetails.type == .getFileInput && fieldValueType != "skipped" {
            fieldValueMessage = Message(from: userJID, userType: .customer, type: .fieldValues, deliveryStatus: isDisconnected ? .notSent : .toSent, text: "", files: files, fieldValueDetails: fieldValueDetails)
        } else{
            fieldValueMessage = Message(from: userJID, userType: .customer, type: .fieldValues, deliveryStatus: isDisconnected ? .notSent : .toSent, text: convertFieldValuesToText(fieldValueDetails: fieldValueDetails), fieldValueDetails: fieldValueDetails)
        }
       
        DispatchQueue.main.async { [weak self] in
            if let index = self?.messages.firstIndex(where: { $0.id == formMsgId }) {
                self?.messages[index].formDetails?.isSubmitted = true
                self?.messages.append(fieldValueMessage)
                self?.triggerScrollToBottom()
                self?.sendFieldValueMessage(with: fieldValueMessage)
            }
        }
    }
    
    func onSuggestionValueSelected(_ selectedSuggestionOption: SuggestionOption, _ actionButtonType: ActionButtonType) {
        self.showSuggestionOptions = false
        self.createAndSendMessages(text: selectedSuggestionOption.text, selectedActionButtonValue: selectedSuggestionOption.value, selectedActionButtonType: actionButtonType)
    }
        
    func onChatFormSubmit(preChatPayload: [[String: Any]], completion: @escaping (Bool) -> Void) {
        self.handlePreChatFormSubmit(payload: preChatPayload, completion: completion)
    }

    func handlePreChatFormSubmit(payload: [[String: Any]], confirmationMessage: String? = nil, completion: @escaping (Bool) -> Void) {
        // 1. Agent pre-chat form message — use the localized string or fallback
        let agentFormMessage = Message(from: "", userType: .agent, type: .text, deliveryStatus: .undelivered, isReceiptRequested: true, isArchived: false, text: self.settings?.chatSettings.preChatFormDetails?.preChatFormMessage ?? "", textFormat: .html)
        
        func displayLabel(for apiName: String) -> String {
            switch apiName {
            case "emailId":        return "Email"
            case "contactName":    return "Name"
            case "contactPhoneNo": return "Phone"
            case "chatCategoryId": return "Category"
            default:
                // For non-default fields -> Use the field label
                if let field = self.preChatFormFields.first(where: { $0.apiName == apiName }) {
                    if let label = field.labelForChatWidget?.trimmingCharacters(in: .whitespacesAndNewlines), !label.isEmpty {
                        return label
                    }
                }
                return apiName
            }
        }

        // 2. Customer message: use provided display message per field if available
        let customerFormText = payload.compactMap { item -> String? in
            guard let apiName = item["apiName"] as? String else { return nil }
            let rawMessage = (item["message"] as? String) ?? (item["value"] as? String) ?? ""
            let text = rawMessage.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            let label = displayLabel(for: apiName)
            return "\(label): \(text)"
        }.joined(separator: "\n")

        let customerFormMessage = Message(from: self.userJID, userType: .customer, type: .text, deliveryStatus: .undelivered, isReceiptRequested: true, isArchived: false, text: customerFormText, textFormat: TextFormat.none)

        self.isMsgFooterDisabled = true

        // 3. requestedBy — respect BoldDeskChatSDK.name/email/phoneNo if set
        let isRequesterInStorage = WidgetStorageManager.isRequesterDetailsAvailableInStorage(appKey: BDChatSDK.appKey, emailId: BDChatSDK.email)

        var finalName = payload.first(where: { $0["apiName"] as? String == "contactName" })?["value"] as? String ?? ""

        var finalEmail = isRequesterInStorage ? "" : payload.first(where: { $0["apiName"] as? String == "emailId" })?["value"] as? String ?? ""

        var finalPhone = payload.first(where: { $0["apiName"] as? String == "contactPhoneNo" })?["value"] as? String ?? ""
        let finalChatCategory = payload.first(where: { $0["apiName"] as? String == "chatCategoryId" })?["value"] as? String ?? ""

        // If the SDK has a user token, prefer stored BDChatSDK values for any empty fields
        if let sdkToken = BDChatSDK.userToken, !sdkToken.isEmpty {
            if finalName.isEmpty, let sdkName = BDChatSDK.name, !sdkName.isEmpty {
                finalName = sdkName
            }
            if finalEmail.isEmpty, let sdkEmail = BDChatSDK.email, !sdkEmail.isEmpty {
                finalEmail = sdkEmail
            }
            if finalPhone.isEmpty, let sdkPhone = BDChatSDK.phoneNo, !sdkPhone.isEmpty {
                finalPhone = sdkPhone
            }
        }

        let requestedBy = RequestedBy(name: finalName, email: finalEmail, phoneNo: finalPhone, category: finalChatCategory, timeZone: isRequesterInStorage ? nil : TimeZone.current.identifier)
        let requesterMessage = RequesterMessage(guid: customerFormMessage.id, message: customerFormText)

        // 4. Custom fields — include all submitted fields except excluded, then merge BoldDeskChatSDK.fields
        let excludedFields = ["emailId", "contactName", "contactPhoneNo", "chatCategoryId"]
        var customFields: [String: Any] = [:]
        // Take values from original payload to preserve arrays
        for item in payload {
            guard let key = item["apiName"] as? String, !excludedFields.contains(key) else { continue }
            if let arr = item["value"] as? [String] {
                customFields[key] = arr
            } else if let str = item["value"] as? String {
                customFields[key] = str
            }
        }
        // Merge SDK fields if provided (now supports FieldValue)
//        if let sdkFields = BoldDeskChatSDK.fields, !sdkFields.isEmpty {
//            for (key, value) in sdkFields where !excludedFields.contains(key) && customFields[key] == nil {
//                switch value {
//                case .string(let s):
//                    customFields[key] = s
//                case .array(let arr):
//                    customFields[key] = arr
//                }
//            }
//        }
        
        // Determine requester type based on email and storage status
        let formEmailId = payload.first(where: { $0["apiName"] as? String == "emailId" })?["value"] as? String ?? ""
        let hasFormEmail = !formEmailId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasBDChatSDKEmail = !(BDChatSDK.email?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let isUserExists = WidgetStorageManager.isUserExistAlready(appKey: BDChatSDK.appKey, emailId: BDChatSDK.email)
        
        let finalRequesterType: RequesterType
        if hasFormEmail || (hasBDChatSDKEmail && !isRequesterInStorage && !isUserExists) {
            finalRequesterType = .user
        } else if isRequesterInStorage || isUserExists {
            finalRequesterType = RequesterType(rawValue: self.requesterType) ?? .visitor
        } else {
            finalRequesterType = .visitor
        }
        
        Task { @MainActor [weak self] in
            guard let self = self else { completion(false); return }

            let isConvCreated = await self.createNewConversation(
                requiresToken: true,
                requestedBy: requestedBy,
                requesterId: self.requesterId,
                requesterType: finalRequesterType,
                requesterMessage: requesterMessage,
                chatWelcomeMessageIds: self.chatWelomeMessageIds,
                selectedActionButtonValue: nil,
                formMessageId: agentFormMessage.id,
                confirmationMessage: confirmationMessage,
                selectedActionButtonType: nil,
                fields: customFields.isEmpty ? nil : customFields
            )

            if isConvCreated {
                self.messages.append(contentsOf: [agentFormMessage, customerFormMessage].compactMap { $0 })
                self.handlePolicyNoticeClose()
                if let msg = confirmationMessage?.trimmingCharacters(in: .whitespacesAndNewlines), !msg.isEmpty {
                    let confirmationMsg = Message(from: "", userType: .agent, type: .text, deliveryStatus: .undelivered, isReceiptRequested: true, isArchived: false, text: msg, textFormat: .html)
                    self.messages.append(confirmationMsg)
                }

                Task {
                    let preChatFormWelcomeMsgAgentInfo = await ChatUtils.shared.getAgentAvatarDetailsById(agentId: getSystemUserId())
                    if let preChatFormMsgIndex = self.messages.firstIndex(where: { $0.id == agentFormMessage.id }) {
                        self.messages[preChatFormMsgIndex].agentInfo = preChatFormWelcomeMsgAgentInfo
                    }
                }

                self.triggerScrollToBottom()
                self.canShowMsgFooter = true
                completion(true)
            } else {
                completion(false)
            }
        }
    }

    func sendFieldValueMessage(with message: Message) {
        guard message.deliveryStatus != .notSent else { return }
        
        manageUserTypingIndicator(shouldClearTimeout: true)
        manageAIMessages()
        
        if let fieldValueDetails = message.fieldValueDetails, fieldValueDetails.mod == .ai {
            sendAIResponseStanza(message: message) { self.handleStanzaSendResult(for: message.id, isSent: $0) }
        } else {
            sendFieldValueStanza(message: message) { self.handleStanzaSendResult(for: message.id, isSent: $0) }
        }
    }
    
    func sendFieldValueStanza(message: Message, completion: ((Bool) -> Void)? = nil) {
        guard let fieldValueDetails = message.fieldValueDetails else { return }
        
        let toJid = settings?.toJid ?? ""
        
        // Use existing values directly from fieldValueDetails
        let fieldType = fieldValueDetails.fieldValueType
        let isMasked = fieldValueDetails.isMasked ? "true" : "false"
        let valueTag: String
        if fieldType == "skipped" {
            valueTag = "<value/>"
        } else if fieldValueDetails.pickerValue == nil || fieldValueDetails.pickerValue!.isEmpty {
            valueTag = "<value>\(fieldValueDetails.value)</value>"
        } else {
            // We already checked that pickerValue is not nil above
            if let pickerValues = fieldValueDetails.pickerValue, !pickerValues.isEmpty {
                let allTags = pickerValues.reduce("") { (result, pickerValue) in
                    result + "<value label=\"\(pickerValue.displayName)\">\(pickerValue.id)</value>"
                }
                valueTag = allTags
            } else {
                valueTag = "<value></value>"
            }
        }
        let file = message.files?.first

        if message.fieldValueDetails?.fieldValueType == "file", let file = file {
            let normalStanza = """
            <message xmlns='jabber:client' from='\(userJID)' to='\(toJid)' id='\(message.id)' type='chat'>
                <attachments xmlns="https://www.bolddesk.com/attachments">
                    <file xmlns="https://www.bolddesk.com/attachments" disposition="\(file.disposition)">
                        <media-type>\(file.mediaType)</media-type>
                        <name>\(file.name)</name>
                        <size>\(file.size)</size>
                        <source-id>\(file.cID ?? "")</source-id>
                        <target>\(message.fieldValueDetails?.value ?? "")</target>
                    </file>
                </attachments>

                <fieldvalues xmlns='https://www.bolddesk.com/field-values' formMsgId='\(fieldValueDetails.formMsgId)'>
                    <field type='\(fieldType)' ismasked='\(isMasked)'>
                        \(valueTag)
                    </field>
                </fieldvalues>

                <thread>\(conversationId)</thread>
                <chatdata xmlns='https://www.bolddesk.com/chat-data'
                          ruleId='\(fieldValueDetails.ruleId)'
                          type='\(MessageType.fieldValues.rawValue)'
                          workflowId='\(fieldValueDetails.id)'
                          mod='\(fieldValueDetails.mod.rawValue)'
                          requesterId='\(self.requesterId)'/>
                <request xmlns='urn:xmpp:receipts'></request>
                <store xmlns='urn:xmpp:hints' />
            </message>
            """
            
            let carbonStanza = """
            <message from='\(userJID)' to='\(userJID)' type='chat' xmlns="jabber:client">
                <forwarded xmlns='urn:xmpp:forward:0'>
                    <message from='\(userJID)' to='\(toJid)' id='\(message.id)' type='chat' xmlns="jabber:client">
                        <attachments xmlns="https://www.bolddesk.com/attachments">
                            <file xmlns="https://www.bolddesk.com/attachments" disposition="\(file.disposition)">
                                <media-type>\(file.mediaType)</media-type>
                                <name>\(file.name)</name>
                                <size>\(file.size)</size>
                                <source-id>\(file.cID ?? "")</source-id>
                                <target>\(message.fieldValueDetails?.value ?? "")</target>
                            </file>
                        </attachments>

                        <fieldvalues xmlns='https://www.bolddesk.com/field-values' formMsgId='\(fieldValueDetails.formMsgId)'>
                            <field type='\(fieldType)' ismasked='\(isMasked)'>
                                \(valueTag)
                            </field>
                        </fieldvalues>

                        <thread>\(conversationId)</thread>
                        <chatdata xmlns='https://www.bolddesk.com/chat-data'
                                  ruleId='\(fieldValueDetails.ruleId)'
                                  type='\(MessageType.fieldValues.rawValue)'
                                  workflowId='\(fieldValueDetails.id)'
                                  mod='\(fieldValueDetails.mod.rawValue)'
                                  requesterId='\(self.requesterId)'/>
                        <request xmlns='urn:xmpp:receipts'></request>
                        <store xmlns='urn:xmpp:hints' />
                    </message>
                </forwarded>
            </message>
            """
            
            // ✅ Send normal FIRST, then carbon
            send(carbonStanza, completion: nil)
            send(normalStanza, completion: completion)
        }
        else {
            let normalStanza = """
                <message xmlns='jabber:client' from='\(userJID)' to='\(toJid)' id='\(message.id)' type='chat'>
                    <fieldvalues xmlns='https://www.bolddesk.com/field-values' formMsgId='\(fieldValueDetails.formMsgId)'>
                        <field type='\(fieldType)' ismasked='\(isMasked)'>
                            \(valueTag)
                        </field>
                    </fieldvalues>
                    <thread>\(conversationId)</thread>
                    <chatdata xmlns='https://www.bolddesk.com/chat-data' ruleId='\(fieldValueDetails.ruleId)' type='\(MessageType.fieldValues.rawValue)' workflowId='\(fieldValueDetails.id)' mod='\(fieldValueDetails.mod.rawValue)' requesterId='\(self.requesterId)'/>
                    <request xmlns='urn:xmpp:receipts'></request>
                    <store xmlns='urn:xmpp:hints' />
                </message>
                """
            
            let carbonStanza = """
                <message from='\(userJID)' to='\(userJID)' type='chat' xmlns="jabber:client">
                    <forwarded xmlns='urn:xmpp:forward:0'>
                        <message from='\(userJID)' to='\(toJid)' id='\(message.id)' type='chat' xmlns="jabber:client">
                            <fieldvalues xmlns='https://www.bolddesk.com/field-values' formMsgId='\(fieldValueDetails.formMsgId)'>
                                <field type='\(fieldType)' ismasked='\(isMasked)'>
                                    \(valueTag)
                                </field>
                            </fieldvalues>
                            <thread>\(conversationId)</thread>
                            <chatdata xmlns='https://www.bolddesk.com/chat-data' ruleId='\(fieldValueDetails.ruleId)' type='\(MessageType.fieldValues.rawValue)' workflowId='\(fieldValueDetails.id)' mod='\(fieldValueDetails.mod.rawValue)' requesterId='\(self.requesterId)'/>
                            <request xmlns='urn:xmpp:receipts'></request>
                            <store xmlns='urn:xmpp:hints' />
                        </message>
                    </forwarded>
                </message>
                """
            
            // ✅ Send normal FIRST, then carbon
            send(carbonStanza, completion: nil)
            send(normalStanza, completion: completion)
        }
    }
    
    func createAndSendAIResponseMessage(with formDetails: FormDetails, formMsgId: String, value: DropdownItemModel) {
        let fieldValueDetails = FieldValueDetails(apiName: formDetails.apiName, fieldValueType: formDetails.fieldValueType ?? "", formMsgId: formMsgId, mod: .ai, pickerValue: [value])
        
        let aiMessageResponse = Message(from: self.userJID, userType: .customer, type: .fieldValues, deliveryStatus: .toSent, text: convertFieldValuesToText(fieldValueDetails: fieldValueDetails), fieldValueDetails: fieldValueDetails)
        
        if value.id == AIResponseButtonEnum.thatHelped.rawValue {
            _ = EndChatPayload(appToken: ChatWidgetAPIPaths.appToken, conversationId: conversationId, requesterId: requesterId)
            self.endChat(aiResponseValue: .thatHelped)
        } else if value.id == AIResponseButtonEnum.contactUs.rawValue {
//            self.endChat(aiResponseValue: .thatHelped)
//            clearChatSession()
            self.canshowCreateTicketWebView = true
            self.canShowOfflineForm = true
            Task {
                self.offlineAgentInfo = await ChatUtils.shared.getAgentAvatarDetailsById(agentId: getSystemUserId())
            }
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            // Append the new message and send it
            self?.messages.append(aiMessageResponse)
            self?.triggerScrollToBottom()
            self?.sendFieldValueMessage(with: aiMessageResponse)
        }
    }
    
    func sendAIResponseStanza(message: Message, completion: ((Bool) -> Void)? = nil) {
        guard let fieldValueDetails = message.fieldValueDetails,
              let pickerValue = fieldValueDetails.pickerValue, let value = pickerValue.first,
              let apiName = fieldValueDetails.apiName, !apiName.isEmpty else {
            return
        }
        
        let toJid = settings?.toJid ?? ""
        let valueTag = "<value label=\"\(value.displayName)\">\(value.id)</value>"
        
        let normalStanza = """
        <message xmlns='jabber:client' from='\(userJID)' to='\(toJid)' id='\(message.id)' type='chat'>
            <fieldvalues xmlns='https://www.bolddesk.com/field-values' formMsgId='\(fieldValueDetails.formMsgId)'>
                <field type='\(fieldValueDetails.fieldValueType)' var='\(apiName)'>
                    \(valueTag)
                </field>
            </fieldvalues>
            <thread>\(conversationId)</thread>
            <chatdata xmlns='https://www.bolddesk.com/chat-data' mod='\(fieldValueDetails.mod.rawValue)' type='\(MessageType.fieldValues.rawValue)' requesterId='\(self.requesterId)'/>
            <request xmlns='urn:xmpp:receipts'></request>
            <store xmlns='urn:xmpp:hints' />
        </message>
        """
        
        let carbonStanza = """
        <message from='\(userJID)' to='\(userJID)' type='chat' xmlns="jabber:client">
            <forwarded xmlns='urn:xmpp:forward:0'>
                <message from='\(userJID)' to='\(toJid)' id='\(message.id)' type='chat' xmlns="jabber:client">
                    <fieldvalues xmlns='https://www.bolddesk.com/field-values' formMsgId='\(fieldValueDetails.formMsgId)'>
                        <field type='\(fieldValueDetails.fieldValueType)' var='\(apiName)'>
                            \(valueTag)
                        </field>
                    </fieldvalues>
                    <thread>\(conversationId)</thread>
                    <chatdata xmlns='https://www.bolddesk.com/chat-data' mod='\(fieldValueDetails.mod.rawValue)' type='\(MessageType.fieldValues.rawValue)' requesterId='\(self.requesterId)'/>
                    <request xmlns='urn:xmpp:receipts'></request>
                    <store xmlns='urn:xmpp:hints' />
                </message>
            </forwarded>
        </message>
        """
        
        // ✅ Send normal FIRST, then carbon
        send(carbonStanza, completion: nil)
        send(normalStanza, completion: completion)
    }
    
    func sendStickyButtonValueStanza(message: Message, completion: ((Bool) -> Void)? = nil) {
        let toJid = settings?.toJid ?? ""
        let label = escapeHTML(message.text ?? "")
        let value = escapeHTML(message.actionButtonValue ?? "")
        let acttypeAttr: String = {
            if let t = message.actionButtonType { return " acttype='\(t.rawValue)'" }
            return ""
        }()
        
        let normalStanza = """
        <message xmlns='jabber:client' from='\(userJID)' to='\(toJid)' id='\(message.id)' type='chat'>
            <fieldvalues xmlns='https://www.bolddesk.com/field-values'>
                <field ismasked='false' type='string'>
                    <value label='\(label)'>\(value)</value>
                </field>
            </fieldvalues>
            <thread>\(conversationId)</thread>
            <chatdata xmlns='https://www.bolddesk.com/chat-data'\(acttypeAttr) mod='\(ChatFormsModuleEnum.general.rawValue)' type='\(MessageType.fieldValues.rawValue)' requesterId='\(self.requesterId)'/>
            <request xmlns='urn:xmpp:receipts'></request>
            <store xmlns='urn:xmpp:hints' />
        </message>
        """
        
        let carbonStanza = """
        <message from='\(userJID)' to='\(userJID)' type='chat' xmlns="jabber:client">
            <forwarded xmlns='urn:xmpp:forward:0'>
                <message from='\(userJID)' to='\(toJid)' id='\(message.id)' type='chat' xmlns="jabber:client">
                    <fieldvalues xmlns='https://www.bolddesk.com/field-values'>
                        <field ismasked='false' type='string'>
                            <value label='\(label)'>\(value)</value>
                        </field>
                    </fieldvalues>
                    <thread>\(conversationId)</thread>
                    <chatdata xmlns='https://www.bolddesk.com/chat-data'\(acttypeAttr) mod='\(ChatFormsModuleEnum.general.rawValue)' type='\(MessageType.fieldValues.rawValue)' requesterId='\(self.requesterId)'/>
                    <request xmlns='urn:xmpp:receipts'></request>
                    <store xmlns='urn:xmpp:hints' />
                </message>
            </forwarded>
        </message>
        """
        
        // ✅ Send normal FIRST, then carbon
        send(carbonStanza, completion: nil)
        send(normalStanza, completion: completion)
    }
    
    private func manageAIMessages() {
        // Update all AI form messages to show as submitted
        for i in 0..<(self.messages.count) {
            if let formDetails = self.messages[i].formDetails {
                if formDetails.mod == .ai, !formDetails.isSubmitted {
                    self.messages[i].formDetails?.isSubmitted = true
                } else if formDetails.mod == .workflow && formDetails.type == .scheduler {
                    self.messages[i].formDetails?.isSubmitted = true
                }
            }
        }
    }
    
    private func getAssigneeFieldId(_ msgElement: XMLIndexer) -> Int? {
        guard let _ = msgElement["fieldvalues"].element else { return nil }

        for fieldElement in msgElement["fieldvalues"]["field"].all {
            if fieldElement.element?.attribute(by: "var")?.text == "chatAgentId" {
                let agentId = fieldElement["value"].all.first { $0.element?.attribute(by: "label")?.text == "NewValue" }?.element?.text
                if let id = agentId {
                    return Int(id)
                }
            }
        }

        return nil
    }
    
    private func handleAssigneeFieldUpdateNotification(_ msgElement: XMLIndexer, _ message: Message) {
        guard let _ = msgElement["fieldvalues"].element else { return }
        
        msgElement["fieldvalues"]["field"].all.forEach { fieldElement in
            if let varAttr = fieldElement.element?.attribute(by: "var")?.text, varAttr == "chatAgentId" {
                // Find <value label="NewValue">
                let newValue = fieldElement["value"].all.first { $0.element?.attribute(by: "label")?.text == "NewValue" }?.element?.text
                
                // Find <value label="OldValue">
                let oldValue = fieldElement["value"].all.first { $0.element?.attribute(by: "label")?.text == "OldValue" }?.element?.text
                
                if (!message.isArchived || message.isUnsyncMessage) {
                    isConvAssignedToAIAgent = msgElement["chatdata"].element?.attribute(by: "isAIAgent")?.text == "1" ? true : false
                }
                
                Task {
                    self.manageAiAgentThinkingIndicator(isAiAgentThinking: false)
                    let notificationText = await getAssigneeFieldUpdateNotificationText(widgetId: self.settings?.widgetId ?? "", oldValue: oldValue, newValue: newValue)
                    if let msgIndex = self.messages.firstIndex(where: { message.id == $0.id }) {
                        self.messages[msgIndex].text = notificationText
                        self.triggerScrollToBottom()
                    }
                }
            }
        }
    }
    
    /// Updates the visibility of the message footer based on user permissions and chat state.
    private func updateFooterVisibility() {
        // Early return if user is blocked
        guard !isUserBlocked else { return }
        
        Task { @MainActor in
            // Hide footer if conversation is closed or inactive
            if !isActive || isConvClosed {
                self.canShowMsgFooter = false
                return
            }
            
            do {
                // Check server permissions for sending messages
                let canSendMessage = try await chatAPIClient.getCanSendMessage(conversationId: conversationId)
                // Recheck after API call - state might have changed during the async operation
                if !isActive || isConvClosed {
                    canShowMsgFooter = false
                    return
                }
                canShowMsgFooter = canSendMessage
            } catch {
                NetworkLogger.log("❌ Failed to getCanSendMessage: \(error.localizedDescription)", level: .error)
            }
        }
    }
    
    func createNewConversationWithExistingRequesterDetails(_ userFirstMsg: Message) {
        self.isMsgFooterDisabled = true
        self.showSuggestionOptions = false
        let requestedBy = RequestedBy(name: "", email: (BDChatSDK.userToken ?? "").isEmpty ? "" : BDChatSDK.email ?? "", phoneNo: "", category: nil, timeZone: TimeZone.current.identifier)
        let confirmationMsg = WidgetStorageManager.getSetting(for: "cMsg", appKey: BDChatSDK.appKey, emailId: BDChatSDK.email)
        Task {
            let isConvStarted = await self.createNewConversation(requestedBy: requestedBy, requesterId: self.requesterId, requesterType: nil, requesterMessage: RequesterMessage(guid: userFirstMsg.id, message: userFirstMsg.text ?? ""), chatWelcomeMessageIds: self.chatWelomeMessageIds, selectedActionButtonValue: userFirstMsg.actionButtonValue, confirmationMessage: confirmationMsg, selectedActionButtonType: userFirstMsg.actionButtonType)
            if isConvStarted {
                self.isChatConnected = true
            } else {
                self.isMsgFooterDisabled = false
            }
        }
    }
    
    private func sendChatState(_ chatState: ChatStates) {
        let messageId = UUID().uuidString.lowercased()
        let xml = """
        <message id="\(messageId)" to="\(settings!.toJid)" from="\(userJID)" type="chat">
            <no-store xmlns="urn:xmpp:hints"/>
            <thread>\(conversationId)</thread>
            <chatstates xmlns="http://jabber.org/protocol/chatstates" state="\(chatState.rawValue)"/>
            <chatdata xmlns="https://www.bolddesk.com/chat-data" type="\(MessageType.chatStates.rawValue)" requesterId="\(requesterId)"/>
        </message>
        """
        send(xml)
    }
    
    /// Handles the user's typing indicator, including start, stop, and automatic timeout.
    /// - Parameters:
    ///   - shouldClearTimeout: If true, cancels any existing typing timer immediately.
    ///   - isTyping: True if the user is currently typing; false to stop the indicator.
    func manageUserTypingIndicator(shouldClearTimeout: Bool, isTyping: Bool = false) {
        if shouldClearTimeout {
            typingIndicatorTimer?.invalidate()
            typingIndicatorTimer = nil
            return
        }
        
        guard !isDisconnected else { return }
        
        if !isTyping && typingIndicatorTimer != nil {
            // User cleared input → send "typing stopped"
            typingIndicatorTimer?.invalidate()
            typingIndicatorTimer = nil
            sendChatState(.typingStopped)
        } else if isTyping && typingIndicatorTimer == nil {
            sendChatState(.composing)
            typingIndicatorTimer = Timer.scheduledTimer(withTimeInterval: AppConstant.typingIndicatorTimeout, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.typingIndicatorTimer = nil
                }
            }
        }
    }
    
    /// Handles an agent's typing indicator, optionally fetching agent info, with automatic timeout.
    /// - Parameters:
    ///   - isComposing: True if the agent is typing; false to clear the indicator.
    ///   - agentId: Optional agent ID to fetch avatar details for display.
    func manageAgentTypingIndicator(isComposing: Bool, agentId: Int? = nil) {
        guard isComposing else {
            typingAgentInfo = nil
            agentTypingIndicatorTimer?.invalidate()
            agentTypingIndicatorTimer = nil
            return
        }
        
        if agentTypingIndicatorTimer != nil {
            agentTypingIndicatorTimer?.invalidate()
            agentTypingIndicatorTimer = nil
        }
        
        if let agentId = agentId {
            Task {
                let typingAgentInfo = await ChatUtils.shared.getAgentAvatarDetailsById(agentId: agentId)
                if typingAgentInfo.id != -1 { self.typingAgentInfo = typingAgentInfo }
            }
        }
        
        agentTypingIndicatorTimer = Timer.scheduledTimer(withTimeInterval: AppConstant.typingIndicatorTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.agentTypingIndicatorTimer = nil
                self?.typingAgentInfo = nil
            }
        }
    }
    
    private func manageAiAgentThinkingIndicator(isAiAgentThinking: Bool, agentId: Int? = nil, keepFooterDisabled: Bool = false) {
        // Stop thinking state: clear indicator, optionally re-enable input, and cancel timeout
        guard isAiAgentThinking else {
            aiThinkingTimeoutTimer?.invalidate()
            aiThinkingTimeoutTimer = nil
            thinkingAiAgentInfo = nil
            if !keepFooterDisabled { isMsgFooterDisabled = false }
            return
        }
        
        // Start thinking: disable input and (re)start a 60s timeout to auto-enable input
        isMsgFooterDisabled = true
        
        // Fetch thinking agent info if provided
        if let agentId = agentId {
            Task {
                let aiThinkingAgentInfo = await ChatUtils.shared.getAgentAvatarDetailsById(agentId: agentId)
                if aiThinkingAgentInfo.id != -1 { self.thinkingAiAgentInfo = aiThinkingAgentInfo }
            }
        }
        
        // Reset any existing timer and schedule a new one for configured timeout
        aiThinkingTimeoutTimer?.invalidate()
        aiThinkingTimeoutTimer = Timer.scheduledTimer(withTimeInterval: AppConstant.aiThinkingTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                // If still waiting (no AI response), re-enable input but keep the thinking indicator visible
                self.isMsgFooterDisabled = false
                self.aiThinkingTimeoutTimer = nil
            }
        }
    }
    
    private func isOfflineAndAiNotEnabled() -> Bool {
        guard let settings = self.settings else { return true }
        return settings.isOffline && !settings.isAIEnabled
    }
    
    func areClientAPIUserInfoValid() -> Bool {
        let validationResult = validateClientAPIDetails()
        let isFieldsValid = validateFields()
        if !validationResult.isValid {
            if let notificationType = validationResult.notificationType {
                NotificationManager.shared.show(notificationType, shouldAutoHide: true)
                return false
            }
            return true
        }
        if !isFieldsValid {
            return false
        }
        return true
    }
    
    func validateFields() -> Bool {
        guard let fieldsDict = BDChatSDK.fields else { return true }

        for field in preChatFormFields {

            guard
                let control = FieldControlName(rawValue: field.fieldControlName),
                let rawValue = fieldsDict[field.apiName]
            else { continue }

            let apiName = field.apiName

            switch control {

            // ✅ CHECKBOX / RADIO → Bool or String
            case .checkBox, .radioButton:
                if let bool = rawValue as? Bool {
                    if !bool {
                        showInvalidPrefilledError(for: apiName)
                        return false
                    }
                } else if let str = rawValue as? String {
                    if str.lowercased() != "true" {
                        showInvalidPrefilledError(for: apiName)
                        return false
                    }
                }

            // ✅ TEXTBOX → String length
            case .textBox:
                guard let text = rawValue as? String else { break }

                if apiName != "contactName",
                   apiName != "contactPhoneNo",
                   text.count > AppConstant.singleLineTextBoxMaxLength {
                    showInvalidPrefilledError(for: apiName)
                    return false
                }

            // ✅ TEXTAREA → String length
            case .textArea:
                guard let text = rawValue as? String else { break }

                if text.count > AppConstant.customMultiLineTextBoxMaxLength {
                    showInvalidPrefilledError(for: apiName)
                    return false
                }

            // ✅ NUMERIC / DECIMAL → Int / Double / String
            case .numeric, .decimal:
                let number: Double?

                if let d = rawValue as? Double {
                    number = d
                } else if let i = rawValue as? Int {
                    number = Double(i)
                } else {
                    number = nil
                }

                guard let value = number else {
                    showInvalidPrefilledError(for: apiName)
                    return false
                }

                let validation = parseAdditionalValidation(
                        field.additionalFieldValidation
                    )

                if let max = validation?.maxValue, value > max {
                    showInvalidPrefilledError(for: apiName)
                    return false
                }

                if let min = validation?.minValue, value < min {
                    showInvalidPrefilledError(for: apiName)
                    return false
                }

            // ✅ REGEX → String only
            case .regex:
                guard
                    let text = rawValue as? String,
                    let pattern = field.regex,
                    isMatchingRegex(text, pattern: pattern)
                else {
                    showInvalidPrefilledError(for: apiName)
                    return false
                }

            // ✅ URL → String only
            case .url:
                guard
                    let text = rawValue as? String,
                    isMatchingRegex(text, pattern: AppConstant.urlRegex)
                else {
                    showInvalidPrefilledError(for: apiName)
                    return false
                }
            case .date:
                if !isValidDateValue(rawValue) {
                    showInvalidPrefilledError(for: apiName)
                    return false
                }

            case .datetime:
                if !isValidDateTimeValue(rawValue) {
                    showInvalidPrefilledError(for: apiName)
                    return false
                }
            default:
                break
            }
        }

        return true
    }

    func showInvalidPrefilledError(for apiName: String) {
        NotificationManager.shared.show(
            .custom(
                String(
                    format: ResourceManager.localized("invalid_prefilled_value"),
                    apiName
                ),
                .error
            ),
            shouldAutoHide: true
        )
    }

    func parseAdditionalValidation(
        _ jsonString: String?
    ) -> AdditionalFieldValidation? {

        guard
            let json = jsonString,
            !json.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            let data = json.data(using: .utf8)
        else {
            return nil
        }

        return try? JSONDecoder().decode(
            AdditionalFieldValidation.self,
            from: data
        )
    }

    func clearChatSession() {
        guard let settings = self.settings else { return }
        WidgetStorageManager.clearAllSettings(appKey: BDChatSDK.appKey, emailId: BDChatSDK.email)

        // Invalidate any running timers
        canShowStartNewConversationButton = true
        isChatCleared = true
        typingIndicatorTimer?.invalidate()
        typingIndicatorTimer = nil
        agentTypingIndicatorTimer?.invalidate()
        agentTypingIndicatorTimer = nil
        aiThinkingTimeoutTimer?.invalidate()
        aiThinkingTimeoutTimer = nil

        // Reset connection/auth state
        // Ensure next disconnect is handled silently again
        allowSilentReconnect = true
        isChatConnected = false
        isXMPPServerConnected = false
        isDisconnected = false
        conversationId = ""
        threadId = ""
        userJID = ""
        authToken = ""
        authStep = 0
        isOnline = true
        sessionId = ""

        // Reset requester
        requesterId = ""
        requesterType = 0

        // Reset chat state flags and UI
        isConvClosed = false
        isActive = true
        isUserBlocked = false
        isMsgFooterDisabled = false
        canShowMsgFooter = false // Corrected to false
        isFetchingArchivedMessages = false
        firstVisibleMsg = nil
        scrollTrigger = 0
        showSuggestionOptions = false
        isConvAssignedToAIAgent = nil
        canReopen = nil
        canShowOfflineForm = false
        canShowMsgListShimmer = false
        isLoading = false
        isInitialLoading = false
        isLoadingMoreConversations = false
        
        cancelTokenRefresh()

        // Clear agent/AI indicators
        lastMsgAgentId = nil
        lastMsgAgentInfo = nil
        typingAgentInfo = nil
        thinkingAiAgentInfo = nil
        offlineAgentInfo = nil

        // Clear data
        messages = []
        chatWelomeMessageIds = []
        
        // Clear conversation list and reset pagination
        conversationList = []
        page = 1
        hasMoreConversations = true
        
        // Clear streaming context
        streamingContextMap.removeAll()
        
        // Reset pre-chat form session
        preChatFormSessionId = UUID()

        // Reset notifications
        NotificationManager.shared.hide()
        
        // Clear composer text for new conversation
        self.messageText = ""
        
        // Close WebSocket connection if it exists
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        
        if isOfflineAndAiNotEnabled() {
            self.canShowOfflineForm = true
            Task {
                self.offlineAgentInfo = await ChatUtils.shared.getAgentAvatarDetailsById(agentId: getSystemUserId())
            }
            return
        }
        
        Task {
            // Clear and refetch Pre-chat form fields for a fresh session
            self.preChatFormFields = []
            do {
                self.preChatFormFields = try await self.chatAPIClient.getPreChatFormDetails()
                if let preDetails = settings.chatSettings.preChatFormDetails {
                    self.sortPreChatFormFields(preChatFormDetails: preDetails)
                }
            } catch {
                // Silently ignore; pre-chat will fallback to existing config
                print(error)
            }
            
            if WidgetStorageManager.getSetting(for: "isPolicyNoticeClosed", appKey: BDChatSDK.appKey, emailId: BDChatSDK.email) == nil {
                WidgetStorageManager.updateSetting(key: "isPolicyNoticeClosed", value: "false", appKey: BDChatSDK.appKey, emailId: BDChatSDK.email)
            }
            
            // Re-evaluate footer visibility and suggestions based on settings for a new session
            if settings.chatSettings.displayOption == .none || isOnlyUserFieldsAndPrefilled() {
                DispatchQueue.main.async { self.canShowMsgFooter = true }
                
                if let enableSuggestions = settings.chatSettings.enableSuggestions, enableSuggestions == true, let suggestions = settings.chatSettings.suggestions, !suggestions.isEmpty {
                    DispatchQueue.main.async { self.showSuggestionOptions = true }
                }
            }
            
            // For anonymous/email pre-filled widget, show the policy notice before the conversation has been started by the user.
            if let isPolicyNoticeClosed = WidgetStorageManager.getSetting(for: "isPolicyNoticeClosed", appKey: BDChatSDK.appKey, emailId: BDChatSDK.email), isPolicyNoticeClosed == "false" {
                DispatchQueue.main.async { self.canShowPrivacyPolicyNotice = true }
            }
            
            // Re-add welcome messages if they exist in settings
            let welcomeMessages = settings.chatSettings.welcomeMessages
            if !welcomeMessages.isEmpty {
                DispatchQueue.main.async {
                    for welcomeMsg in welcomeMessages {
                        let message = Message(from: "", userType: .agent, type: .text, deliveryStatus: .undelivered, isReceiptRequested: true, isArchived: false, text: welcomeMsg.message, textFormat: .html)
                        let welcomeMsgId = ChatWelcomeMessageId(id: welcomeMsg.id, guid: message.id)
                        self.chatWelomeMessageIds.append(welcomeMsgId)
                        self.messages.append(message)
                        Task {
                            let systemUserInfo = await ChatUtils.shared.getAgentAvatarDetailsById(agentId: self.getSystemUserId())
                            if let messageIndex = self.messages.firstIndex(where: { $0.id == message.id }) {
                                self.messages[messageIndex].agentInfo = systemUserInfo
                            }
                        }
                    }
                }
            }
        }
    }
    
//    func handleChatViewOpen() {
//        guard self.settings != nil else { return }
//        if WidgetStorageManager.isUserExistAlready(appKey: BDChatSDK.appKey, emailId: BDChatSDK.email) {
//            self.updateSeenStatus()
//        } else if !WidgetStorageManager.isRequesterDetailsAvailableInStorage(appKey: BDChatSDK.appKey, emailId: BDChatSDK.email) {
//            Task {
//                do {
//                    defer { canShowMsgListShimmer = false }
//                    canShowMsgListShimmer = true
//                    let offlineStatusResponse = try await chatAPIClient.getOfflineStatus()
//                    self.settings!.isOffline = offlineStatusResponse.isOffline
//                    self.settings!.isAIEnabled = offlineStatusResponse.aiAgentEnabled
//                    if isOfflineAndAiNotEnabled() {
//                        self.canShowOfflineForm = true
//                        self.offlineAgentInfo = await ChatUtils.shared.getAgentAvatarDetailsById(agentId: getSystemUserId())
//                    } else {
//                        self.canShowOfflineForm = false
//                        
//                        // Enable msg footer and suggestion options(if present) for anonymous/email-configured chat
//                        if settings!.chatSettings.displayOption == .none || isOnlyUserFieldsAndPrefilled() {
//                            await MainActor.run { canShowMsgFooter = true }
//                            
//                            if let enableSuggestions = settings?.chatSettings.enableSuggestions, enableSuggestions == true, let suggestions = settings?.chatSettings.suggestions, !suggestions.isEmpty {
//                                self.showSuggestionOptions = true
//                            }
//                        }
//                        
//                        // Append the welcome messages
//                        self.messages = []
//                        self.chatWelomeMessageIds = []
//                        let welcomeMessages = settings!.chatSettings.welcomeMessages
//                        if !welcomeMessages.isEmpty {
//                            await MainActor.run {
//                                for welcomeMsg in welcomeMessages {
//                                    let message = Message(from: "", userType: .agent, type: .text, deliveryStatus: .undelivered, isReceiptRequested: true, isArchived: false, text: welcomeMsg.message, textFormat: .html)
//                                    let welcomeMsgId = ChatWelcomeMessageId(id: welcomeMsg.id, guid: message.id)
//                                    self.chatWelomeMessageIds.append(welcomeMsgId)
//                                    self.messages.append(message)
//                                    Task {
//                                        let systemUserInfo = await ChatUtils.shared.getAgentAvatarDetailsById(agentId: getSystemUserId())
//                                        if let messageIndex = self.messages.firstIndex(where: { $0.id == message.id }) {
//                                            self.messages[messageIndex].agentInfo = systemUserInfo
//                                        }
//                                    }
//                                }
//                            }
//                        }
//                    }
//                } catch {
//                    NotificationManager.shared.show(.somethingWentWrong)
//                }
//            }
//        }
//    }
//    
    func handlePolicyNoticeClose() {
        self.canShowPrivacyPolicyNotice = false
        WidgetStorageManager.updateSetting(key: "isPolicyNoticeClosed", value: "true", appKey: BDChatSDK.appKey, emailId: BDChatSDK.email)
    }
    
    func sortPreChatFormFields(preChatFormDetails: PreChatFormDetails) {
        // Create a map: fieldId → fieldOrder (from backend configuration)
        let orderMap = preChatFormDetails.fields.reduce(into: [Int: Int]()) { dict, config in
            dict[config.fieldId] = config.fieldOrder
        }
        
        // Sort the actual preChatFormFields using the configured order
        self.preChatFormFields.sort { fieldA, fieldB in
            let orderA = orderMap[fieldA.fieldId] ?? Int.max
            let orderB = orderMap[fieldB.fieldId] ?? Int.max
            return orderA < orderB
        }
    }
    
    func requestEmailTranscript() {
        let emailTranscriptPayload = EmailTranscriptPayload(appToken: ChatWidgetAPIPaths.appToken, conversationId: self.conversationId, requesterId: self.requesterId)
        Task {
            do {
                let response  = try await self.chatAPIClient.sendEmailTranscript(emailTranscriptPayload: emailTranscriptPayload)
                NotificationManager.shared.show(response.message, style: .success)
            } catch {
                guard
                    let nsError = error as? NSError,
                    let data = (nsError.userInfo["responseString"] as? String)?.data(using: .utf8)
                            ?? nsError.userInfo["responseBody"] as? Data,
                    let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let errors = json["errors"] as? [[String: Any]]
                else {
                    NotificationManager.shared.show(.somethingWentWrong, shouldAutoHide: true)
                    return
                }
                                
                if nsError.code == 401 {
                    NotificationManager.shared.show(.accessDenied)
                } else if errors.contains(where: { $0["field"] as? String == "email" && $0["errorType"] as? String == "Required" }) {
                    NotificationManager.shared.show(.emailAddressNotConfigured)
                } else {
                    NotificationManager.shared.show(.somethingWentWrong, shouldAutoHide: true)
                }
            }
        }
    }
    
    func endChat(aiResponseValue: AIResponseButtonEnum? = nil) {
        isLoading = true

        Task {
            do {
                _ = try await chatAPIClient.endChat(
                    endChatPayload: EndChatPayload(
                        appToken: ChatWidgetAPIPaths.appToken,
                        conversationId: conversationId,
                        requesterId: requesterId
                    ),
                    aiResponseValue: aiResponseValue?.rawValue
                )

                isLoading = false   // ✅ success
            } catch {
                isLoading = false   // ✅ failure

                if let nsError = error as NSError?, nsError.code == 401 {
                    NotificationManager.shared.show(.accessDenied)
                } else {
                    NotificationManager.shared.show(.somethingWentWrong)
                }
            }
        }
    }

    
    func isPreChatFormContainsNonUserFields() -> Bool {
        let nonUserFields = self.preChatFormFields.filter { !AppConstant.userDetailsFieldApi.contains($0.apiName) }
        return nonUserFields.isEmpty ? false : true
    }
    
//    func isClientEmailConfigured() -> Bool {
//        guard self.settings?.chatSettings.displayOption == ChatValidation.none else { return false }
//        if let email = BoldDeskChatSDK.email {
//            return !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
//        } else {
//            return false
//        }
//    }
    
    // Returns true if pre-chat form contains only user fields (emailId, contactName, contactPhoneNo)
    // and all those present fields are already prefilled in BoldDeskChatSDK.
    func isOnlyUserFieldsAndPrefilled() -> Bool {

        // 1️⃣ No fields → do not hide
        if preChatFormFields.isEmpty { return false }

        let customFields = BDChatSDK.fields ?? [:]

        // Helper: validate value
        func isValidValue(_ value: Any?) -> Bool {
            switch value {
            case let str as String:
                return !str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

            case let arr as [Any]:
                return !arr.isEmpty

            case let _ as Int:
                return true

            case let _ as Double:
                return true

            case let _ as Bool:
                return true

            default:
                return false
            }
        }

        // 2️⃣ Validate ALL preChatFormFields
        for field in preChatFormFields {

            let api = field.apiName

            switch api {

            // 🔹 User fields
            case "emailId":
                if !isValidValue(BDChatSDK.email) { return false }

            case "contactName":
                if !isValidValue(BDChatSDK.name) { return false }

            case "contactPhoneNo":
                if !isValidValue(BDChatSDK.phoneNo) { return false }

            // 🔹 Custom fields (from BDChatSDK.fields)
            default:
                guard customFields.keys.contains(api) else {
                    return false   // field not provided at all
                }

                if !isValidValue(customFields[api]) {
                    return false
                }
            }
        }

        // 3️⃣ ALL fields are prefilled
        return true
    }

    
    // MARK: - Scheduler
    func handleScheduleEvent(scheduleEventURL: String, msgIndex: Int) {
        Task { [weak self] in
            guard let self = self else { return }
            do {
                _ = try await self.chatAPIClient.scheduleEvent(conversationId: self.conversationId, scheduleEventUrl: scheduleEventURL)
                self.messages[msgIndex].formDetails?.isSubmitted = true
            } catch {
                NotificationManager.shared.show(.somethingWentWrong, shouldAutoHide: true)
            }
        }
    }
    
    // MARK: - Token Refresh Global Timer Helpers
    private func scheduleTokenRefresh(after seconds: TimeInterval) {
        // Ensure only one timer exists
        tokenRefreshTimer?.invalidate()
        tokenRefreshTimer = Timer.scheduledTimer(withTimeInterval: max(0, seconds), repeats: false) { [weak self] _ in
            Task { _ = await self?.updateAuthToken() }
        }
    }
    
    private func cancelTokenRefresh() {
        tokenRefreshTimer?.invalidate()
        tokenRefreshTimer = nil
    }
    
    func getSystemUserId() -> Int {
        if settings?.aiSettings.enableAIAgent == true && settings?.aiSettings.handoverMode == 1, let agentId = settings?.aiSettings.aiAgentUserId {
            return agentId
        }
        return AppConstant.systemUserId
    }
    
    func resolvedCategoryId() -> String? {
        let apiName = "chatCategoryId"

        guard preChatFormFields.contains(where: { $0.apiName == apiName }) else {
            return nil
        }

        guard let rawValue = BDChatSDK.fields?[apiName] else {
            return nil
        }

        if let strValue = rawValue as? String {
            return strValue.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let intValue = rawValue as? Int {
            return String(intValue)
        }

        return nil
    }
    
    func downloadFile(completion: @escaping () -> Void) {
        
        guard let url = URL(string: ChatWidgetAPIPaths.getDownloadTranscript(
            conversationId: self.conversationId,
            widgetId: self.settings?.widgetId ?? "",
            requesterId: self.requesterId
        )) else {
            DispatchQueue.main.async {
                NotificationManager.shared.show(.somethingWentWrong, shouldAutoHide: true)
                completion()
            }
            return
        }

        URLSession.shared.downloadTask(with: url) { tempURL, response, error in
            
            defer {
                DispatchQueue.main.async { completion() }
            }
            
            if let error = error {
                NetworkLogger.log(
                    """
                    URL: \(url.absoluteString)
                    Method: \("GET")
                    Response: \(error)
                    """,
                    level: .error
                )
                DispatchQueue.main.async {
                    NotificationManager.shared.show(.somethingWentWrong, shouldAutoHide: true)
                }
                return
            }
            
            guard let tempURL = tempURL,
                  let response = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    NotificationManager.shared.show(.somethingWentWrong, shouldAutoHide: true)
                }
                return
            }

            // MARK: - Check HTTP status code
            let statusCode = response.statusCode
            if statusCode == 403 {
                DispatchQueue.main.async {
                    NotificationManager.shared.show(.accessDenied, shouldAutoHide: true)
                }
                return
            } else if statusCode < 200 || statusCode >= 300 {
                // Any other non-success status code
                DispatchQueue.main.async {
                    NotificationManager.shared.show(.somethingWentWrong, shouldAutoHide: true)
                }
                return
            }

            // MARK: - Extract filename
            let fileName = self.conversationId

            // MARK: - Force correct extension (.txt)
            let finalFileName: String = {
                
                // Format date -> 9-4-2026
                let formatter = DateFormatter()
                formatter.dateFormat = "d-M-yyyy"
                let dateString = formatter.string(from: Date())
                
                // Base name (remove extension)
                let base = "Conversation_\(self.conversationId)_\(dateString)"
                
                return base + ".txt"
            }()

            // MARK: - Save in Documents (more stable than tmp)
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let destinationURL = documentsURL.appendingPathComponent(finalFileName)

            do {
                // Remove old file if exists
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }

                try FileManager.default.copyItem(at: tempURL, to: destinationURL)

                DispatchQueue.main.async {
                    NotificationManager.shared.show(.transcriptDownloadedSuccessfully, shouldAutoHide: true)
                    openFile(destinationURL)
                }

            } catch {
                NetworkLogger.log(
                    """
                    URL: \(url.absoluteString)
                    Method: \("GET")
                    Response: \(error)
                    """,
                    level: .error
                )
                DispatchQueue.main.async {
                    NotificationManager.shared.show(.somethingWentWrong, shouldAutoHide: true)
                }
            }
        }.resume()
    }
}
