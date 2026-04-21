import Foundation
import SwiftUI

@MainActor
class SingleSelectViewModel: ObservableObject {
    @Published var items: [DropdownItemModel] = []
    @Published var isLoading: Bool = false
    @Published var selectedItem: DropdownItemModel?
    
    private var currentSearchTask: Task<Void, Never>?
    var fetchItemsAPI: ((String) async -> [DropdownItemModel]) // Removed Int parameter
    
    init(fetchItemsAPI: @escaping (String) async -> [DropdownItemModel]) { // Removed Int parameter
        self.fetchItemsAPI = fetchItemsAPI
    }
    
    func loadItems(search: String = "") async { // Removed index parameter
        currentSearchTask?.cancel()
        
        currentSearchTask = Task {
            isLoading = true
            
            // Use Task cancellation to handle aborted fetches
            guard !Task.isCancelled else {
                return
            }
            
            let result = await fetchItemsAPI(search) // Removed index parameter
            
            guard !Task.isCancelled else {
                return
            }
            
            if search.isEmpty, let selected = selectedItem {
                let others = result.filter { $0 != selected }
                self.items = [selected] + others
            } else {
                self.items = result
            }
            
            isLoading = false
        }
    }
}
