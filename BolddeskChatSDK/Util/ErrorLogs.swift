import Foundation
internal import Sentry

struct ExceptionMessage: Codable {
    var type: String?
    var title: String?
    var status: Int?
    var detail: String?
    var instance: String?
    var errors: [ErrorDetail]?
    var message: String?
    var statusCode: Int?
    var result: ResultDetail?

    enum CodingKeys: String, CodingKey {
        case type, title, status, detail, instance, errors, message, statusCode, result
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        type = try container.decodeIfPresent(String.self, forKey: .type)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        status = try container.decodeIfPresent(Int.self, forKey: .status)
        detail = try container.decodeIfPresent(String.self, forKey: .detail)
        instance = try container.decodeIfPresent(String.self, forKey: .instance)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        statusCode = try container.decodeIfPresent(Int.self, forKey: .statusCode)
        errors = try container.decodeIfPresent([ErrorDetail].self, forKey: .errors)

        // Decode result from array if possible
        if let resultArray = try? container.decodeIfPresent([ResultDetail].self, forKey: .result),
           let firstResult = resultArray.first {
            result = firstResult
        }
    }
}

struct ErrorDetail: Codable {
    var field: String?
    var errorMessage: String?
    var errorType: String?
}

struct ResultDetail: Codable {
    var id: Int?
    var isSuccess: Bool?
    var reason: String?
}


struct ErrorLogs {
    static func logErrors(
        data: Any?,
        exceptionPage: String = "",
        isCatchError: Bool = false,
        statusCode: Int? = nil,
        stackTrace: String? = nil
    ) {
        if isCatchError {
            handleCaughtError(data, exceptionPage: exceptionPage)
        } else {
            handleAPIError(data)
        }
    }
}

// MARK: - Private Helpers
extension ErrorLogs {
    fileprivate static func handleAPIError(_ data: Any?) {
        // 0️⃣ No data => log unknown error and exit
        guard let data = data else {
            if AppConstant.environment != "development" {
                captureSentryMessage("Unknown error")
            }
            return
        }
        do {
            // Build Data from supported inputs, preferring JSON objects for parity with reference logic
            let jsonData: Data
            if JSONSerialization.isValidJSONObject(data) {
                jsonData = try JSONSerialization.data(withJSONObject: data, options: [])
            } else if let rawData = data as? Data {
                jsonData = rawData
            } else if let stringValue = data as? String, let stringData = stringValue.data(using: .utf8) {
                jsonData = stringData
            } else {
                // Unsupported payload type
                if AppConstant.environment != "development" {
                    captureSentryMessage("Unhandled error format")
                }
                return
            }

            // 1️⃣ Try to extract custom `errorMessage` from errors[0].errorMessage
            if let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let errorMessage = (jsonObject["errors"] as? [[String: Any]])?.first?["errorMessage"] as? String,
               !errorMessage.isEmpty {
                if AppConstant.environment != "development" {
                    captureSentryMessage(errorMessage)
                }
                return
            }

            // 2️⃣ Try decoding `ExceptionMessage`
            if let decoded = try? JSONDecoder().decode(ExceptionMessage.self, from: jsonData),
               let message = decoded.message,
               message.lowercased() != "cancelled" {
                let finalMessage = message.isEmpty ? "Something went wrong" : message
                if AppConstant.environment != "development" {
                    captureSentryMessage(finalMessage)
                }
                return
            }
            // If nothing matched, do not emit a generic user-facing toast. Only log when we have a meaningful message.
        } catch {
            if AppConstant.environment != "development" {
                captureSentryMessage(error.localizedDescription)
            }
        }
    }

    fileprivate static func handleCaughtError(
        _ data: Any?,
        exceptionPage: String?
    ) {
        guard
            let error = data as? Error,
            AppConstant.environment != "development"
        else { return }
        captureSentryError(error: error, exceptionPage: exceptionPage)
    }
}

// MARK: - Sentry Logging
extension ErrorLogs {
    fileprivate static func captureSentryError(
        error: Error,
        exceptionPage: String?
    ) {
        DispatchQueue.main.async {
            configureSentryScope(exceptionPage: exceptionPage)
            SentrySDK.capture(error: error)
        }
    }

    fileprivate static func captureSentryMessage(_ message: String) {
        DispatchQueue.main.async {
            configureSentryScope()
            SentrySDK.capture(message: message)
        }
    }

    fileprivate static func configureSentryScope(exceptionPage: String? = nil) {
        SentrySDK.configureScope { scope in
            scope.setTag(value: ChatWidgetAPIPaths.appToken, key: "App ID")
            scope.setTag(value: ChatWidgetAPIPaths.base, key: "BrandURL")
            scope.setTag(value: AppConstant.clientAppName, key: "Integrated app name")
            scope.setTag(value: AppConstant.deviceName, key: "Device name")
            scope.setTag(value: AppConstant.osVersion, key: "Device OS version")
            scope.setTag(value: AppConstant.sdkVersion, key: "SDK version")
            scope.setTag(value: AppConstant.environment, key: "Environment")
            if let page = exceptionPage, !page.isEmpty {
                scope.setTag(value: page, key: "Exception Page")
            }
        }
    }
}
