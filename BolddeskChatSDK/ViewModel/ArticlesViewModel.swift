import SwiftUI
internal import BoldDeskSupportSDK

@MainActor
class ArticlesListViewModel: ObservableObject {
    @Published var articles: [KBArticle] = []
    @Published var searchArticles: [KBSearchArticle] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var title: String? = nil
    @Published var descriptionText: String? = nil

    private let apiClient = ChatAPIClient()
    private(set) var widgetId: String?
    init(){
        BDSupportSDK.applyTheme(primaryColor: AppConstant.appBarColor.isEmpty ? AppConstant.appBarHex : AppConstant.appBarColor)
    }

    func setWidgetId(_ id: String?) async {
        guard let id = id, !id.isEmpty else { return }
        self.widgetId = id
    }

    func clearArticles() async {
        self.articles = []
        self.errorMessage = nil
    }

    func fetchArticles(categoryId: Int? = nil, sectionId: Int? = nil, searchText: String? = nil) async {
        guard let wid = widgetId else {
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            let resp = try await apiClient.getKBArticles(widgetId: wid, categoryId: categoryId, sectionId: sectionId, searchText: searchText)
            self.articles = resp.result
            // set header fields if provided
            self.title = resp.title
            self.descriptionText = resp.description
        } catch {
            self.errorMessage = error.localizedDescription
            self.title = nil
            self.descriptionText = nil
        }
        isLoading = false
    }
    
    func fetchKBSearchArticles(categoryId: Int? = nil, sectionId: Int? = nil, searchText: String? = nil) async {
        guard let wid = widgetId else {
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            let resp = try await apiClient.getKBSearchArticles(widgetId: wid, searchText: searchText)
            self.searchArticles = resp
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
