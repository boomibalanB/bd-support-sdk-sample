import SwiftUI
import UIKit

struct FontFamily {
    
    static func customFont(
        size: CGFloat,
        weight: UIFont.Weight,
        isScaled: Bool = true
    ) -> Font {
        let style = mapTextStyle(for: size)
        let font = UIFont.inter(size: size, weight: weight)
        
        let finalFont: UIFont
        if BDChatSDK.applySystemFontSize && isScaled{
            finalFont = UIFontMetrics(forTextStyle: style).scaledFont(for: font)
        } else {
            finalFont = font
        }
        
        return Font(finalFont)
    }

    static func customUIFont(
        size: CGFloat,
        weight: UIFont.Weight
    ) -> UIFont {
        let style = mapTextStyle(for: size)
        let font = UIFont.inter(size: size, weight: weight)
        
        if BDChatSDK.applySystemFontSize {
            return UIFontMetrics(forTextStyle: style).scaledFont(for: font)
        } else {
            return font
        }
    }
    
    /// Map font size → text style
    private static func mapTextStyle(for size: CGFloat) -> UIFont.TextStyle {
        switch size {
        case ..<11: return .caption2   // 10
        case 11...12: return .caption2 // 11–12
        case 13: return .footnote
        case 14: return .body
        case 15...16: return .callout
        case 17...18: return .headline
        case 19...20: return .title3
        case 21...24: return .title2
        case 25...28: return .title1
        default: return .body
        }
    }
}

extension UIFontDescriptor {
    static func inter(weight: UIFont.Weight) -> UIFontDescriptor {
        let fontName = BDChatSDK.customFontName ?? "Inter"
        
        // ✅ Check if font is actually registered
        let availableFonts = UIFont.fontNames(forFamilyName: fontName)
        
        if availableFonts.isEmpty {
            // Fallback to system font if custom font not found
            return UIFont.systemFont(ofSize: UIFont.systemFontSize, weight: weight).fontDescriptor
        }
        
        return UIFontDescriptor(fontAttributes: [
            .family: fontName,
            .traits: [UIFontDescriptor.TraitKey.weight: weight]
        ])
    }
}

extension UIFont {
    static func inter(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        return UIFont(descriptor: .inter(weight: weight), size: size)
    }
}
