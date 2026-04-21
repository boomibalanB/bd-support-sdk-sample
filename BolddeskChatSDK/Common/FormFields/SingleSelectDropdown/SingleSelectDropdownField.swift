import SwiftUI

struct SingleSelectDropdownField: View {
    var placeholder: String
    var updateSelectedItem: (DropdownItemModel?) -> Void
    var validation: ((DropdownItemModel?) -> Bool)? = nil
    
    @Binding var selectedItem: DropdownItemModel?
    @Binding var errorMessage: String
    @Binding var isValid: Bool
    
    var fetchItems: (String) async -> [DropdownItemModel]
    
    @State private var showPicker = false
    @StateObject var singleSelectViewModel: SingleSelectViewModel
    
    init(
        placeholder: String,
        updateSelectedItem: @escaping (DropdownItemModel?) -> Void,
        validation: ((DropdownItemModel?) -> Bool)? = nil,
        selectedItem: Binding<DropdownItemModel?>,
        fetchItems: @escaping (String) async -> [DropdownItemModel],
        errorMessage: Binding<String>,
        isValid: Binding<Bool>
    ) {
        self.placeholder = placeholder
        self.updateSelectedItem = updateSelectedItem
        self.validation = validation
        self._selectedItem = selectedItem
        self.fetchItems = fetchItems
        self._errorMessage = errorMessage
        self._isValid = isValid
        _singleSelectViewModel = StateObject(wrappedValue: SingleSelectViewModel(fetchItemsAPI: fetchItems))
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            ZStack(alignment: .leading) {
                HStack {
                    Text(selectedItem?.displayName ?? placeholder)
                        .font(FontFamily.customFont(size: FontSize.medium, weight: .regular))
                        .foregroundColor(selectedItem == nil ? Color.textPlaceholder : Color.textSecondary)
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
                        !isValid ? Color.borderError : (showPicker ? Color.brand200 : Color.borderPrimary),
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
                Task {
                    showPicker = true
                    singleSelectViewModel.selectedItem = selectedItem
                    await singleSelectViewModel.loadItems(search: "")
                }
            }
            .onChange(of: selectedItem) { newValue in
                updateSelectedItem(newValue)
                _ = validation?(newValue)
            }
            .animation(.easeOut, value: selectedItem)
            .sheet(isPresented: $showPicker) {
                BottomSheetSinglePicker(
                    updateSelectedItem: { item in
                        selectedItem = item
                    },
                    selectedItem: selectedItem,
                    isPresented: $showPicker,
                    singleSelectViewModel: singleSelectViewModel
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
