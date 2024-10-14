////
////  SQColor.swift
////  BeastFitness
////
////  Created by Patrick Doyle on 10/6/24.
////
//
import SwiftUI
//
//final class SQColorManager {
//    static let shared = SQColorManager()
//    let isDarkMode: Bool
//    
//    init() {
//        isDarkMode = UIViewController().traitCollection.userInterfaceStyle == .dark
//    }
//}
//
//enum SQColor {
//    static var isDarkMode = SQColorManager.shared.isDarkMode
//    case background
//    case alertBackground
//    case backgroundWithOpacity(Double)
//    case backgroundSecondary
//    case backgroundContainer
//    case backgroundContainerDarkMode
//    case backgroundContainer2
//    case white(Double = 1)
//    case accent(Double = 1)
//    case accentLight(Double = 1)
//    case buttonBackground
//    case primaryText
//    case primaryTextInverse
//    case primaryTextDarkMode
//    case secondaryText
//    case tertiaryText
//    case black(Double = 1)
//    case almostBlackBorders
//    case defaultBlue
//    case green
//    case fadedGreen
//    case fadedRed
//    case fadedOrange
//    case red
//    case pendingSelection
//    case statSelectionColor
//    case greenPct(Double)
//    case redPct(Double)
//    case greenRed(Double)
//    case clear
//    case feedSecondaryText
//    case feedCellBackground
//    case feedCellFadedBorder(Double = 1)
//    case fadedBlue(Double = 1)
//    case forumIsUserBg
//    case simBottomBorder
//    case simButtonBorder
//    case hex(String)
//    
//    var uiColor: UIColor {
//        switch self {
//        case .black(let alpha):
//            return .black.withAlphaComponent(alpha)
//        case .red:
//            return .init(red: 216/255, green: 73/255, blue: 75/255, alpha: 1)
//        case .fadedRed:
//            return Self.defaultRed(of: 0.45)
//        case .fadedGreen:
//            return Self.defaultGreen(of: 0.45)
//        case .fadedOrange:
//            return Self.defaultOrange(of: 0.45)
//        case .fadedBlue(let alpha):
//            return SQColor.defaultBlue.uiColor.withAlphaComponent(alpha)
//        case .green:
//            return .init(red: 0/255, green: 255/255, blue: 127/255, alpha: 1)
//        case .defaultBlue:
//            return .init(red: 88/255, green: 116/255, blue: 252/255, alpha: 1)
//        case .background:
//            return Self.isDarkMode ? .init(red: 23/255, green: 26/255, blue: 35/255, alpha: 1) : .white
//        case .backgroundWithOpacity(let alpha):
//            return SQColor.background.uiColor.withAlphaComponent(alpha)
//        case .backgroundSecondary:
//            return .init(red: 42/255, green: 46/255, blue: 62/255, alpha: 1)
//        case .alertBackground:
//            return Self.isDarkMode ? SQColor.background.uiColor : SQColor.backgroundContainer.uiColor
//        case .almostBlackBorders:
//            return .init(red: 30/255, green: 30/255, blue: 30/255, alpha: 1)
//        case .backgroundContainer:
//            return Self.isDarkMode ? SQColor.backgroundContainerDarkMode.uiColor : UIColor(hexString: "#EAE7E7")!
//        case .backgroundContainerDarkMode:
//            return .init(red: 50/255, green: 53/255, blue: 68/255, alpha: 1)
//        case .backgroundContainer2:
//            return Self.isDarkMode ? SQColor.backgroundContainer.uiColor : UIColor(red: 240/255, green: 240/255, blue: 240/255, alpha: 1)
//        case .accent(let alpha):
//            return SQColor.defaultBlue.uiColor.withAlphaComponent(alpha)
//        case .accentLight(let alpha):
//            return .init(red: 215/255, green: 109/255, blue: 252/255, alpha: alpha)
//        case .white(let percent):
//            return .white.withAlphaComponent(percent)
//        case .pendingSelection:
//            return .systemCyan
//        case .buttonBackground:
//            return UIColor(hexString: "#4E4E4E")!
//        case .primaryText:
//            return Self.isDarkMode ? SQColor.primaryTextDarkMode.uiColor : UIColor(hexString: "#020202")!
//        case .primaryTextDarkMode:
//            return .init(red: 242/255, green: 242/255, blue: 243/255, alpha: 1)
//        case .primaryTextInverse:
//            return !Self.isDarkMode ? .init(red: 242/255, green: 242/255, blue: 243/255, alpha: 1) : UIColor(hexString: "#020202")!
//        case .secondaryText:
//            return Self.isDarkMode ? .init(red: 138/255, green: 142/255, blue: 160/255, alpha: 1) : UIColor(hexString: "#807e7e")!
//        case .tertiaryText:
//            return Self.isDarkMode ? .init(red: 128/255, green: 128/255, blue: 130/255, alpha: 1) : UIColor(hexString: "#bab8b8")!
//        case .greenRed(let percent):
//            return Self.defaultGreenRed(of: percent)
//        case .greenPct(let percent):
//            return Self.defaultGreen(of: percent)
//        case .redPct(let percent):
//            return Self.defaultRed(of: percent)
//        case .statSelectionColor:
//            return .systemCyan
//        case .clear:
//            return .clear
//        case .feedSecondaryText:
//            return .init(red: 154/255, green: 169/255, blue: 175/255, alpha: 1)
//        case .feedCellBackground:
//            return .init(red: 24/255, green: 28/255, blue: 31/255, alpha: 1)
//        case .feedCellFadedBorder(let alpha):
//            return .init(red: 89/255, green: 76/255, blue: 76/255, alpha: alpha)
//        case .forumIsUserBg:
//            return .systemCyan.withAlphaComponent(0.12)
//        case .simBottomBorder:
//            return Self.isDarkMode ? .init(red: 52/255, green: 52/255, blue: 52/255, alpha: 1) : UIColor(hexString: "#f0f0f0")!
//        case .simButtonBorder:
//            return .init(red: 221/255, green: 132/255, blue: 252/255, alpha: 1)
//        case .hex(let hexString):
//            return UIColor(hexString: hexString)!
//        }
//    }
//    
//    var color: Color {
//        Color(uiColor)
//    }
//    
//    struct RGB {
//        let r: Double
//        let g: Double
//        let b: Double
//    }
//    
//    /// The base color when there is no tint (green or red).  Use white for dark mode and grey for light mode
//    static let baseColor = isDarkMode ? RGB(r: 66, g: 66, b: 66) : RGB(r: 225, g: 225, b: 225)
//    static let baseGreen = RGB(r: 0, g: 255, b: 128)
//    static let baseRed = RGB(r: 218, g: 1, b: 45)
//    
//    static func defaultGreen(of percent: Double) -> UIColor {
//        let r = baseColor.r - (baseColor.r - baseGreen.r) * percent
//        let g = baseColor.g - (baseColor.g - baseGreen.g) * percent
//        let b = baseColor.b - (baseColor.b - baseGreen.b) * percent
//        return .init(red: r/255, green: g/255, blue: b/255, alpha: 1)
//    }
//    static func defaultRed(of percent: Double) -> UIColor {
//        let r = baseColor.r - (baseColor.r - baseRed.r) * percent
//        let g = baseColor.g - (baseColor.g - baseRed.g) * percent
//        let b = baseColor.b - (baseColor.b - baseRed.b) * percent
//        return .init(red: r/255, green: g/255, blue: b/255, alpha: 1)
//    }
//    static func defaultOrange(of percent: Double) -> UIColor {
//        let r = 255.0 - (255 - 240) * percent
//        let g = 255.0 - (255 - 94) * percent
//        let b = 255.0 - (255 - 35) * percent
//        return .init(red: r/255, green: g/255, blue: b/255, alpha: 1)
//    }
//    
//    // Higher percentages return greener colors
//    // Lower percentages return redder colors
//    static func defaultGreenRed(of percent: Double) -> UIColor {
//        if percent >= 0.5 {
//            let greenPercent = (percent - 0.5) / 0.5
//            return defaultGreen(of: greenPercent)
//        } else {
//            let redPercent = 1.0 - percent * 2.0
//            return defaultRed(of: redPercent)
//        }
//    }
//}

