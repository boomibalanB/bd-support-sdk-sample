import SwiftUI

extension UIColor {
    static func dynamicColor(light: UIColor, dark: UIColor) -> UIColor {
        return UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? dark : light
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    static func updateColors(from palette: [String: String]?) {
        guard let palette = palette else { return }
        
        func set(_ key: String, assign: (Color) -> Void) {
            if let hex = palette[key] {
                assign(Color(hex: hex))
            }
        }
        
        set("--brand-25")  { brand25  = $0 }
        set("--brand-50")  { brand50  = $0 }
        set("--brand-100") { brand100 = $0 }
        set("--brand-200") { fallbackColor in
            let hex = AppConstant.buttonColor
            if !hex.isEmpty,
               let uiColor = UIColor.fromHex(hex) {
                brand200 = Color(uiColor).opacity(0.2)
            } else {
                brand200 = fallbackColor
            }
        }

        set("--brand-300") { brand300 = $0 }
        set("--brand-400") { brand400 = $0 }
        set("--brand-500") { brand500 = $0 }
        set("--brand-600") { fallbackColor in
            if let paletteHex = palette["--brand-600"], !paletteHex.isEmpty {
                
                brand600 = Color(hex: paletteHex)   // ✅ Color
                AppConstant.appBarHex = paletteHex  // ✅ Store hex string
                
            } else {
                
                brand600 = fallbackColor            // ✅ fallback Color
                AppConstant.appBarHex = ""          // or keep previous value
                
            }
        }
        set("--brand-700") { brand700 = $0 }
        set("--brand-800") { brand800 = $0 }
        set("--brand-900") { brand900 = $0 }
        set("--brand-950") { brand950 = $0 }
        
        set("--actioncolor-25")  { actionColor25  = $0 }
        set("--actioncolor-50")  { actionColor50  = $0 }
        set("--actioncolor-100") { actionColor100 = $0 }
        set("--actioncolor-200") { actionColor200 = $0 }
        set("--actioncolor-300") { actionColor300 = $0 }
        set("--actioncolor-400") { actionColor400 = $0 }
        set("--actioncolor-500") { actionColor500 = $0 }
        set("--actioncolor-600") { actionColor600 = $0 }
        set("--actioncolor-700") { actionColor700 = $0 }
        set("--actioncolor-800") { actionColor800 = $0 }
        set("--actioncolor-900") { actionColor900 = $0 }
        set("--actioncolor-950") { actionColor950 = $0 }
        
        // Text colors
        set("--color-bc-text-primary-on-brand") { fallbackColor in
            let hex = AppConstant.chatBackgroundColor
            if !hex.isEmpty,
               let uiColor = UIColor.fromHex(hex) {
                textPrimaryOnBrand = Color(uiColor.commonAutoTextColor)
            } else {
                textPrimaryOnBrand = fallbackColor
            }
        }

        set("--color-bc-text-primary-on-appbar") { fallbackColor in
            let hex = AppConstant.appBarColor
            if !hex.isEmpty,
               let uiColor = UIColor.fromHex(hex) {
                appBarBackgroundSource = Color(uiColor)
            } else {
                appBarBackgroundSource = fallbackColor
            }
        }

        set("--color-bc-actioncolor-primary-fg") { fallbackColor in
            let hex = AppConstant.buttonColor
            if !hex.isEmpty,
               let uiColor = UIColor.fromHex(hex) {
                actionColorPrimaryFg = Color(uiColor.commonAutoTextColor)
            } else {
                actionColorPrimaryFg = fallbackColor
            }
        }

        set("--stickybuttoncolor-600") { fallbackColor in
            let hex = AppConstant.stickyButtonColor
            if !hex.isEmpty,
               let color = Color.fromHex(hex) {
                stickyButtonColor = color
            } else {
                stickyButtonColor = fallbackColor
            }
        }

        set("--color-bc-stickybuttoncolor-primary-fg") { fallbackColor in
            let hex = AppConstant.stickyButtonColor
            if !hex.isEmpty,
               let uiColor = UIColor.fromHex(hex) {
                stickyButtonTextColor = Color(uiColor.autoTextColor())
            } else {
                stickyButtonTextColor = fallbackColor
            }
        }

    }
    static var appBarBackgroundSource: Color?

    // Brand colors
    static var brand25 = Color(UIColor.dynamicColor(
        light: UIColor(red: 245/255, green: 248/255, blue: 255/255, alpha: 1.0),
        dark: UIColor(red: 245/255, green: 248/255, blue: 255/255, alpha: 1.0)
    ))
    static var brand50 = Color(UIColor.dynamicColor(
        light: UIColor(red: 239/255, green: 244/255, blue: 255/255, alpha: 1.0),
        dark: UIColor(red: 239/255, green: 244/255, blue: 255/255, alpha: 1.0)
    ))
    static var brand100 = Color(UIColor.dynamicColor(
        light: UIColor(red: 209/255, green: 224/255, blue: 255/255, alpha: 1.0),
        dark: UIColor(red: 209/255, green: 224/255, blue: 255/255, alpha: 1.0)
    ))
    static var brand200 = Color(UIColor.dynamicColor(
        light: UIColor(red: 178/255, green: 204/255, blue: 255/255, alpha: 1.0),
        dark: UIColor(red: 178/255, green: 204/255, blue: 255/255, alpha: 1.0)
    ))
    static var brand300 = Color(UIColor.dynamicColor(
        light: UIColor(red: 132/255, green: 173/255, blue: 255/255, alpha: 1.0),
        dark: UIColor(red: 132/255, green: 173/255, blue: 255/255, alpha: 1.0)
    ))
    static var brand400 = Color(UIColor.dynamicColor(
        light: UIColor(red: 82/255, green: 139/255, blue: 255/255, alpha: 1.0),
        dark: UIColor(red: 82/255, green: 139/255, blue: 255/255, alpha: 1.0)
    ))
    static var brand500 = Color(UIColor.dynamicColor(
        light: UIColor(red: 41/255, green: 112/255, blue: 255/255, alpha: 1.0),
        dark: UIColor(red: 41/255, green: 112/255, blue: 255/255, alpha: 1.0)
    ))
    static var brand600 = Color(UIColor.dynamicColor(
        light: UIColor(red: 21/255, green: 94/255, blue: 239/255, alpha: 1.0),
        dark: UIColor(red: 21/255, green: 94/255, blue: 239/255, alpha: 1.0)
    ))
    static var brand700 = Color(UIColor.dynamicColor(
        light: UIColor(red: 0/255, green: 78/255, blue: 235/255, alpha: 1.0),
        dark: UIColor(red: 0/255, green: 78/255, blue: 235/255, alpha: 1.0)
    ))
    static var brand800 = Color(UIColor.dynamicColor(
        light: UIColor(red: 0/255, green: 64/255, blue: 193/255, alpha: 1.0),
        dark: UIColor(red: 0/255, green: 64/255, blue: 193/255, alpha: 1.0)
    ))
    static var brand900 = Color(UIColor.dynamicColor(
        light: UIColor(red: 0/255, green: 53/255, blue: 158/255, alpha: 1.0),
        dark: UIColor(red: 0/255, green: 53/255, blue: 158/255, alpha: 1.0)
    ))
    static var brand950 = Color(UIColor.dynamicColor(
        light: UIColor(red: 0/255, green: 34/255, blue: 102/255, alpha: 1.0),
        dark: UIColor(red: 0/255, green: 34/255, blue: 102/255, alpha: 1.0)
    ))
    
    // Action colors
    static var actionColor25 = Color(UIColor.dynamicColor(
        light: UIColor(red: 245/255, green: 248/255, blue: 255/255, alpha: 1.0),
        dark: UIColor(red: 245/255, green: 248/255, blue: 255/255, alpha: 1.0)
    ))
    static var actionColor50 = Color(UIColor.dynamicColor(
        light: UIColor(red: 239/255, green: 244/255, blue: 255/255, alpha: 1.0),
        dark: UIColor(red: 239/255, green: 244/255, blue: 255/255, alpha: 1.0)
    ))
    static var actionColor100 = Color(UIColor.dynamicColor(
        light: UIColor(red: 209/255, green: 224/255, blue: 255/255, alpha: 1.0),
        dark: UIColor(red: 209/255, green: 224/255, blue: 255/255, alpha: 1.0)
    ))
    static var actionColor200 = Color(UIColor.dynamicColor(
        light: UIColor(red: 178/255, green: 204/255, blue: 255/255, alpha: 1.0),
        dark: UIColor(red: 178/255, green: 204/255, blue: 255/255, alpha: 1.0)
    ))
    static var actionColor300 = Color(UIColor.dynamicColor(
        light: UIColor(red: 132/255, green: 173/255, blue: 255/255, alpha: 1.0),
        dark: UIColor(red: 132/255, green: 173/255, blue: 255/255, alpha: 1.0)
    ))
    static var actionColor400 = Color(UIColor.dynamicColor(
        light: UIColor(red: 82/255, green: 139/255, blue: 255/255, alpha: 1.0),
        dark: UIColor(red: 82/255, green: 139/255, blue: 255/255, alpha: 1.0)
    ))
    static var actionColor500 = Color(UIColor.dynamicColor(
        light: UIColor(red: 41/255, green: 112/255, blue: 255/255, alpha: 1.0),
        dark: UIColor(red: 41/255, green: 112/255, blue: 255/255, alpha: 1.0)
    ))
    
    static var actionColor600 = Color(UIColor.dynamicColor(
        light: UIColor(red: 21/255, green: 94/255, blue: 239/255, alpha: 1.0),
        dark: UIColor(red: 21/255, green: 94/255, blue: 239/255, alpha: 1.0)
    ))
    
    static var actionColor700 = Color(UIColor.dynamicColor(
        light: UIColor(red: 0/255, green: 78/255, blue: 235/255, alpha: 1.0),
        dark: UIColor(red: 0/255, green: 78/255, blue: 235/255, alpha: 1.0)
    ))
    
    static var actionColor800 = Color(UIColor.dynamicColor(
        light: UIColor(red: 0/255, green: 64/255, blue: 193/255, alpha: 1.0),
        dark: UIColor(red: 0/255, green: 64/255, blue: 193/255, alpha: 1.0)
    ))
    
    static var actionColor900 = Color(UIColor.dynamicColor(
        light: UIColor(red: 0/255, green: 53/255, blue: 158/255, alpha: 1.0),
        dark: UIColor(red: 0/255, green: 53/255, blue: 158/255, alpha: 1.0)
    ))
    
    static var actionColor950 = Color(UIColor.dynamicColor(
        light: UIColor(red: 0/255, green: 34/255, blue: 102/255, alpha: 1.0),
        dark: UIColor(red: 0/255, green: 34/255, blue: 102/255, alpha: 1.0)
    ))
    static var actionColorPrimaryBg: Color {
        let hex = AppConstant.buttonColor
        if !hex.isEmpty, let color = Color.fromHex(hex) {
            return color
        }
        return actionColor600
    }
    
    static var boldDeskLogoColor : Color {
        let hex = "#e62e05"
        if !hex.isEmpty, let color = Color.fromHex(hex) {
            return color
        }
        return actionColor600
    }

    static var actionColorPrimaryBorder: Color {
        let hex = AppConstant.buttonColor
        if !hex.isEmpty, let color = Color.fromHex(hex) {
            return color
        }
        return actionColor600
    }

    static var appBarColor: Color {
        let hex = AppConstant.appBarColor
        if !hex.isEmpty, let color = Color.fromHex(hex) {
            return color
        }
        return brand600
    }

    static var bgBrandSolid: Color {
        let hex = AppConstant.chatBackgroundColor
        if !hex.isEmpty, let color = Color.fromHex(hex) {
            return color
        }
        return brand600
    }

    // Brand text color
    static var textPrimaryOnBrand = Color(UIColor.dynamicColor(
        light: UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 1.0),
        dark: UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 1.0)
    ))
    
    static var textPrimaryAppBarColor: Color {
        let bg = appBarBackgroundSource ?? appBarColor
        let ui = UIColor(bg)
        return Color(ui.autoTextColorSafe())
    }
    
    static var textBrandSecondary: Color { brand700 }
    
    static let fgWhite = Color(UIColor.dynamicColor(
        light: UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 1.0),
        dark: UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 1.0)
    ))
    
    static let fgSuccessSecondary = Color(UIColor.dynamicColor(
        light: UIColor(red: 23/255, green: 178/255, blue: 106/255, alpha: 1.0),
        dark: UIColor(red: 23/255, green: 178/255, blue: 106/255, alpha: 1.0)
    ))
    
    static let textSecondary = Color(UIColor.dynamicColor(
        light: UIColor(red: 52/255.0, green: 64/255.0, blue: 84/255.0, alpha: 1.0),
        dark: UIColor(red: 206/255.0, green: 207/255.0, blue: 210/255.0, alpha: 1.0)
    ))
    
    static let textTertiary  = Color(UIColor.dynamicColor(
        light: UIColor(red: 71/255.0, green: 84/255.0, blue: 103/255.0, alpha: 1.0),
        dark: UIColor(red: 148/255.0, green: 150/255.0, blue: 156/255.0, alpha: 1.0)
    ))
    
    static let textQuarterary = Color(UIColor.dynamicColor(
        light: UIColor(red: 102/255.0, green: 112/255.0, blue: 133/255.0, alpha: 1.0),
        dark: UIColor(red: 148/255.0, green: 150/255.0, blue: 156/255.0, alpha: 1.0)
    ))
    
    static let bgPrimary = Color(UIColor.dynamicColor(
        light: UIColor(red: 255/255.0, green: 255/255.0, blue: 255/255.0, alpha: 1.0),
        dark: UIColor(red: 12/255.0, green: 17/255.0, blue: 29/255.0, alpha: 1.0)
    ))
    
    static let bgSecondary = Color(UIColor.dynamicColor(
        light: UIColor(red: 249/255.0, green: 250/255.0, blue: 251/255.0, alpha: 1.0),
        dark: UIColor(red: 22/255.0, green: 27/255.0, blue: 38/255.0, alpha: 1.0)
    ))
    
    static let bgTertiary = Color(UIColor.dynamicColor(
        light: UIColor(red: 242/255, green: 244/255, blue: 247/255, alpha: 1.0),
        dark: UIColor(red: 31/255, green: 36/255, blue: 47/255, alpha: 1.0)
    ))
    
    static let borderSecondary = Color(UIColor.dynamicColor(
        light: UIColor(red: 234/255, green: 236/255, blue: 240/255, alpha: 1.0),
        dark: UIColor(red: 31/255, green: 36/255, blue: 47/255, alpha: 1.0)
    ))
    
    static let borderTertiary = Color(UIColor.dynamicColor(
        light: UIColor(red: 242/255, green: 244/255, blue: 247/255, alpha: 1.0),
        dark: UIColor(red: 31/255, green: 36/255, blue: 47/255, alpha: 1.0)
    ))
    
    static var utilityBrand100: Color { brand100 }
    
    static let textErrorPrimary = Color(UIColor.dynamicColor(
        light: UIColor(red: 217/255, green: 45/255, blue: 32/255, alpha: 1.0),
        dark: UIColor(red: 249/255, green: 112/255, blue: 102/255, alpha: 1.0)
    ))
    
    static let utilitySuccess50 = Color(UIColor.dynamicColor(
        light: UIColor(red: 236/255, green: 253/255, blue: 243/255, alpha: 1.0),
        dark: UIColor(red: 4/255, green: 51/255, blue: 32/255, alpha: 1.0)
    ))
    
    static let bgWarningPrimary = Color(UIColor.dynamicColor(
        light: UIColor(red: 255/255, green: 250/255, blue: 235/255, alpha: 1.0),
        dark: UIColor(red: 247/255, green: 144/255, blue: 9/255, alpha: 1.0)
    ))
    
    static let utilityError50 = Color(UIColor.dynamicColor(
        light: UIColor(red: 254/255, green: 243/255, blue: 242/255, alpha: 1.0),
        dark: UIColor(red: 85/255, green: 22/255, blue: 12/255, alpha: 1.0)
    ))
    
    static let fgErrorPrimary = Color(UIColor.dynamicColor(
        light: UIColor(red: 217/255, green: 45/255, blue: 32/255, alpha: 1.0),
        dark: UIColor(red: 240/255, green: 68/255, blue: 56/255, alpha: 1.0)
    ))
    
    static let fgPrimarySuccess = Color(UIColor.dynamicColor(
        light: UIColor(red: 7/255, green: 148/255, blue: 85/255, alpha: 1.0),
        dark: UIColor(red: 23/255, green: 178/255, blue: 106/255, alpha: 1.0)
    ))
    
    static let textPlaceholder = Color(UIColor.dynamicColor(
        light: UIColor(red: 102/255, green: 112/255, blue: 133/255, alpha: 1.0),
        dark: UIColor(red: 133/255, green: 136/255, blue: 142/255, alpha: 1.0)
    ))
    
    static let utilityGray800 = Color(UIColor.dynamicColor(
        light: UIColor(red: 24/255, green: 34/255, blue: 48/255, alpha: 1.0),
        dark: UIColor(red: 24/255, green: 34/255, blue: 48/255, alpha: 1.0)
    ))
    
    static var fgBrandPrimary: Color { brand600 }
    
    
    // Action text color
    static var actionColorPrimaryFg = Color(UIColor.dynamicColor(
        light: UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 1.0),
        dark: UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 1.0)
    ))
    
    static let transparentBlack = Color(UIColor.dynamicColor(
        light: UIColor(red: 0/255, green: 0/255, blue: 0/255, alpha: 0.1),
        dark: UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 0.1)
    ))
    
    static let borderPrimary = Color(UIColor.dynamicColor(
        light: UIColor(red: 208/255, green: 213/255, blue: 221/255, alpha: 1.0),
        dark: UIColor(red: 51/255, green: 55/255, blue: 65/255, alpha: 1.0)
    ))
    
    static let borderError = Color(UIColor.dynamicColor(
        light: UIColor(red: 253/255.0, green: 162/255.0, blue: 155/255.0, alpha: 1.0),
        dark: UIColor(red: 249/255.0, green: 112/255.0, blue: 102/255.0, alpha: 1.0)
    ))
    
    static let fgSenary = Color(UIColor.dynamicColor(
        light: UIColor(red: 208/255.0, green: 213/255.0, blue: 221/255.0, alpha: 1.0),
        dark: UIColor(red: 97/255.0, green: 100/255.0, blue: 108/255.0, alpha: 1.0)
    ))
    
    static let fgQuarterary = Color(UIColor.dynamicColor(
        light: UIColor(red: 102/255.0, green: 112/255.0, blue: 133/255.0, alpha: 1.0),
        dark: UIColor(red: 148/255.0, green: 150/255.0, blue: 156/255.0, alpha: 1.0)
    ))
    
    static let fgQuinary = Color(UIColor.dynamicColor(
        light: UIColor(red: 152/255, green: 161/255, blue: 178/255, alpha: 1.0), // #98A1B2
        dark: UIColor(red: 133/255, green: 136/255, blue: 142/255, alpha: 1.0)   // #85888E
    ))
    
    static let fgTertiary = Color(UIColor.dynamicColor(
        light: UIColor(red: 71/255, green: 84/255, blue: 103/255, alpha: 1.0),
        dark: UIColor(red: 71/255, green: 84/255, blue: 103/255, alpha: 1.0)
    ))
    
    static let fgSecondary = Color(UIColor.dynamicColor(
        light: UIColor(red: 52/255, green: 64/255, blue: 84/255, alpha: 1.0),   // #344054
        dark: UIColor(red: 206/255, green: 207/255, blue: 210/255, alpha: 1.0)  // #CECFD2
    ))
    
    static let fgDisabled = Color(UIColor.dynamicColor(
        light: UIColor(red: 152/255.0, green: 162/255.0, blue: 179/255.0, alpha: 1.0), // #98A2B3
        dark: UIColor(red: 133/255.0, green: 136/255.0, blue: 142/255.0, alpha: 1.0)   // #85888E
    ))
    
    static let bcAlphaWhite30 = Color(UIColor.dynamicColor(
        light: UIColor(red: 255/255.0, green: 255/255.0, blue: 255/255.0, alpha: 0.3),
        dark: UIColor(red: 12/255.0, green: 17/255.0, blue: 29/255.0, alpha: 0.3)
    ))
    
    static let fgAlphaBlack60 = Color(UIColor.dynamicColor(
        light: UIColor(red: 0/255.0, green: 0/255.0, blue: 0/255.0, alpha: 0.6),
        dark: UIColor(red: 0/255.0, green: 0/255.0, blue: 0/255.0, alpha: 0.6)
    ))
    
    static let textPrimaryColor = Color(UIColor.dynamicColor(
        light: UIColor(red: 16/255.0, green: 24/255.0, blue: 40/255.0, alpha: 1.0),
        dark: UIColor(red: 16/255.0, green: 24/255.0, blue: 40/255.0, alpha: 1.0)
    ))
    
        static var stickyButtonColor = Color(UIColor.dynamicColor(
            light: UIColor(red: 247/255.0, green: 187/255.0, blue: 204/255.0, alpha: 1.0), // #F7BBCC
            dark: UIColor(red: 247/255.0, green: 187/255.0, blue: 204/255.0, alpha: 1.0)
        ))
        
        static var stickyButtonTextColor = Color(UIColor.dynamicColor(
            light: UIColor(red: 114/255.0, green: 14/255.0, blue: 42/255.0, alpha: 1.0), // #720E2A
            dark: UIColor(red: 114/255.0, green: 14/255.0, blue: 42/255.0, alpha: 1.0)
        ))
    
    static let tooltipBackground = Color(UIColor.dynamicColor(
        light: UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 1.0),
        dark: UIColor(red: 12/255, green: 17/255, blue: 29/255, alpha: 1.0)
    ))
    
    static let tooltipText = Color(UIColor.dynamicColor(
        light: UIColor(red: 16/255, green: 24/255, blue: 40/255, alpha: 1.0),
        dark: UIColor(red: 245/255, green: 245/255, blue: 246/255, alpha: 1.0)
    ))
}

