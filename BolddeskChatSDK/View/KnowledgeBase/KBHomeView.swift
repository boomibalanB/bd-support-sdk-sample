import SwiftUI

struct KBHomeView: View {
    @ObservedObject var chatViewModel: ChatViewModel
    @ObservedObject var viewModel: KnowledgeBaseViewModel
    @State private var searchText: String = ""
    @State private var navigateToArticles: Bool = false
    @State private var navigateToCategoryList: Bool = false
    @State private var selectedCategoryId: Int? = nil
    @State private var openAsSearchMode: Bool = false
    let onBack: (() -> Void)?

    init(chatViewModel: ChatViewModel, viewModel: KnowledgeBaseViewModel, onBack: (() -> Void)? = nil) {
        self.chatViewModel = chatViewModel
        self.viewModel = viewModel
        self.onBack = onBack
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Fill safe area with app bar background color
            GeometryReader { geometry in
                Color.appBarColor
                    .frame(height: geometry.safeAreaInsets.top)
                    .ignoresSafeArea(edges: .top)
            }

            VStack(spacing: 0) {
                // Header with logo, title, and description
                kbHeaderView
                Rectangle()
                    .fill(Color.borderSecondary)
                    .frame(height: 1)
                // Content below header
                kbContentView
            }
        }
    }

    // MARK: - KB Header View
    private var kbHeaderView: some View {
        VStack(alignment: .center, spacing: 0) {
            ZStack {
                HStack {
                    Button(action: {
                        if let onBack = onBack {
                            onBack()
                        }
                    }) {
                        AppIcon(
                            icon: .arrowLeft,
                            size: FontSize.extralarge,
                            color: .textPrimaryAppBarColor
                        )
                        .frame(width: 32, height: 32)
                    }
                    Spacer()
                }

                // Logo (centered)
                let logoCandidate = chatViewModel.settings?.widgetSettings.brandLogo
                let logoUrl: String? = {
                    if let l = logoCandidate, !l.isEmpty { return l }
                    return AppConstant.brandLogoURL.isEmpty
                        ? nil : AppConstant.brandLogoURL
                }()

                if let brandLogoUrl = logoUrl, let brandLogoURL = URL(string: brandLogoUrl) {
                    RemoteImage(
                        url: brandLogoURL,
                        borderColor: nil,
                        showOnlineIndicator: true,
                        isOffline: false,
                        indicatorOffset: 1,
                        backgroundColor: shouldShowErrorBackground(brandLogoURL: brandLogoURL) ? Color.boldDeskLogoColor : nil,
                        onLoadFailure: nil
                    )
                    .padding(.bottom, 12)
                }
            }
            // Header Title
            Text(
                chatViewModel.settings?.widgetSettings.headerTitle
                    ?? ResourceManager.localized("welcome_to_bolddesk")
            )
            .font(
                FontFamily.customFont(size: FontSize.xlarge, weight: .semibold)
            )
            .foregroundColor(Color.textPrimaryAppBarColor)
            .multilineTextAlignment(.center)
            .padding(.bottom, 8)

            // Header Description
            if let description = chatViewModel.settings?.widgetSettings
                .headerDescription, !description.isEmpty
            {
                Text(description)
                    .font(
                        FontFamily.customFont(
                            size: FontSize.small,
                            weight: .regular
                        )
                    )
                    .foregroundColor(Color.textPrimaryAppBarColor.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 20)
        .background(Color.appBarColor)
    }

    // MARK: - KB Content View
    private var kbContentView: some View {
        VStack(spacing: 0) {
            // If still loading, show shimmer rows
            if viewModel.isLoading {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(0..<4) { _ in
                            CategoryShimmerRow()
                        }
                    }
                    .padding(.horizontal, 12)
                }

            // If there are no categories at all, show a full-page message
            } else if viewModel.categories.isEmpty {
                VStack {
                    Spacer()
                    Text(ResourceManager.localized("no_categories"))
                        .foregroundColor(Color.textTertiary)
                        .font(
                            FontFamily.customFont(
                                size: FontSize.medium,
                                weight: .regular
                            )
                        )
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    Spacer()
                }

            // Otherwise show the search + category list UI
            } else {
                // Search field (tapping opens ArticlesList in search mode)
                Button(action: {
                    openAsSearchMode = true
                    navigateToArticles = true
                    // clear any search text for navigation mode
                    searchText = ""
                }) {
                    HStack(spacing: 8) {
                        AppIcon(
                            icon: .search,
                            size: FontSize.semilarge,
                            color: .textTertiary
                        )
                        Text(ResourceManager.localized("search_article"))
                            .foregroundColor(Color.textPlaceholder)
                            .font(
                                FontFamily.customFont(
                                    size: FontSize.medium,
                                    weight: .regular
                                )
                            )
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.bgPrimary)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.borderPrimary, lineWidth: 1)
                    )
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 16)

                // Category list header
                HStack {
                    Text(ResourceManager.localized("category"))
                        .font(
                            FontFamily.customFont(
                                size: FontSize.large,
                                weight: .medium
                            )
                        )
                        .foregroundColor(Color.textTertiary)
                    Spacer()
                    Button(action: { navigateToCategoryList = true }) {
                        Text(ResourceManager.localized("view_all"))
                            .font(
                                FontFamily.customFont(
                                    size: FontSize.medium,
                                    weight: .semibold
                                )
                            )
                            .foregroundColor(Color.actionColorPrimaryBg)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)

                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredCategories.prefix(4)) { cat in
                            categoryCardView(for: cat)
                        }
                    }
                    .padding(.horizontal, 12)

                    Spacer(minLength: 80)
                }
            }

            Spacer()

            NavigationLink(
                destination: KBCategoryListView(chatViewModel: chatViewModel),
                isActive: $navigateToCategoryList
            ) { EmptyView() }

            NavigationLink(
                destination: ArticlesListView(
                    chatViewModel: chatViewModel,
                    widgetId: chatViewModel.settings?.widgetId,
                    categoryId: openAsSearchMode ? nil : selectedCategoryId,
                    searchMode: openAsSearchMode
                ),
                isActive: $navigateToArticles
            ) { EmptyView() }
        }
        // KBHomeView uses the provided viewModel which loads categories in its initializer.
    }

    private var filteredCategories: [KBCategory] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return viewModel.categories
        }
        return viewModel.categories.filter {
            $0.name.lowercased().contains(searchText.lowercased())
        }
    }

    // MARK: - Category Card View
    private func categoryCardView(for category: KBCategory) -> some View {
        Button(action: {
            selectedCategoryId = category.id
            openAsSearchMode = false
            navigateToArticles = true
        }) {
            HStack(spacing: 12) {
                // Category Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(category.name)
                        .foregroundColor(Color.textSecondary)
                        .font(
                            FontFamily.customFont(
                                size: FontSize.medium,
                                weight: .medium
                            )
                        )
                        .lineLimit(1)

                    if let count = category.articleCount {
                        Text(
                            "\(count) \(count == 1 ?  ResourceManager.localized("articleText"): ResourceManager.localized("articlesText"))"
                        )
                        .foregroundColor(Color.textTertiary)
                        .font(
                            FontFamily.customFont(
                                size: FontSize.small,
                                weight: .regular
                            )
                        )
                    }
                }

                Spacer()
                // Chevron
                AppIcon(
                    icon: .chevronRight,
                    size: FontSize.semilarge,
                    color: .fgQuarterary
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.bgPrimary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.borderSecondary, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
