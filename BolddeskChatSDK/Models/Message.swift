import SwiftUI

struct Message: Identifiable, Hashable {
    let id: String
    let from: String
    let userType: UserType
    let type: MessageType
    var deliveryStatus: DeliveryStatus
    let time: String
    let timeLabel: String
    let isReceiptRequested: Bool
    let isArchived: Bool
    var text: String?
    var textFormat: TextFormat?
    let uploaderFileId: String?
    var files: [File]?
    let chatStates: ChatStates?
    var agentInfo: AgentInfo?
    var isRetracted: Bool
    var isReplaced: Bool
    var formDetails: FormDetails?
    let fieldValueDetails: FieldValueDetails?
    let archiveId: String?
    let isUnsyncMessage: Bool
    var actionButtonValue: String?
    var actionButtonType: ActionButtonType?
    // Streaming state
    var isStreaming: Bool = false
    var currentSeq: Int? = nil
    var attachmentInfo: AttachmentInfo?
    
    init(id: String = UUID().uuidString.lowercased(), from: String, userType: UserType, type: MessageType, deliveryStatus: DeliveryStatus, time: String = ISO8601DateFormatter().string(from: Date()), timeLabel: String = {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a" // Or "HH:mm" for 24-hour
        formatter.timeZone = .current
        return formatter.string(from: now)
    }(), isReceiptRequested: Bool = false, isArchived: Bool = false, text: String? = nil, textFormat: TextFormat? = nil, uploaderFileId: String? = nil, files: [File]? = nil, chatStates: ChatStates? = nil, agentInfo: AgentInfo? = nil, isRetracted: Bool = false, isReplaced: Bool = false, formDetails: FormDetails? = nil, fieldValueDetails: FieldValueDetails? = nil, archiveId: String? = nil, isUnsyncMessage: Bool = false, actionButtonValue: String? = nil, actionButtonType: ActionButtonType? = nil, isStreaming: Bool = false, currentSeq: Int? = nil, attachmentInfo: AttachmentInfo? = nil) {
        self.id = id
        self.from = from
        self.userType = userType
        self.type = type
        self.deliveryStatus = deliveryStatus
        self.time = time
        self.timeLabel = timeLabel
        self.isReceiptRequested = isReceiptRequested
        self.isArchived = isArchived
        self.text = text
        self.textFormat = textFormat
        self.uploaderFileId = uploaderFileId
        self.files = files
        self.chatStates = chatStates
        self.agentInfo = agentInfo
        self.isRetracted = isRetracted
        self.isReplaced = isReplaced
        self.formDetails = formDetails
        self.fieldValueDetails = fieldValueDetails
        self.archiveId = archiveId
        self.isUnsyncMessage = isUnsyncMessage
        self.actionButtonValue = actionButtonValue
        self.actionButtonType = actionButtonType
        self.isStreaming = isStreaming
        self.currentSeq = currentSeq
        self.attachmentInfo = attachmentInfo
    }
}
