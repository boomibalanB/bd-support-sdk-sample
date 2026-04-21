import UIKit

enum DeviceConfig {
    static var isIPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }
    
    static var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    static var isPortrait: Bool {
        UIScreen.main.bounds.height >= UIScreen.main.bounds.width
    }
    
    static var languageCode: String = "en-US"
}

struct BuildConfig {
    static var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}

