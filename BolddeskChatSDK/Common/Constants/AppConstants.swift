import SwiftUI

struct AppConstant {
    static let emailRegex = "^(?=.{1,254}$)(?=.{1,64}@)[a-zA-Z0-9!#$%&'*+/=?^_`{|}~-]+(?:\\.[a-zA-Z0-9!#$%&'*+/=?^_`{|}~-]+)*@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9]){1,})+(?:\\.[a-zA-Z0-9-]+)*$"
    static let urlRegex = "(?:https?|ftp)://[^\\s/$.?#].[^\\s]*"
    static let phoneRegex = "^\\+?\\d{4,15}$"
    static let imgMaxSize = 10485760 // In bytes
    static let notificationAutoHideDelay: TimeInterval = 4 // In seconds
    static let tokenRefreshBufferMinutes = 2 // (In minutes) Need to update the token 2 minutes before it actually expires
    static let systemUserId = 5
    static let invalidTextCharRegex = "^(?!.*(?:[\\u2700-\\u27bf]|(?:\\ud83c[\\udde6-\\uddff]){2}|[\\ud800-\\udbff][\\udc00-\\udfff]|[\\u0023-\\u0039]\\ufe0f?\\u20e3|\\u3299|\\u3297|\\u303d|\\u3030|\\u24c2|\\ud83c[\\udd70-\\udd71]|\\ud83c[\\udd7e-\\udd7f]|\\ud83c\\udd8e|\\ud83c[\\udd91-\\udd9a]|\\ud83c[\\udde6-\\uddff]|\\ud83c[\\ude01-\\ude02]|\\ud83c\\ude1a|\\ud83c\\ude2f|\\ud83c[\\ude32-\\ude3a]|\\ud83c[\\ude50-\\ude51]|\\u203c|\\u2049|[\\u25aa-\\u25ab]|\\u25b6|\\u25c0|[\\u25fb-\\u25fe]|\\u00a9|\\u00ae|\\u2122|\\u2139|\\ud83c\\udc04|[\\u2600-\\u26FF]|\\u2b05|\\u2b06|\\u2b07|\\u2b1b|\\u2b1c|\\u2b50|\\u2b55|\\u231a|\\u231b|\\u2328|\\u23cf|[\\u23e9-\\u23f3]|[\\u23f8-\\u23fa]|\\ud83c\\udccf|\\u2934|\\u2935|[\\u2190-\\u21ff]|[\\<])).*$"
    static let minMaxDateRange: [String: [String]] = [
        "datetime": ["1900-01-01T00:00:00.000Z",
                     "2099-12-31T23:59:00.000Z"],
        "date": ["1900-01-01", "2099-12-31"]
    ]
    static let singleLineTextBoxMaxLength = 255
    static let customMultiLineTextBoxMaxLength = 3000
    static let nameFieldMaxLength = 100
    static let maxArchivedMessageLimit = 20 // Limit per archived message request
    static let maxUnsyncedMessageLimit = 100 // Limit per unsynced message request
    static let typingIndicatorTimeout: TimeInterval = 30 // in seconds
    static let aiThinkingTimeout: TimeInterval = 60 // in seconds
    static let bolddeskURL = "https://www.bolddesk.com/"
    static let userDetailsFieldApi = ["emailId", "contactName", "contactPhoneNo"];
    static let sentryDSN = "https://97c1fba6823e91af7c8520a419ef99cb@logs.bolddesk.com/137";
    static let environment = "development";
    static var sdkVersion = "1.0.0"
    static var platform = "iOS"
    static var deviceName = ""
    static var osVersion = ""
    static var clientAppName = ""
    static var applicationInfo: [String: Any]?
    static var appBarHex: String = ""
    static var brandLogoURL: String = "https://storage.googleapis.com/cdn-bolddesk/agent-angular-app/images/bold-desk-logo_v1.png"
    @Preference(key: "buttonColor", defaultValue: "") static var buttonColor
    @Preference(key: "chatBackgroundColor", defaultValue: "") static var chatBackgroundColor
    @Preference(key: "appBarColor", defaultValue: "") static var appBarColor
    @Preference(key: "stickyButtonColor", defaultValue: "") static var stickyButtonColor
    @Preference(key: "customThemeApplied", defaultValue: "") static var customTheme
    @Preference(key: "languageCode", defaultValue: "") static var languageCode
    @Preference(key: "email", defaultValue: "") static var email
    @Preference(key: "fcmToken", defaultValue: "") static var fcmToken
}
