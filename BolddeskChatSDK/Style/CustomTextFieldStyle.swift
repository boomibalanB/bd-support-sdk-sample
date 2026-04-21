import SwiftUI

struct CustomTextFieldStyle: TextFieldStyle {
    let keyboardType: UIKeyboardType
    let isValid: Bool
    let isFocused: Bool
    let errorMessage: String

    func _body(configuration: TextField<Self._Label>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            configuration
                .keyboardType(keyboardType)
                .autocorrectionDisabled(true)
                .autocapitalization(.none)
                .padding(10)
                .frame(height: 36)
                .background(Color.bgPrimary)
                .cornerRadius(8)
                .font(FontFamily.customFont(size: FontSize.medium, weight: .regular))
                .foregroundColor(Color.textSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            !isValid ? Color.borderError :
                                (isFocused ? Color.brand200 : Color.borderPrimary),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: !isValid ? (isFocused ? Color.textErrorPrimary.opacity(0.5) : .clear) :
                           (isFocused ? Color.brand200 : Color(red: 16/255, green: 24/255, blue: 40/255).opacity(0.05)),
                    radius: !isValid ? (isFocused ? 4 : 0) : (isFocused ? 4 : 2),
                    x: 0,
                    y: !isValid ? (isFocused ? 0 : 0) : (isFocused ? 0 : 1)
                )
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(FontFamily.customFont(size: FontSize.small, weight: .regular))
                    .foregroundColor(Color.textErrorPrimary)
                    .padding(.top, 4)
            }
        }
    }
}
