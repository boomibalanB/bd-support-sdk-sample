internal import BoldDeskSupportSDK
import SwiftUI

struct ArticlesListView: View {
    @ObservedObject var chatViewModel: ChatViewModel
    let widgetId: String?
    let categoryId: Int?
    let sectionId: Int?
    let searchMode: Bool

    @StateObject private var viewModel = ArticlesListViewModel()
    @State private var searchText: String = ""
    @State private var searchTask: Task<Void, Never>? = nil
    @State private var hasLoadedInitially: Bool = false
    @State private var previousSearchText: String = ""

    init(
        chatViewModel: ChatViewModel,
        widgetId: String?,
        categoryId: Int? = nil,
        sectionId: Int? = nil,
        searchMode: Bool = false
    ) {
        self.chatViewModel = chatViewModel
        self.widgetId = widgetId
        self.categoryId = categoryId
        self.sectionId = sectionId
        self.searchMode = searchMode
    }

    @Environment(\.presentationMode) private var presentationMode

    @State private var navigateToSection: Bool = false
    @State private var selectedSectionId: Int? = nil

    var body: some View {
        ZStack(alignment: .top) {
            // Fill safe area with app bar background color
            GeometryReader { geometry in
                Color.appBarColor
                    .frame(height: geometry.safeAreaInsets.top)
                    .ignoresSafeArea(edges: .top)
            }

            VStack(spacing: 0) {
                // Header
                SimpleHeaderView(
                    title: ResourceManager.localized("help"),
                    onBack: { presentationMode.wrappedValue.dismiss() },
                    isInitialLoading: false,
                    shouldShowChatDirectly: false
                )

                // Search field
                HStack(spacing: 8) {
                    AppIcon(
                        icon: .search,
                        size: FontSize.semilarge,
                        color: .textTertiary
                    )

                    ZStack(alignment: .leading) {
                        if searchText.isEmpty {
                            Text(ResourceManager.localized("search_article"))
                                .foregroundColor(Color.textPlaceholder)
                                .font(
                                    FontFamily.customFont(
                                        size: FontSize.medium,
                                        weight: .regular
                                    )
                                )
                        }

                        TextField("", text: $searchText)
                            .foregroundColor(Color.textSecondary)
                            .font(
                                FontFamily.customFont(
                                    size: FontSize.medium,
                                    weight: .regular
                                )
                            )
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.bgPrimary)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)  // 🔥 match radius
                        .stroke(Color.borderPrimary, lineWidth: 1)
                )
                .padding(12)
                .background(Color.bgSecondary)
                // Header title & description from API (if present)
                if let title = viewModel.title, !title.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(
                                FontFamily.customFont(
                                    size: FontSize.large,
                                    weight: .semibold
                                )
                            )
                            .foregroundColor(Color.textSecondary)
                        if let desc = viewModel.descriptionText, !desc.isEmpty {
                            Text(desc)
                                .font(
                                    FontFamily.customFont(
                                        size: FontSize.small,
                                        weight: .regular
                                    )
                                )
                                .foregroundColor(Color.textTertiary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                }

                // Content area
                if viewModel.isLoading {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(0..<10) { _ in
                                CategoryShimmerRow()
                            }
                        }
                        .padding(.top, 12)
                        .padding(.horizontal, 12)
                    }
                } else if self.searchMode {
                    if viewModel.searchArticles.isEmpty {
                        VStack {
                            Spacer()
                            Text(ResourceManager.localized("no_articles"))
                                .foregroundColor(Color.textTertiary)
                                .font(
                                    FontFamily.customFont(
                                        size: FontSize.medium,
                                        weight: .regular
                                    )
                                )
                            Spacer()
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(viewModel.searchArticles) { article in
                                    searchArticleCardView(for: article)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.top, 12)
                            Spacer(minLength: 80)
                        }
                    }
                } else {
                    if viewModel.articles.isEmpty {
                        VStack {
                            Spacer()
                            Text(ResourceManager.localized("no_articles"))
                                .foregroundColor(Color.textTertiary)
                                .font(
                                    FontFamily.customFont(
                                        size: FontSize.medium,
                                        weight: .regular
                                    )
                                )
                            Spacer()
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(viewModel.articles) { article in
                                    if article.isSection ?? false {
                                        // Section (folder-style) - navigate into same view with sectionId
                                        sectionCardView(for: article)
                                    } else {
                                        // Regular article - show row
                                        articleCardView(for: article)
                                    }
                                }
                            }
                            .padding(.horizontal, 12)

                            Spacer(minLength: 80)
                        }
                    }
                }
                Rectangle()
                    .fill(Color.borderSecondary)
                    .frame(height: 1)
                // Powered by footer (show when settings enable it)
                if chatViewModel.settings?.generalSettings.includePoweredBy
                    == true
                {
                    PoweredByBolddeskView()
                }
            }
        }
        .background(
            NavigationLink(
                destination: Group {
                    if let sid = selectedSectionId {
                        ArticlesListView(
                            chatViewModel: chatViewModel,
                            widgetId: widgetId,
                            categoryId: nil,
                            sectionId: sid,
                            searchMode: false
                        )
                        .navigationBarHidden(true)
                    } else {
                        EmptyView()
                    }
                },
                isActive: $navigateToSection
            ) {
                EmptyView()
            }
            .hidden()
        )
        .navigationBarHidden(true)
        .onAppear {
            // Only load data on initial appearance, not when returning from navigation
            guard !hasLoadedInitially else { return }

            // configure viewModel widget id and initial fetch behavior
            Task {
                if let wid = widgetId {
                    await viewModel.setWidgetId(wid)
                } else if let wid = chatViewModel.settings?.widgetId {
                    await viewModel.setWidgetId(wid)
                }

                // If not opened in searchMode, fetch articles
                if !searchMode {
                    // If opened for a section, fetch by sectionId; else if category provided, fetch by category
                    if let sid = sectionId {
                        await viewModel.fetchArticles(sectionId: sid)
                    } else if let catId = categoryId {
                        await viewModel.fetchArticles(categoryId: catId)
                    }
                }
                // Note: If searchMode is true, user can start typing to trigger search via onChange

                // Mark as loaded to prevent reload on back navigation
                await MainActor.run {
                    hasLoadedInitially = true
                }
            }
        }
        .onChange(of: searchText) { _ in
            // Schedule debounced search when user types. No API call on empty initial searchMode open.
            scheduleSearchDebounce()
        }
    }

    private func doSearch() async {
        // Trimmed text
        let text = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        // Determine context: section takes precedence, then category, else global search
        if self.searchMode {
            await viewModel.fetchKBSearchArticles(searchText: text)
        } else {
            await viewModel.fetchArticles(
                categoryId: categoryId,
                sectionId: sectionId,
                searchText: text
            )
        }
    }

    private func scheduleSearchDebounce() {
        searchTask?.cancel()

        searchTask = Task { [searchText] in
            try? await Task.sleep(nanoseconds: 350 * 1_000_000)
            if Task.isCancelled { return }

            let trimmedText = searchText.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            let previousTrimmed = previousSearchText.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            // Case 1: Only spaces → ignore
            if trimmedText.isEmpty && previousTrimmed.isEmpty {
                return
            }

            // Case 2: Text typed OR cleared after typing → call API
            await doSearch()

            // Update previous state
            previousSearchText = searchText
        }
    }

    // MARK: - Section Card View
    private func sectionCardView(for article: KBArticle) -> some View {
        Button(action: {
            selectedSectionId = article.id
            navigateToSection = true
        }) {
            HStack(alignment: .top, spacing: 0) {
                // Section icon with folder style
                AppIcon(
                    icon: .folder,
                    size: FontSize.semilarge,
                    color: .textTertiary
                )
                .frame(width: 24, height: 24)
                .padding(.trailing, 8)
                // Section Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(article.name ?? "")
                        .foregroundColor(Color.textSecondary)
                        .font(
                            FontFamily.customFont(
                                size: FontSize.medium,
                                weight: .medium
                            )
                        )
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)

                    if let count = article.articleCount {
                        Text(
                            "\(count) \(count == 1 ? ResourceManager.localized("articleText") : ResourceManager.localized("articlesText"))"
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
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .padding(.leading, 8)
            .padding(.trailing, 12)
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

    // MARK: - Article Card View
    private func articleCardView(for article: KBArticle) -> some View {
        Button(action: {
            BDSupportSDK.showArticle(
                articleId: article.id,
                articleSlugTitle: "",
                directlyShowArticle: true,
                domainUrl:
                    "\(WidgetStorageManager.getBrandUrl() ?? "")/\(DeviceConfig.languageCode)",
                appKey: chatViewModel.settings?.widgetId
            )
        }) {
            HStack(alignment: .top, spacing: 0) {
                // Article icon
                AppIcon(
                    icon: .article,
                    size: FontSize.semilarge,
                    color: .textTertiary
                )
                .frame(width: 24, height: 24)
                .padding(.trailing, 8)
                // Article Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(article.name ?? "")
                        .foregroundColor(Color.textSecondary)
                        .font(
                            FontFamily.customFont(
                                size: FontSize.medium,
                                weight: .regular
                            )
                        )
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)

                    if let slug = article.slugTitle, !slug.isEmpty {
                        Text(slug)
                            .foregroundColor(Color.textTertiary)
                            .font(
                                FontFamily.customFont(
                                    size: FontSize.small,
                                    weight: .regular
                                )
                            )
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Chevron
                AppIcon(
                    icon: .chevronRight,
                    size: FontSize.semilarge,
                    color: .fgQuarterary
                )
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .padding(.leading, 8)
            .padding(.trailing, 12)
            .padding(.vertical, 8)
            .background(Color.bgPrimary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.borderSecondary, lineWidth: 1)
            )
        }
    }

    private func searchArticleCardView(for article: KBSearchArticle)
        -> some View
    {
        let hasDescription = !(article.description?.isEmpty ?? true)

        return Button(action: {
            BDSupportSDK.showArticle(
                articleId: article.id ?? 0,
                articleSlugTitle: "",
                directlyShowArticle: true,
                domainUrl:
                    "\(WidgetStorageManager.getBrandUrl() ?? "")/\(DeviceConfig.languageCode)",
                appKey: chatViewModel.settings?.widgetId
            )
        }) {
            HStack(alignment: hasDescription ? .top : .center, spacing: 0) {

                // Article icon
                AppIcon(
                    icon: .article,
                    size: FontSize.semilarge,
                    color: .textTertiary
                )
                .frame(width: 24, height: 24)
                .padding(.trailing, 8)

                // Article Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(article.title ?? "")
                        .foregroundColor(Color.textSecondary)
                        .font(
                            FontFamily.customFont(
                                size: FontSize.medium,
                                weight: .regular
                            )
                        )
                        .lineLimit(1)

                    if hasDescription {
                        Text(article.description!)
                            .foregroundColor(Color.textTertiary)
                            .font(
                                FontFamily.customFont(
                                    size: FontSize.small,
                                    weight: .regular
                                )
                            )
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Chevron
                AppIcon(
                    icon: .chevronRight,
                    size: FontSize.semilarge,
                    color: .fgQuarterary
                )
                .frame(
                    maxHeight: .infinity,
                    alignment: hasDescription ? .center : .center
                )
            }
            .padding(.leading, 8)
            .padding(.trailing, 12)
            .padding(.vertical, 8)
            .background(Color.bgPrimary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.borderSecondary, lineWidth: 1)
            )
        }
    }
}
