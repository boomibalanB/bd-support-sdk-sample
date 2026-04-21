import Foundation

// Streaming context model for incremental/RTT message handling
struct StreamingContext {
    var accumulatedText: String = ""
    var lastSequenceNumber: Int = -1
    var hasFinalContent: Bool = false
}
