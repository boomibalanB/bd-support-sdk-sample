import SwiftUI

enum NotificationType: Equatable {
    case serverOnline
    case reconnecting
    case serverDisconnected
    case accessDenied
    case somethingWentWrong
    case fileMaxSizeExceeded(String)
    case imageMaxSizeExceeded(String)
    case invalidName
    case invalidEmail
    case invalidPhoneNo
    case emailAddressNotConfigured
    case uploadExtensionNotAllowedWithSingleAllowedFile(String)
    case uploadExtensionNotAllowedWithMultipleAllowedFile(String, String)
    case invalidAuthenticationToken
    case intervalLimitExceeded
    case internetOffline
    case internetOnline
    case newConversationButtonError
    case reopenNotAllowedText
    case transcriptDownloadedSuccessfully
    // Custom notification with arbitrary message and style
    case custom(String, Style)

    // Computed property to return a localized message for each notification type
    var message: String {
        switch self {
        case .serverOnline:
            return ResourceManager.localized("server_online")
        case .reconnecting:
            return ResourceManager.localized("reconnecting")
        case .serverDisconnected:
            return ResourceManager.localized("server_disconnected")
        case .accessDenied:
            return ResourceManager.localized("access_denied")
        case .somethingWentWrong:
            return ResourceManager.localized("something_went_wrong")
        case .fileMaxSizeExceeded(let size):
            let format = ResourceManager.localized("file_max_size_exceeded")
            return String(format: format, size)
        case .imageMaxSizeExceeded(let size):
            let format = ResourceManager.localized("image_max_size_exceeded")
            return String(format: format, size)
        case .invalidName:
            return ResourceManager.localized("invalid_name")
        case .invalidEmail:
            return ResourceManager.localized("invalid_email")
        case .invalidPhoneNo:
            return ResourceManager.localized("invalid_phone_no")
        case .emailAddressNotConfigured:
            return ResourceManager.localized("email_address_not_configured")
        case .uploadExtensionNotAllowedWithSingleAllowedFile(let ext):
            let format = ResourceManager.localized("upload_extension_not_allowed_with_single")
            return String(format: format, ext)
        case .uploadExtensionNotAllowedWithMultipleAllowedFile(let list, let last):
            let format = ResourceManager.localized("upload_extension_not_allowed_with_multiple")
            return String(format: format, list, last)
        case .invalidAuthenticationToken:
            return ResourceManager.localized("invalid_authentication_token")
        case .intervalLimitExceeded:
            return ResourceManager.localized("interval_limit_exceeded")
        case .internetOffline:
            return ResourceManager.localized("internet_offline")
        case .internetOnline:
            return ResourceManager.localized("internet_online")
        case .newConversationButtonError:
            return ResourceManager.localized("newConversationButtonError")
        case .reopenNotAllowedText:
            return ResourceManager.localized("reopenNotAllowedText")
        case .transcriptDownloadedSuccessfully:
            return ResourceManager.localized("transcript_downloaded_successfully")
        case .custom(let text, _):
            return text
        }
    }

    // Enum to define the style of the notification (used for UI styling)
    enum Style {
        case success, error, info
    }

    // Computed property to return the style based on the notification type
    var style: Style {
        switch self {
        case .serverOnline, .internetOnline, .transcriptDownloadedSuccessfully:
            return .success
        case .reconnecting:
            return .info
        case .serverDisconnected, .accessDenied, .somethingWentWrong, .fileMaxSizeExceeded, .imageMaxSizeExceeded, .invalidName, .invalidEmail, .invalidPhoneNo, .emailAddressNotConfigured, .uploadExtensionNotAllowedWithSingleAllowedFile, .uploadExtensionNotAllowedWithMultipleAllowedFile ,.invalidAuthenticationToken, .intervalLimitExceeded, .internetOffline, .newConversationButtonError, .reopenNotAllowedText:
            return .error
        case .custom(_, let style):
            return style
        }
    }

    // Determines whether the notification should automatically disappear
    var shouldAutoHide: Bool {
        switch self {
        case .serverOnline, .fileMaxSizeExceeded, .imageMaxSizeExceeded, .emailAddressNotConfigured, .uploadExtensionNotAllowedWithSingleAllowedFile, .uploadExtensionNotAllowedWithMultipleAllowedFile, .intervalLimitExceeded, .internetOnline, .newConversationButtonError, .reopenNotAllowedText, .transcriptDownloadedSuccessfully:
            return true
        default:
            return false
        }
    }
    
    // Indicates whether a retry option should be shown for the notification
    var canShowRetry: Bool {
        switch self {
        case .serverDisconnected:
            return true
        default:
            return false
        }
    }
    
    // Custom equality check for NotificationType, required due to associated values
    static func == (lhs: NotificationType, rhs: NotificationType) -> Bool {
        switch (lhs, rhs) {
        case (.serverOnline, .serverOnline),
            (.reconnecting, .reconnecting),
            (.serverDisconnected, .serverDisconnected),
            (.accessDenied, .accessDenied),
            (.somethingWentWrong, .somethingWentWrong),
            (.invalidName, .invalidName),
            (.invalidEmail, .invalidEmail),
            (.invalidPhoneNo, .invalidPhoneNo),
            (.emailAddressNotConfigured, .emailAddressNotConfigured),
            (.invalidAuthenticationToken, .invalidAuthenticationToken),
            (.intervalLimitExceeded, .intervalLimitExceeded),
            (.internetOffline, .internetOffline),
            (.newConversationButtonError, .newConversationButtonError),
            (.reopenNotAllowedText, .reopenNotAllowedText),
            (.transcriptDownloadedSuccessfully, .transcriptDownloadedSuccessfully),
            (.internetOnline, .internetOnline):
            return true
        case (.fileMaxSizeExceeded(let lhsSize), .fileMaxSizeExceeded(let rhsSize)):
            return lhsSize == rhsSize
        case (.imageMaxSizeExceeded(let lhsSize), .imageMaxSizeExceeded(let rhsSize)):
            return lhsSize == rhsSize
        case (.uploadExtensionNotAllowedWithSingleAllowedFile(let lExt), .uploadExtensionNotAllowedWithSingleAllowedFile(let rExt)):
            return lExt == rExt
        case (.uploadExtensionNotAllowedWithMultipleAllowedFile(let lList, let lLast), .uploadExtensionNotAllowedWithMultipleAllowedFile(let rList, let rLast)):
            return lList == rList && lLast == rLast
        case (.custom(let lMsg, let lStyle), .custom(let rMsg, let rStyle)):
            return lMsg == rMsg && lStyle == rStyle
        default:
            return false
        }
    }
}
