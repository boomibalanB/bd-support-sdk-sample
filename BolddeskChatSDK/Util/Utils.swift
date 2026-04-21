import SwiftUI
internal import SWXMLHash
import UIKit

func convertToFormattedSize(_ bytes: Int) -> String {
    let kilobytes = Double(bytes) / 1024.0

    if kilobytes < 1 {
        return "\(bytes) bytes"
    } else if kilobytes < 1024 {
        return "\(Int(kilobytes)) KB"
    } else {
        let megabytes = kilobytes / 1024.0
        return "\(Int(megabytes)) MB"
    }
}

func isValidDateValue(_ rawValue: Any?) -> Bool {
    guard
        let text = rawValue as? String,
        let parsedDate = isValidDate(text)
    else {
        return false
    }

    if
        let minStr = AppConstant.minMaxDateRange["date"]?.first,
        let maxStr = AppConstant.minMaxDateRange["date"]?.last,
        let minDate = isValidDate(minStr),
        let maxDate = isValidDate(maxStr)
    {
        if parsedDate < minDate || parsedDate > maxDate {
            return false
        }
    }

    return true
}

func isValidDateTimeValue(_ rawValue: Any?) -> Bool {
    guard
        let text = rawValue as? String,
        let parsedDate = isValidISODateTime(text)
    else {
        return false
    }

    if
        let minStr = AppConstant.minMaxDateRange["datetime"]?.first,
        let maxStr = AppConstant.minMaxDateRange["datetime"]?.last,
        let minDate = isValidISODateTime(minStr),
        let maxDate = isValidISODateTime(maxStr)
    {
        if parsedDate < minDate || parsedDate > maxDate {
            return false
        }
    }

    return true
}


func convertISOStringToDate(from string: String) -> Date? {
    return isoDateFormatter.date(from: string)
}

func convertDateToISOString(date: Date) -> String {
    return isoDateFormatter.string(from: date)
}

func formatDateTime(date: Date, format: String) -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = format
    dateFormatter.locale = Locale.current
    dateFormatter.timeZone = TimeZone.current
    return dateFormatter.string(from: date)
}

/// A shared ISO8601 date formatter for parsing and formatting date strings.
let isoDateFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter
}()

/// A shared DateFormatter for date format "MM/dd/yyyy".
let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "MM/dd/yyyy"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter
}()

/// A shared DateFormatter for datetime format "MM/dd/yyyy hh:mm a".
let dateTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "MM/dd/yyyy hh:mm a"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone.current
    return formatter
}()

func isValidDate(_ text: String) -> Date? {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.date(from: text)
}

func isValidISODateTime(_ text: String) -> Date? {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.date(from: text)
}


func stringToDate(_ value: String) -> Date? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    // 1️⃣ ISO 8601 (date or datetime)
    let isoFormatter = ISO8601DateFormatter()
    isoFormatter.formatOptions = [
        .withInternetDateTime,
        .withFractionalSeconds
    ]
    isoFormatter.timeZone = TimeZone(secondsFromGMT: 0)

    if let date = isoFormatter.date(from: trimmed) {
        return date
    }

    // 2️⃣ ISO date only: yyyy-MM-dd
    let isoDateOnly = DateFormatter()
    isoDateOnly.dateFormat = "yyyy-MM-dd"
    isoDateOnly.locale = Locale(identifier: "en_US_POSIX")
    isoDateOnly.timeZone = TimeZone(secondsFromGMT: 0)

    if let date = isoDateOnly.date(from: trimmed) {
        return date
    }

    // 3️⃣ UI DateTime: dd/MMM/yyyy hh:mm a
    let uiDateTime = DateFormatter()
    uiDateTime.dateFormat = "dd/MMM/yyyy hh:mm a"
    uiDateTime.locale = Locale.current
    uiDateTime.timeZone = TimeZone.current

    if let date = uiDateTime.date(from: trimmed) {
        return date
    }

    // 4️⃣ UI Date only: dd/MMM/yyyy
    let uiDate = DateFormatter()
    uiDate.dateFormat = "dd/MMM/yyyy"
    uiDate.locale = Locale.current
    uiDate.timeZone = TimeZone.current

    return uiDate.date(from: trimmed)
}


func convertISOToDisplayString(
    _ isoString: String,
    type: FieldDateType
) -> String {
    guard let date = isoDateFormatter.date(from: isoString) else {
        return isoString
    }

    switch type {
    case .date:
        return dateFormatter.string(from: date)

    case .dateTime:
        return dateTimeFormatter.string(from: date)
    }
}


