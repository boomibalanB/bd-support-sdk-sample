import SwiftUI
import UIKit

struct ChatView: View {
    let conversationId: String
    @Environment(\.presentationMode) private var presentationMode
    @ObservedObject var viewModel: ChatViewModel
    @State private var activeAlert: ActiveAlert? = nil
    @State private var showHeaderMoreOptions: Bool = false

    private var shouldShowMoreOptions: Bool {
        viewModel.isChatConnected
            && (viewModel.settings?.widgetSettings.enableNotificationSound
                == true
                || viewModel.settings?.widgetSettings.featuresSettings?.endChat
                    == true
                || viewModel.settings?.widgetSettings.featuresSettings?
                    .emailTranscript == true)
    }

    var body: some View {
        VStack(spacing: 0) {
            Color.appBarColor
                .frame(
                    height: UIApplication.shared.windows.first?.safeAreaInsets
                        .top ?? 44
                )
            if let settings = viewModel.settings {
                HeaderView(
                    settings: settings,
                    isCompact: true,
                    isOffline: viewModel.canShowOfflineForm,
                    shouldShowMoreOptions: shouldShowMoreOptions,
                    agentAvatar: viewModel.lastMsgAgentInfo,
                    isLoadingHeaderInfo: viewModel.isLoadingHeaderInfo,
                    isShowMenuIcon: !viewModel.conversationId.isEmpty,
                    onBack: {
                        handleBackButtonPressed()
                    }
                ) {
                    let features = viewModel.settings?.widgetSettings
                        .featuresSettings

                    // Notification sound
                    if viewModel.settings?.widgetSettings
                        .enableNotificationSound == true
                    {
                        Button(
                            viewModel.isNotificationSoundEnabled
                                ? ResourceManager.localized(
                                    "disable_notification_sound"
                                )
                                : ResourceManager.localized(
                                    "enable_notification_sound"
                                )
                        ) {
                            viewModel.isNotificationSoundEnabled.toggle()
                        }
                    }

                    // Email transcript
                    if features?.emailTranscript == true
                        && !viewModel.isDisconnected
                    {
                        Button(
                            ResourceManager.localized("email_transcript_title")
                        ) {
                            activeAlert = .emailTranscript
                        }
                    }

                    // Download transcript
                    if features?.downloadTranscript == true
                        && !viewModel.isDisconnected && viewModel.isActive
                    {
                        Button(
                            ResourceManager.localized("download_transcript")
                        ) {
                            viewModel.isLoading = true
                            viewModel.downloadFile() {
                                viewModel.isLoading = false
                            }
                        }
                    }

                    // End chat (destructive workaround for iOS 14)
                    if features?.endChat == true && !viewModel.isConvClosed
                        && !viewModel.isDisconnected && viewModel.isActive
                    {

                        if #available(iOS 15, *) {
                            Button(role: .destructive) {
                                activeAlert = .endChat
                            } label: {
                                Text(ResourceManager.localized("end_chat"))
                            }
                        } else {
                            Button {
                                activeAlert = .endChat
                            } label: {
                                Text(ResourceManager.localized("end_chat"))
                                    .foregroundColor(.red)  // 👈 manual destructive look
                            }
                        }
                    }
                }
                .overlay(
                    Rectangle()
                        .fill(Color.borderSecondary)
                        .frame(height: 1),
                    alignment: .bottom
                )
                NotificationOverlayView(onRetry: {
                    viewModel.retryConnection()
                })
                ConversationView(
                    viewModel: viewModel,
                    showHeaderMoreOptions: $showHeaderMoreOptions,
                    activeAlert: $activeAlert
                )
            }
        }
        .ignoresSafeArea(edges: .top)
        .overlay(
            Group {
                if viewModel.isLoading {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()

                        ProgressView()
                            .progressViewStyle(
                                CircularProgressViewStyle(
                                    tint: .actionColorPrimaryBg
                                )
                            )
                            .scaleEffect(1.5)
                    }
                }
            }
        )
        .alert(item: $activeAlert) { alertType in
            switch alertType {
            case .emailTranscript:
                Alert(
                    title: Text(
                        ResourceManager.localized("email_transcript_title")
                    ),
                    message: Text(
                        ResourceManager.localized("email_transcript_message")
                    ),
                    primaryButton: .default(
                        Text(ResourceManager.localized("send"))
                    ) { viewModel.requestEmailTranscript() },
                    secondaryButton: .cancel(
                        Text(ResourceManager.localized("cancel"))
                    )
                )
            case .endChat:
                Alert(
                    title: Text(ResourceManager.localized("end_chat")),
                    message: Text(
                        ResourceManager.localized("end_chat_confirmation")
                    ),
                    primaryButton: .destructive(
                        Text(ResourceManager.localized("end_chat"))
                    ) { viewModel.endChat() },
                    secondaryButton: .cancel(
                        Text(ResourceManager.localized("cancel"))
                    )
                )
            }
        }
        .onAppear {
            // Mark SDK as open whenever ChatView appears
            BDChatSDK.isOpen = true

            if !conversationId.isEmpty {
                // Opening an existing conversation: properly reset state and load messages
                Task { @MainActor in
                    await viewModel.openConversation(
                        conversationId: self.conversationId
                    )

                    // If we're already connected, hide any stale reconnect banner
                    if viewModel.isChatConnected
                        || viewModel.isXMPPServerConnected
                    {
                        NotificationManager.shared.hide()
                    } else {
                        // Attempt a retry to (re)establish connection when entering chat
                        viewModel.retryConnection()
                    }
                }
            }
        }
        .onDisappear {
            if BDChatSDK.isOpen {
                BDChatSDK.isOpen = false
            }
        }
        .navigationBarHidden(true)
    }

    private func handleBackButtonPressed() {
        // Clear conversation ID
        viewModel.conversationId = ""

        // Simply dismiss - this will go back to ConversationListView or main app
        presentationMode.wrappedValue.dismiss()
    }
}

