// Array of field dependencies returned by the API
struct FieldDependency: Codable {
    let fieldDependencyId: Int
    let parentField: FieldInfo
    let childField: FieldInfo
    let dependencyMapping: [DependencyMapping]
    let parentOptions: [DynamicDropdownOption]
    let childOptions: [DynamicDropdownOption]
}

struct FieldInfo: Codable {
    let fieldId: Int
    let apiName: String
    let labelForAgentPortal: String
    let labelForCustomerPortal: String
}

struct DependencyMapping: Codable {
    let parentFieldOptionId: Int
    let childFieldOptionId: [Int]
}

struct DynamicDropdownOption: Codable {
    let id: Int
    let name: String
    let isReadOnly: Bool
    let isPrivate: Bool
    let sortOrder: Int
    let isSystemDefault: Bool
}
