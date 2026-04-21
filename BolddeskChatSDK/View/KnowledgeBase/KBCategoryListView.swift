import SwiftUI

struct KBCategoryListView: View {
    @ObservedObject var chatViewModel: ChatViewModel
    @StateObject private var viewModel: KnowledgeBaseViewModel
    @State private var searchText: String = ""
    @State private var navigateToArticles: Bool = false
    @State private var selectedCategoryId: Int? = nil
    @State private var openAsSearchMode: Bool = false
    @Environment(\.presentationMode) private var presentationMode

    init(chatViewModel: ChatViewModel) {
        self.chatViewModel = chatViewModel
        _viewModel = StateObject(
            wrappedValue: KnowledgeBaseViewModel(
                widgetId: chatViewModel.settings?.widgetId,
                perPage: 100
            )
        )
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
                            Text(ResourceManager.localized("search_category"))
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
                } else {
                    if filteredCategories.isEmpty {
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
                            Spacer()
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(filteredCategories) { cat in
                                    categoryCardView(for: cat)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)

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

                NavigationLink(
                    destination: ArticlesListView(
                        chatViewModel: chatViewModel,
                        widgetId: chatViewModel.settings?.widgetId,
                        categoryId: selectedCategoryId,
                        searchMode: openAsSearchMode
                    )
                    .navigationBarHidden(true),
                    isActive: $navigateToArticles
                ) { EmptyView() }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if let wid = chatViewModel.settings?.widgetId {
                Task { await viewModel.setWidgetId(wid) }
            }
        }
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
