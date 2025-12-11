//
//  Double+Extensions.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 10/7/24.
//

import Foundation

// MARK: - Optional Double helpers

extension Double? {
    /// Short string for optional doubles. Returns "N/A" if nil.
    var sqShortString: String {
        guard let value = self else {
            return "N/A"
        }
        return value.sqShortString
    }
}

// MARK: - Core Double formatting

extension Double {
    
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
    /// - Parameter decimals: Number of digits after the decimal point.
    /// - Parameter showPositiveSign: If true, prefixes "+" for positive values.
    func toPercentageString(decimals: Int = 1, showPositiveSign: Bool = false) -> String {
        let percentageValue = self * 100
        let prefix = showPositiveSign && percentageValue > 0 ? "+" : ""
        // Reuse roundedString for consistent formatting
        let valueString = percentageValue.roundedString(decimals: decimals)
        return "\(prefix)\(valueString)%"
    }
}

extension Double {
    
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
}
