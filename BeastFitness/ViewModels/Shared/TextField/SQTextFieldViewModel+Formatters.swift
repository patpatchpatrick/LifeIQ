//
//  SQTextFieldViewModel+Formatters.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/26/25.
//

extension SQTextFieldViewModel {
    enum TextChangeFormatter {
        case custom((String, String) -> String)
        case `default`
        case numeric
        case decimal(maxDecimalPlaces: Int)
        
        var formatter: (String, String) -> String {
            switch self {
            case .custom(let formatter):
                return formatter
            case .default:
                return { (_, newText) in return newText }
            case .numeric:
                return { (_, newText) in
                    // Allow only digits 0-9
                    let filtered = newText.filter { $0.isWholeNumber }
                    return filtered
                }
            case .decimal(maxDecimalPlaces: let maxDecimalPlaces):
                return decimalFormatter(maxDecimalPlaces: maxDecimalPlaces)
            }
        }
    }
}

// MARK: - Text Change Formatters

extension SQTextFieldViewModel.TextChangeFormatter {
    private func decimalFormatter(maxDecimalPlaces: Int) -> (String, String) -> String {
        return { (_, newText) in
            // 1. Keep digits and at most one dot
            var filtered = newText.filter { $0.isWholeNumber || $0 == "." }
            
            // 2. Enforce ONE decimal point
            if filtered.filter({ $0 == "." }).count > 1 {
                // Remove every dot except the first
                var seenDot = false
                filtered = filtered.filter {
                    if $0 == "." {
                        defer { seenDot = true }
                        return !seenDot
                    }
                    return true
                }
            }
            
            // 3. Enforce max decimal places
            if let dotIndex = filtered.firstIndex(of: ".") {
                let decimalPart = filtered[filtered.index(after: dotIndex)...]
                if decimalPart.count > maxDecimalPlaces {
                    // Trim extra decimal digits
                    let allowedEnd = filtered.index(dotIndex, offsetBy: 1 + maxDecimalPlaces)
                    filtered = String(filtered[..<allowedEnd])
                }
            }
            
            return filtered
        }
    }
}
