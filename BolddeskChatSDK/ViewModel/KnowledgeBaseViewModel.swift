import Foundation
import SwiftUI

@MainActor
class KnowledgeBaseViewModel: ObservableObject {
    @Published var categories: [KBCategory] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let apiClient = ChatAPIClient()
    private(set) var widgetId: String?
    private var hasLoadedCategories: Bool = false

    init(widgetId: String? = nil, perPage: Int = 4) {
        self.widgetId = widgetId
        if let wid = widgetId, !wid.isEmpty {
            Task { await loadCategoriesIfNeeded(widgetId: wid, page: 1, perPage: perPage) }
        }
    }

    func setWidgetId(_ id: String?) async {
        guard let id = id, !id.isEmpty else { return }
        self.widgetId = id
        await loadCategoriesIfNeeded(widgetId: id, page: 1, perPage: 100)
    }

    private func loadCategoriesIfNeeded(widgetId: String, page: Int = 1, perPage: Int = 100) async {
        guard !hasLoadedCategories else { return }
        hasLoadedCategories = true
        await fetchCategories(widgetId: widgetId, page: page, perPage: perPage)
    }

    func fetchCategories(widgetId: String, page: Int = 1, perPage: Int = 4) async {
        isLoading = true
        errorMessage = nil
        do {
            let resp = try await apiClient.getKBCategories(widgetId: widgetId, page: page, perPage: perPage)
            categories = resp.categorylist
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