final class SQColorManager {
    static let shared = SQColorManager()
    let isDarkMode: Bool

    init() {
        isDarkMode = UIViewController().traitCollection.userInterfaceStyle == .dark
    }
}

enum SQColor {
    case background
    case backgroundContainer
    case backgroundContainerDarkMode
    case text
    
    var isDarkMode: Bool {
        SQColorManager.shared.isDarkMode
    }
    
    var uiColor: UIColor {
        switch self {
        case .background:
                  return isDarkMode ? .init(red: 23/255, green: 26/255, blue: 35/255, alpha: 1) : .white
        case .text:
            return isDarkMode ? .white : .black
        case .backgroundContainer:
            return isDarkMode ? SQColor.backgroundContainerDarkMode.uiColor : UIColor(hexString: "#EAE7E7")!
        case .backgroundContainerDarkMode:
            return .init(red: 50/255, green: 53/255, blue: 68/255, alpha: 1)
        }
    }
    
        var color: Color {
            Color(uiColor)
        }
    
        struct RGB {
            let r: Double
            let g: Double
            let b: Double
        }
    
        /// The base color when there is no tint (green or red).  Use white for dark mode and grey for light mode
    static let baseColor = SQColorManager.shared.isDarkMode ? RGB(r: 66, g: 66, b: 66) : RGB(r: 225, g: 225, b: 225)
        static let baseGreen = RGB(r: 0, g: 255, b: 128)
        static let baseRed = RGB(r: 218, g: 1, b: 45)
    
        static func defaultGreen(of percent: Double) -> UIColor {
            let r = baseColor.r - (baseColor.r - baseGreen.r) * percent
            let g = baseColor.g - (baseColor.g - baseGreen.g) * percent
            let b = baseColor.b - (baseColor.b - baseGreen.b) * percent
            return .init(red: r/255, green: g/255, blue: b/255, alpha: 1)
        }
        static func defaultRed(of percent: Double) -> UIColor {
            let r = baseColor.r - (baseColor.r - baseRed.r) * percent
            let g = baseColor.g - (baseColor.g - baseRed.g) * percent
            let b = baseColor.b - (baseColor.b - baseRed.b) * percent
            return .init(red: r/255, green: g/255, blue: b/255, alpha: 1)
        }
        static func defaultOrange(of percent: Double) -> UIColor {
            let r = 255.0 - (255 - 240) * percent
            let g = 255.0 - (255 - 94) * percent
            let b = 255.0 - (255 - 35) * percent
            return .init(red: r/255, green: g/255, blue: b/255, alpha: 1)
        }
}
