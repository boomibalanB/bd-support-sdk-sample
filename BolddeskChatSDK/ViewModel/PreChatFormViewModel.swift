import Foundation

@MainActor
final class PreChatFormViewModel: ObservableObject {
    @Published var fields: [PreChatField] = []
    @Published var systemUserId: Int
    @Published var isLoading = false
    @Published var agentInfo: AgentInfo?
    @Published var fieldDependencies: [FieldDependency] = []
    var brandOptionId: Int?

    private let preChatFormFields: [PreChatFormField]

    init(preChatFormFields: [PreChatFormField], systemUserId: Int, brandOptionId: Int?) {
        self.preChatFormFields = preChatFormFields
        self.systemUserId = systemUserId
        self.brandOptionId = brandOptionId
    }

    func loadPreChatFields() async {
        isLoading = true
        defer { isLoading = false }

        do {
            self.fieldDependencies = try await ChatAPIClient()
                .getPreChatFormFieldDependencies()
        } catch {
            self.fieldDependencies = []
        }

        // Convert API model → UI model (no filtering, no sorting)
        self.fields = preChatFormFields.filter { $0.visibleToUser != false }
            .map(PreChatField.init(from:))

        await self.setDefaultValues()

        self.applyDisplayConditions()

        for i in fields.indices {
            if (fields[i].fieldControlName == "dropdown"
                || fields[i].fieldControlName == "multiselect")
                && fields[i].isValid
            {
                self.validateAndClearInvalidChildSelections(
                    for: fields[i].apiName ?? ""
                )
            }
        }

        // Load agent info
        let info = await ChatUtils.shared.getAgentAvatarDetailsById(
            agentId: systemUserId
        )
        self.agentInfo = info
    }
    
    func setDefaultValues() async {

        // 1️⃣ Core user fields
        if let email = BDChatSDK.email?.trimmed,
            let idx = fields.firstIndex(where: { $0.apiName == "emailId" })
        {
            fields[idx].text = email
        }

        if let name = BDChatSDK.name?.trimmed,
            let idx = fields.firstIndex(where: { $0.apiName == "contactName" })
        {
            fields[idx].text = name
        }

        if let phone = BDChatSDK.phoneNo?.trimmed,
            let idx = fields.firstIndex(where: {
                $0.apiName == "contactPhoneNo"
            })
        {
            fields[idx].text = phone
        }

        // 2️⃣ Custom fields
        let customFields = BDChatSDK.fields ?? [:]

        for i in fields.indices {

            guard
                let apiName = fields[i].apiName,
                let control = FieldControlName(
                    rawValue: fields[i].fieldControlName
                )
            else { continue }

            let rawValue = customFields[apiName]

            switch control {

            // TEXT / NUMERIC / DECIMAL / URL / REGEX
            case .textBox, .textArea, .numeric, .decimal, .url, .regex:
                if let value = rawValue {
                    // Safely unwrap any type
                    switch value {
                    case let str as String:
                        fields[i].text = str
                    case let num as Int:
                        fields[i].text = String(num)
                    case let dbl as Double:
                        fields[i].text = String(dbl)
                    case let bool as Bool:
                        fields[i].text = bool ? "true" : "false"
                    default:
                        fields[i].text = String(describing: value)
                    }
                }

            // CHECKBOX
            case .checkBox:
                if let boolValue = rawValue as? Bool {
                    // Raw value is Bool → use it
                    fields[i].text = boolValue ? "true" : "false"
                    fields[i].defaultValue = fields[i].text
                } else if let stringValue = rawValue as? String {
                    // Raw value is String → accept "true"/"false"
                    let lower = stringValue.lowercased()
                    fields[i].text = (lower == "true") ? "true" : "false"
                    fields[i].defaultValue = fields[i].text
                }
            // RADIO
            case .radioButton:
                if let boolValue = rawValue as? Bool {
                    fields[i].text = boolValue ? "Yes" : "No"
                    fields[i].defaultValue = fields[i].text == "Yes" ? "true" : "false"
                } else if let stringValue = rawValue as? String {
                    let lower = stringValue.lowercased()
                    fields[i].text = (lower == "true") ? "Yes" : "No"
                    fields[i].defaultValue = fields[i].text == "Yes" ? "true" : "false"
                }
                else{
                    fields[i].text = fields[i].defaultValue == "true" ? "Yes" : "No"
                }
            // DROPDOWN (single select)
            case .dropDown:
                let options = await getPrechatDropdownItems(apiName: apiName)(
                    ""
                )

                // Convert rawValue to string if possible
                var valueString: String?
                if let str = rawValue as? String {
                    valueString = str
                } else if let num = rawValue as? Int {
                    valueString = String(num)
                } else if let num = rawValue as? Double {
                    valueString = String(num)
                }

                // 1️⃣ If rawValue is provided → use it
                if let value = valueString,
                    let matched = options.first(where: { $0.id == value })
                {
                    fields[i].selectedDropdownItem = matched
                }
                // 2️⃣ If rawValue is nil → fallback to defaultValue
                else if let defaultValue = fields[i].defaultValue,
                    let matched = options.first(where: { $0.id == defaultValue }
                    )
                {
                    fields[i].selectedDropdownItem = matched
                }

            // MULTISELECT
            case .multiSelect:
                var valueStrings: [String] = []

                if let strings = rawValue as? [String] {
                    valueStrings = strings
                } else if let numbers = rawValue as? [Int] {
                    valueStrings = numbers.map { String($0) }
                } else if let numbers = rawValue as? [Double] {
                    valueStrings = numbers.map { String($0) }
                }

                if !valueStrings.isEmpty {
                    let options = await getPrechatDropdownItems(
                        apiName: apiName
                    )("")
                    let matchedItems = options.filter {
                        valueStrings.contains($0.id)
                    }
                    fields[i].selectedDropdownItems = matchedItems
                }

            // DATE / DATETIME
            case .date:
                if let dateString = rawValue as? String {
                    if isValidDateValue(rawValue){
                        fields[i].text = convertISOToDisplayString(dateString, type: control == FieldControlName.datetime ? .dateTime : .date)
                    }
                }
                
            case .datetime:
                if let dateString = rawValue as? String {
                    if isValidDateTimeValue(rawValue){
                        fields[i].text = convertISOToDisplayString(dateString, type: control == FieldControlName.datetime ? .dateTime : .date)
                    }
                }

            // UPLOAD
            case .upload:
                break  // handled elsewhere
            }
        }
    }

