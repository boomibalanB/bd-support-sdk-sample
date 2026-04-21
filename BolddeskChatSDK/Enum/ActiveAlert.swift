import Foundation

// Global alert type shared across views/files
enum ActiveAlert: Identifiable {
    case emailTranscript
    case endChat
    var id: Int { hashValue }
}
