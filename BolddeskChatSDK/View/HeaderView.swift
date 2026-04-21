import SwiftUI

struct HeaderView<MenuContent: View>: View {
    var settings: Settings?
    var isCompact: Bool = false
    var isOffline: Bool = false
    var shouldShowMoreOptions: Bool = false
    var agentAvatar: AgentInfo?
    var isLoadingHeaderInfo: Bool = false
    var onBack: (() -> Void)
    let menuContent: MenuContent
    var isShowMenuIcon: Bool
    @StateObject private var headerViewModel = HeaderViewModel()
    @State var isHeaderLogoLoadFailed: Bool = false
    @State var isAgentAvatarLoadFailed: Bool = false

    // Cached/derived settings to avoid repeated optional chaining and URL parsing
    private var widget: WidgetSettings? { settings?.widgetSettings }
    private var showAgents: Bool { (widget?.showAgents == true && (settings?.aiSettings.enableAIAgent != true)) }
    private var showBrandLogo: Bool { widget?.showBrandLogo ?? false }
    private var brandLogoURL: URL? { widget.flatMap { URL(string: $0.brandLogo) } }
    
    init(
            settings: Settings? = nil,
            isCompact: Bool = false,
            isOffline: Bool = false,
            shouldShowMoreOptions: Bool = false,
            agentAvatar: AgentInfo? = nil,
            isLoadingHeaderInfo: Bool = false,
            isShowMenuIcon: Bool = true,
            onBack: @escaping () -> Void,
            @ViewBuilder menuContent: () -> MenuContent
        ) {
            self.settings = settings
            self.isCompact = isCompact
            self.isOffline = isOffline
            self.shouldShowMoreOptions = shouldShowMoreOptions
            self.agentAvatar = agentAvatar
            self.isLoadingHeaderInfo = isLoadingHeaderInfo
            self.isShowMenuIcon = isShowMenuIcon
            self.onBack = onBack
            self.menuContent = menuContent()
        }