    func updateEnteredText(at index: Int, text: String) {
        guard fields.indices.contains(index) else { return }
        fields[index].text = text
    }

    func textFieldValidation(index: Int, text: String) {
        guard fields.indices.contains(index) else { return }
        let field = fields[index]
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedText.isEmpty {
            self.setError(
                index: index,
                message: ResourceManager.localized("field_required_validation")
            )
            return
        }

        switch field.apiName {
        case "emailId":
            if !isValidEmail(trimmedText) {
                self.setError(
                    index: index,
                    message: ResourceManager.localized("invalid_email")
                )
                return
            }
        case "contactName":
            if trimmedText.count > AppConstant.nameFieldMaxLength {
                self.setError(
                    index: index,
                    message: String(
                        format: ResourceManager.localized(
                            "max_char_exceeded_validation"
                        ),
                        "\(AppConstant.nameFieldMaxLength)"
                    )
                )
                return
            }
        case "contactPhoneNo":
            if !isValidPhoneNo(trimmedText) {
                self.setError(
                    index: index,
                    message: ResourceManager.localized("invalid_phoneno")
                )
                return
            }
        default:
            break
        }

        switch field.fieldControlName {
        case "textbox":
            if field.apiName != "contactName"
                && field.apiName != "contactPhoneNo"
                && trimmedText.count > AppConstant.singleLineTextBoxMaxLength
            {
                self.setError(
                    index: index,
                    message: String(
                        format: ResourceManager.localized(
                            "max_char_exceeded_validation"
                        ),
                        "\(AppConstant.singleLineTextBoxMaxLength)"
                    )
                )
                return
            }
        case "textarea":
            if trimmedText.count > AppConstant.customMultiLineTextBoxMaxLength {
                self.setError(
                    index: index,
                    message: String(
                        format: ResourceManager.localized(
                            "max_char_exceeded_validation"
                        ),
                        "\(AppConstant.customMultiLineTextBoxMaxLength)"
                    )
                )
                return
            }
        case "numeric", "decimal":
            if let maxValue = field.additionalFieldValidation?.maxValue,
                let enteredValue = Double(trimmedText), enteredValue > maxValue
            {
                self.setError(
                    index: index,
                    message: field.customErrorMessage
                        ?? String(
                            format: ResourceManager.localized(
                                "max_value_exceeded_validation"
                            ),
                            "\(enteredValue)",
                            "\(maxValue)"
                        )
                )
                return
            }
            if let minValue = field.additionalFieldValidation?.minValue,
                let enteredValue = Double(trimmedText), enteredValue < minValue
            {
                self.setError(
                    index: index,
                    message: field.customErrorMessage
                        ?? String(
                            format: ResourceManager.localized(
                                "min_value_exceeded_validation"
                            ),
                            "\(enteredValue)",
                            "\(minValue)"
                        )
                )  // Changed to min_value_exceeded_validation
                return
            }
        case "regex":
            if let regex = field.regex,
                !isMatchingRegex(trimmedText, pattern: regex)
            {
                self.setError(
                    index: index,
                    message: field.customErrorMessage
                        ?? ResourceManager.localized("invalid_field")
                )
                return
            }
        case "url":
            if !isMatchingRegex(trimmedText, pattern: AppConstant.urlRegex) {
                self.setError(
                    index: index,
                    message: field.customErrorMessage
                        ?? ResourceManager.localized("invalid_field")
                )
                return
            }
        default:
            break
        }

        fields[index].isValid = true
        fields[index].errorMessage = ""
    }

