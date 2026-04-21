
import Foundation

// MARK: - Configuration

let supportedLanguageCodes = [
    "bg","cs","da","de","el","es","fi","fr","hu",
    "id","it","ja","ko","ms","nb","nl","pl",
    "pt-BR","ro","ru","sv","th","tr","uk","vi",
    "zh","zh-Hant","hi","pt","en-GB",
    "sr-Cyrl","lv","hr","sl","ta","si","lt","cy","et","he","lv-LV","lt-LT"
]

let reservedKeys: [String: String] = [
    "aiText": "AI",
    "ccText": "Cc",
    "iDText": "ID",
    "boldDeskText": "BoldDesk®!"
]

// CHANGE THIS FLAG
let isAddingNewFile = true

// MARK: - File Helpers

func readStringsFile(_ path: String) -> [String: String] {
    guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
        return [:]
    }

    var result: [String: String] = [:]

    let lines = content.split(separator: "\n")

    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        guard
            !trimmed.hasPrefix("//"),
            trimmed.contains("="),
            trimmed.hasSuffix(";")
        else { continue }

        let parts = trimmed
            .replacingOccurrences(of: ";", with: "")
            .split(separator: "=", maxSplits: 1)

        guard parts.count == 2 else { continue }

        let key = parts[0]
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\"", with: "")

        let value = parts[1]
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\"", with: "")

        result[key] = value
    }

    return result
}


func writeStringsFile(language: String, data: [String: String]) throws {
    // Base path to your localization folder
    // Get folder of this script
    let scriptDir = URL(fileURLWithPath: #file).deletingLastPathComponent()

    // The Localization folder is the parent folder of Scripts
    let localizationBasePath = scriptDir
        .deletingLastPathComponent() // go up from Scripts to Localization parent
        .path


    // Folder for this language
    let folderPath = "\(localizationBasePath)/\(language).lproj"

    // Create the folder if it doesn't exist
    try FileManager.default.createDirectory(
        atPath: folderPath,
        withIntermediateDirectories: true
    )

    // Full path to the strings file
    let filePath = "\(folderPath)/Localizable.strings"

    // Sort keys alphabetically (optional, makes file easier to read)
    let sorted = data.sorted { $0.key < $1.key }

    // Build the content string
    var content = ""
    for (key, value) in sorted {
        content += "\(key) = \"\(value)\";\n"
    }

    // Write the file to disk
    try content.write(
        toFile: filePath,
        atomically: true,
        encoding: .utf8
    )

}


// MARK: - Diff Logic (Same as Flutter)

func getNewAndUpdatedEntries(
    old: [String: String],
    new: [String: String]
) -> [String: String] {
    var updated: [String: String] = [:]

    for (key, value) in new {
        if old[key] != value {
            updated[key] = value
        }
    }
    return updated
}

// MARK: - Batch Helper

func batch<T>(_ items: [T], size: Int) -> [[T]] {
    stride(from: 0, to: items.count, by: size).map {
        Array(items[$0..<min($0 + size, items.count)])
    }
}

// MARK: - Azure Translator

struct AzureTranslator {

    let endpoint: String
    let keys: [String]
    let region: String

    private var currentKeyIndex = 0

    init(endpoint: String, keys: [String], region: String) {
        self.endpoint = endpoint
        self.keys = keys
        self.region = region
    }

    mutating func nextKey() -> String {
        let key = keys[currentKeyIndex]
        currentKeyIndex = (currentKeyIndex + 1) % keys.count
        return key
    }

    mutating func translate(_ texts: [String], to locale: String) async throws -> [String] {
        let url = URL(string: "\(endpoint)/translate?api-version=3.0&from=en&to=\(locale)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let key = nextKey()
        
        // Generate a unique trace ID for this request
        let uuid = UUID().uuidString

        // Add headers
        let concatenatedKeys = keys.joined()
        request.addValue(concatenatedKeys, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        request.addValue(region, forHTTPHeaderField: "Ocp-Apim-Subscription-Region")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(uuid, forHTTPHeaderField: "X-ClientTraceId")  // ← Added

        // Build the body
        let body = texts.map { ["text": $0] }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Make the request
        let (data, response) = try await URLSession.shared.data(for: request)

        // Check HTTP status
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let bodyString = String(data: data, encoding: .utf8) ?? "(no body)"
            print("❌ Azure request failed: status \(http.statusCode), body: \(bodyString)")
            throw NSError(domain: "AzureTranslationFailed", code: http.statusCode)
        }

        // Parse response
        let json = try JSONSerialization.jsonObject(with: data) as! [[String: Any]]
        return json.map {
            (($0["translations"] as! [[String: Any]])[0]["text"] as! String)
        }
    }


}


// MARK: - Main Pipeline
func runGenerator() async throws {
    print("🚀 Localization generator started")

    var translator = AzureTranslator(
        endpoint: "https://api.cognitive.microsofttranslator.com",
        keys: [
            "d90720a3a1b",
            "042a4ab3f8a0",
            "770177eee"
        ],
        region: "eastus"
    )

    // Get folder of this script
    let scriptDir = URL(fileURLWithPath: #file).deletingLastPathComponent()

    // The Localization folder is the parent folder of Scripts
    let localizationBasePath = scriptDir
        .deletingLastPathComponent() // go up from Scripts to Localization parent
        .path



    let currentEnglish = readStringsFile("\(localizationBasePath)/en.lproj/Localizable.strings")
    let defaultEnglish = readStringsFile("\(localizationBasePath)/default_en/Localizable.strings")


    let valuesToTranslate = isAddingNewFile
        ? currentEnglish
        : getNewAndUpdatedEntries(old: defaultEnglish, new: currentEnglish)

    guard !valuesToTranslate.isEmpty else {
        return
    }

    let sorted = valuesToTranslate.sorted { $0.key < $1.key }
    let keys = sorted.map { $0.key }
    let values = sorted.map { $0.value }

    let batches = batch(values, size: 500)

    for lang in supportedLanguageCodes {
        var translated: [String: String] = [:]

        for chunk in batches {
            let translatedChunk = try await translator.translate(chunk, to: lang)
            for (k, v) in zip(keys, translatedChunk) {
                translated[k] = v
            }
        }

        reservedKeys.forEach { translated[$0.key] = $0.value }
        try writeStringsFile(language: lang, data: translated)
    }

    try writeStringsFile(language: "en", data: currentEnglish)
}

//import Dispatch
//
//let semaphore = DispatchSemaphore(value: 0)

//Task {
//    do {
//        try await runGenerator()
//    } catch {
//        print("❌ Error:", error)
//    }
//    semaphore.signal()
//}
//
//semaphore.wait()


// Uncomment the above code to run the generator directly from terminal (Line Number: 259 to 272)
// Open the Localization folder in terminal
// and run: swift Scripts/localization_generator.swift

