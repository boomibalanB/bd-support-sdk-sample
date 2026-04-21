import SwiftUI
import UIKit
import CoreText

/// A helper class to locate the framework bundle
private class BundleLocator {}

public enum ResourceManager {
    
    /// Returns the bundle where your framework's resources live
    public static var frameworkBundle: Bundle {
        return Bundle(for: BundleLocator.self)
    }
    
    // MARK: - Font Loading
    
    /// Register custom fonts from the framework bundle
    public static func registerFonts(_ fontFileNames: [String]) {
        for fileName in fontFileNames {
            let parts = fileName.split(separator: ".")
            guard parts.count == 2,
                  let url = frameworkBundle.url(forResource: String(parts[0]), withExtension: String(parts[1])),
                  let dataProvider = CGDataProvider(url: url as CFURL),
                  let font = CGFont(dataProvider) else {
                continue
            }
            
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterGraphicsFont(font, &error) {
            }
        }
    }
    
    /// Localized string from the framework's Localizable.strings
       public static func localized(
           _ key: String,
           value: String = "",
           comment: String = ""
       ) -> String {

           let language = DeviceConfig.languageCode

           let shortLang = language.split(separator: "-").first.map(String.init) ?? "en"

           guard
               let path = frameworkBundle.path(
                   forResource: shortLang,
                   ofType: "lproj"
               ),
               let localizedBundle = Bundle(path: path)
           else {
               // fallback to English
               return NSLocalizedString(
                   key,
                   tableName: nil,
                   bundle: frameworkBundle,
                   value: value,
                   comment: comment
               )
           }

           return NSLocalizedString(
               key,
               tableName: nil,
               bundle: localizedBundle,
               value: value,
               comment: comment
           )
       }
}
