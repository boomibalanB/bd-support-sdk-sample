import SwiftUI

struct TextAreaFieldView: View {
    var placeholder: String?
    @Binding var text: String
    @Binding var errorMessage: String
    @Binding var isValid: Bool
    @State private var isFocused: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .frame(minHeight: 150, maxHeight: 150)
                    .font(FontFamily.customFont(size: FontSize.medium, weight: .regular))
                    .padding(10)
                    .background(Color.bgPrimary)
                    .cornerRadius(8)
                    .autocorrectionDisabled(true)
                    .autocapitalization(.none)
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
                    .onTapGesture {
                        isFocused = true
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                        isFocused = true
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                        isFocused = false
                    }
                
                if text.isEmpty, let placeholder = placeholder, !placeholder.isEmpty {
                    Text(placeholder)
                        .font(FontFamily.customFont(size: FontSize.medium, weight: .regular))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                }
            }
            .padding(0)
            .onTapGesture {
                 isFocused = false // For dismissing keyboard when tapping outside
            }
            
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(FontFamily.customFont(size: FontSize.medium, weight: .regular))
                    .foregroundColor(.textErrorPrimary)
            }
        }
    }
}