    var body: some View {
        Group {
            if isCompact || !hasTopVisual {
                compactView
            } else {
                regularView
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.appBarColor)
        .onAppear {
            if let widgetId = settings?.widgetId, showAgents {
                Task { await headerViewModel.fetchOnlineAgents(widgetId: widgetId) }
            }
        }
        .onChange(of: agentAvatar) { _ in
            isAgentAvatarLoadFailed = false
        }
    }

    private var onlineAgentsAvatars: some View {
        let agents = Array(headerViewModel.onlineAgents.prefix(3))
        let lastId = agents.last?.id
        return HStack(spacing: -8) {
            ForEach(agents, id: \.id) { agent in
                if let urlString = agent.profileImageUrl, let url = URL(string: urlString), agent.isProfileImageLoaded != false {
                    RemoteImage(
                        url: url,
                        borderColor: Color.appBarColor,
                        showOnlineIndicator: agent.id == lastId,
                        isOffline: isOffline,
                        onLoadFailure: {
                            DispatchQueue.main.async {
                                if let index = headerViewModel.onlineAgents.firstIndex(where: { $0.id == agent.id }) {
                                    headerViewModel.onlineAgents[index].isProfileImageLoaded = false
                                }
                            }
                        }
                    )
                } else {
                    Text(agent.shortCode)
                        .font(FontFamily.customFont(size: FontSize.medium, weight: .bold))
                        .foregroundColor(Color.fgWhite)
                        .frame(width: 32, height: 32)
                        .background(Color(hex: agent.colorCode))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.appBarColor, lineWidth: 2))
                        .overlay(
                            Group { if agent.id == lastId { OnlineIndicatorView(isOffline: isOffline, offset: 1) } },
                            alignment: .bottomTrailing
                        )
                }
            }
        }
    }

    private var agentAvatarView: some View {
        Group {
            if isLoadingHeaderInfo {
                CircleShimmerView()
            } else if let agent = agentAvatar {
                if let urlString = agent.profileImageUrl, let url = URL(string: urlString), !isAgentAvatarLoadFailed {
                    RemoteImage(url: url, borderColor: Color.appBarColor, showOnlineIndicator: true, isOffline: isOffline, indicatorOffset: -2, onLoadFailure: {
                        self.isAgentAvatarLoadFailed = true
                    })
                } else {
                    Text(agent.shortCode)
                        .font(FontFamily.customFont(size: FontSize.medium, weight: .bold))
                        .foregroundColor(Color.fgWhite)
                        .frame(width: 32, height: 32)
                        .background(Color(hex: agent.colorCode))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.fgWhite, lineWidth: 1.5))
                        .overlay(
                            Group { OnlineIndicatorView(isOffline: isOffline, offset: 1) },
                            alignment: .bottomTrailing
                        )
                }
            }
        }
    }

    private var agentNameView: some View {
        Group {
            if isLoadingHeaderInfo {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.bcAlphaWhite30)
                    .frame(width: isCompact ? 120 : 180, height: isCompact ? 16 : 20)
                    .shimmer()
            } else {
                Text(agentAvatar?.displayName ?? "")
                    .font(FontFamily.customFont(size: FontSize.large, weight: .bold))
                    .foregroundColor(.textPrimaryAppBarColor)
                    .multilineTextAlignment(isCompact ? .leading : .center)
            }
        }
    }

    private var headerLogoElement: some View {
        Group {
            if let url = brandLogoURL, !isHeaderLogoLoadFailed {
                RemoteImage(
                    url: url, 
                    borderColor: nil, 
                    showOnlineIndicator: true, 
                    isOffline: isOffline,
                    backgroundColor: shouldShowErrorBackground(brandLogoURL: url) ? Color.boldDeskLogoColor : nil,
                    onLoadFailure: {
                        self.isHeaderLogoLoadFailed = true
                    }
                )
            }
        }
    }

    private var headerLogoShimmer: some View {
        CircleShimmerView()
            .frame(width: 32, height: 32)
    }

    private var headerTitleElement: some View {
        Text(settings!.widgetSettings.headerTitle)
            .font(FontFamily.customFont(size: FontSize.large, weight: .bold))
            .foregroundColor(.textPrimaryAppBarColor)
            .multilineTextAlignment(isCompact ? .leading : .center)
    }

    private var headerTitleShimmer: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.bcAlphaWhite30)
            .frame(width: isCompact ? 160 : 220, height: isCompact ? 16 : 20)
            .shimmer()
    }

    private var headerDescriptionElement: some View {
        Text(isOffline ? settings!.offlineSettings.headerDescription : settings!.widgetSettings.headerDescription)
            .font(FontFamily.customFont(size: FontSize.xsmall, weight: .regular))
            .foregroundColor(.textPrimaryAppBarColor)
            .multilineTextAlignment(isCompact ? .leading : .center)
    }

    private var headerDescriptionShimmer: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.bcAlphaWhite30)
            .frame(width: isCompact ? 180 : 260, height: isCompact ? 12 : 16)
            .shimmer()
    }

    // Detect if a visual (avatar/brand/online avatars/shimmer) is placed above the title in regular view
    private var hasTopVisual: Bool {
        if agentAvatar != nil || isLoadingHeaderInfo { return true }
        if headerViewModel.isLoadingAgents { return true }
        if !headerViewModel.onlineAgents.isEmpty, showAgents { return true }
        if showBrandLogo && !isHeaderLogoLoadFailed, brandLogoURL != nil { return true }
        return false
    }
    
    // Static more options icon with callback
    @ViewBuilder
    private var moreOptionsButton: some View {
        if isShowMenuIcon {
            Menu {
                menuContent
            } label: {
                AppIcon(
                    icon: .moreVerticalDot,
                    size: FontSize.semilarge,
                    color: .textPrimaryAppBarColor
                )
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
                .accessibilityLabel(Text("More options"))
            }
        }
    }
    
    // Back button used in both compact and regular headers
    private var backButton: some View {
        Button(action: { onBack() }) {
            AppIcon(icon: .arrowLeft, size: FontSize.extralarge, color: .textPrimaryAppBarColor)
                .frame(width: 32, height: 32) // Match avatar/logo size to align vertically in compact mode
                .contentShape(Rectangle())
                .accessibilityLabel(Text("Back"))
        }
    }
    
    private var compactView: some View {
        HStack(alignment: .top) {
            // Back button
            backButton
            
            if let _ = agentAvatar {
                // Agent avatar + name horizontally, vertically centered
                HStack(alignment: .center, spacing: 16) {
                    agentAvatarView
                    agentNameView
                }
            } else {
                // Online agents / header logo / shimmer
                Group {
                    if headerViewModel.isLoadingAgents || isLoadingHeaderInfo {
                        headerLogoShimmer
                    } else if !headerViewModel.onlineAgents.isEmpty, !isOffline, showAgents {
                        onlineAgentsAvatars
                    } else if showBrandLogo && !isHeaderLogoLoadFailed, brandLogoURL != nil {
                        headerLogoElement
                    }
                }
                
                // Title + description stacked vertically
                VStack(alignment: .leading, spacing: 4) {
                    if settings != nil && !isLoadingHeaderInfo {
                        headerTitleElement
                        headerDescriptionElement
                    } else {
                        headerTitleShimmer
                        headerDescriptionShimmer
                    }
                }.padding(.leading, hasTopVisual ? 8 : 0)
            }
            
            Spacer()
            if shouldShowMoreOptions { moreOptionsButton }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
    }
    
    
    
    
    private var regularView: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                if agentAvatar != nil {
                    agentAvatarView
                        .padding(.bottom, 16)
                    agentNameView
                } else if headerViewModel.isLoadingAgents || isLoadingHeaderInfo {
                    headerLogoShimmer
                        .padding(.bottom, 16)
                    headerTitleShimmer
                        .padding(.bottom, 10)
                    headerDescriptionShimmer
                } else if let _ = settings {
                    if !headerViewModel.onlineAgents.isEmpty, !isOffline, showAgents {
                        onlineAgentsAvatars
                            .padding(.bottom, 16)
                    } else if showBrandLogo && !isHeaderLogoLoadFailed, brandLogoURL != nil {
                        headerLogoElement
                            .padding(.bottom, 16)
                    }
                    Group {
                        headerTitleElement
                            .padding(.bottom, 10)
                        headerDescriptionElement
                    }
                    .padding(.horizontal, 20)
                } else {
                    VStack(spacing: 0) {
                        headerLogoShimmer
                            .padding(.bottom, 16)
                        headerTitleShimmer
                            .padding(.bottom, 10)
                        headerDescriptionShimmer
                    }
                }
            }
            .frame(maxWidth: .infinity)

            backButton
                .padding(.leading, 16)
            
            if shouldShowMoreOptions {
                HStack { Spacer(); moreOptionsButton }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 16)
            }
        }
        .padding(.vertical, 20)
    }
}

