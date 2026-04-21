import SwiftUI

struct RadioButtonsView: View {
    @State private var selectedOption: Bool = true
    let options: [String]
    let validation: ((Bool) -> Bool)?
    let updateSelectedRadioButton: ((Bool) -> Void)
    let defaultValue: Bool
    @Binding var errorMessage: String
    @Binding var isValid: Bool
    @State private var isFocused: Bool = false
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                radioButton(option: options[0], isSelected: selectedOption)
                radioButton(option: options[1], isSelected: !selectedOption)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if !isValid, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(FontFamily.customFont(size: FontSize.medium, weight: .regular))
                    .foregroundColor(.textErrorPrimary)
            }
        }
        .onChange(of: defaultValue) { newValue in
            selectedOption = newValue
            updateSelectedRadioButton(selectedOption)
        }
        .padding(.bottom, 16)
        .padding(.trailing, 12)
    }
    
    @ViewBuilder
    private func radioButton(option: String, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .strokeBorder(isSelected ? Color.actionColorPrimaryBg : Color.borderSecondary, lineWidth: 2)
                    .background(Circle().fill(Color.bgPrimary))
                    .frame(width: 20, height: 20)
                
                Circle()
                    .fill(Color.actionColorPrimaryBg)
                    .frame(width: 10, height: 10)
                    .scaleEffect(isSelected ? 1 : 0.01)
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
            }
            .onTapGesture {
                let newValue = option == options[0]
                withAnimation(.easeInOut(duration: 0.15)) {
                    selectedOption = newValue
                }
                updateSelectedRadioButton(newValue)
                let _ = validation?(newValue)
            }

            Text(option)
                .font(FontFamily.customFont(size: FontSize.medium, weight: .regular))
                .foregroundColor(.textSecondary)
        }
        .contentShape(Rectangle()) // Makes entire row tappable
        .onTapGesture {
            let newValue = option == options[0]
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedOption = newValue
            }
            updateSelectedRadioButton(newValue)
            let _ = validation?(newValue)
        }
    }
}
