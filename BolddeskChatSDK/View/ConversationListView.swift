import Foundation
import SwiftUI
import UIKit

struct ConversationListView: View {
    var initialConversationId: String
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var viewModel = ChatViewModel()
    @State private var navigateToNewChat: Bool = false
    @State private var navigateToChatWithId: Bool = false
    @State private var selectedConversationId: String = ""
    @State private var isInitialLoading: Bool = true
    @State private var shouldShowChatDirectly: Bool = false
    // KB / Chat toggle state
    @State private var activeTab: String = "chat"  // "chat" or "help"
    @State private var isKbEnabled: Bool = true
    // KB view-model instance (created once when widgetId becomes available)
    @State private var kbViewModel: KnowledgeBaseViewModel? = nil

    // MARK: - Body
    var body: some View {
        let totalUnread = viewModel.conversationList
            .filter { $0.unReadMessage == true }
            .count
        
        NavigationView {
            ZStack(alignment: .top) {
                StatusBarBackground(color: Color.appBarColor)
                VStack(spacing: 0) {
                    headerView
                    contentView
                    if !isInitialLoading && !shouldShowChatDirectly {
                        VStack(spacing: 0) {
                            // Show new conversation button only when on Chat tab
                            if ((viewModel.settings != nil
                                && !viewModel.isUserBlocked
                                && viewModel.canShowStartNewConversationButton)
                                || (viewModel.settings?.generalSettings
                                    .includePoweredBy == true))
                                && activeTab == "chat"
                            {
                                Rectangle()
                                    .fill(Color.borderSecondary)
                                    .frame(height: 1)
                            }
                            if viewModel.settings != nil
                                && !viewModel.isUserBlocked
                                && viewModel.canShowStartNewConversationButton
                                && activeTab == "chat"
                            {
                                floatingActionButton
                                    .padding(
                                        .bottom,
                                        (viewModel.settings?.generalSettings
                                            .includePoweredBy == true
                                            && !isInitialLoading
                                            && !shouldShowChatDirectly) ? 2 : 12
                                    )
                            }

                            // Place tab toggle below New Conversation button (or at top if on Help tab)
                            if isKbEnabled {
                                tabToggleView(totalUnread)
                                    .padding(.horizontal, 16)
                                    .padding(.top, activeTab == "help" ? 0 : 8)
                            }

                            if viewModel.settings?.generalSettings
                                .includePoweredBy == true && !isInitialLoading
                                && !shouldShowChatDirectly
                            {
                                PoweredByBolddeskView()
                            }
                        }
                    }
                }

                // Navigation Links
                NavigationLink(
                    destination: ChatView(
                        conversationId: selectedConversationId,
                        viewModel: viewModel
                    ),
                    isActive: $navigateToChatWithId
                ) {
                    EmptyView()
                }

                NavigationLink(
                    destination: ChatView(
                        conversationId: "",
                        viewModel: viewModel
                    ),
                    isActive: $navigateToNewChat
                ) {
                    EmptyView()
                }
            }
            .onAppear {
                BDChatSDK.isSDKOpen = true
                BDChatSDK.setClearSessionAction { [weak viewModel] in
                    viewModel?.clearChatSession()
                }
                BDChatSDK.isConversationListOpen = true
                // Reset shouldShowChatDirectly when returning to conversation list
                if !isInitialLoading && viewModel.settings != nil {
                    shouldShowChatDirectly = false
                }

                handleOnAppear()
            }
            .onDisappear {
                BDChatSDK.isSDKOpen = false
                BDChatSDK.isConversationListOpen = false
                BDChatSDK.isFromPushNotification = false
            }
            .onChange(of: navigateToChatWithId) { newValue in
                // Reset flag when returning from chat navigation
                if !newValue {
                    shouldShowChatDirectly = false
                }
            }
            .onChange(of: navigateToNewChat) { newValue in
                // Reset flag when returning from new chat navigation
                if !newValue {
                    shouldShowChatDirectly = false
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onChange(of: viewModel.settings?.widgetId) { newWidgetId in
            if kbViewModel == nil, let wid = newWidgetId, !wid.isEmpty {
                kbViewModel = KnowledgeBaseViewModel(widgetId: wid)
            }
        }
    }

    // MARK: - Header View
    @ViewBuilder
    private var headerView: some View {
        // Only show header when on Chat tab or when loading/error state
        if !viewModel.settingsLoadFailed && activeTab == "chat" {
            SimpleHeaderView(
                title: ResourceManager.localized("conversations_text"),
                onBack: handleDismiss,
                isInitialLoading: isInitialLoading,
                shouldShowChatDirectly: shouldShowChatDirectly
            )
            .animation(nil, value: activeTab)  // Disable animation for header
            .transition(.identity)  // No transition effect
        } else if !viewModel.settingsLoadFailed && activeTab == "help" {
            // Empty view for help tab (KB Home has its own header)
            EmptyView()
        }
    }

    // MARK: - Content View
    @ViewBuilder
    private var contentView: some View {
        if isInitialLoading
            || (viewModel.settings == nil && !viewModel.settingsLoadFailed)
        {
            shimmerView
        } else if viewModel.settingsLoadFailed {
            errorView
        } else if viewModel.settings != nil && !shouldShowChatDirectly {
            if activeTab == "help" {
                NotificationOverlayView(onRetry: {
                    viewModel.retryConnection()
                })
            }
            VStack(spacing: 0) {

                if activeTab == "chat" {
                    mainContentView
                } else {
                    if let kbVM = kbViewModel {
                        KBHomeView(chatViewModel: viewModel, viewModel: kbVM, onBack: handleDismiss)
                    } else {
                        // Show lightweight placeholder while KB VM is created
                        VStack {
                            ProgressView()
                                .padding()
                            Spacer()
                        }
                    }
                }
            }
        }
        // Create KB view-model once when widgetId becomes available
    }

    private func tabToggleView(_ totalUnread: Int) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Button(action: {
                    activeTab = "help"
                }) {
                    VStack(spacing: 4) {
                        AppIcon(
                            icon: activeTab == "help" ? .circleHelpFill : .helpCircle,
                            size: FontSize.extralarge,
                            color: activeTab == "help"
                                ? Color.actionColorPrimaryBg
                                : Color.textSecondary
                        )
                        Text(ResourceManager.localized("help"))
                            .font(
                                FontFamily.customFont(
                                    size: FontSize.small,
                                    weight: .medium
                                )
                            )
                            .foregroundColor(
                                activeTab == "help"
                                    ? Color.actionColorPrimaryBg
                                    : Color.textSecondary
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }

                Button(action: {
                    activeTab = "chat"
                }) {
                    VStack(spacing: 4) {
                        
                        ZStack(alignment: .topTrailing) {
                            
                            AppIcon(
                                icon: activeTab == "chat" ? .chatFilled : .chat,
                                size: FontSize.extralarge,
                                color: activeTab == "chat"
                                    ? Color.actionColorPrimaryBg
                                    : Color.textSecondary
                            )
                            
                            if totalUnread > 0 {
                                Text(totalUnread > 99 ? "99+" : "\(totalUnread)")
                                    .font(FontFamily.customFont(size: FontSize.xxxsmall, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, totalUnread > 9 ? 5 : 6)
                                    .padding(.vertical, 2)
                                    .background(Color.red)
                                    .clipShape(Capsule())
                                    .fixedSize()
                                    .offset(x: 8, y: -4)
                            }
                        }
                        
                        Text(ResourceManager.localized("chat"))
                            .font(
                                FontFamily.customFont(
                                    size: FontSize.small,
                                    weight: .medium
                                )
                            )
                            .foregroundColor(
                                activeTab == "chat"
                                    ? Color.actionColorPrimaryBg
                                    : Color.textSecondary
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
            }
            .background(Color.bgPrimary)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.borderTertiary, lineWidth: 1),
                alignment: .bottom
            )
            .shadow(
                color: Color.borderTertiary,  // 👈 adjust
                radius: 20,
                x: 0,
                y: 4
            )
        }
        .padding(.horizontal, 36)
    }

    // MARK: - Main Content
    @ViewBuilder
    private var mainContentView: some View {
        ZStack(alignment: .bottom) {
            if viewModel.conversationList.isEmpty {
                emptyStateView
            } else {
                conversationListView
            }
            navigationLink
        }
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack {
            Spacer(minLength: 0)
            VStack(spacing: 0) {
                if let uiImage = UIImage(
                    named: "Group_48097078",
                    in: Bundle(for: SDKBundleFinder.self),
                    compatibleWith: nil
                ) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 280, height: 229)
                        .clipped()
                        .padding(.bottom, DeviceType.isPhone ? 20 : 12)
                }

                Text(ResourceManager.localized("noConversationtext"))
                    .font(
                        FontFamily.customFont(
                            size: DeviceType.isPhone
                                ? FontSize.xlarge : FontSize.semilarge,
                            weight: .semibold
                        )
                    )
                    .foregroundColor(Color.textSecondary)
                    .padding(.bottom, 8)
                Text(ResourceManager.localized("startOneToSeeYourconversation"))
                    .font(
                        FontFamily.customFont(
                            size: DeviceType.isPhone
                                ? FontSize.medium : FontSize.large,
                            weight: .regular
                        )
                    )
                    .foregroundColor(Color.textTertiary)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)
            Spacer()
        }
    }

    // MARK: - Conversation List
    private var conversationListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.conversationList.indices, id: \.self) {
                    index in
                    let item = viewModel.conversationList[index]
                    Button(action: {
                        selectedConversationId = item.conversationId ?? ""
                        navigateToChatWithId = true
                    }) {
                        VStack(spacing: 0) {
                            ConversationRowView(
                                item: item,
                                viewModel: viewModel
                            )
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)

                            Rectangle()
                                .fill(Color.borderSecondary)
                                .frame(height: 1)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        // 🚀 LOAD MORE when last item appears
                        if index == viewModel.conversationList.count - 1
                            && viewModel.conversationList.count > 19
                        {
                            Task {
                                await viewModel.getConversationListItems(
                                    isLoadMore: true
                                )
                            }
                        }
                    }
                }
                if viewModel.isLoadingMoreConversations {
                    ProgressView()
                        .padding(.vertical, 16)
                }
                Spacer(minLength: 80)
            }
            .padding(.top, 16)
        }
    }

    // MARK: - Floating Action Button
    @ViewBuilder
    private var floatingActionButton: some View {
        if viewModel.settings != nil && !viewModel.isUserBlocked
            && viewModel.canShowStartNewConversationButton
        {
            BcButton(
                icon: .newConversation,
                label: "start_new_conversation",
                mainAction: handleStartNewConversation,
            )
            .disabled(viewModel.isDisconnected)
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
    }

    // MARK: - Navigation Link
    private var navigationLink: some View {
        NavigationLink(
            destination: ChatView(conversationId: "", viewModel: viewModel),
            isActive: $navigateToNewChat
        ) {
            EmptyView()
        }
        .animation(nil, value: navigateToNewChat)
    }

    // MARK: - Shimmer View
    // MARK: - Progress View (replaces shimmer)
    private var shimmerView: some View {
        VStack {
            Spacer()
            ProgressView()
                .progressViewStyle(
                    CircularProgressViewStyle(
                        tint: .actionColorPrimaryBg
                    )
                )
                .scaleEffect(1.5)
            Spacer(minLength: 80)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error View
    private var errorView: some View {
        InitialErrorView(
            title: ResourceManager.localized("error_start_chat_text"),
            message: ResourceManager.localized("could_not_connect_text"),
            tryAgainTitle: ResourceManager.localized("try_again_text"),
            cancelTitle: ResourceManager.localized("cancel"),
            onTryAgain: { Task { await viewModel.fetchWidgetSettings() } },
            onCancel: handleDismiss
        )
    }

    // MARK: - Actions
    private func handleDismiss() {
        viewModel.stopNetworkMonitoring()
        presentationMode.wrappedValue.dismiss()
    }

    private func handleStartNewConversation() {
        Task {
            let isShowConversationButton =
                await viewModel.checkConversationInitiationStatus()
            if isShowConversationButton {
                if !viewModel.conversationList.isEmpty {
                    viewModel.resetAndCreateNewConversation()
                }
                navigateToNewChat = true
            }
        }
    }

    private func handleOnAppear() {
        viewModel.startNetworkMonitoring()
        Task {
            if viewModel.settings == nil && !viewModel.settingsLoadFailed {
                await MainActor.run { isInitialLoading = true }

                // Fetch widget settings
                await viewModel.fetchWidgetSettings()

                // Check if settings load failed
                if viewModel.settingsLoadFailed {
                    await MainActor.run { isInitialLoading = false }
                    return
                }

                // Fetch conversation list
                await viewModel.getConversationListItems()

                // Decide navigation based on conversation list
                await MainActor.run {
                    decideNavigation()
                    isInitialLoading = false
                }
            }
        }
    }

    private func decideNavigation() {
        let conversationList = viewModel.conversationList

        if conversationList.isEmpty
            && viewModel.canShowStartNewConversationButton
        {
            // No conversations - show chat view without conversation ID
            selectedConversationId = ""
            shouldShowChatDirectly = true
            navigateToNewChat = true
        } else {
            // Check for first non-closed conversation (status.id != 3)
            if let firstOpenConversation = conversationList.first(where: {
                $0.status?.id != 3
            }) {
                // Found non-closed conversation - show chat view with that conversation
                selectedConversationId =
                    BDChatSDK.isFromPushNotification
                    ? self.initialConversationId
                    : firstOpenConversation.conversationId ?? ""
                shouldShowChatDirectly = true
                navigateToChatWithId = true
            } else {
                // All conversations are closed - show conversation list
                shouldShowChatDirectly = false
            }
        }
    }
}

struct ConversationRowView: View {
    let item: Conversation
    @ObservedObject var viewModel: ChatViewModel

    var body: some View {
        // Calculate values fresh on every render to ensure reactivity
        let senderName = item.lastMessage?.senderName ?? "You"
        let messagePreview = viewModel.parseLastMessage(
            raw: item.lastMessage?.message,
            senderName: senderName,
            agentName: senderName
        )
        let agentDisplayName = getAgentDisplayName()
        let timestampText = timeDifference(
            isoTimestamp: item.lastMessage?.createdAt
        )

        HStack(alignment: .center, spacing: 0) {
            // Avatar
            ConversationListAvatarSection(agentInfo: item.assignedAgent)
                .padding(.trailing, 10)

            // Conversation Details
            VStack(alignment: .leading, spacing: 4) {
                Text(agentDisplayName)
                    .foregroundColor(Color.textSecondary)
                    .font(
                        FontFamily.customFont(
                            size: FontSize.large,
                            weight: item.unReadMessage ?? false
                                ? .semibold : .regular
                        )
                    )
                    .lineLimit(1)
                    .truncationMode(.tail)

                // Message Preview
                if !messagePreview.senderName.isEmpty
                    || !messagePreview.text.isEmpty
                {
                    HStack(spacing: 0) {
                        // Sender Name (e.g., "You:")
                        if !messagePreview.senderName.isEmpty {
                            Text("\(messagePreview.senderName):")
                                .font(
                                    FontFamily.customFont(
                                        size: FontSize.medium,
                                        weight: item.unReadMessage ?? false
                                            ? .medium : .regular
                                    )
                                )
                                .foregroundColor(.textTertiary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Spacer().frame(width: 4)
                        }

                        // Icon (if present)
                        if let icon = messagePreview.icon {
                            AppIcon(
                                icon: icon,
                                size: FontSize.medium,
                                color: .textTertiary
                            )
                            .padding(.trailing, 4)
                        }

                        // Message Content
                        if !messagePreview.text.isEmpty {
                            Text(messagePreview.text)
                                .font(
                                    FontFamily.customFont(
                                        size: FontSize.medium,
                                        weight: item.unReadMessage ?? false
                                            ? .medium : .regular
                                    )
                                )
                                .foregroundColor(.textTertiary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                }
            }

            Spacer()

            // Timestamp
            VStack(alignment: .trailing, spacing: 0) {
                if !timestampText.isEmpty {
                    Text(timestampText)
                        .foregroundColor(Color.textSecondary)
                        .font(
                            FontFamily.customFont(
                                size: FontSize.medium,
                                weight: .regular
                            )
                        )
                        // Removed fixed maxHeight to allow the Spacer to do the work
                        .alignmentGuide(.top) { d in d[.top] }
                }

                // This pushes the top element up and the bottom element down
                Spacer(minLength: -4)

                if let unRead = item.unReadMessage, unRead {
                    BadgeView()
                }
                if timestampText.isEmpty {
                    Spacer(minLength: 0)
                }
            }
            .frame(maxHeight: .infinity)  // Ensure the VStack fills the available vertical space

        }
    }

    // Helper method
    private func getAgentDisplayName() -> String {
        if let name = item.assignedAgent?.displayName, !name.isEmpty {
            return "\(ResourceManager.localized("chatWithtext")) \(name)"
        }
        return ResourceManager.localized("connectingToAgentText")
    }
}

struct BadgeView: View {

    var body: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 10, height: 10)
    }
}

struct SimpleHeaderView: View {

    let title: String
    let onBack: () -> Void
    let isInitialLoading: Bool
    let shouldShowChatDirectly: Bool

    var body: some View {
        // Header content
        HStack(spacing: 0) {
            Button(action: onBack) {
                AppIcon(
                    icon: .arrowLeft,
                    size: FontSize.extralarge,
                    color: .textPrimaryAppBarColor
                )
                .frame(width: 32, height: 32)
            }

            if !isInitialLoading && !shouldShowChatDirectly {
                Text(title)
                    .font(
                        FontFamily.customFont(
                            size: FontSize.large,
                            weight: .bold
                        )
                    )
                    .foregroundColor(.textPrimaryAppBarColor)
                    .padding(.leading, 4)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(Color.appBarColor)
        .overlay(
            Rectangle()
                .fill(Color.borderSecondary)
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

// MARK: - Conversation List Shimmer
struct ConversationListShimmerView: View {
    private let itemCount = 18
    private let avatarSize: CGFloat = 48
    private let titleHeight: CGFloat = 14
    private let subtitleHeight: CGFloat = 12

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(0..<itemCount, id: \.self) { _ in
                    shimmerItem
                }
            }
            .padding(.top, 16)
        }
    }

    private var shimmerItem: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: avatarSize, height: avatarSize)

            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: titleHeight)
                    .frame(maxWidth: .infinity)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.25))
                    .frame(height: subtitleHeight)
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.6)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.bgPrimary)
        .redacted(reason: .placeholder)
    }
}

struct StatusBarBackground: View {
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            color
                .frame(height: geometry.safeAreaInsets.top)
                .ignoresSafeArea(edges: .top)
        }
    }
}