struct RemoteImage: View {
    @StateObject private var loader: ImageLoader
    let url: URL
    var borderColor: Color? = nil
    var showOnlineIndicator: Bool = false
    var isOffline: Bool = false
    var indicatorOffset: CGFloat = 1
    var backgroundColor: Color? = nil
    var onLoadFailure: (() -> Void)? = nil

    init(url: URL, borderColor: Color? = nil, showOnlineIndicator: Bool = false, isOffline: Bool = false, indicatorOffset: CGFloat = 1, backgroundColor: Color? = nil, onLoadFailure: (() -> Void)? = nil) {
        self.url = url
        self.borderColor = borderColor
        self.showOnlineIndicator = showOnlineIndicator
        self.isOffline = isOffline
        self.indicatorOffset = indicatorOffset
        self.backgroundColor = backgroundColor
        self.onLoadFailure = onLoadFailure
        _loader = StateObject(wrappedValue: ImageLoader(url: url))
    }

    var body: some View {
        Group {
            if let uiImage = loader.image {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                    .padding(0)
                    .background(backgroundColor ?? borderColor ?? .clear)
                    .clipShape(Circle())
                    .overlay(
                        Group { if showOnlineIndicator { OnlineIndicatorView(isOffline: isOffline, offset: indicatorOffset) } },
                        alignment: .bottomTrailing
                    )
            } else if loader.failed {
                CircleShimmerView()
                    .onAppear { onLoadFailure?() }
            } else {
                CircleShimmerView()
            }
        }
        .frame(width: 32, height: 32)
    }
}

// MARK: - Image loading with cache to avoid refetching between mode changes
final class ImageLoader: ObservableObject {
    @Published var image: UIImage? = nil
    @Published var failed: Bool = false

    private let url: URL
    private var task: URLSessionDataTask?

    init(url: URL) {
        self.url = url
        if let cached = ImageCache.shared.image(for: url) {
            self.image = cached
            return
        }
        fetch()
    }

    deinit {
        task?.cancel()
    }

    private func fetch() {
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 30)
        task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let error = error {
                    self.failed = true
                    self.onFailureLog(error)
                    return
                }
                guard let data = data, let uiImage = UIImage(data: data) else {
                    self.failed = true
                    return
                }
                ImageCache.shared.insert(uiImage, for: self.url)
                self.image = uiImage
            }
        }
        task?.resume()
    }

    private func onFailureLog(_ error: Error) {
        // Intentionally minimal; keep behavior unchanged from caller side
        // Caller receives failure via 'failed' state and optional onLoadFailure closure.
    }
}

final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSURL, UIImage>()

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func insert(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }
}

struct CircleShimmerView: View {
    @State private var move = false
    
    var body: some View {
        Circle()
            .frame(width: 32, height: 32)
            .foregroundColor(Color.bcAlphaWhite30)
            .shimmer()
    }
}



struct OnlineIndicatorView: View {
    let isOffline: Bool
    let offset: CGFloat

    init(isOffline: Bool = false, offset: CGFloat = 1) {
        self.isOffline = isOffline
        self.offset = offset
    }
    
    var body: some View {
        Circle()
            .fill(isOffline ? Color.fgDisabled : Color.fgSuccessSecondary)
            .frame(width: 10.75, height: 10.75)
            .overlay(Circle().stroke(Color.fgWhite, lineWidth: 1.25))
            .offset(x: offset, y: offset)
    }
}
