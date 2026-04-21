import SwiftUI

struct DropdownSearchField: View {
    var onSearch: (String) -> Void

    @State private var searchText: String = ""
    @State private var isFocused: Bool = false
    @Binding var isResetVisible: Bool

    // Default initializer
    init(onSearch: @escaping (String) -> Void, isResetVisible: Binding<Bool> = .constant(false)) {
         self.onSearch = onSearch
         self._isResetVisible = isResetVisible
     }

    var body: some View {
        HStack {
            ZStack(alignment: .leading) {
                if searchText.isEmpty {
                    Text("Search")
                        .foregroundColor(Color.textPlaceholder)
                        .padding(.horizontal, 12)
                        .font(FontFamily.customFont(size: FontSize.medium, weight: .regular))
                }

                TextField("", text: $searchText, onEditingChanged: { isEditing in
                    isFocused = isEditing
                })
                .foregroundColor(Color.textSecondary)
                .font(FontFamily.customFont(size: FontSize.medium, weight: .regular))
                .padding(.vertical, 12)
                .padding(.horizontal, 12)
                .onChange(of: searchText) { newText in
                    let trimmedText = newText.trimmingCharacters(in: .whitespacesAndNewlines)
                    onSearch(trimmedText)
                }
            }

            Divider()
                .frame(width: 1, height: 44)
                .background(isFocused ? Color.brand200 : Color.borderPrimary)

            AppIcon(icon: .search, size: FontSize.xlarge)
                .padding(.leading, 6)
                .padding(.trailing, 12)
        }
        .frame(height: 40)
        .background(Color.bgPrimary)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isFocused ? Color.brand200 : Color.borderPrimary, lineWidth: 2)
        )
        .cornerRadius(8)
        .shadow(color: isFocused ? Color.brand200 : .clear, radius: 4, x: 0, y: 0)
        .padding(.leading, 16)
        .padding(.trailing, isResetVisible ? 8 : 16)
        .padding(.vertical, 14)
    }
}