/// Returns a formatted string representing the time the message was sent, based on its date.
/// - Parameter date: The date of the chat message.
/// - Returns: A formatted string showing the time or date based on its relation to the current date.
func getChatMessageTime(for date: Date) -> String {
    let calendar = Calendar.current
    let currentDate = Date()
    
    // Check if the message date is in a different year than the current date
    if !calendar.isDate(date, equalTo: currentDate, toGranularity: .year) {
        // Format the date including the year for messages from different years
        return formatDateTime(date: date, format: "MMM dd yyyy, hh:mm a")
    } else if calendar.isDateInToday(date) {
        // Format the time only for messages sent today
        return formatDateTime(date: date, format: "hh:mm a")
    } else if calendar.isDateInYesterday(date) {
        // Indicate "Yesterday" for messages sent the day before and format the time
        return "\(ResourceManager.localized("yesterday")), \(formatDateTime(date: date, format: "hh:mm a"))"
    } else if calendar.isDate(date, equalTo: currentDate, toGranularity: .month) {
        // Format the date without the year for messages sent in the current month
        return formatDateTime(date: date, format: "MMM dd, hh:mm a")
    } else {
        // Messages sent within the same year but not today or yesterday
        return formatDateTime(date: date, format: "MMM dd, hh:mm a")
    }
}

func convertFieldValuesToText(fieldValueDetails: FieldValueDetails) -> String {
    let value = fieldValueDetails.value
    var textResult = ""

    if fieldValueDetails.fieldValueType == "skipped" {
        textResult = ResourceManager.localized("skipped")
    } else if let pickerOption = fieldValueDetails.pickerValue, pickerOption.count > 0 {
        textResult = pickerOption.map { $0.displayName }.joined(separator: ", ")
    } else if fieldValueDetails.fieldValueType == "date" {
        if let date = convertISOStringToDate(from: value) {
            textResult = formatDateTime(date: date, format: "MM/dd/yyyy")
        } else {
            // Fallback: if ISO parsing fails, return the original value
            textResult = value.isEmpty ? "" : value
        }
    } else if fieldValueDetails.fieldValueType == "datetime" {
        if let date = convertISOStringToDate(from: value) {
            textResult = formatDateTime(date: date, format: "MM/dd/yyyy hh:mm a")
        } else {
            // Fallback: if ISO parsing fails, return the original value
            textResult = value.isEmpty ? "" : value
        }
    } else {
        textResult = value
    }
    return textResult
}

/// Validates a given string against a specified regex pattern using NSPredicate.
/// - Parameters:
///   - text: The text to validate.
///   - pattern: The regex pattern to match the text against.
/// - Returns: A Boolean indicating whether the text matches the regex pattern.
func isMatchingRegex(_ text: String, pattern: String) -> Bool {
    return NSPredicate(format: "SELF MATCHES %@", pattern).evaluate(with: text)
}

func escapeHTML(_ htmlString: String) -> String {
    return htmlString
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "'", with: "&apos;")
        .replacingOccurrences(of: "\"", with: "&quot;")
}

func getAssigneeFieldUpdateNotificationText(widgetId: String, oldValue: String?, newValue: String?) async -> String {
    var oldAgentName = ""
    var isOldAgentAI = false
    var newAgentName = ""
    var isNewAgentAI = false
    
    // Fetch old agent name
    if let oldValue = oldValue, let oldAgentId = Int(oldValue) {
        let agent: AgentInfo = await ChatUtils.shared.getAgentAvatarDetailsById(agentId: oldAgentId)
        oldAgentName = agent.id == -1 ? "" : agent.displayName
        isOldAgentAI = agent.isAIAgent ?? false
    }
    
    // Fetch new agent name
    if let newValue = newValue, let newAgentId = Int(newValue) {
        let agent: AgentInfo = await ChatUtils.shared.getAgentAvatarDetailsById(agentId: newAgentId)
        newAgentName = agent.id == -1 ? "" : agent.displayName
        isNewAgentAI = agent.isAIAgent ?? false
    }
    
    // Determine notification text
    if oldAgentName.isEmpty && !newAgentName.isEmpty {
        // New agent/AI joined
        let notificationText = ResourceManager.localized(isNewAgentAI ? "ai_joined" : "assignee_joined")
        return "<span>\(isNewAgentAI ? "\(notificationText) <b>\(newAgentName)</b>." : "<b>\(newAgentName)</b>\(notificationText)")</span>"
        
    } else if !oldAgentName.isEmpty && newAgentName.isEmpty {
        // Old agent/AI left
        let notificationText = ResourceManager.localized(isOldAgentAI ? "ai_left" : "assignee_left")
        return "<span><b>\(oldAgentName)</b>\(notificationText)</span>"
        
    } else if !oldAgentName.isEmpty && !newAgentName.isEmpty && oldAgentName != newAgentName {
        // Old agent/AI got replaced by new agent/AI
        let localizedText = ResourceManager.localized("assignee_replaced")
        return "<span><b>\(newAgentName)</b>\(String(format: localizedText, "<b>\(oldAgentName)</b>"))</span>"
    }
    
    return ""
}

