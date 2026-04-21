import Foundation
import SwiftUI

@MainActor
class MultiSelectViewModel: ObservableObject {
    @Published var items: [DropdownItemModel] = []
    @Published var isLoading: Bool = false
    @Published var tempSelectedItems: [DropdownItemModel] = []
    @Published var displayedItems: [DropdownItemModel] = []
    
    private var currentSearchTask: Task<Void, Never>?
    var fetchItemsAPI: ((String) async -> [DropdownItemModel])
    
    init(fetchItemsAPI: @escaping (String) async -> [DropdownItemModel], tempSelectedItems: [DropdownItemModel]) {
        self.fetchItemsAPI = fetchItemsAPI
        self.tempSelectedItems = tempSelectedItems
    }
    
    func loadItems(search: String = "") {
        // Cancel the ongoing task, if any
        currentSearchTask?.cancel()
        
        currentSearchTask = Task {
            isLoading = true
            
            // Use Task cancellation to handle aborted fetches
            guard !Task.isCancelled else {
                return
            }
            
            let result = await fetchItemsAPI(search)
            
            guard !Task.isCancelled else {
                return
            }
            
            self.items = result
            
            if search.isEmpty {
                // Ensure only selected items that are present in result
                let selected = tempSelectedItems.filter { selectedItem in
                    result.contains(where: { $0.id == selectedItem.id })
                }
                
                let unselected = result.filter { item in
                    !selected.contains(where: { $0.id == item.id })
                }
                
                self.displayedItems = selected + unselected
            } else {
                self.displayedItems = result
            }
            
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
    }
}
