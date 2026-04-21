import Foundation

struct WidgetStorageManager {
    
    // Global config (not tied to a widget)
    private static let globalAppTokenKey = "bd__appToken"
    private static let globalBrandUrlKey = "bd_brandUrl"
    
    /// Persist global config
    static func setGlobalConfig(appToken: String, brandUrl: String) {
        UserDefaults.standard.set(appToken, forKey: globalAppTokenKey)
        UserDefaults.standard.set(brandUrl, forKey: globalBrandUrlKey)
    }
    
    /// Read persisted global config
    static func getAppToken() -> String? {
        UserDefaults.standard.string(forKey: globalAppTokenKey)
    }
    
    static func getBrandUrl() -> String? {
        UserDefaults.standard.string(forKey: globalBrandUrlKey)
    }
    
    /// Clear persisted global config
    static func clearGlobalConfig() {
        UserDefaults.standard.removeObject(forKey: globalAppTokenKey)
        UserDefaults.standard.removeObject(forKey: globalBrandUrlKey)
    }
    
    /// Keys
    private static func settingsKey(appKey: String, emailId: String? = nil) -> String {
        guard
            let email = emailId?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                !email.isEmpty
            else {
                return getAppToken() ?? ""
            }

            return "\(getAppToken())_\(email)"
    }
    
    /// Update a single key-value pair
    static func updateSetting(key: String, value: String, appKey: String, emailId: String? = nil) {
        let fullKey = settingsKey(appKey: appKey, emailId: emailId)
        var settings = UserDefaults.standard.dictionary(forKey: fullKey) as? [String: String] ?? [:]
        settings[key] = value
        UserDefaults.standard.set(settings, forKey: fullKey)
    }
    
    /// Get all settings for a widget
    private static func getAllSettings(appKey: String, emailId: String? = nil) -> [String: String]? {
        let fullKey = settingsKey(appKey: appKey, emailId: emailId)
        return UserDefaults.standard.dictionary(forKey: fullKey) as? [String: String]
    }
    
    /// Get a specific setting
    static func getSetting(for key: String, appKey: String, emailId: String? = nil) -> String? {
        return getAllSettings(appKey: appKey, emailId: emailId)?[key]
    }
    
    /// Remove a specific setting
    static func removeSetting(for key: String, appKey: String, emailId: String? = nil) {
        let fullKey = settingsKey(appKey: appKey, emailId: emailId)
        var settings = UserDefaults.standard.dictionary(forKey: fullKey) as? [String: String] ?? [:]
        settings.removeValue(forKey: key)
        UserDefaults.standard.set(settings, forKey: fullKey)
    }
    
    /// Clear all settings for a widget
    static func clearAllSettings(appKey: String, emailId: String? = nil) {
        let fullKey = settingsKey(appKey: appKey, emailId: emailId)
        UserDefaults.standard.removeObject(forKey: fullKey)
    }
    
    static func isUserExistAlready(appKey: String, emailId: String? = nil) -> Bool {
        // Get widget settings
        guard let settings = UserDefaults.standard.dictionary(forKey: settingsKey(appKey: appKey, emailId: emailId)) as? [String: String] else {
            return false
        }

        // Required keys to check
        let requiredKeys = ["rId", "userJid", "rType", "sessionId"]

        // Ensure all required fields are non-empty and non-whitespace
        for key in requiredKeys {
            guard let value = settings[key], !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return false
            }
        }

        return true
    }
    
    static func clearConversationDataInStorage(appKey: String, emailId: String? = nil) {
        let fullKey = settingsKey(appKey: appKey, emailId: emailId)
        var settings = UserDefaults.standard.dictionary(forKey: fullKey) as? [String: String] ?? [:]
        let keysToClear = ["userJid", "cId", "token", "tokenExpiry"]
        for key in keysToClear {
            settings.removeValue(forKey: key)
        }
        
        UserDefaults.standard.set(settings, forKey: fullKey)
    }
    
    static func isRequesterDetailsAvailableInStorage(appKey: String, emailId: String? = nil) -> Bool {
        guard let settings = UserDefaults.standard.dictionary(forKey: settingsKey(appKey: appKey, emailId: emailId)) as? [String: String] else {
            return false
        }
        
        let requesterKeys = ["rId", "rType"]
        // Ensure all required fields are non-empty and non-whitespace
        for key in requesterKeys {
            guard let value = settings[key], !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return false
            }
        }
        return true
    }
}