    // Helper to set error message and validation state
    private func setError(index: Int, message: String) {
        fields[index].isValid = false
        fields[index].errorMessage = message
    }

    // Validate dropdown field
    func validateDropdownField(index: Int, item: DropdownItemModel?) {
        let isEmpty =
            (item == nil)
            || (item?.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ?? true)
        if isEmpty {
            setError(
                index: index,
                message: ResourceManager.localized("field_required_validation")
            )
        } else {
            fields[index].isValid = true
            fields[index].errorMessage = ""
        }
    }

    func validateMultiSelectField(index: Int, items: [DropdownItemModel]?) {
        guard let items = items else {
            setError(
                index: index,
                message: ResourceManager.localized("field_required_validation")
            )
            return
        }
        let isEmpty = items.isEmpty
        if isEmpty {
            setError(
                index: index,
                message: ResourceManager.localized("field_required_validation")
            )
        } else {
            self.fields[index].isValid = true
            self.fields[index].errorMessage = ""
        }
    }

    // Validate radio button field
    func validateRadioButtonField(index: Int, value: Bool) {
        if !value {
            setError(
                index: index,
                message: ResourceManager.localized("field_required_validation")
            )
        } else {
            fields[index].isValid = true
            fields[index].errorMessage = ""
        }
    }

    func validateCheckBoxField(index: Int, value: Bool) {
        if !value {
            setError(
                index: index,
                message: ResourceManager.localized("field_required_validation")
            )
        } else {
            fields[index].isValid = true
            fields[index].errorMessage = ""
        }
    }

    // Validate all fields and update error states
    func validateAllFields() -> Bool {
        for idx in fields.indices {
            let field = fields[idx]
            switch field.fieldControlName {
            case "dropdown":
                validateDropdownField(
                    index: idx,
                    item: field.selectedDropdownItem
                )
            case "multiselect":
                validateMultiSelectField(
                    index: idx,
                    items: field.selectedDropdownItems
                )
            case "radiobutton":
                validateRadioButtonField(index: idx, value: field.text == "Yes")
            case "checkbox":
                validateCheckBoxField(index: idx, value: field.text == "true")
            default:
                textFieldValidation(index: idx, text: field.text)
            }
        }
        return fields.filter { $0.isVisible }.allSatisfy { $0.isValid }
    }

    // Build payload as array of objects: [{ apiName, value, message }]
    func buildPayload() -> [[String: Any]] {
        var payloadItems: [[String: Any]] = []
        for field in fields {
            guard let key = field.apiName, field.isVisible else { continue }

            var item: [String: Any] = ["apiName": key]

            if field.fieldControlName == "multiselect",
                let items = field.selectedDropdownItems, !items.isEmpty
            {
                // For multiselect: value is array of ids, message is comma-separated display names
                item["value"] = items.map { $0.id }
                item["message"] = items.map { $0.displayName }.joined(
                    separator: ", "
                )
            } else if let selected = field.selectedDropdownItem {
                // Single select dropdown
                item["value"] = selected.id
                item["message"] = selected.displayName
            } else if field.fieldControlName == "radiobutton" {
                item["value"] = field.text == "Yes" ? "true" : "false"
                item["message"] = field.text
            }
            else if field.fieldControlName == FieldControlName.date.rawValue {
                item["value"] = field.text
                item["message"] = convertISOToDisplayString(field.text, type: .date)
            }
            else if field.fieldControlName == FieldControlName.datetime.rawValue {
                item["value"] = field.text
                item["message"] = convertISOToDisplayString(field.text, type: .dateTime)
            }
            else if field.fieldControlName == FieldControlName.decimal.rawValue {
                if let number = Double(field.text) {
                        let formatted = String(format: "%.2f", number)
                        item["value"] = formatted
                        item["message"] = formatted
                    } else {
                        item["value"] = field.text
                        item["message"] = field.text
                    }
            }
            else {
                // Fallback to text fields
                item["value"] = field.text
                item["message"] = field.text
            }

            payloadItems.append(item)
        }
        return payloadItems
    }