/// Validates if the provided string is a valid email address using the regex pattern from AppConstants.
/// - Parameter email: The email string to validate.
/// - Returns: A Boolean indicating whether the email is valid.
func isValidEmail(_ email: String) -> Bool {
    let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
    return isMatchingRegex(trimmedEmail, pattern: AppConstant.emailRegex)
}

/// Validates if the provided string is a valid phone number using the regex pattern from AppConstants.
/// - Parameter phoneNo: The phone number string to validate.
/// - Returns: A Boolean indicating whether the phone number is valid.
func isValidPhoneNo(_ phoneNo: String) -> Bool {
    let trimmedPhone = phoneNo.trimmingCharacters(in: .whitespacesAndNewlines)
    return isMatchingRegex(trimmedPhone, pattern: AppConstant.phoneRegex)
}

/// Validates client API details including email, name, and phone number.
/// - Parameter boldChatSettings: The BoldChatSettings object containing user input data.
/// - Returns: A tuple containing validation result and notification type if validation fails.
func validateClientAPIDetails() -> (isValid: Bool, notificationType: NotificationType?) {
    // Return valid if email is nil
    guard BDChatSDK.email != nil else { return (true, nil) }
    
    // Return valid if email is empty
    guard let email = BDChatSDK.email, !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return (true, nil)
    }
    
    // Email validation first - early return if invalid
    guard isValidEmail(email) else {
        return (false, .invalidEmail)
    }
    
    // Name validation - check for invalid characters and length
    if let name = BDChatSDK.name, !name.isEmpty {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !isMatchingRegex(trimmedName, pattern: AppConstant.invalidTextCharRegex) || trimmedName.count > AppConstant.nameFieldMaxLength {
            return (false, .invalidName)
        }
    }
    
    // Phone validation - check for invalid characters, regex pattern, and length
    if let phoneNo = BDChatSDK.phoneNo, !phoneNo.isEmpty {
        let trimmedPhone = phoneNo.trimmingCharacters(in: .whitespacesAndNewlines)
        if !isMatchingRegex(trimmedPhone, pattern: AppConstant.invalidTextCharRegex) || !isValidPhoneNo(trimmedPhone) || trimmedPhone.count > AppConstant.singleLineTextBoxMaxLength {
            return (false, .invalidPhoneNo)
        }
    }
    
    return (true, nil)
}

// Builds a detailed upload extension error based on allowed extensions
// - If one extension: Only {ext} is permitted
// - If multiple: Only {list} and {last} are permitted
func getUploadExtensionErrorNotification(allowedExtensions: [String]) -> NotificationType {
    if allowedExtensions.count == 1, let only = allowedExtensions.first {
        return .uploadExtensionNotAllowedWithSingleAllowedFile(only)
    }
    let list = allowedExtensions.dropLast().joined(separator: ", ")
    let last = allowedExtensions.last ?? ""
    return .uploadExtensionNotAllowedWithMultipleAllowedFile(list, last)
}

class ChatUtils {
    static let shared = ChatUtils()
    private let chatAPIClient = ChatAPIClient()
    private var agentAvatars: [AgentInfo] = []
    private var ongoingRequests: [Int: Task<AgentInfo, Never>] = [:]

    /// Clears the agent avatar cache and cancels any ongoing requests
    func clearCache() {
        agentAvatars.removeAll()
        ongoingRequests.values.forEach { $0.cancel() }
        ongoingRequests.removeAll()
    }

    func getAgentAvatarDetailsById(agentId: Int) async -> AgentInfo {
        // 1. Check cache and update isProfileImageLoad flag if found
        if let index = agentAvatars.firstIndex(where: { $0.id == agentId }) {
            // Update isProfileImageLoad flag in the cache (critical step!)
            if agentAvatars[index].isProfileImageLoaded != true {
                agentAvatars[index].isProfileImageLoaded = true
            }
            return agentAvatars[index]
        }
        
        // 2. Handle existing request if available - THREAD SAFE
        let existingTask = await MainActor.run {
            return ongoingRequests[agentId]
        }
        
        if let existingTask = existingTask {
            return await existingTask.value
        }
        
        // 3. Create new API request task
        let task = Task<AgentInfo, Never> {
            do {
                // Replace with actual API call
                let agentDetails = try await chatAPIClient.getAgentInfo(agentId: String(agentId))
                // Update cache with new agent - THREAD SAFE
                await MainActor.run {
                    self.agentAvatars.append(agentDetails)
                    self.ongoingRequests[agentId] = nil
                }
                return agentDetails
                
            } catch {
                // Error handling: clear request and return default agent
                await MainActor.run {
                    self.ongoingRequests[agentId] = nil
                }
                return AgentInfo(
                    id: -1,
                    displayName: "Agent",
                    colorCode: "",
                    shortCode: "A",
                    profileImageUrl: nil,
                    isAIAgent: false,
                    isProfileImageLoaded: false
                )
            }
        }
        
        // 4. Store request - THREAD SAFE
        await MainActor.run {
            ongoingRequests[agentId] = task
        }
        
        return await task.value
    }
}

