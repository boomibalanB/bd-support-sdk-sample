import SwiftUI

enum ChatWidgetAPIPaths {
    static var appToken: String { WidgetStorageManager.getAppToken() ?? "" }
    static var base: String { WidgetStorageManager.getBrandUrl() ?? "" }
    static let version = "v1"
    static var api: String { "\(base)/chatsdk-api/\(version)/" }

    static var settingAPI: String { "\(base)chatwidget-api/widget/\(version)/" }

    static func getWidgetSettings(appToken: String) -> String {
        return "\(api)widget?appToken=\(appToken)&culture=\(AppConstant.languageCode)"
    }

    static func createConversation() -> String {
        return "\(api)conversations?culture=\(DeviceConfig.languageCode)"
    }

    static func getVersion(time: Int) -> String {
        return "\(api)server/version?time=\(time)"
    }

    static func getToken(
        requesterId: String,
        requesterType: Int,
        conversationId: String,
        sessionId: String?,
        email: String?,
        userToken: String?
        
        
    ) -> String {
        var urlString = "\(api)server/auth_token?requesterId=\(requesterId)&requesterType=\(requesterType)&conversationId=\(conversationId)"
        
        if let sessionId = sessionId {
            urlString += "&sessionId=\(sessionId)"
        }
        
        if let email = email {
            urlString += "&email=\(email)"
        }
        
        if let userToken = userToken {
            urlString += "&userToken=\(userToken)"
        }
        
        urlString += "&AppToken=\(appToken)"
        
        return urlString
    }

    static func uploadAttachment(isWorkflow: Bool = false) -> String {
        if isWorkflow {
            return "\(api)attachment?isWorkflowRequest=true"
        }
        else{
            return "\(api)attachment"
        }
    }

    static func uploadInlineImage(isWorkflow: Bool = false) -> String {
        if isWorkflow {
            return "\(api)attachment/inline?isWorkflowRequest=true"
        }
        else{
            return "\(api)attachment/inline"
        }
    }

    static func getConversationStatusInfo(conversationId: String) -> String {
        return "\(api)conversations/\(conversationId)/state"
    }

    static func getAgentInfo(agentId: String) -> String {
        return "\(api)agents/\(agentId)?AppToken=\(appToken)"
    }

    static func getOnlineAgents() -> String {
        return "\(api)agents/online?appToken=\(appToken)"
    }

    static func getLastMsgAgentDetails(conversationId: String) -> String {
        return "\(api)agents/assigned/\(conversationId)"
    }

    static func getDropdownOptions(conversationId: String, apiName: String)
        -> String
    {
        return
            "\(api)conversations/\(conversationId)/collection/\(apiName)/field-options?culture=\(DeviceConfig.languageCode)"
    }

    static func endChat() -> String {
        return "\(api)conversations/end_chat"
    }

    static func sendEmailTranscript() -> String {
        return "\(api)conversations/email_transcript"
    }

    static func getCanSendMessage(conversationId: String) -> String {
        return "\(api)conversations/\(conversationId)/can_send_message"
    }

    static func getOfflineStatus() -> String {
        return "\(api)widget/offline_status?appToken=\(appToken)"
    }

    static func deleteDeviceToken(deviceToken: String) -> String {
        return "\(api)widget/device_token?deviceToken=\(deviceToken)"
    }

    static func getPreChatFormDetails() -> String {
        return
            "\(api)widget/\(appToken)/prechat_fields?culture=\(DeviceConfig.languageCode)"
    }

    static func getPrechatDropdownOptions(apiName: String) -> String {
        print(DeviceConfig.languageCode)
        return
            "\(base)/\(DeviceConfig.languageCode)/widget/field_options/collection/\(apiName)/options/?requiresCounts=true"
    }

    static func getPreChatFormFieldDependencies() -> String {
        return
            "\(api)widget/field_dependency?culture=\(DeviceConfig.languageCode)"
    }

    static func scheduleEvent(conversationId: String, scheduleEventURL: String)
        -> String
    {
        return
            "\(api)conversations/schedule_event?conversationId=\(conversationId)&scheduleEventURL=\(scheduleEventURL)"
    }
    
    static func getConversationList() -> String {
        return "\(api)conversations/list?culture=\(DeviceConfig.languageCode)"
    }
    
    static func getConversationInitiationStatus() -> String {
        return "\(api)conversations/conversation_initiation_status?culture=\(DeviceConfig.languageCode)"
    }
    