struct ConversationView: View {
    @ObservedObject var viewModel: ChatViewModel
    @StateObject private var keyboard = KeyboardObserver()

    @State private var showFooterActionBarOptions = false
    @State private var isPreChatFormProcessing = false

    // Present header 'More options' from within ConversationView (avoid root conflicts)
    @Binding var showHeaderMoreOptions: Bool
    @Binding var activeAlert: ActiveAlert?
    //
    //    private var dropdownOptions: [DropdownOption]? {
    //        guard viewModel.settings?.widgetSettings.allowReopen == true && viewModel.canReopen != false else { return nil }
    //        return [
    //            DropdownOption(title: "start_new_conversation", action: { done in
    //                viewModel.resetAndCreateNewConversation()
    //                done()
    //            }),
    //            DropdownOption(title: "continue_current_conversation", action: { done in
    //                viewModel.reopenConversation { _ in
    //                    done()
    //                }
    //            })
    //        ]
    //    }

    var body: some View {
        VStack(spacing: 0) {
            messageList
                .frame(maxHeight: .infinity)
            if !viewModel.isUserBlocked && !viewModel.canShowMsgListShimmer {
                if viewModel.isConvClosed && viewModel.isActive
                    && viewModel.canReopen ?? false
                {
                    // Closed conversation — allow reopen if settings permit
                    BcButton(
                        icon: .chat,
                        label: "continue_current_conversation",
                        mainAction: {
                            viewModel.reopenConversation { _ in }
                        },
                    ).disabled(viewModel.isDisconnected)
                        .padding(.top, 6)
                } else {
                    if viewModel.canShowMsgFooter
                        && (!viewModel.canShowOfflineForm
                            || !viewModel.conversationId.isEmpty)
                        && !viewModel.canShowMsgListShimmer
                        && viewModel.isActive
                        && !viewModel.isConvClosed
                    {
                        if viewModel.settings?.chatSettings.enableStickyButtons
                            == true,
                            let stickyButtons = viewModel.settings?.chatSettings
                                .stickyButtons, !stickyButtons.isEmpty
                        {
                            StickyButtonsContainer(
                                buttons: stickyButtons,
                                isDisabled: viewModel.isMsgFooterDisabled
                            ) { btn in
                                viewModel.createAndSendMessages(
                                    text: btn.text,
                                    selectedActionButtonValue: btn.value,
                                    selectedActionButtonType: .footer
                                )
                            }
                            .padding(.bottom, 16)
                        }
                        footer
                    }
                }

                let shouldShowPrivacyNotice =
                    viewModel.canShowPrivacyPolicyNotice
                    && viewModel.settings?.chatPrivacyPolicySettings
                        .enablePrivacyPolicy == true
                    && viewModel.isActive && !viewModel.isConvClosed
                    && !viewModel.canShowMsgListShimmer
                    && !keyboard.isKeyboardVisible

                if shouldShowPrivacyNotice,
                    let privacyMessage = viewModel.settings?
                        .chatPrivacyPolicySettings.privacyPolicyMessage
                {
                    privacyPolicyNotice(message: privacyMessage)
                } else if viewModel.settings?.generalSettings.includePoweredBy
                    == true && !keyboard.isKeyboardVisible
                {
                    PoweredByBolddeskView()
                }
            }
        }
        .background(Color.bgPrimary)
    }