func jsonString(from dict: [String: Any]) -> String? {
    guard let data = try? JSONSerialization.data(withJSONObject: dict, options: []) else {
        return nil
    }
    return String(data: data, encoding: .utf8)
}


enum FieldDateType {
    case date
    case dateTime
}


func timeDifference(isoTimestamp: String?) -> String {
    guard let isoTimestamp,
          !isoTimestamp.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
        return ""
    }

    let isoFormatter = ISO8601DateFormatter()
    isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    // Try parsing with fractional seconds first, fallback if needed
    let givenDate =
        isoFormatter.date(from: isoTimestamp) ??
        ISO8601DateFormatter().date(from: isoTimestamp)

    guard let givenDate else {
        return ""
    }

    let currentDate = Date()
    let totalSeconds = Int(currentDate.timeIntervalSince(givenDate))

    // Less than a minute
    if totalSeconds < 60 {
        return "Now"
    }

    // Less than an hour
    if totalSeconds < 3600 {
        let minutes = totalSeconds / 60
        return "\(minutes)m"
    }

    // Less than a day
    if totalSeconds < 86400 {
        let hours = totalSeconds / 3600
        return "\(hours)h"
    }

    // Day-based comparison
    let calendar = Calendar.current
    let givenDay = calendar.startOfDay(for: givenDate)
    let currentDay = calendar.startOfDay(for: currentDate)

    let dayDifference = calendar.dateComponents([.day], from: givenDay, to: currentDay).day ?? 0

    // Yesterday
    if dayDifference == 1 {
        return "Yesterday"
    }

    // Older dates
    let formatter = DateFormatter()
    formatter.locale = Locale.current

    let givenYear = calendar.component(.year, from: givenDate)
    let currentYear = calendar.component(.year, from: currentDate)

    if givenYear == currentYear {
        formatter.dateFormat = "d MMM"
    } else {
        formatter.dateFormat = "d MMM yyyy"
    }

    return formatter.string(from: givenDate).lowercased()
}

extension XMLIndexer {

    /// Find first element by tag name anywhere (Jsoup-like)
    func firstDescendant(named name: String) -> XMLElement? {
        for child in children {
            if child.element?.name == name {
                return child.element
            }
            if let found = child.firstDescendant(named: name) {
                return found
            }
        }
        return nil
    }
}


extension String {

    func stripHTML() -> String {
        var text = self

        // Remove tags
        text = text.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        )

        // Decode common entities
        let entities: [String: String] = [
            "&nbsp;": " ",
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&#39;": "'"
        ]

        for (entity, value) in entities {
            text = text.replacingOccurrences(of: entity, with: value)
        }

        return text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension String {
    var sanitizedOptional: String {
        if self.hasPrefix("Optional(") {
            return self
                .replacingOccurrences(of: "Optional(\"", with: "")
                .replacingOccurrences(of: "\")", with: "")
        }
        return self
    }
}

// Check if brand logo URL matches the AppConstant brandLogoURL AND app bar color is white
func shouldShowErrorBackground(brandLogoURL: URL?) ->  Bool {
    guard let currentURL = brandLogoURL?.absoluteString else { return false }
    
    // Check if URL matches
    let urlMatches = currentURL == AppConstant.brandLogoURL
    
    // Check if app bar color is white
    let isAppBarWhite = isColorWhite(hex: AppConstant.appBarColor)
    
    // Both conditions must be true
    return urlMatches && isAppBarWhite
}

// Helper to check if a color is white based on RGB values
func isColorWhite(hex: String) -> Bool {
    let hexColor = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    
    // Check for common white color representations
    let whiteColors = [
        "FFFFFF", "ffffff",
        "FFF", "fff"
    ]
    
    if whiteColors.contains(hexColor) {
        return true
    }
    
    // For 6-digit hex, check RGB values
    guard hexColor.count == 6 else { return false }
    
    let scanner = Scanner(string: hexColor)
    var hexNumber: UInt64 = 0
    
    guard scanner.scanHexInt64(&hexNumber) else { return false }
    
    let r = CGFloat((hexNumber & 0xFF0000) >> 16)
    let g = CGFloat((hexNumber & 0x00FF00) >> 8)
    let b = CGFloat(hexNumber & 0x0000FF)
    
    // Check if all RGB values are 255 (pure white) or very close (250-255)
    return r >= 250 && g >= 250 && b >= 250
}
