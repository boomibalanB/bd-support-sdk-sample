enum TextFormat: String {
    case none = "none"
    case html = "html"
    case markdown = "markdown"
}

enum DeliveryStatus: String {
    case undelivered = "0" //The message has not received by the recipient's device.
    case sent = "1" //The message has been effectively sent from the sender's device.
    case delivered = "2" //The message has been successfully received by the recipient's device.
    case seen = "3"  //The message has been successfully seen by the receipient's device.
    case toSent = "4" //The message is lined up and prepared for transmission.
    case notSent = "5" //The message did not send due to an error.
    case uploading = "6" //The file is in the process of being uploaded for transmission.
}

enum UserType {
    case agent
    case customer
}

enum MessageType: String {
    case text = "1"
    case image = "2"
    case attachment = "3"
    case audio = "4"
    case video = "5"
    case contact = "6"
    case location = "7"
    case chatStates = "8"
    case deliveryReceipt = "9"
    case readReceipt = "10"
    case whatsappTemplate = "11"
    case visitedPages = "12"
    case fieldUpdate = "13"
    case assigneeFieldUpdate = "14"
    case form = "15"
    case csat = "16"
    case fieldValues = "17"
}

enum ActionButtonType: Int, Codable {
    case none = 0
    case suggestion = 1
    case footer = 2
    case suggestionFAQ = 3
}

enum MessageDirection {
    case sent
    case received
}

enum FieldValueType: String {
    case skipped
    case file
    case date
    case datetime
    case textarray
    case text
}