extension UIColor {
    static func fromHex(_ hex: String) -> UIColor? {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexString.hasPrefix("#") { hexString.removeFirst() }

        guard hexString.count == 6,
            let rgbValue = UInt64(hexString, radix: 16)
        else {
            return nil
        }

        let red = CGFloat((rgbValue >> 16) & 0xFF) / 255.0
        let green = CGFloat((rgbValue >> 8) & 0xFF) / 255.0
        let blue = CGFloat(rgbValue & 0xFF) / 255.0

        return UIColor(red: red, green: green, blue: blue, alpha: 1.0)
    }
    
    var brightness: CGFloat {
            var r: CGFloat = 0
            var g: CGFloat = 0
            var b: CGFloat = 0
            var a: CGFloat = 0

            guard getRed(&r, green: &g, blue: &b, alpha: &a) else { return 0 }

            // WCAG luminance formula
            return (0.299 * r + 0.587 * g + 0.114 * b)
        }
    
    func darker(by percentage: CGFloat = 30) -> UIColor {
            var r: CGFloat = 0
            var g: CGFloat = 0
            var b: CGFloat = 0
            var a: CGFloat = 0

            guard getRed(&r, green: &g, blue: &b, alpha: &a) else {
                return self
            }

            return UIColor(
                red: max(r - percentage / 100, 0),
                green: max(g - percentage / 100, 0),
                blue: max(b - percentage / 100, 0),
                alpha: a
            )
        }
    
    func autoTextColor() -> UIColor {
            if brightness < 0.5 {
                // Dark background → white text
                return .white
            } else {
                // Light background → darker tone (NOT black)
                return darker(by: 45)
            }
        }
    
    func autoTextColorSafe() -> UIColor {
        brightness < 0.5
            ? .white
            : UIColor(white: 0.12, alpha: 1.0) // soft black
    }

    var isDarkColor: Bool {
            var r: CGFloat = 0
            var g: CGFloat = 0
            var b: CGFloat = 0
            var a: CGFloat = 0

            guard getRed(&r, green: &g, blue: &b, alpha: &a) else {
                return false
            }

            // WCAG luminance formula
            let brightness = (0.299 * r + 0.587 * g + 0.114 * b)
            return brightness < 0.5
        }
    
    var commonAutoTextColor: UIColor {
        return isDarkColor ? .white : UIColor(Color.textPrimaryColor)
        }
}

extension Color {
    static func fromHex(_ hex: String) -> Color? {
        guard let uiColor = UIColor.fromHex(hex) else { return nil }
        return Color(uiColor)
    }
}
