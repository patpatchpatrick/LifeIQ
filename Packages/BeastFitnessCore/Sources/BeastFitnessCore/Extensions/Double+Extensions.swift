//
//  Double+Extensions.swift
//  BeastFitnessCore
//
//  Created by Patrick Doyle on 12/30/25.
//

import Foundation

// MARK: - Optional Double helpers

public extension Optional where Wrapped == Double {
    
    /// Short string for optional doubles. Returns "N/A" if nil.
    var sqShortString: String {
        guard let value = self else {
            return "N/A"
        }
        return value.sqShortString
    }
}

// MARK: - Core Double formatting

public extension Double {
    
    /// Core rounding to a given number of decimal places as a Double.
    /// e.g. 1.23456.sqRounded(to: 2) -> 1.23
    func sqRounded(to places: Int) -> Double {
        let factor = pow(10.0, Double(max(0, places)))
        return (self * factor).rounded() / factor
    }
    
    /// Returns a string rounded to the given number of decimal places.
    /// e.g. 1.23456.roundedString(decimals: 2) -> "1.23"
    func roundedString(decimals: Int = 0) -> String {
        let d = max(0, decimals)
        return String(format: "%.\(d)f", self)
    }
    
    /// Backwards-compatible wrapper using the older naming.
    func sqRoundedTo(places: Int) -> Double? {
        // Always succeeds, but kept as Optional for compatibility.
        sqRounded(to: places)
    }
    
    /// Backwards-compatible wrapper using the older naming.
    func sqStringRoundedTo(places: Int) -> String {
        roundedString(decimals: places)
    }
    
    /// Short string used throughout the app, rounded to 2 decimal places.
    /// e.g. 1.234 -> "1.23"
    var sqShortString: String {
        roundedString(decimals: 2)
    }
    
    /// Converts a decimal double (e.g. 0.53123) into a percentage string (e.g. "53.1%").
    /// - Parameters:
    ///   - decimals: Number of digits after the decimal point.
    ///   - showPositiveSign: If true, prefixes "+" for positive values.
    func toPercentageString(
        decimals: Int = 1,
        showPositiveSign: Bool = false
    ) -> String {
        let percentageValue = self * 100
        let prefix = showPositiveSign && percentageValue > 0 ? "+" : ""
        let valueString = percentageValue.roundedString(decimals: decimals)
        return "\(prefix)\(valueString)%"
    }

    /// Formats a value that is already expressed as a percentage (e.g. 1.5 means 1.5%)
    /// with adaptive precision: 1 decimal if >= 1%, 2 decimals if < 1%.
    /// e.g. 1.5 → "1.5%", 0.04 → "0.04%", 0.0 → "0.00%"
    var adaptivePercentString: String {
        let decimals = self >= 1.0 ? 1 : 2
        return roundedString(decimals: decimals) + "%"
    }
}

// MARK: - Time Formatting

public extension Double {
    
    /// Converts a duration (in seconds) into a compact readable string.
    /// Example: 165432308 → "5y 3d 22h 5m 8s"
    func readableTime() -> String {
        var remaining = Int(self)
        
        let years   = remaining / (60 * 60 * 24 * 365)
        remaining  %= (60 * 60 * 24 * 365)
        
        let days    = remaining / (60 * 60 * 24)
        remaining  %= (60 * 60 * 24)
        
        let hours   = remaining / (60 * 60)
        remaining  %= (60 * 60)
        
        let minutes = remaining / 60
        let seconds = remaining % 60
        
        var parts: [String] = []
        
        if years   > 0 { parts.append("\(years)y") }
        if days    > 0 { parts.append("\(days)d") }
        if hours   > 0 { parts.append("\(hours)h") }
        if minutes > 0 { parts.append("\(minutes)m") }
        if seconds > 0 || parts.isEmpty {
            parts.append("\(seconds)s")
        }
        
        return parts.joined(separator: " ")
    }
    
    /// Converts a duration into a human-friendly time code:
    /// - Days > 0  →  "D:HH:MM:SS"  (fully padded)
    /// - Hours > 0 →  "H:M:SS"      (H and M not padded)
    /// - Hours = 0 →  "M:SS"        (M not padded)
    func timeCode() -> String {
        let total = Int(self)
        
        let days = total / 86_400
        let hours = (total % 86_400) / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        
        if days > 0 {
            // D:HH:MM:SS — fully padded
            return "\(days):" +
                String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        
        if hours > 0 {
            // H:M:SS — hours & minutes unpadded
            return "\(hours):\(minutes):" +
                String(format: "%02d", seconds)
        }
        
        // M:SS — minutes unpadded, seconds padded
        return "\(minutes):" + String(format: "%02d", seconds)
    }
    
    /// Converts seconds to "m:ss" (or "h:mm:ss" if >= 1 hour)
    var asPaceString: String {
        guard self.isFinite, self >= 0 else { return "--:--" }
        let total = Int(self.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}