    static func getConversationDetails(conversationId: String) -> String {
        return "\(api)conversations/details?conversationId=\(conversationId)"
    }

    // MARK: - Knowledge Base API Paths
    static func getKBCategories(widgetId: String, page: Int = 1, perPage: Int = 4) -> String {
        let wid = widgetId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
        return "\(base)/\(DeviceConfig.languageCode)/widget/\(wid)/categories/?requiresCounts=true&page=\(page)&perPage=\(perPage)&isChatWidgetRequest=true"
    }
    static func getKBSearchArticles(widgetId: String, searchText: String? = nil) -> String {
        if let search = searchText,
           !search.isEmpty {
            let encodedSearch = search.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
            return "\(base)/\(DeviceConfig.languageCode)/widget/\(widgetId)/search/\(encodedSearch)?requiresCounts=true&page=1&perPage=999&isChatWidgetRequest=true"
        }
        return ""
    }
    static func getKBArticles(widgetId: String, categoryId: Int? = nil, sectionId: Int? = nil, searchText: String? = nil) -> String {
        
        let wid = widgetId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
        let lang = DeviceConfig.languageCode
        
        let trimmedSearch = searchText?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // ✅ CASE 1: Only search (no categoryId & sectionId)
        if categoryId == nil,
           sectionId == nil,
           let search = trimmedSearch,
           !search.isEmpty {
            
            let encodedSearch = search.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
            
            return "\(base)/\(lang)/widget/\(wid)/search/\(encodedSearch)?requiresCounts=true&page=1&perPage=999&isChatWidgetRequest=true"
        }
        
        // ✅ CASE 2: Default (section_article/list)
        var url = "\(base)/\(lang)/widget/\(wid)/section_article/list?"
        
        if let categoryId = categoryId {
            url += "categoryid=\(categoryId)&"
        }
        
        if let sectionId = sectionId {
            url += "sectionid=\(sectionId)&"
        }
        
        if let search = trimmedSearch, !search.isEmpty {
            let encoded = search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            url += "searchtext=\(encoded)&"
        }
        
        url += "requiresCounts=true&page=1&perPage=999&isChatWidgetRequest=true"
        
        return url
    }
    
    static func getUpdateToken() -> String {
        return "\(api)widget/device_token"
    }
    
    static func getDownloadTranscript(conversationId: String, widgetId: String, requesterId: String) -> String {
        return "\(api)conversations/\(conversationId)/download_transcript?appToken=\(appToken)&requesterId=\(requesterId)"
    }
}

struct ChatAPIClient {
    func fetchDataFromAPI<T: Decodable>(
        url: String,
        method: String,
        requestBody: Data? = nil,
        customHeaders: [String: String]? = nil,
        includeDefaultHeaders: Bool = true,
        responseType: T.Type
    ) async throws -> T {

        guard let apiURL = URL(string: url) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: apiURL)
        request.httpMethod = method

        if includeDefaultHeaders {
            request.setValue(
                "application/json",
                forHTTPHeaderField: "Content-Type"
            )
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            if let appInfo = AppConstant.applicationInfo,
                let json = jsonString(from: appInfo)
            {
                request.setValue(json, forHTTPHeaderField: "User-Agent")
            }
        }

        // Add custom headers
        customHeaders?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Set body if present
        if let body = requestBody {
            request.httpBody = body
        }

