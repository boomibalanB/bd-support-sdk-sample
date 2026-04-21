import SwiftUI

/// Validates work form input based on form details and field requirements
func validateWorkFormInput(text: String, formDetails: FormDetails) -> (isValid: Bool, errorMessage: String) {
    let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
    
    // Required field validation
    guard !formDetails.isRequired || !trimmedText.isEmpty else {
        return (false, ResourceManager.localized("field_required_validation"))
    }
    guard !trimmedText.isEmpty else { return (true, "") }
    
    // Customer details validation
    if formDetails.type == .getCustomerDetails {
        if let error = validateCustomerDetails(text: trimmedText, subType: formDetails.subType) { return error }
    }
    
    // General text validation
    if [.getCustomerDetails, .getTextInput].contains(formDetails.type) {
        if let error = validateGeneralText(text: trimmedText, subType: formDetails.subType) { return error }
    }
    
    // Text input specific validation
    if formDetails.type == .getTextInput {
        if let error = validateTextInput(text: trimmedText, formDetails: formDetails) { return error }
    }
    
    return (true, "")
}

// MARK: - Compact Helper Methods

/// Validates customer-specific fields
private func validateCustomerDetails(text: String, subType: ChatWorkflowBlockSubType?) -> (Bool, String)? {
    switch subType {
    case .name where text.count > AppConstant.nameFieldMaxLength:
        return (false, String(format: ResourceManager.localized("max_char_exceeded_validation"), "\(AppConstant.nameFieldMaxLength)"))
    case .email where !isValidEmail(text):
        return (false, ResourceManager.localized("invalid_email"))
    case .phone where !isValidPhoneNo(text):
        return (false, ResourceManager.localized("invalid_phoneno"))
    default: return nil
    }
}

/// Validates general text input
private func validateGeneralText(text: String, subType: ChatWorkflowBlockSubType?) -> (Bool, String)? {
    guard isMatchingRegex(text, pattern: AppConstant.invalidTextCharRegex) else {
        return (false, ResourceManager.localized("invalid_text_char_msg"))
    }
    let maxLength = subType == .textArea ? AppConstant.customMultiLineTextBoxMaxLength : AppConstant.singleLineTextBoxMaxLength
    guard text.count <= maxLength else {
        return (false, String(format: ResourceManager.localized("max_char_exceeded_validation"), "\(maxLength)"))
    }
    return nil
}

/// Validates text input fields with custom rules
private func validateTextInput(text: String, formDetails: FormDetails) -> (Bool, String)? {
    // Custom regex validation
    if let regex = formDetails.validate?.regex, !isMatchingRegex(text, pattern: regex) {
        return (false, ResourceManager.localized("invalid_field"))
    }
    
    // Field-specific validation
    if formDetails.subType == .url && !isMatchingRegex(text, pattern: AppConstant.urlRegex) {
        return (false, NSLocalizedString("invalid_field", comment: ""))
    } else if formDetails.subType == .number || formDetails.subType == .decimal {
        return validateNumeric(text: text, validate: formDetails.validate)
    } else if formDetails.subType == .date || formDetails.subType == .dateTime {
        return validateDate(text: text, subType: formDetails.subType, validate: formDetails.validate)
    } else if let maxCharLength = Int(formDetails.validate?.max ?? ""), text.count > maxCharLength {
        return (false, String(format: ResourceManager.localized("max_char_exceeded_validation"), "\(maxCharLength)"))
    }
    return nil
}

/// Validates numeric fields
private func validateNumeric(text: String, validate: FormDetails.Validate?) -> (Bool, String)? {
    guard let value = Double(text) else { return nil }
    if let maxString = validate?.max, let max = Double(maxString), value > max {
        return (false, String(format: ResourceManager.localized("max_value_exceeded_validation"), "\(value)", "\(max)"))
    }
    if let minString = validate?.min, let min = Double(minString), value < min {
        return (false, String(format: ResourceManager.localized("min_value_required_validation"), "\(value)", "\(min)"))
    }
    return nil
}

/// Validates date fields
private func validateDate(text: String, subType: ChatWorkflowBlockSubType?, validate: FormDetails.Validate?) -> (Bool, String)? {
    guard let entryDate = isoDateFormatter.date(from: text) else { return nil }
    let format = subType == .dateTime ? "dd MMM yyyy, hh:mm a" : "dd MMM yyyy"
    
    if let minString = validate?.min, let minDate = isoDateFormatter.date(from: minString), entryDate < minDate {
        let formattedEntryDate = formatDateTime(date: entryDate, format: format)
        let formattedMinDate = formatDateTime(date: minDate, format: format)
        return (false, String(format: ResourceManager.localized("workflow_validation_mindate"), formattedEntryDate, formattedMinDate))
    }
    
    if let maxString = validate?.max, let maxDate = isoDateFormatter.date(from: maxString), entryDate > maxDate {
        let formattedEntryDate = formatDateTime(date: entryDate, format: format)
        let formattedMaxDate = formatDateTime(date: maxDate, format: format)
        return (false, String(format: ResourceManager.localized("workflow_validation_maxdate"), formattedEntryDate, formattedMaxDate))
    }
    return nil
}

/// Validates picker input for both single and multi-select options
func validateWorkflowPickerInput(selectedItems: [DropdownItemModel], formDetails: FormDetails) -> (isValid: Bool, errorMessage: String) {
    // Required field validation - same for both types
    if formDetails.isRequired && selectedItems.isEmpty {
        return (false, ResourceManager.localized("field_required_validation"))
    }
    
    // Additional validation for multi-select
    if formDetails.subType == .multiSelect {
        // Min validation
        if let minString = formDetails.validate?.min,
           let minCount = Int(minString),
           selectedItems.count < minCount {
            return (false, String(format: ResourceManager.localized("min_selection_validation"), "\(selectedItems.count)", "\(minCount)"))
        }
        
        // Max validation
        if let maxString = formDetails.validate?.max,
           let maxCount = Int(maxString),
           selectedItems.count > maxCount {
            return (false, String(format: ResourceManager.localized("max_selection_validation"), "\(selectedItems.count)", "\(maxCount)"))
        }
    }
    
    return (true, "")
}

// Common fetchItems function
func getWorkflowDropdownItems(formDetails: FormDetails) -> (String) async -> [DropdownItemModel] {
    return { searchText in
        if let options = formDetails.options, !options.isEmpty {
            guard !searchText.isEmpty else { return options }
            
            let search = searchText.lowercased()
            return options.filter { option in
                option.displayName.lowercased().contains(search) ||
                option.id.lowercased().contains(search)
            }
        }
        else if let apiUrl = formDetails.apiUrl, !apiUrl.isEmpty {
            do {
                let response: WorkflowDropdownResponse = try await ChatAPIClient().fetchDataFromAPI(
                    url: apiUrl,
                    method: "GET",
                    responseType: WorkflowDropdownResponse.self
                )
                
                let options = response.result.map {
                    DropdownItemModel(id: String($0.id), displayName: $0.name)
                }
                
                guard !searchText.isEmpty else { return options }
                
                let search = searchText.lowercased()
                return options.filter { option in
                    option.displayName.lowercased().contains(search) ||
                    option.id.lowercased().contains(search)
                }
            } catch {
                return []
            }
        }
        else {
            return []
        }
    }
}
