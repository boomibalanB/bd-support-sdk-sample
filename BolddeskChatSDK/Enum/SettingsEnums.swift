enum ChatValidation: Int, Decodable {
    case none = 1
    case email = 2
}

enum FileUploadOption: Int, Decodable {
    case none = 1
    case singleFiles = 2
    case multipleFiles = 3
}

enum SuggestionType: Int, Decodable {
    case none = 0
    case actionButton = 1
    case frequentlyAskedQuestion = 2
}
