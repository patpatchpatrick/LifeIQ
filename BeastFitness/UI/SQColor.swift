//
//  SQColor.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 8/4/25.
//

import Foundation
import SwiftUI

final class SQColorManager {
    static let shared = SQColorManager()
    let isDarkMode: Bool

    init() {
        isDarkMode = UIViewController().traitCollection.userInterfaceStyle == .dark
    }
}

indirect enum SQColor {
    static var isDarkMode = true

    // MARK: - Text
    case textPrimary
    case textSecondary
    case textTertiary
    case textDisabled
    case textWarning
    case textError
    case textInfo

    // MARK: - Backgrounds
    case background
    case backgroundSheet
    case backgroundSecondary
    case backgroundSecondaryLight
    case backgroundTertiaryDark
    case backgroundTertiaryLight

    // MARK: - Dashboard Atmosphere
    case dashboardGradientStart
    case dashboardGradientMid
    case dashboardGradientEnd
    case dashboardGlowBlue
    case dashboardGlowMint

    // MARK: - Glass Surfaces
    case glassCardTint
    case glassPopoverTint
    case glassStroke
    case glassStrokeStrong

    // MARK: - Alert Backgrounds
    case backgroundWarning
    case backgroundError
    case backgroundSuccess
    case backgroundInfo

    // MARK: - System
    case divider(Double = 1)
    case border(Double = 1)
    case accent(Double = 1)
    case accentSecondary(Double = 1)
    case defaultAccent
    
    // MARK: - Neutral accent colors
    // Stat / accent neutrals for inline metrics
    case accentNeutral1   // e.g. time
    case accentNeutral2   // e.g. calories
    case accentNeutral3   // e.g. output
    case accentNeutral4   // e.g. heart rate

    // MARK: - Utility & Metrics
    case colorDefaultBlue
    case colorErrorRed
    case colorFadedRed
    case colorFadedGreen
    case colorNeonGreen   // vibrant sparkline green
    case colorNeonRed     // vibrant sparkline red
    case colorGreenDarkBorder

    /// Interpolates between red → base color → green on a **-1 to +1 scale**:
    ///
    /// - `+1.0` → full green
    /// - ` 0.0` → `base` color (neutral, defaults to `.textPrimary`)
    /// - `-1.0` → full red
    ///
    /// Values between these points are linearly interpolated.
    ///
    /// **Example — rank-based coloring:**
    /// ```swift
    /// // rank 1 = best (green), last rank = worst (red)
    /// let percent = 1.0 - 2.0 * Double(rank) / Double(total)
    /// SQColor.colorGreenRed(percent: percent)
    /// ```
    ///
    /// **Example — change percentage (amplified for small values):**
    /// ```swift
    /// // percent is e.g. +0.52 (52% up) or -0.30 (30% down)
    /// SQColor.colorGreenRed(percent: percent * 4) // multiply to reach full green/red sooner
    /// ```
    case colorGreenRed(percent: Double, base: SQColor = .textPrimary)

    /// Interpolates from `base` toward green on a **0 to 1 scale**:
    /// - `0.0` → `base` color (neutral)
    /// - `1.0` → full green
    case colorGreenPct(percent: Double, base: SQColor = .textPrimary)

    /// Interpolates from `base` toward red on a **0 to 1 scale**:
    /// - `0.0` → `base` color (neutral)
    /// - `1.0` → full red
    case colorRedPct(percent: Double, base: SQColor = .textPrimary)
    // MARK: - Raw
    case hex(String)

    var uiColor: UIColor {
        switch self {

        // MARK: - Text
        case .textPrimary:
            return Self.isDarkMode ? UIColor(hexString: "#E0E0E0")! : .black // light gray for dark mode
        case .textSecondary:
            return Self.isDarkMode ? UIColor(hexString: "#B0B0B0")! : UIColor(hexString: "#6F6F6F")! // medium gray
        case .textTertiary:
            return Self.isDarkMode ? UIColor(hexString: "#7F7F7F")! : UIColor(hexString: "#A0A0A0")! // slightly lighter gray
        case .textDisabled:
            return Self.isDarkMode ? UIColor(hexString: "#4D4D4D")! : UIColor(hexString: "#B8B8B8")! // dimmed text for dark mode
        case .textWarning:
            return UIColor(red: 255/255, green: 155/255, blue: 50/255, alpha: 1) // soft yellow warning color
        case .textError:
            return UIColor(red: 220/255, green: 70/255, blue: 70/255, alpha: 1) // error color (dark red)
        case .textInfo:
            return UIColor(red: 60/255, green: 115/255, blue: 175/255, alpha: 1) // info blue

        // MARK: - Backgrounds
            
        case .background:
            return Self.isDarkMode ? UIColor(hexString: "#000000")! : .white

        case .backgroundSheet:
            return Self.isDarkMode
                ? UIColor(hexString: "#0F0F0F")!
                : UIColor(hexString: "#F8F8F8")!

        case .backgroundSecondary:
            return Self.isDarkMode
                ? UIColor(hexString: "#171717")!
                : UIColor(red: 245/255, green: 245/255, blue: 245/255, alpha: 1)

        case .backgroundSecondaryLight:
            return Self.isDarkMode
                ? UIColor(hexString: "#1F1F1F")!
                : UIColor(hexString: "#FAFAFA")!

        case .backgroundTertiaryDark:
            return Self.isDarkMode
                ? UIColor(hexString: "#0D0D0D")!
                : UIColor(hexString: "#EDEDED")!

        case .backgroundTertiaryLight:
            return Self.isDarkMode
                ? UIColor(hexString: "#2E2E2E")!
                : UIColor(hexString: "#FAFAFA")!

        // MARK: - Dashboard Atmosphere
        case .dashboardGradientStart:
            return Self.isDarkMode
                ? UIColor(hexString: "#07141A")!
                : UIColor(hexString: "#F7FBFC")!
        case .dashboardGradientMid:
            return Self.isDarkMode
                ? UIColor(hexString: "#0C2630")!
                : UIColor(hexString: "#EAF6F2")!
        case .dashboardGradientEnd:
            return Self.isDarkMode
                ? UIColor(hexString: "#15424A")!
                : UIColor(hexString: "#E7F0FA")!
        case .dashboardGlowBlue:
            return Self.isDarkMode
                ? UIColor(hexString: "#6FD7FF")!
                : UIColor(hexString: "#B5E8FF")!
        case .dashboardGlowMint:
            return Self.isDarkMode
                ? UIColor(hexString: "#8BF0CB")!
                : UIColor(hexString: "#C9F7E5")!

        // MARK: - Glass Surfaces
        case .glassCardTint:
            return Self.isDarkMode
                ? UIColor.white.withAlphaComponent(0.10)
                : UIColor.white.withAlphaComponent(0.58)
        case .glassPopoverTint:
            return Self.isDarkMode
                ? UIColor.white.withAlphaComponent(0.16)
                : UIColor.white.withAlphaComponent(0.72)
        case .glassStroke:
            return Self.isDarkMode
                ? UIColor.white.withAlphaComponent(0.14)
                : UIColor.white.withAlphaComponent(0.52)
        case .glassStrokeStrong:
            return Self.isDarkMode
                ? UIColor.white.withAlphaComponent(0.24)
                : UIColor.white.withAlphaComponent(0.72)

            

        // MARK: - Alert Backgrounds
        case .backgroundWarning:
            return UIColor(red: 255/255, green: 244/255, blue: 150/255, alpha: 1) // soft yellow for warning
        case .backgroundError:
            return UIColor(red: 255/255, green: 225/255, blue: 215/255, alpha: 1) // light red for error background
        case .backgroundSuccess:
            return UIColor(hexString: "#2D7A7D")! // greenish blue for success background
        case .backgroundInfo:
            return UIColor(red: 227/255, green: 242/255, blue: 253/255, alpha: 1) // soft light blue for info background

        // MARK: - System
        case .divider(let opacity):
            return UIColor(hexString: "#384150")!.withAlphaComponent(opacity)
        case .border(let opacity):
            return UIColor(hexString: "#384150")!.withAlphaComponent(opacity)
        case .accent(let alpha):
            return SQColor.defaultAccent.uiColor.withAlphaComponent(alpha)
        case .accentSecondary(let alpha):
            return UIColor(hexString: "#8B5CF6")!.withAlphaComponent(alpha)
        case .defaultAccent:
            return UIColor(hexString: "#4F5DFF")! // default blue accent color
            
        // MARK: - Neutral accent colors
        case .accentNeutral1:
            // Muted blue
            return Self.isDarkMode
                ? UIColor(hexString: "#7FAAFF")!   // soft blue for dark
                : UIColor(hexString: "#2F5EA8")!   // deeper blue for light

        case .accentNeutral2:
            // Muted orange
            return Self.isDarkMode
                ? UIColor(hexString: "#FFB878")!   // warm soft orange
                : UIColor(hexString: "#C26A28")!   // richer orange in light

        case .accentNeutral3:
            // Muted yellow / gold
            return Self.isDarkMode
                ? UIColor(hexString: "#FFE38A")!   // soft golden yellow
                : UIColor(hexString: "#C49526")!   // darker golden in light

        case .accentNeutral4:
            // Muted red
            return Self.isDarkMode
                ? UIColor(hexString: "#ff8093")!   // soft red
                : UIColor(hexString: "#ff8093")!

        // MARK: - Metrics & Color Utilities
        case .colorDefaultBlue:
            return UIColor(red: 100/255, green: 140/255, blue: 255/255, alpha: 1) // lighter blue for defaults
        case .colorErrorRed:
            return UIColor(hexString: "#D32F2F")!
        case .colorFadedRed:
            return Self.defaultRed(of: 0.35, base: SQColor.textPrimary.uiColor) // softer red
        case .colorFadedGreen:
            return Self.defaultGreen(of: 0.35, base: SQColor.textPrimary.uiColor) // softer green
        case .colorNeonGreen:
            return UIColor(hexString: "#0DFF6E")! // electric green for sparklines
        case .colorNeonRed:
            return UIColor(hexString: "#FF2D55")! // vivid red for sparklines
        case .colorGreenDarkBorder:
            return UIColor(hexString: "#0C500B")!
        case .colorGreenRed(let percent, let base):
            return Self.defaultGreenRed(of: percent, base: base.uiColor)
        case .colorGreenPct(let percent, let base):
            return Self.defaultGreen(of: percent, base: base.uiColor)
        case .colorRedPct(let percent, let base):
            return Self.defaultRed(of: percent, base: base.uiColor)

        // MARK: - Raw
        case .hex(let hexString):
            return UIColor(hexString: hexString)!
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
    
    fileprivate static let baseColor = !isDarkMode ? RGB(r: 66, g: 66, b: 66) : RGB(r: 225, g: 225, b: 225)
    fileprivate static let baseGreen = RGB(r: 0, g: 255, b: 128)
    fileprivate static let baseRed = RGB(r: 218, g: 1, b: 45)
    
    /// Linear interpolate between two UIColors
    fileprivate static func lerpColor(from: UIColor, to: UIColor, percent: Double) -> UIColor {
        var fr: CGFloat = 0, fg: CGFloat = 0, fb: CGFloat = 0, fa: CGFloat = 0
        var tr: CGFloat = 0, tg: CGFloat = 0, tb: CGFloat = 0, ta: CGFloat = 0
        from.getRed(&fr, green: &fg, blue: &fb, alpha: &fa)
        to.getRed(&tr, green: &tg, blue: &tb, alpha: &ta)

        let r = fr + (tr - fr) * CGFloat(percent)
        let g = fg + (tg - fg) * CGFloat(percent)
        let b = fb + (tb - fb) * CGFloat(percent)
        let a = fa + (ta - fa) * CGFloat(percent)

        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
    
    fileprivate static let targetGreen = UIColor(red: 0/255, green: 255/255, blue: 128/255, alpha: 1)
    fileprivate static let targetRed = UIColor(red: 218/255, green: 1/255, blue: 45/255, alpha: 1)

    fileprivate static func defaultGreen(of percent: Double, base: UIColor) -> UIColor {
        lerpColor(from: base, to: targetGreen, percent: percent.clamped01)
    }

    fileprivate static func defaultRed(of percent: Double, base: UIColor) -> UIColor {
        lerpColor(from: base, to: targetRed, percent: percent.clamped01)
    }

    fileprivate static func defaultGreenRed(of percent: Double, base: UIColor) -> UIColor {
        if percent >= 0 {
            return defaultGreen(of: percent, base: base)
        } else {
            return defaultRed(of: -percent, base: base)
        }
    }
}

fileprivate extension Double {
    var clamped01: Double {
        max(0.0, min(1.0, self))
    }
}

fileprivate extension UIColor {
    convenience init?(hexString: String) {
        let r, g, b, a: CGFloat

        if hexString.hasPrefix("#") {
            let start = hexString.index(hexString.startIndex, offsetBy: 1)
            let hexColor = String(hexString[start...])

            if hexColor.count == 6 {
                let scanner = Scanner(string: hexColor)
                var hexNumber: UInt64 = 0

                if scanner.scanHexInt64(&hexNumber) {
                    r = CGFloat((hexNumber & 0xff0000) >> 16) / 255
                    g = CGFloat((hexNumber & 0x00ff00) >> 8) / 255
                    b = CGFloat(hexNumber & 0x0000ff) / 255
                    a = 1

                    self.init(red: r, green: g, blue: b, alpha: a)
                    return
                }
            }
        }

        return nil
    }
}
