//
//  APIErrorHandler.swift
//  BolddeskChatSDK
//
//  Created on 30/03/2026.
//

import Foundation

/// Utility class for handling API errors consistently across the application
final class APIErrorHandler {
    
    // MARK: - Singleton
    
    static let shared = APIErrorHandler()
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Centralized error handler for API errors with HTTP status code handling
    /// - Parameters:
    ///   - error: The error to handle
    ///   - hideNewConversationButton: Whether to hide the new conversation button on 401 errors
    ///   - shouldAutoHide: Whether notifications should auto-hide
    ///   - defaultNotification: Custom default notification for errors not matching specific status codes
    ///   - onBadRequest: Optional custom handler for 400 errors (e.g., for reopen interval checks)
    ///   - onUnauthorized: Optional custom handler for 401 errors (e.g., to hide conversation button)
    /// - Returns: The notification type that was shown (useful for testing or chaining logic)
    @discardableResult
    func handleAPIError(
        _ error: Error,
        shouldAutoHide: Bool = true,
        defaultNotification: NotificationType = .somethingWentWrong,
        onBadRequest: (() -> Void)? = nil,
        onUnauthorized: (() -> Void)? = nil
    ) -> NotificationType? {
        guard let nsError = error as NSError? else {
            NotificationManager.shared.show(defaultNotification, shouldAutoHide: shouldAutoHide)
            return defaultNotification
        }
        
        switch nsError.code {
        case 401:
            // Unauthorized - extract custom error message if available
            let message = extractErrorMessage(from: nsError)
            let notificationType: NotificationType
            
            if let message = message {
                notificationType = .custom(message, .error)
            } else {
                // Use default notification if no custom message available
                notificationType = defaultNotification
            }
            
            NotificationManager.shared.show(notificationType, shouldAutoHide: false)
            
            // Execute custom handler (e.g., hide new conversation button)
            onUnauthorized?()
            
            return notificationType
            
        case 403:
            // Forbidden - access denied
            NotificationManager.shared.show(.accessDenied)
            return .accessDenied
            
        case 400:
            // Check for specific field errors (phone number validation)
            if let fieldError = extractFieldError(from: nsError) {
                NotificationManager.shared.show(fieldError)
                onBadRequest?()
                return fieldError
            }
            
            // Execute custom handler if provided (e.g., for reopen interval)
            onBadRequest?()
            
            // Generic 400 error
            NotificationManager.shared.show(defaultNotification)
            return defaultNotification
            
        case 404:
            // Not found
            NotificationManager.shared.show(.somethingWentWrong)
            return .somethingWentWrong
            
        default:
            // Generic error - use default notification
            NotificationManager.shared.show(defaultNotification, shouldAutoHide: shouldAutoHide)
            return defaultNotification
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// Extracts the error message from the API response JSON
    /// - Parameter nsError: The NSError containing response data
    /// - Returns: The extracted error message or nil
    private func extractErrorMessage(from nsError: NSError) -> String? {
        guard let responseString = nsError.userInfo["responseString"] as? String,
              let data = responseString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = json["message"] as? String else {
            return nil
        }
        return message
    }
    
    /// Extracts field-specific errors from 400 responses (e.g., phone number validation)
    /// - Parameter nsError: The NSError containing response data
    /// - Returns: A notification type for the field error or nil
    private func extractFieldError(from nsError: NSError) -> NotificationType? {
        guard let responseString = nsError.userInfo["responseString"] as? String,
              let data = responseString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let errors = json["errors"] as? [[String: Any]],
              let firstError = errors.first,
              let field = firstError["field"] as? String,
              let errorMessage = firstError["errorMessage"] as? String else {
            return nil
        }
        
        let fieldLower = field.lowercased()
        // Check for phone number field errors
        if fieldLower == "phonenumber" || fieldLower == "phoneno" {
            return .custom(errorMessage, .error)
        }
        
        // Return generic custom error for other fields
        return .custom(errorMessage, .error)
    }
}
