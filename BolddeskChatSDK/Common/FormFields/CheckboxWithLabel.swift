import SwiftUI

struct CheckboxWithLabel: View {
    var isChecked: Bool
    let title: String?
    let validation: ((Bool) -> Bool)?
    let updateSelectedCheckbox: ((Bool) -> Void)
    @Binding var errorMessage: String
    @Binding var isValid: Bool
    @State private var isFocused: Bool = false

    var body: some View {
        VStack(alignment: .leading) {
            HStack(spacing: 12) {
                FormCheckBox(isChecked: isChecked) { newValue in
                    updateSelectedCheckbox(newValue)
                }

                if let title = title, !title.isEmpty {
                    Text(title)
                        .font(FontFamily.customFont(size: FontSize.medium, weight: .regular))
                        .foregroundColor(.textSecondary)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                let newValue = !isChecked
                updateSelectedCheckbox(newValue)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .onChange(of: isChecked) { newValue in
                
                let _ = validation?(newValue)
                isFocused = true
            }

            if !isValid, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(FontFamily.customFont(size: FontSize.medium, weight: .regular))
                    .foregroundColor(.textErrorPrimary)
            }
        }
        .padding(.bottom, 16)
        .padding(.trailing, 12)
    }
}
