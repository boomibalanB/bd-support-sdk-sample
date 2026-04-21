struct FormDetails: Equatable, Hashable {
    struct Validate: Equatable, Hashable {
        let min: String?
        let max: String?
        let regex: String?
    }
    struct Scheduler: Equatable, Hashable {
        let buttonText: String?
        let calendlyUrl: String?
    }
    let apiName: String
    let isRequired: Bool
    let description: String
    let type: ChatWorkflowBlockType?
    let subType: ChatWorkflowBlockSubType?
    let placeholder: String
    let ruleId: String
    let workflowId: String
    let mod: ChatFormsModuleEnum
    var errorMessage: String
    let isMasked: Bool
    var isSubmitted: Bool
    let validate: Validate?
    let options: [DropdownItemModel]?
    let apiUrl: String?
    let fieldValueType: String?
    let scheduler: Scheduler?
    let allowedFileTypes: [String]?
    
    init (apiName: String = "", isRequired: Bool = true, description: String = "", type: ChatWorkflowBlockType? = nil, subType: ChatWorkflowBlockSubType? = nil, placeholder: String = "", ruleId: String = "", workflowId: String = "", mod: ChatFormsModuleEnum, errorMessage: String = "", isMasked: Bool = false, isSubmitted: Bool = false, validate: Validate? = nil, options: [DropdownItemModel]? = nil, apiUrl: String? = nil, fieldValueType: String? = nil, scheduler: Scheduler? = nil, allowedFileTypes: [String]? = nil) {
        self.apiName = apiName
        self.isRequired = isRequired
        self.description = description
        self.type = type
        self.subType = subType
        self.placeholder = placeholder
        self.ruleId = ruleId
        self.workflowId = workflowId
        self.mod = mod
        self.errorMessage = errorMessage
        self.isMasked = isMasked
        self.isSubmitted = isSubmitted
        self.validate = validate
        self.options = options
        self.apiUrl = apiUrl
        self.fieldValueType = fieldValueType
        self.scheduler = scheduler
        self.allowedFileTypes = allowedFileTypes
    }
}

struct FieldValueDetails: Equatable, Hashable {
    let apiName: String?
    let fieldValueType: String
    let ruleId: String
    let id: String
    let value: String
    let isMasked: Bool
    let formMsgId: String
    let mod: ChatFormsModuleEnum
    let pickerValue: [DropdownItemModel]?
    
    init(apiName: String? = nil, fieldValueType: String = "", ruleId: String = "", id: String = "", value: String = "", isMasked: Bool? = nil, formMsgId: String, mod: ChatFormsModuleEnum, pickerValue: [DropdownItemModel]? = nil) {
        self.apiName = apiName
        self.fieldValueType = fieldValueType
        self.ruleId = ruleId
        self.id = id
        self.value = value
        self.isMasked = isMasked ?? false
        self.formMsgId = formMsgId
        self.mod = mod
        self.pickerValue = pickerValue
    }
}

struct DropdownItemModel: Identifiable, Equatable, Hashable {
    let id: String
    let displayName: String
}

struct WorkflowDropdownResponse: Decodable {
    let result: [WorkflowDropdownItem]
}

struct WorkflowDropdownItem: Decodable {
    let id: Int
    let name: String
}

struct ScheduleEventResponse: Decodable {
    let message: String
}
