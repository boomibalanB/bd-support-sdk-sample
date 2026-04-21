import Foundation

struct PreChatFormField: Codable {
    let labelForChatWidget: String?
    let placeholderForChatWidget: String?
    let visibleToUser: Bool?
    
    let fieldId: Int
    let labelForAgentPortal: String
    let apiName: String
    let isDefaultField: Bool
    
    let noteMessage: String?
    let noteMessageDisplayBelowField: Bool
    
    let fieldTypeId: Int
    let fieldControlName: String
    let fieldDataType: String
    let isMandatoryForSubmittingFormInAgentPortal: Bool
    let isDeactivated: Bool
    let fieldType: String
    
    let urlPrefix: String?
    let sortOrder: Int
    let regex: String?
    let defaultValue: String?
    let parentFieldId: Int?
    let displayCondition: String?
    
    let agentCanEdit: Bool
    let userCanEdit: Bool
    let isRequiredForClosingTicket: Bool
    
    let hideInCreateFormCustomerPortal: Bool?
    let hideInCreateFormAgentPortal: Bool?
    let cannotEditAfterCreateCustomerPortal: Bool?
    let cannotEditAfterCreateAgentPortal: Bool?
    let isRequiredForUpdatingTicketStatusInAgentPortal: Bool
    
    let targetModuleId: Int?
    let lookUpFieldConfiguration: String?
    let isFixedField: Bool?
    let isPrimaryField: Bool?
    
    let additionalFieldValidation: String?
    let placeholderForAgentPortal: String?
    let placeholderForCustomerPortal: String?
    let customErrorMessage: String?
    let permissionSettings: String?
}


// MARK: - UI Model for Pre-Chat Fields (used in SwiftUI)
struct PreChatField: Identifiable {
    let id: Int
    let label: String
    let placeholder: String
    let apiName: String?
    let fieldControlName: String
    let regex: String?
    let customErrorMessage: String?
    let noteMessage: String?
    let additionalFieldValidation: AdditionalFieldValidation?
    var defaultValue: String?
    let displayCondition: DisplayCondition?
    
    // These are the per-field validation states
    var text: String = ""
    var isValid: Bool = true
    var errorMessage: String = ""
    var selectedDropdownItem: DropdownItemModel?
    var selectedDropdownItems: [DropdownItemModel]?
    var isVisible: Bool = true
    
    // Convert from API model → UI model
    init(from apiField: PreChatFormField) {
        self.id = apiField.fieldId
        self.label = apiField.labelForChatWidget ?? apiField.labelForAgentPortal
        self.placeholder = apiField.placeholderForChatWidget ?? "Please enter your \(label.lowercased())"
        self.apiName = apiField.apiName
        self.fieldControlName = apiField.fieldControlName
        self.regex = apiField.regex
        self.customErrorMessage = apiField.customErrorMessage
        self.noteMessage = apiField.noteMessage
        // Parse JSON string once → store parsed object directly here
        if let jsonString = apiField.additionalFieldValidation,
           !jsonString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let data = jsonString.data(using: .utf8) {
            self.additionalFieldValidation = try? JSONDecoder().decode(AdditionalFieldValidation.self, from: data)
        } else {
            self.additionalFieldValidation = nil
        }
        self.defaultValue = apiField.defaultValue
        
        // Parse displayCondition JSON string
        if let conditionStr = apiField.displayCondition,
           !conditionStr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let data = conditionStr.data(using: .utf8) {
            do {
                let condition = try JSONDecoder().decode(DisplayCondition.self, from: data)
                // Optionally inject childField if needed later
                self.displayCondition = condition
            } catch {
                self.displayCondition = nil
            }
        } else {
            self.displayCondition = nil
        }
    }
}

struct AdditionalFieldValidation: Decodable {
    let maxValue: Double?
    let minValue: Double?
}

struct DisplayConditionRule: Codable {
    let type: String
    let field: String
    let value: [String] // Always stored as strings
    let `operator`: String // Backticks escape the reserved keyword

    // Map JSON "operator" → Swift property `operator`
    enum CodingKeys: String, CodingKey {
        case type
        case field
        case value
        case `operator` // This maps to the JSON key "operator"
    }

    // Custom decoding to handle value as [String] or [Bool]
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.type = try container.decode(String.self, forKey: .type)
        self.field = try container.decode(String.self, forKey: .field)
        self.`operator` = try container.decode(String.self, forKey: .`operator`)
        
        // Handle flexible value types
        if let stringValues = try? container.decode([String].self, forKey: .value) {
            self.value = stringValues
        } else if let boolValues = try? container.decode([Bool].self, forKey: .value) {
            self.value = boolValues.map { $0.description } // true → "true"
        } else if let singleString = try? container.decode(String.self, forKey: .value) {
            // Sometimes backend sends single value as string instead of array
            self.value = [singleString]
        } else if let singleBool = try? container.decode(Bool.self, forKey: .value) {
            self.value = [singleBool.description]
        } else {
            self.value = []
        }
    }

    // Required for Encodable – minimal implementation (safe since we don't encode)
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(field, forKey: .field)
        try container.encode(value, forKey: .value)
        try container.encode(self.`operator`, forKey: .`operator`)
    }
}

struct DisplayCondition: Codable {
    let condition: String
    let rules: [DisplayConditionRule]
}

