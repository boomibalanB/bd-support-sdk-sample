import SwiftUI


import SwiftUI

struct BottomSheetSinglePicker: View {
    var updateSelectedItem: (DropdownItemModel?) -> Void
    var selectedItem: DropdownItemModel?
    @Binding var isPresented: Bool
    @ObservedObject var singleSelectViewModel: SingleSelectViewModel
    @State private var isDragging = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                Rectangle()
                    .fill(Color.fgSenary)
                    .frame(width: 32, height: 4)
                    .cornerRadius(2)
                    .padding(.top, 4)
                HStack {
                    Spacer()
                    Button(action: {
                        isPresented = false
                    }) {
                        AppIcon(icon: .close, size: FontSize.xlarge, color: .fgQuarterary)
                            .padding([.top, .trailing], 16)
                    }
                }
            }
            .frame(height: 40)
            
            HStack {
                DropdownSearchField(
                    onSearch: { text in
                        Task {
                            await singleSelectViewModel.loadItems(search: text)
                        }
                    },
                    isResetVisible: Binding<Bool>(
                        get: { selectedItem != nil },
                        set: { _ in }
                    )
                )
                if selectedItem != nil {
                    Button(action: {
                        updateSelectedItem(nil)
                        isPresented = false
                    }) {
                        Text("Reset")
                            .font(FontFamily.customFont(size: FontSize.medium, weight: .semibold))
                            .foregroundColor(Color.actionColorPrimaryBg)
                    }
                    .padding(.trailing, 16)
                }
            }

            ZStack {
                if singleSelectViewModel.isLoading {
                    VStack {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .bgBrandSolid))
                            .scaleEffect(2)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.bgPrimary)
                } else {
                    if !singleSelectViewModel.items.isEmpty {
                        ScrollView {
                            ForEach(singleSelectViewModel.items, id: \.id) { item in
                                HStack {
                                    Text(item.displayName)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .foregroundColor(selectedItem == item ? Color.actionColorPrimaryFg : Color.textSecondary)
                                        .font(FontFamily.customFont(size: FontSize.large, weight: .medium))
                                        .padding(.leading, 8)
                                }
                                .padding(16)
                                .background(
                                    selectedItem == item
                                    ? Color.actionColorPrimaryBg
                                    : Color.bgPrimary
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if !isDragging {
                                        updateSelectedItem(item)
                                        isPresented = false
                                    }
                                }
                            }
                        }
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 5)
                                .onChanged { _ in
                                    if !isDragging { isDragging = true }
                                }
                                .onEnded { _ in
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        isDragging = false
                                    }
                                }
                        )
                    } else {
                        VStack {
                            Spacer()
                            Text("No results found")
                                .foregroundColor(Color.textSecondary)
                                .font(FontFamily.customFont(size: FontSize.large, weight: .medium))
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .padding(.bottom, 12)
        .background(Color.bgPrimary)
    }
}