    // MARK: - Message List with Scroll + Suggestions + Email Form
    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack {
                    if viewModel.canShowMsgListShimmer {
                        MessageListShimmerView()
                    } else if viewModel.canShowOfflineForm
                        && viewModel.conversationId.isEmpty,
                        let offlineMsg = viewModel.settings?.offlineSettings
                            .offlineMessage
                    {
                        // Offline welcome message
                        ChatMessageView(
                            viewModel: viewModel,
                            message: Message(
                                from: "",
                                userType: .agent,
                                type: .text,
                                deliveryStatus: .delivered,
                                text: offlineMsg,
                                agentInfo: viewModel.offlineAgentInfo,
                                formDetails: viewModel.canShowOfflineForm
                                    ? FormDetails(
                                        mod: .ai,
                                        isSubmitted: false,
                                        options: [
                                            DropdownItemModel(
                                                id: "3",
                                                displayName: viewModel.settings?
                                                    .offlineSettings
                                                    .createTicketButtonText
                                                    ?? ""
                                            )
                                        ]
                                    ) : nil
                            )
                        )
                    } else {
                        // Messages
                        ForEach(
                            Array(viewModel.messages.enumerated()),
                            id: \.element.id
                        ) { index, message in
                            ChatMessageView(
                                viewModel: viewModel,
                                message: message,
                                onRetryClick: {
                                    viewModel.retryMessage(withId: $0)
                                },
                                onFormSubmit: {
                                    viewModel.createAndSendFieldValueMessage(
                                        with: $0,
                                        formMsgId: $1,
                                        value: $2,
                                        pickerValue: $3,
                                        files: $4
                                    )
                                },
                                onScheduleEvent: { eventUri in
                                    viewModel.handleScheduleEvent(
                                        scheduleEventURL: eventUri,
                                        msgIndex: index
                                    )
                                },
                                isFormElementDisabled: (viewModel.isDisconnected
                                    || viewModel.isConvClosed
                                    || !viewModel.isActive)
                                    || (message.formDetails?.type
                                        == .getFileInput && message.files != nil
                                        && message.deliveryStatus == .uploading)
                            )
                            .onAppear {
                                // Fetch archived messages when scrolled to top
                                if index == 0,
                                    !viewModel.messages.isEmpty,
                                    !viewModel.isFetchingArchivedMessages,
                                    let archiveId = message.archiveId
                                {
                                    viewModel.firstVisibleMsg = message
                                    viewModel.isFetchingArchivedMessages = true
                                    viewModel.getArchivedMessages(
                                        msgArchiveId: archiveId
                                    )
                                }
                            }
                            .padding(.top, index == 0 ? 16 : 0)
                            .padding(
                                .bottom,
                                index == (viewModel.messages.count - 1) ? 8 : 0
                            )
                            .id(message.id)
                        }

                        // Suggestion Options
                        if viewModel.showSuggestionOptions,
                            let suggestionOptions = viewModel.settings?
                                .chatSettings.suggestions,
                            let suggestionType = viewModel.settings?
                                .chatSettings.suggestionType
                        {
                            if suggestionType == .actionButton {
                                SuggestionOptionsView(
                                    suggestions: suggestionOptions
                                ) {
                                    viewModel.onSuggestionValueSelected(
                                        $0,
                                        .suggestion
                                    )
                                }
                                .padding(.leading, 56)
                                .padding(.trailing, 16)
                            } else if suggestionType == .frequentlyAskedQuestion
                            {
                                FAQSuggestionOptionsView(
                                    suggestions: suggestionOptions
                                ) {
                                    viewModel.onSuggestionValueSelected(
                                        $0,
                                        .suggestionFAQ
                                    )
                                }
                                .padding(.leading, 50)
                            }
                        }

                        // Pre Chat Form
                        if let settings = viewModel.settings,
                            settings.chatSettings.displayOption == .email,
                            !viewModel.isOnlyUserFieldsAndPrefilled(),
                            !viewModel.canShowOfflineForm,
                            !viewModel.preChatFormFields.isEmpty,
                            !viewModel.canShowMsgFooter,
                            viewModel.conversationId.isEmpty
                        {
                            PreChatFormView(
                                preChatFormMessage: settings.chatSettings
                                    .preChatFormDetails?.preChatFormMessage
                                    ?? "",
                                preChatFormFields: viewModel.preChatFormFields,
                                systemUserId: viewModel.getSystemUserId(),
                                isProcessing: $isPreChatFormProcessing,
                                onStartChat: { payload in
                                    Task {
                                        isPreChatFormProcessing = true
                                        viewModel.onChatFormSubmit(
                                            preChatPayload: payload
                                        ) { _ in
                                            isPreChatFormProcessing = false
                                        }
                                    }
                                },
                                brandOptionId: viewModel.settings?.brandOptionId
                            )
                            .id(viewModel.preChatFormSessionId)
                        }

                        // Agent typing indicator
                        if let typingAgentInfo = viewModel.typingAgentInfo {
                            AgentTypingIndicatorView(agentInfo: typingAgentInfo)
                                .id("agentTypingIndicator")
                        }

                        // AI agent thinking indicator
                        if let thinkingAiAgentInfo = viewModel
                            .thinkingAiAgentInfo
                        {
                            AiAgentThinkingIndicatorView(
                                agentInfo: thinkingAiAgentInfo
                            )
                            .id("thinkingAiAgentIndicator")
                        }
                    }

                    // Bottom padding to ensure last message is visible above footer
                    Color.clear
                        .frame(height: 20)
                }
                .onChange(of: viewModel.scrollTrigger) { _ in
                    if let lastMessage = viewModel.messages.last {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                .onChange(of: viewModel.typingAgentInfo) { newValue in
                    if newValue != nil {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo(
                                    "agentTypingIndicator",
                                    anchor: .top
                                )
                            }
                        }
                    }
                }
                .onChange(of: viewModel.thinkingAiAgentInfo) { newValue in
                    if newValue != nil {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(
                                "thinkingAiAgentIndicator",
                                anchor: .top
                            )
                        }
                    }
                }
                .onChange(of: keyboard.isKeyboardVisible) { isVisible in
                    if let lastMessage = viewModel.messages.last {
                        if isVisible {
                            withAnimation(.easeInOut(duration: 0.35)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        } else {
                            DispatchQueue.main.asyncAfter(
                                deadline: .now() + 0.05
                            ) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Footer Input
    @State private var dynamicHeight: CGFloat = 0

    private var footer: some View {
        HStack(alignment: .top) {
            GrowingTextView(
                text: $viewModel.messageText,
                font:
                    FontFamily
                    .customUIFont(size: FontSize.medium, weight: .regular),
                onHeightChange: { newHeight in
                    dynamicHeight = newHeight
                }
            )
            .frame(height: dynamicHeight)
            .padding()
            .padding(.trailing, 0)
            .onChange(of: viewModel.messageText) { newValue in
                viewModel.manageUserTypingIndicator(
                    shouldClearTimeout: false,
                    isTyping: !newValue.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).isEmpty
                )
            }
            HStack(spacing: 24) {
                if viewModel.settings?.widgetSettings.fileUploadOption
                    != FileUploadOption.none
                    && !viewModel.conversationId.isEmpty
                    && viewModel.isChatConnected
                    && trimmedMessageText.isEmpty
                {

                    AttachmentPickerView(
                        isEnabled: !viewModel.isMsgFooterDisabled
                            && viewModel.isConvAssignedToAIAgent != true,
                        onFilesPicked: { urls in
                            viewModel.uploadFiles(urls)
                        },
                        onImagePicked: { image in
                            viewModel.uploadFiles(image)
                        }
                    ) {
                        AppIcon(
                            icon: .attachment1,
                            size: FontSize.semilarge,
                            color: viewModel.isMsgFooterDisabled
                                || viewModel.isConvAssignedToAIAgent == true
                                ? Color.fgDisabled
                                : Color.fgSecondary
                        )
                    }
                }

                if !trimmedMessageText.isEmpty {
                    Button(action: { sendMessage() }) {
                        AppIcon(
                            icon: .send,
                            size: FontSize.semilarge,
                            color: viewModel.isMsgFooterDisabled
                                ? Color.fgDisabled : Color.actionColorPrimaryBg
                        )
                    }
                    .disabled(viewModel.isMsgFooterDisabled)
                }
            }
            .padding(.top, 20)
            .padding(.trailing, 20)

        }
        .font(FontFamily.customFont(size: FontSize.medium, weight: .regular))
        .frame(minHeight: 64)
        .background(Color.bgSecondary)
        .border(Color.borderSecondary)
    }

    private var trimmedMessageText: String {
        viewModel.messageText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func sendMessage() {
        viewModel.createAndSendMessages(text: trimmedMessageText)
        viewModel.messageText = ""
    }

    private func privacyPolicyNotice(message: String) -> some View {
        HStack(alignment: .top) {
            if #available(iOS 15.0, *) {
                PrivacyPolicyContentView(message: message)
            } else {
                HTMLContentView(html: message)
            }
            Spacer()
            Button(action: { viewModel.handlePolicyNoticeClose() }) {
                AppIcon(icon: .close, size: FontSize.medium)
            }
        }
        .padding(16)
        .background(Color.bgPrimary)
    }

    @available(iOS 15.0, *)
    private struct PrivacyPolicyContentView: View {
        let message: String
        @State private var attributedText: AttributedString?

        var body: some View {
            Group {
                if let attributedText {
                    Text(attributedText)
                        .font(.system(size: FontSize.medium, weight: .regular))
                        .foregroundColor(Color.textSecondary)
                        .environment(
                            \.openURL,
                            OpenURLAction { url in
                                UIApplication.shared.open(url)
                                return .handled
                            }
                        )
                } else {
                    Text("")
                        .font(.system(size: FontSize.medium, weight: .regular))
                        .foregroundColor(Color.textSecondary)
                }
            }
            .task(id: message) {
                let html = message
                DispatchQueue.global(qos: .userInitiated).async {
                    let result = buildAttributedString(
                        from: html,
                        baseFontSize: FontSize.xxsmall
                    )
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut(duration: 0.1)) {
                            self.attributedText = result
                        }
                    }
                }
            }
        }

        @available(iOS 15.0, *)
        private func buildAttributedString(
            from html: String,
            baseFontSize: CGFloat
        ) -> AttributedString? {
            let styledHtml =
                "<style>body, p, div { margin: 0; padding: 0; }</style>" + html
            guard let data = styledHtml.data(using: .utf8) else { return nil }

            do {
                let nsAttrRaw = try NSMutableAttributedString(
                    data: data,
                    options: [
                        .documentType: NSAttributedString.DocumentType.html,
                        .characterEncoding: String.Encoding.utf8.rawValue,
                    ],
                    documentAttributes: nil
                )

                nsAttrRaw.trimTrailingWhitespace()
                let baseFont = UIFont.systemFont(
                    ofSize: baseFontSize,
                    weight: .regular
                )

                nsAttrRaw.enumerateAttributes(
                    in: NSRange(location: 0, length: nsAttrRaw.length),
                    options: []
                ) { attrs, range, _ in
                    var updatedAttrs = attrs

                    if let font = updatedAttrs[.font] as? UIFont {
                        let traits = font.fontDescriptor.symbolicTraits
                        let descriptor = baseFont.fontDescriptor

                        var symbolicTraits: UIFontDescriptor.SymbolicTraits = []
                        if traits.contains(.traitBold) {
                            symbolicTraits.insert(.traitBold)
                        }
                        if traits.contains(.traitItalic) {
                            symbolicTraits.insert(.traitItalic)
                        }

                        if let newDescriptor = descriptor.withSymbolicTraits(
                            symbolicTraits
                        ) {
                            updatedAttrs[.font] = UIFont(
                                descriptor: newDescriptor,
                                size: baseFontSize
                            )
                        } else {
                            updatedAttrs[.font] = baseFont
                        }
                    } else {
                        updatedAttrs[.font] = baseFont
                    }

                    if updatedAttrs[.link] != nil {
                        updatedAttrs[.underlineStyle] = 0
                        updatedAttrs[.foregroundColor] = UIColor(
                            Color.actionColorPrimaryBg
                        )

                        let traits =
                            (updatedAttrs[.font] as? UIFont)?.fontDescriptor
                            .symbolicTraits ?? []
                        let baseFont = UIFont.systemFont(
                            ofSize: baseFontSize,
                            weight: .medium
                        )
                        if let descriptor = baseFont.fontDescriptor
                            .withSymbolicTraits(traits)
                        {
                            updatedAttrs[.font] = UIFont(
                                descriptor: descriptor,
                                size: baseFontSize
                            )
                        } else {
                            updatedAttrs[.font] = baseFont
                        }
                    } else {
                        updatedAttrs[.foregroundColor] = UIColor(
                            Color.textSecondary
                        )
                    }

                    nsAttrRaw.setAttributes(updatedAttrs, range: range)
                }

                return AttributedString(nsAttrRaw)
            } catch {
                return nil
            }
        }
    }

}

extension NSMutableAttributedString {
    func trimTrailingWhitespace() {
        let invertedSet = CharacterSet.whitespacesAndNewlines.inverted
        let range = (string as NSString).rangeOfCharacter(
            from: invertedSet,
            options: .backwards
        )
        if range.location != NSNotFound {
            let length = range.location + range.length
            if length < self.length {
                deleteCharacters(
                    in: NSRange(location: length, length: self.length - length)
                )
            }
        }
    }
}
