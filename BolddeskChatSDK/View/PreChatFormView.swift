import SwiftUI

struct PreChatFormView: View {
    @StateObject private var vm: PreChatFormViewModel
    @Binding var isProcessing: Bool
    let onStartChat: ([[String: Any]]) -> Void
    private let preChatFormMessage: String
    private let preChatFormFields: [PreChatFormField]
    private let systemUserId: Int
    private let brandOptionId: Int?
    
    init(preChatFormMessage: String, preChatFormFields: [PreChatFormField], systemUserId: Int, isProcessing: Binding<Bool>, onStartChat: @escaping ([[String: Any]]) -> Void, brandOptionId: Int?) {
        _vm = StateObject(wrappedValue: PreChatFormViewModel(preChatFormFields: preChatFormFields, systemUserId: systemUserId, brandOptionId: brandOptionId))
        self._isProcessing = isProcessing
        self.onStartChat = onStartChat
        self.preChatFormMessage = preChatFormMessage
        self.preChatFormFields = preChatFormFields
        self.systemUserId = systemUserId
        self.brandOptionId = brandOptionId
    }
        
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if let agentInfo = vm.agentInfo {
                AgentAvatarSection(agentInfo: agentInfo)
            } else {
                Circle()
                    .frame(width: 32, height: 32)
                    .foregroundColor(Color.utilityBrand100)
                    .overlay(Text("A").foregroundColor(.white))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(vm.agentInfo?.displayName ?? "Agent")
                    .font(FontFamily.customFont(size: FontSize.xsmall, weight: .regular))
                    .foregroundColor(Color.textTertiary)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(preChatFormMessage)
                        .font(FontFamily.customFont(size: FontSize.medium, weight: .regular))
                        .foregroundColor(Color.textSecondary)
                    // Render all fields – no validation
                    ForEach(Array(vm.fields.enumerated()), id: \.offset) { index, field in
                        VStack(alignment: .leading, spacing: 4) {
                            if field.fieldControlName == FieldControlName.checkBox.rawValue && field.isVisible {
                                // Checkbox renders its own label side-by-side
                                renderFormField(for: field, index: index)
                            } else if field.isVisible {
                                Text(field.label)
                                    .font(FontFamily.customFont(size: FontSize.medium, weight: .medium))
                                    .foregroundColor(Color.textSecondary)
                                renderFormField(for: field, index: index)
                            }
                            if let noteMessage = field.noteMessage {
                                Text(noteMessage)
                                    .font(FontFamily.customFont(size: FontSize.xsmall, weight: .medium))
                                    .foregroundColor(Color.textTertiary)
                            }
                        }
                    }
                    
                    // Start Chat Button
                    Button {
                        // Validate all fields first
                        let isValid = vm.validateAllFields()
                        guard isValid else { return }
                        
                        // Build payload and proceed
                        let payloadArray = vm.buildPayload()
                        onStartChat(payloadArray)
                    } label: {
                        if isProcessing {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .scaleEffect(0.8)
                                Text(ResourceManager.localized("processing"))
                            }
                        } else {
                            Text(ResourceManager.localized("start_chat"))
                        }
                    }
                    .buttonStyle(CustomButtonStyle())
                    .padding(.top, 6)
                    .disabled(isProcessing || vm.fields.isEmpty)
                }
                .padding(10)
                .background(Color.bgSecondary)
                .clipShape(CustomCorners(topLeft: 2, topRight: 12, bottomLeft: 12, bottomRight: 12))
                .overlay(
                    CustomCorners(topLeft: 2, topRight: 12, bottomLeft: 12, bottomRight: 12)
                        .stroke(Color.borderSecondary, lineWidth: 1)
                )
                .disabled(isProcessing)
                .opacity(isProcessing ? 0.7 : 1.0)
            }
            
            Spacer()
        }
        .padding(.leading, 16)
        .padding(.trailing, 10)
        .padding(.vertical, 8)
        .onAppear {
            if vm.fields.isEmpty {
                Task {
                    await vm.loadPreChatFields()
                }
            }
        }
        .opacity(vm.isLoading ? 0 : 1)
    }

    @ViewBuilder
    private func renderFormField(for field: PreChatField, index: Int) -> some View {
        if field.fieldControlName == FieldControlName.dropDown.rawValue {
            SingleSelectDropdownField(
                placeholder: field.placeholder,
                updateSelectedItem: { item in
                    vm.fields[index].selectedDropdownItem = item
                    vm.applyDisplayConditions()
                    vm.validateAndClearInvalidChildSelections(for: field.apiName ?? "")
                },
                validation: { item in
                    vm.validateDropdownField(index: index, item: item)
                    return true
                },
                selectedItem: Binding(
                    get: { vm.fields[index].selectedDropdownItem },
                    set: { vm.fields[index].selectedDropdownItem = $0 }
                ),
                fetchItems: { search in
                    await vm.getPrechatDropdownItems(apiName: field.apiName ?? "")(search)
                },
                errorMessage: Binding(
                    get: { field.errorMessage },
                    set: { _ in }
                ),
                isValid: Binding(
                    get: { field.isValid },
                    set: { _ in }
                )
            )
        }
        else if field.fieldControlName == FieldControlName.multiSelect.rawValue {
            MultiSelectDropdownField(
                placeholder: field.placeholder,
                updateSelectedItem: { items in
                    vm.fields[index].selectedDropdownItems = items
                    vm.applyDisplayConditions()
                    vm.validateAndClearInvalidChildSelections(for: field.apiName ?? "")
                },
                validation: { items in
                    vm.validateMultiSelectField(index: index, items: items)
                    return true
                },
                selectedItems: Binding(
                    get: { vm.fields[index].selectedDropdownItems ?? [] },
                    set: { newItems in
                        vm.fields[index].selectedDropdownItems = newItems
                    }
                ),
                fetchItems: { search in
                    await vm.getPrechatDropdownItems(apiName: field.apiName ?? "")(search)
                },
                errorMessage: Binding(
                    get: { field.errorMessage },
                    set: { _ in }
                ),
                isValid: Binding(
                    get: { field.isValid },
                    set: { _ in }
                )
            )
        }
        else if field.fieldControlName == FieldControlName.textBox.rawValue || field.fieldControlName == FieldControlName.url.rawValue || field.fieldControlName == FieldControlName.regex.rawValue || (field.apiName == "emailId") {
            SingleLineTextFieldView(
                placeholder: field.placeholder,
                validation: { text in
                    vm.textFieldValidation(index: index, text: text)
                    return true
                },
                updateEnteredText: { text in
                    vm.updateEnteredText(at: index, text: text)
                },
                text: Binding(
                    get: { vm.fields[index].text },
                    set: { newText in
                        vm.fields[index].text = newText
                    }
                ),
                errorMessage: Binding(
                    get: { field.errorMessage },
                    set: { _ in }
                ),
                isValid: Binding(
                    get: { field.isValid },
                    set: { _ in }
                ),
            )
        }
        else if field.fieldControlName == FieldControlName.numeric.rawValue {
            NumericFieldView(
                value: Binding(
                    get: { vm.fields[index].text },
                    set: { newText in
                        vm.fields[index].text = newText
                    }
                ),
                placeholder: field.placeholder,
                validation: { text in
                    vm.textFieldValidation(index: index, text: text)
                    return true
                },
                updateEnteredText: { text in
                    vm.updateEnteredText(at: index, text: text)
                },
                errorMessage: Binding(
                    get: { field.errorMessage },
                    set: { _ in }
                ),
                isValid: Binding(
                    get: { field.isValid },
                    set: { _ in }
                ),
            )
        }
        else if field.fieldControlName == FieldControlName.decimal.rawValue {
            DecimalFieldView(
                value: Binding(
                    get: { vm.fields[index].text },
                    set: { newText in
                        vm.fields[index].text = newText
                    }
                ),
                placeholder: field.placeholder,
                validation: { text in
                    vm.textFieldValidation(index: index, text: text)
                    return true
                },
                errorMessage: Binding(
                    get: { field.errorMessage },
                    set: { _ in }
                ),
                isValid: Binding(
                    get: { field.isValid },
                    set: { _ in }
                ),
            )
        }
        else if field.fieldControlName == FieldControlName.textArea.rawValue {
            TextAreaFieldView(
                placeholder: field.placeholder,
                text: Binding(
                    get: { field.text },
                    set: { text in
                        vm.updateEnteredText(at: index, text: text)
                        vm.textFieldValidation(index: index, text: text)}
                ),
                errorMessage: Binding(
                    get: { field.errorMessage },
                    set: { _ in }
                ),
                isValid: Binding(
                    get: { field.isValid },
                    set: { _ in }
                )
            )
        }
        else if field.fieldControlName == FieldControlName.date.rawValue {
            DateFieldView(
                placeholder: field.placeholder,
                minDate: nil,
                maxDate: nil,
                selectedDate: (field.text.isEmpty ? nil : field.text),
                updateSelectedDate: { value in
                    vm.updateEnteredText(at: index, text: value ?? "")
                },
                validation: { value in
                    vm.textFieldValidation(index: index, text: value ?? "")
                    return true
                },
                errorMessage: Binding(
                    get: { field.errorMessage },
                    set: { _ in }
                ),
                isValid: Binding(
                    get: { field.isValid },
                    set: { _ in }
                )
            )
        }
        else if field.fieldControlName == FieldControlName.datetime.rawValue {
            DateTimeFieldView(
                placeholder: field.placeholder,
                minDate: nil,
                maxDate: nil,
                selectedDateTime: (field.text.isEmpty ? nil : field.text),
                updateSelectedDateTime: { value in
                    vm.updateEnteredText(at: index, text: value ?? "")
                },
                validation: { value in
                    vm.textFieldValidation(index: index, text: value ?? "")
                    return true
                },
                errorMessage: Binding(
                    get: { field.errorMessage },
                    set: { _ in }
                ),
                isValid: Binding(
                    get: { field.isValid },
                    set: { _ in }
                )
            )
        }
        else if field.fieldControlName == FieldControlName.radioButton.rawValue {
            RadioButtonsView(
                options: ["Yes", "No"],
                validation: { value in
                    vm.validateRadioButtonField(index: index, value: value)
                    return true
                },
                updateSelectedRadioButton: { value in
                    vm.fields[index].text = value ? "Yes" : "No"
                    vm.applyDisplayConditions()
                },
                defaultValue: field.defaultValue == "true",
                errorMessage: Binding(
                    get: { field.errorMessage },
                    set: { _ in }
                ),
                isValid: Binding(
                    get: { field.isValid },
                    set: { _ in }
                )
            )
        }
        else if field.fieldControlName == FieldControlName.checkBox.rawValue {
            CheckboxWithLabel(
                isChecked: field.text == "true",
                title: field.label,
                validation: { value in
                    vm.validateCheckBoxField(index: index, value: value)
                    return true
                },
                updateSelectedCheckbox: { value in
                    vm.fields[index].text = value ? "true" : "false"
                    vm.applyDisplayConditions()
                },
                errorMessage: Binding(
                    get: { field.errorMessage },
                    set: { _ in }
                ),
                isValid: Binding(
                    get: { field.isValid },
                    set: { _ in }
                )
            )
        }
    }
}
