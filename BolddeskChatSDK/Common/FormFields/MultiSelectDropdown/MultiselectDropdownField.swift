import SwiftUI

struct MultiSelectDropdownField: View {
    var placeholder: String
    var updateSelectedItem: ([DropdownItemModel]) -> Void
    var validation: (([DropdownItemModel]) -> Bool)? = nil
    @Binding var selectedItems: [DropdownItemModel]
    var fetchItems: (String) async -> [DropdownItemModel]
    @Binding var errorMessage: String
    @Binding var isValid: Bool
    var isDisabled: Bool = false
    
    @State private var showPicker: Bool = false
    @StateObject var multiSelectViewModel: MultiSelectViewModel
    
    init(
        placeholder: String,
        updateSelectedItem: @escaping ([DropdownItemModel]) -> Void,
        validation: (([DropdownItemModel]) -> Bool)? = nil,
        selectedItems: Binding<[DropdownItemModel]>,
        fetchItems: @escaping (String) async -> [DropdownItemModel],
        errorMessage: Binding<String>,
        isValid: Binding<Bool>,
        isDisabled: Bool = false
    ) {
        self.placeholder = placeholder
        self.updateSelectedItem = updateSelectedItem
        self.validation = validation
        self._selectedItems = selectedItems
        self.fetchItems = fetchItems
        self._errorMessage = errorMessage
        self._isValid = isValid
        self.isDisabled = isDisabled
        _multiSelectViewModel = StateObject(
            wrappedValue: MultiSelectViewModel(
                fetchItemsAPI: fetchItems,
                tempSelectedItems: selectedItems.wrappedValue
            )
        )
    }
    
    var displayText: String {
        if selectedItems.isEmpty {
            return placeholder
        } else if selectedItems.count == 1 {
            return selectedItems.first?.displayName ?? ""
        } else {
            return "\(selectedItems.first?.displayName ?? "") +\(selectedItems.count - 1)"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading){
            ZStack(alignment: .leading) {
                HStack {
                    Text(displayText)
                        .font(FontFamily.customFont(size: FontSize.medium, weight: .regular))
                        .foregroundColor(selectedItems.isEmpty ? Color.textPlaceholder : Color.textSecondary)
                    Spacer()
                    AppIcon(icon: .chevronDown, size: FontSize.semilarge)
                }
            }
            .padding(10)
            .frame(height: 36)
            .background(Color.bgPrimary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        !isValid ? Color.borderError :
                            (showPicker ? Color.brand200 : Color.borderPrimary),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: !isValid ? (showPicker ? Color.textErrorPrimary.opacity(0.5) : .clear) :
                      (showPicker ? Color.brand200 : Color(red: 16/255, green: 24/255, blue: 40/255).opacity(0.05)),
                radius: !isValid ? (showPicker ? 4 : 0) : (showPicker ? 4 : 2),
                x: 0,
                y: !isValid ? (showPicker ? 0 : 0) : (showPicker ? 0 : 1)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                showPicker = true
                multiSelectViewModel.tempSelectedItems = selectedItems
                multiSelectViewModel.loadItems(search: "")
            }
            .disabled(isDisabled)
            .animation(.easeOut, value: selectedItems)
            .onChange(of: selectedItems) { newValue in
                updateSelectedItem(newValue)
                _ = validation?(newValue)
            }
            .sheet(isPresented: $showPicker) {
                BottomSheetMultiPicker(
                    updateSelectedItem: { items in
                        selectedItems = items
                    },
                    selectedItems: selectedItems,
                    isPresented: $showPicker,
                    multiSelectViewModel: multiSelectViewModel
                )
            }
            
            if !isValid {
                Text(errorMessage)
                    .font(FontFamily.customFont(size: FontSize.small, weight: .regular))
                    .foregroundColor(.textErrorPrimary)
                    .padding(.top, 2)
            }
        }
    }
}
