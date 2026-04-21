import SwiftUI

struct BottomSheetMultiPicker: View {
    var updateSelectedItem: ([DropdownItemModel]) -> Void
    var selectedItems: [DropdownItemModel]
    @Binding var isPresented: Bool
    @ObservedObject var multiSelectViewModel: MultiSelectViewModel
    @State private var isDragging = false
    
    var body: some View {
        VStack(spacing: 0) {
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
                    onSearch:
                        { searchText in
                            multiSelectViewModel.loadItems(search: searchText)
                        },
                    isResetVisible: Binding<Bool>(
                        get: { !multiSelectViewModel.tempSelectedItems.isEmpty },
                        set: { _ in }
                ))
                if !multiSelectViewModel.tempSelectedItems.isEmpty {
                    Button(action: {
                        multiSelectViewModel.tempSelectedItems.removeAll()
                    }) {
                        Text("Reset")
                            .font(FontFamily.customFont(size: FontSize.medium, weight: .semibold))
                            .foregroundColor(Color.actionColorPrimaryBg)
                    }
                    .disabled(multiSelectViewModel.tempSelectedItems.isEmpty)
                    .padding(.trailing, 16)
                }
            }
            
            
            if multiSelectViewModel.isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .bgBrandSolid))
                        .scaleEffect(2)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.bgPrimary)
            }
            else {
                if !multiSelectViewModel.displayedItems.isEmpty {
                    ScrollView {
                        ForEach(multiSelectViewModel.displayedItems, id: \.self) { item in
                            itemButton(item: item)
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
                }
                else {
                    VStack {
                        Spacer()
                        Text("No results found")
                            .foregroundColor(Color.textSecondary)
                            .font(FontFamily.customFont(size: FontSize.large, weight: .medium))
                        Spacer()
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            
            VStack(alignment: .leading) {
                Divider()
                    .frame(height: 1)
                    .background(Color.borderSecondary)
                HStack(spacing: 12) {
                    Button(action: {
                        updateSelectedItem(multiSelectViewModel.tempSelectedItems)
                        isPresented = false
                    }) {
                        Text("Save")
                            .font(FontFamily.customFont(size: FontSize.medium, weight: .semibold))
                            .foregroundColor(Color.actionColorPrimaryFg)
                            .padding(.vertical, 12)
                            .padding(.horizontal)
                            .background(Color.actionColorPrimaryBg)
                            .cornerRadius(6)
                    }
                    Button(action: {
                        isPresented = false
                    }) {
                        Text("Cancel")
                            .font(FontFamily.customFont(size: FontSize.medium, weight: .semibold))
                            .foregroundColor(Color.textSecondary)
                            .padding(.vertical, 12)
                            .padding(.horizontal)
                            .background(Color.bgPrimary)
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.borderPrimary, lineWidth: 1)
                            )
                    }
                }
                .padding(.top, 12)
                .padding(.horizontal)
                .background(Color.bgSecondary)
                .padding(.bottom, 40)
            }
            .background(Color.bgSecondary)
        }
        .background(Color.bgPrimary)
        .ignoresSafeArea(.all, edges: .bottom)
    }
    
    private func itemButton(item: DropdownItemModel) -> some View {
        Button(action: {
            if !isDragging {
                if multiSelectViewModel.tempSelectedItems.contains(item) {
                    multiSelectViewModel.tempSelectedItems.removeAll { $0 == item }
                } else {
                    multiSelectViewModel.tempSelectedItems.append(item)
                }
            }
        }) {
            HStack {
                FormCheckBox(isChecked: multiSelectViewModel.tempSelectedItems.contains(item))
                    .allowsHitTesting(false)
                Text(item.displayName)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundColor(Color.textSecondary)
                    .font(FontFamily.customFont(size: FontSize.large, weight: .medium))
                    .padding(.leading, 8)
                Spacer()
            }
            .padding(16)
        }
    }
}

struct FormCheckBox: View {
    var isChecked: Bool
    var onToggle: ((Bool) -> Void)? = nil
    
    var body: some View {
        Button {
            onToggle?(!isChecked)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        Color.borderPrimary, lineWidth: 2)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isChecked ? Color.actionColorPrimaryBg : Color.bgPrimary)
                    )
                
                if isChecked {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .frame(width: 20, height: 20)
            .animation(.easeInOut(duration: 0.2), value: isChecked)
        }
        .buttonStyle(.plain)
    }
}