        var data: Data
        var response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            ErrorLogs.logErrors(
                data: error,
                exceptionPage: "ChatAPIClient.fetchDataFromAPI",
                isCatchError: true
            )
            throw error
        }

        // Single-place logging of the response (success or error)
        let httpResponseOpt = response as? HTTPURLResponse
        let statusCode = httpResponseOpt?.statusCode ?? -1
        let responseString = String(data: data, encoding: .utf8) ?? ""

        var requestBodyString = ""
        if let requestBody = requestBody {
            if let jsonObj = try? JSONSerialization.jsonObject(with: requestBody, options: []),
               let prettyData = try? JSONSerialization.data(withJSONObject: jsonObj, options: [.prettyPrinted]),
               let pretty = String(data: prettyData, encoding: .utf8) {
                requestBodyString = pretty
            } else if let str = String(data: requestBody, encoding: .utf8) {
                requestBodyString = str
            } else {
                requestBodyString = "<binary data: \(requestBody.count) bytes>"
            }
        }

        NetworkLogger.log(
            """
            URL: \(apiURL.absoluteString)
            Method: \(method)
            Status: \(statusCode)
            Request Body: \(requestBodyString)
            Response: \(responseString)
            """,
            level: statusCode == 200 ? .response : .error
        )

        guard let httpResponse = httpResponseOpt, httpResponse.statusCode == 200
        else {
            let message = HTTPURLResponse.localizedString(
                forStatusCode: statusCode
            ).capitalized
            var userInfo: [String: Any] = [
                NSLocalizedDescriptionKey:
                    "Request failed with status code \(statusCode): \(message)"
            ]

            if !data.isEmpty {
                userInfo["responseBody"] = data
                userInfo["responseString"] = responseString
            }

            ErrorLogs.logErrors(
                data: responseString,
                exceptionPage: "ChatAPIClient.fetchDataFromAPI",
                isCatchError: false,
                statusCode: statusCode
            )

            throw NSError(
                domain: "HTTPError",
                code: statusCode,
                userInfo: userInfo
            )
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            ErrorLogs.logErrors(
                data: error,
                exceptionPage: "ChatAPIClient.fetchDataFromAPI",
                isCatchError: true
            )
            throw error
        }
    }

    func getWidgetSettings() async throws -> Settings {
        let endpoint = ChatWidgetAPIPaths.getWidgetSettings(
            appToken: ChatWidgetAPIPaths.appToken
        )
        let settingsResponse = try await fetchDataFromAPI(
            url: endpoint,
            method: "GET",
            responseType: SettingsResponse.self
        )

        guard let settingsData = settingsResponse.settings.data(using: .utf8)
        else {
            throw NSError(
                domain: "DecodingError",
                code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Failed to convert settings string to Data"
                ]
            )
        }

        let settingsDataJson = try JSONDecoder().decode(
            SettingsString.self,
            from: settingsData
        )
        let settings = Settings(
            chatSettings: settingsDataJson.chatSettings,
            widgetSettings: settingsDataJson.widgetSettings,
            generalSettings: settingsResponse.generalSettings,
            chatPrivacyPolicySettings: settingsDataJson
                .chatPrivacyPolicySettings,
            offlineSettings: settingsDataJson.offlineSettings,
            aiSettings: settingsDataJson.aiSettings,
            widgetId: settingsResponse.widgetId,
            toJid: settingsResponse.toJid,
            api: settingsResponse.api,
            chatServer: settingsResponse.chatServer,
            isOffline: settingsResponse.isOffline,
            isAIEnabled: settingsResponse.isAIEnabled,
            notificationAudioURL: settingsResponse.notificationAudioURL,
            brandName: settingsResponse.brandName,
            brandOptionId: settingsResponse.brandOptionId
        )
        Color.updateColors(from: settings.widgetSettings.colorPalette)
        DeviceConfig.languageCode = settingsResponse.language ?? "en"
        AppConstant.languageCode = settingsResponse.language ?? "en"
        return settings
    }

    // MARK: - Knowledge Base API Methods
    func getKBCategories(widgetId: String, page: Int = 1, perPage: Int = 4) async throws -> KBCategoriesResponse {
        let endpoint = ChatWidgetAPIPaths.getKBCategories(widgetId: widgetId, page: page, perPage: perPage)
        return try await fetchDataFromAPI(
            url: endpoint,
            method: "GET",
            responseType: KBCategoriesResponse.self
        )
    }
    func getKBArticles(widgetId: String, categoryId: Int? = nil, sectionId: Int? = nil, searchText: String? = nil) async throws -> KBArticlesResponse {
        let endpoint = ChatWidgetAPIPaths.getKBArticles(widgetId: widgetId, categoryId: categoryId, sectionId: sectionId, searchText: searchText)
        return try await fetchDataFromAPI(
            url: endpoint,
            method: "GET",
            responseType: KBArticlesResponse.self
        )
    }
    
    func getKBSearchArticles(widgetId: String, searchText: String? = nil) async throws -> [KBSearchArticle] {
        let endpoint = ChatWidgetAPIPaths.getKBSearchArticles(widgetId: widgetId, searchText: searchText)
        return try await fetchDataFromAPI(
            url: endpoint,
            method: "GET",
            responseType: [KBSearchArticle].self
        )
    }

    func createConversation(requestPayload: OpenConversationRequest)
        async throws -> ConversationInfo
    {
        var payload = requestPayload
        payload.userDeviceToken = UserDeviceToken(
            appTypeId: 2,
            deviceToken: BDChatSDK.fcmToken ?? "empty",
            appId: WidgetStorageManager.getAppToken() ?? "",
            additionalConfig:
                AdditionalConfig(
                    deviceName: AppConstant.deviceName
                )
        )
        let endpoint = ChatWidgetAPIPaths.createConversation()
        let jsonData = try JSONEncoder().encode(payload)

        return try await fetchDataFromAPI(
            url: endpoint,
            method: "POST",
            requestBody: jsonData,
            responseType: ConversationInfo.self
        )
    }

    func getVersion() async throws -> VersionInfo {
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let endpoint = ChatWidgetAPIPaths.getVersion(time: timestamp)

        return try await fetchDataFromAPI(
            url: endpoint,
            method: "GET",
            responseType: VersionInfo.self
        )
    }

    func getToken(
        requesterId: String,
        requesterType: Int,
        conversationId: String,
        sessionId: String?,
        email: String?,
        userToken: String?
        
    ) async throws -> TokenInfo {
        let endpoint = ChatWidgetAPIPaths.getToken(
            requesterId: requesterId,
            requesterType: requesterType,
            conversationId: conversationId,
            sessionId: sessionId,
            email: email,
            userToken: userToken
            
        )
        return try await fetchDataFromAPI(
            url: endpoint,
            method: "POST",
            responseType: TokenInfo.self
        )
    }

    func getConversationStatusInfo(conversationId: String) async throws
        -> ConversationStatusInfo
    {
        let endpoint = ChatWidgetAPIPaths.getConversationStatusInfo(
            conversationId: conversationId
        )
        return try await fetchDataFromAPI(
            url: endpoint,
            method: "GET",
            responseType: ConversationStatusInfo.self
        )
    }

    func endChat(endChatPayload: EndChatPayload, aiResponseValue: String?)
        async throws -> EndChatResponse
    {
        let endpoint =
            aiResponseValue != nil
            ? ChatWidgetAPIPaths.endChat()
                + "?aiResponseValue=\(aiResponseValue!)"
            : ChatWidgetAPIPaths.endChat()
        let jsonData = try JSONEncoder().encode(endChatPayload)

        return try await fetchDataFromAPI(
            url: endpoint,
            method: "PUT",
            requestBody: jsonData,
            responseType: EndChatResponse.self
        )
    }

    func sendEmailTranscript(emailTranscriptPayload: EmailTranscriptPayload)
        async throws -> EmailTranscriptResponse
    {
        let endpoint = ChatWidgetAPIPaths.sendEmailTranscript()
        let jsonData = try JSONEncoder().encode(emailTranscriptPayload)

        return try await fetchDataFromAPI(
            url: endpoint,
            method: "PUT",
            requestBody: jsonData,
            responseType: EmailTranscriptResponse.self
        )
    }

    func getCanSendMessage(conversationId: String) async throws -> Bool {
        let endpoint = ChatWidgetAPIPaths.getCanSendMessage(
            conversationId: conversationId
        )
        return try await fetchDataFromAPI(
            url: endpoint,
            method: "GET",
            responseType: Bool.self
        )
    }

    func getAgentInfo(agentId: String) async throws -> AgentInfo {
        let endpoint = ChatWidgetAPIPaths.getAgentInfo(agentId: agentId)
        return try await fetchDataFromAPI(
            url: endpoint,
            method: "GET",
            responseType: AgentInfo.self
        )
    }

    func getOnlineAgents() async throws -> OnlineAgentsResponse {
        let endpoint = ChatWidgetAPIPaths.getOnlineAgents()
        return try await fetchDataFromAPI(
            url: endpoint,
            method: "GET",
            responseType: OnlineAgentsResponse.self
        )
    }

    func getLastMsgAgentDetails(conversationId: String) async throws
        -> AgentInfo
    {
        let endpoint = ChatWidgetAPIPaths.getLastMsgAgentDetails(
            conversationId: conversationId
        )
        return try await fetchDataFromAPI(
            url: endpoint,
            method: "GET",
            responseType: AgentInfo.self
        )
    }

    func getOfflineStatus() async throws -> OfflineStatusResponse {
        let endpoint = ChatWidgetAPIPaths.getOfflineStatus()
        return try await fetchDataFromAPI(
            url: endpoint,
            method: "GET",
            responseType: OfflineStatusResponse.self
        )
    }

    func getPreChatFormDetails() async throws -> [PreChatFormField] {
        let endpoint = ChatWidgetAPIPaths.getPreChatFormDetails()
        return try await fetchDataFromAPI(
            url: endpoint,
            method: "GET",
            responseType: [PreChatFormField].self
        )
    }

    func getPreChatFormFieldDependencies() async throws -> [FieldDependency] {
        let endpoint = ChatWidgetAPIPaths.getPreChatFormFieldDependencies()
        return try await fetchDataFromAPI(
            url: endpoint,
            method: "GET",
            responseType: [FieldDependency].self
        )
    }

    func scheduleEvent(conversationId: String, scheduleEventUrl: String)
        async throws -> ScheduleEventResponse
    {
        let endpoint = ChatWidgetAPIPaths.scheduleEvent(
            conversationId: conversationId,
            scheduleEventURL: scheduleEventUrl
        )
        return try await fetchDataFromAPI(
            url: endpoint,
            method: "GET",
            responseType: ScheduleEventResponse.self
        )
    }

    func deleteDeviceToken(deviceToken: String) async throws
        -> DeleteDeviceTokenResponse
    {
        let endpoint = ChatWidgetAPIPaths.deleteDeviceToken(
            deviceToken: deviceToken
        )
        return try await fetchDataFromAPI(
            url: endpoint,
            method: "DELETE",
            responseType: DeleteDeviceTokenResponse.self
        )
    }
    
    func getConversationList(payload: ConversationListPayload)
        async throws -> ConversationListResponse
    {
        let endpoint = ChatWidgetAPIPaths.getConversationList()
        let jsonData = try JSONEncoder().encode(payload)

        return try await fetchDataFromAPI(
            url: endpoint,
            method: "POST",
            requestBody: jsonData,
            responseType: ConversationListResponse.self
        )
    }
    
    func getConversationInitiationStatus(payload: ConversationInitiationStatusPayload)
        async throws -> ConversationInitiationStatusResponse
    {
        let endpoint = ChatWidgetAPIPaths.getConversationInitiationStatus()
        let jsonData = try JSONEncoder().encode(payload)

        return try await fetchDataFromAPI(
            url: endpoint,
            method: "POST",
            requestBody: jsonData,
            responseType: ConversationInitiationStatusResponse.self
        )
    }
    
    func getConversationDetails(conversationId: String) async throws -> Conversation {
        let endpoint = ChatWidgetAPIPaths.getConversationDetails(conversationId: conversationId)
        
        return try await fetchDataFromAPI(
            url: endpoint,
            method: "POST",
            responseType: Conversation.self
        )
    }
    
    func updateDeviceToken(payload: DeviceTokenRequest) async throws
        -> DeleteDeviceTokenResponse
    {
        let endpoint = ChatWidgetAPIPaths.getUpdateToken()
        let httpBody = try JSONEncoder().encode(payload)
        return try await fetchDataFromAPI(
            url: endpoint,
            method: "POST",
            requestBody: httpBody,
            responseType: DeleteDeviceTokenResponse.self
        )
    }


    func uploadFile(
        to uploadURL: URL,
        file: FileInfo,
        conversationId: String,
        requesterId: String,
        requesterType: Int
    ) async throws -> AttachmentInfo {
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type"
        )

        var body = Data()

        func appendField(name: String, value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append(
                "Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(
                    using: .utf8
                )!
            )
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        // Append text fields
        appendField(name: "conversationId", value: conversationId)
        appendField(name: "requesterId", value: requesterId)
        appendField(name: "AppToken", value: ChatWidgetAPIPaths.appToken)
        appendField(name: "requesterType", value: String(requesterType))

        // Append file (handle security-scoped URLs on real devices)
        var didStartAccessing = false
        var fileData: Data?
        if file.url.startAccessingSecurityScopedResource() {
            didStartAccessing = true
        }
        defer {
            if didStartAccessing {
                file.url.stopAccessingSecurityScopedResource()
            }
        }
        do {
            fileData = try Data(contentsOf: file.url)
        } catch {
            throw NSError(
                domain: "FileAccessError",
                code: -2,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Unable to read selected file data. Please try a different file."
                ]
            )
        }
        if let fileData = fileData {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append(
                "Content-Disposition: form-data; name=\"uploadFiles\"; filename=\"\(file.name)\"\r\n"
                    .data(using: .utf8)!
            )
            body.append(
                "Content-Type: \(file.type)\r\n\r\n".data(using: .utf8)!
            )
            body.append(fileData)
            body.append("\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200
        else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let message = HTTPURLResponse.localizedString(
                forStatusCode: statusCode
            ).capitalized
            throw NSError(
                domain: "HTTPError",
                code: statusCode,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Request failed with status code \(statusCode): \(message)"
                ]
            )
        }

        return try JSONDecoder().decode(AttachmentInfo.self, from: data)
    }
}
