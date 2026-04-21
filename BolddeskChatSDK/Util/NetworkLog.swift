import Foundation
import os

enum NetworkLogLevel: String {
    case response = "✅ RESPONSE"
    case error = "❌ ERROR"
    case info = "ℹ️ INFO"
}

final class NetworkLogger {
    static var isEnabled = false

    private static let logger = Logger(
        subsystem: "com.syncfusion.BoldDeskChatSDK",
        category: "Network"
    )

    static func log(_ message: String, level: NetworkLogLevel) {
        guard isEnabled else { return }

        let timestamp = DateFormatter.localizedString(
            from: Date(),
            dateStyle: .none,
            timeStyle: .medium
        )

        let formattedMessage = """
            \(level.rawValue) [\(timestamp)]
            \(message)
            """

        switch level {
        case .response:
            logger.log("\(formattedMessage, privacy: .public)")
        case .error:
            logger.error("\(formattedMessage, privacy: .public)")
        case .info:
            logger.info("\(formattedMessage, privacy: .public)")
        }
    }
}


