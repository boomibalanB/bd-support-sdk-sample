import SwiftUI

struct SingleLineTextFieldView: View {
    let placeholder: String
    let validation: (String) -> Bool
    let updateEnteredText: (String) -> Void
    
    @Binding var text: String
    @Binding var errorMessage: String
    @Binding var isValid: Bool
    
    @State private var isFocused: Bool = false
    
    var body: some View {
        TextField(placeholder, text: $text, onEditingChanged: { focused in
            isFocused = focused
        })
        .onChange(of: text) { newValue in
            updateEnteredText(newValue)
            let _ = validation(text)
        }
        .textFieldStyle(CustomTextFieldStyle(
            keyboardType: .default,
            isValid: isValid,
            isFocused: isFocused,
            errorMessage: errorMessage
        ))
    }
}
struct DecimalFieldView: View {
    @Binding var value: String
    let placeholder: String
    let validation: (String) -> Bool
    @Binding var errorMessage: String
    @Binding var isValid: Bool
    @State private var isFocused: Bool = false
    
    var body: some View {
        TextField(placeholder, text: $value, onEditingChanged: { focused in
            isFocused = focused
            
            // Format to 2 decimals when field loses focus (iOS 14+)
            if !focused && !value.isEmpty {
                if let doubleVal = Double(value) {
                    // Check if value needs formatting to avoid unnecessary updates
                    let formatted = String(format: "%.2f", doubleVal)
                    if formatted != value {
                        DispatchQueue.main.async {
                            // Double-check field is still unfocused before formatting
                            if !self.isFocused {
                                value = formatted
                                let _ = validation(formatted)
                            }
                        }
                    }
                }
            }
        })
        .onChange(of: value) { newValue in
            // Only filter invalid characters, no auto-formatting
            let filtered = newValue.filter { "0123456789.-".contains($0) }
            var result = ""
            var dotAdded = false
            var minusAdded = false
            
            for (i, char) in filtered.enumerated() {
                if char == "-" {
                    if i == 0 && !minusAdded {
                        result.append(char)
                        minusAdded = true
                    }
                } else if char == "." {
                    if !dotAdded {
                        result.append(char)
                        dotAdded = true
                    }
                } else {
                    result.append(char)
                }
            }
            
            // Update value if filtering changed it
            if result != newValue {
                value = result
            }
            
            // Validate (only if not currently formatting to avoid double validation)
            if !result.isEmpty || newValue.isEmpty {
                let _ = validation(result)
            }
        }
        .textFieldStyle(CustomTextFieldStyle(
            keyboardType: .numbersAndPunctuation,
            isValid: isValid,
            isFocused: isFocused,
            errorMessage: errorMessage
        ))
    }
}

struct NumericFieldView: View {
    @Binding var value: String
    let placeholder: String
    let validation: (String) -> Bool
    let updateEnteredText: (String) -> Void
    @Binding var errorMessage: String
    @Binding var isValid: Bool
    @State private var isFocused: Bool = false
    
    var body: some View {
        TextField(placeholder, text: $value, onEditingChanged: { focused in
            isFocused = focused
        })
        .onChange(of: value) { newValue in
            // Your existing numeric filtering logic
            var filtered = newValue.filter { "0123456789-".contains($0) }
            if filtered.first == "-" {
                let numbersOnly = filtered.dropFirst().filter { "0123456789".contains($0) }
                filtered = "-" + numbersOnly
            } else {
                filtered = filtered.filter { "0123456789".contains($0) }
            }
            
            if filtered != newValue {
                value = filtered
                return
            }
            _ = validation(filtered)
            updateEnteredText(filtered)
        }
        .textFieldStyle(CustomTextFieldStyle(
            keyboardType: .numbersAndPunctuation,
            isValid: isValid,
            isFocused: isFocused,
            errorMessage: errorMessage
        ))
    }
}