    func applyDisplayConditions() {
        // 1. Build current values from ALL fields (even hidden ones)
        var currentValues: [String: String] = [:]

        for field in fields {
            guard let apiName = field.apiName else { continue }

            let value: String = {
                switch field.fieldControlName {
                case "radiobutton":
                    return field.text == "Yes" ? "true" : "false"
                case "checkbox":
                    return field.text == "true" ? "true" : "false"
                case "dropdown":
                    return field.selectedDropdownItem?.id ?? ""
                case "multiselect":
                    return field.selectedDropdownItems?.map { $0.id }.joined(
                        separator: ","
                    ) ?? ""
                default:
                    return field.text.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                }
            }().lowercased()

            currentValues[apiName] = value
        }

        // 2. Re-evaluate visibility — loop until stable (web-style recursive behavior)
        var hasChanged = true

        while hasChanged {
            hasChanged = false

            for i in fields.indices {
                let field = fields[i]

                // No condition → always visible
                guard let condition = field.displayCondition else {
                    if !fields[i].isVisible {
                        fields[i].isVisible = true
                        hasChanged = true
                    }
                    continue
                }

                // CRITICAL: If ANY parent field (that this condition depends on) is hidden → hide this field
                let anyParentHidden = condition.rules.contains { rule in
                    let parentApiName = rule.field  // ← field is String, not Optional

                    guard
                        let parentField = fields.first(where: {
                            $0.apiName == parentApiName
                        })
                    else {
                        return false  // Parent field doesn't exist → skip this rule (don't block visibility)
                    }

                    return !parentField.isVisible
                }

                if anyParentHidden {
                    if fields[i].isVisible {
                        fields[i].isVisible = false
                        hasChanged = true
                    }
                    continue
                }

                // Normal rule evaluation (only when all parents are visible)
                let ruleResults = condition.rules.map { rule -> Bool in
                    guard let currentValueStr = currentValues[rule.field],
                        !currentValueStr.isEmpty
                    else {
                        // ← Only change: if field doesn't exist → return true (rule passes)
                        guard
                            fields.contains(where: { $0.apiName == rule.field })
                        else {
                            return true  // Field not present in form → treat rule as satisfied
                        }

                        return false  // Field exists but empty → rule fails (your current desired behavior)
                    }

                    // Split multiselect: "20301,20302, 20303 " → ["20301", "20302", "20303"]
                    let selectedIds =
                        currentValueStr
                        .components(separatedBy: ",")
                        .map {
                            $0.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                        .filter { !$0.isEmpty }
                        .map { $0.lowercased() }

                    let expectedIds = rule.value.map { $0.lowercased() }

                    // Check if there is any overlap between selected and expected
                    let hasOverlap = selectedIds.contains { selectedId in
                        expectedIds.contains(selectedId)
                    }

                    switch rule.operator.lowercased() {
                    case "in", "equal":
                        return hasOverlap

                    case "not_in", "not_equal":
                        return !hasOverlap

                    default:
                        return hasOverlap
                    }
                }

                let shouldBeVisible =
                    condition.condition.lowercased() == "or"
                    ? ruleResults.contains(true)
                    : !ruleResults.contains(false)

                if fields[i].isVisible != shouldBeVisible {
                    fields[i].isVisible = shouldBeVisible
                    hasChanged = true
                }
            }
        }
    }

    func getPrechatDropdownItems(apiName: String) -> (String) async ->
        [DropdownItemModel]
    {
        return { [weak self] searchText in
            guard let self = self else { return [] }

            // STEP 1: Find if this field is a dependent (child) field
            guard
                let dependency = self.fieldDependencies.first(where: {
                    $0.childField.apiName == apiName
                })
            else {
                // Not a dependent field → always fetch from API
                return await self.fetchDropdownOptionsFromAPI(
                    apiName: apiName,
                    searchText: searchText
                )
            }

            // STEP 2: We have static childOptions → use them (NO API CALL)
            var options = dependency.childOptions.map {
                DropdownItemModel(id: String($0.id), displayName: $0.name)
            }

            // STEP 3: Find parent field and its current selected value
            let parentField = self.fields.first(where: {
                $0.apiName == dependency.parentField.apiName && $0.isVisible
            })

            var parentSelectedId: String?
            if let parentField = parentField {
                parentSelectedId = parentField.selectedDropdownItem?.id ?? parentField.defaultValue
            } else {
                // Brand is not present in the form in some flows — hardcode to 6
                let parentApi = dependency.parentField.apiName.lowercased()
                if parentApi == "chatbrandid" {
                    parentSelectedId = brandOptionId.map(String.init)
                } else {
                    return await self.fetchDropdownOptionsFromAPI(
                        apiName: apiName,
                        searchText: searchText
                    )
                }
            }

            // STEP 4: Apply filtering based on parent's selected value
            guard let selectedId = parentSelectedId,
                let selectedIdInt = Int(selectedId),
                let mapping = dependency.dependencyMapping.first(where: {
                    $0.parentFieldOptionId == selectedIdInt
                })
            else {
                // No mapping → show empty list (web sets APIURL = "" and options = [])
                return await self.fetchDropdownOptionsFromAPI(
                    apiName: apiName,
                    searchText: searchText
                )
            }

            let allowedChildIds = Set(
                mapping.childFieldOptionId.map(String.init)
            )

            // Filter options
            options = options.filter { allowedChildIds.contains($0.id) }

            // STEP 5: Apply search
            guard !searchText.isEmpty else { return options }
            let search = searchText.lowercased()
            return options.filter {
                $0.displayName.lowercased().contains(search)
                    || $0.id.lowercased().contains(search)
            }
        }
    }

    // MARK: - Fallback API fetch (only when not in dependencies)
    private func fetchDropdownOptionsFromAPI(
        apiName: String,
        searchText: String
    ) async -> [DropdownItemModel] {
        let endpoint = ChatWidgetAPIPaths.getPrechatDropdownOptions(
            apiName: apiName
        )

        do {
            let response: WorkflowDropdownResponse = try await ChatAPIClient()
                .fetchDataFromAPI(
                    url: endpoint,
                    method: "GET",
                    responseType: WorkflowDropdownResponse.self
                )

            let options = response.result.map {
                DropdownItemModel(id: String($0.id), displayName: $0.name)
            }

            guard !searchText.isEmpty else { return options }
            let search = searchText.lowercased()
            return options.filter {
                $0.displayName.lowercased().contains(search)
                    || $0.id.lowercased().contains(search)
            }
        } catch {
            return []
        }
    }

    func validateAndClearInvalidChildSelections(for changedApiName: String) {
        // Find all dependencies where the CHANGED field is the PARENT
        let childDependencies = fieldDependencies.filter { dependency in
            dependency.parentField.apiName == changedApiName
        }

        // If no children depend on this field → nothing to do
        guard !childDependencies.isEmpty else { return }

        for dependency in childDependencies {
            // Find the child field in current form
            guard
                let childIndex = fields.firstIndex(where: {
                    $0.apiName == dependency.childField.apiName
                })
            else { continue }

            let childField = fields[childIndex]

            // Find the parent field (must be visible to enforce dependency)
            guard
                let parentField = fields.first(where: {
                    $0.apiName == dependency.parentField.apiName
                        && $0.isVisible == true
                })
            else {
                // Parent is hidden → do NOT clear child (dependency ignored)
                continue
            }

            // Get current parent selection
            let parentSelectedIdStr: String? =
                parentField.selectedDropdownItem?.id ?? parentField.defaultValue

            // Only enforce if parent actually has a selection
            guard let selectedIdStr = parentSelectedIdStr,
                let selectedIdInt = Int(selectedIdStr),
                let mapping = dependency.dependencyMapping.first(where: {
                    $0.parentFieldOptionId == selectedIdInt
                })
            else {
                continue  // No selection yet → keep child value
            }

            // Parent explicitly allows zero child options → clear
            guard !mapping.childFieldOptionId.isEmpty else {
                fields[childIndex].selectedDropdownItem = nil
                fields[childIndex].selectedDropdownItems = []
                continue
            }

            let allowedChildIds = Set(
                mapping.childFieldOptionId.map(String.init)
            )

            // SINGLE SELECT: Clear if invalid
            if let current = childField.selectedDropdownItem,
                !allowedChildIds.contains(current.id)
            {
                fields[childIndex].selectedDropdownItem = nil
            }

            // MULTI SELECT: Remove invalid items
            if let currentItems = childField.selectedDropdownItems,
                !currentItems.isEmpty
            {
                let validItems = currentItems.filter {
                    allowedChildIds.contains($0.id)
                }
                fields[childIndex].selectedDropdownItems =
                    validItems.isEmpty ? [] : validItems
            }
        }
    }
}

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
