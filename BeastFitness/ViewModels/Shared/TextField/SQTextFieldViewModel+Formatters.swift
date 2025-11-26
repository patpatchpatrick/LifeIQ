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
        case maxLength(Int)
        
        var formatter: (String, String) -> String {
            switch self {
            case .custom(let formatter):
                return formatter
                
            case .default:
                return { _, newText in newText }
                
            case .numeric:
                return { _, newText in
                    newText.filter { $0.isWholeNumber }
                }
                
            case .decimal(let maxDecimalPlaces):
                return decimalFormatter(maxDecimalPlaces: maxDecimalPlaces)
                
            case .maxLength(let limit):
                return maxLengthFormatter(limit: limit)
            }
        }
    }
}

// MARK: - Formatters

extension SQTextFieldViewModel.TextChangeFormatter {
    
    fileprivate func decimalFormatter(maxDecimalPlaces: Int) -> (String, String) -> String {
        { _, newText in
            var filtered = newText.filter { $0.isWholeNumber || $0 == "." }
            
            if filtered.filter({ $0 == "." }).count > 1 {
                var seenDot = false
                filtered = filtered.filter {
                    if $0 == "." {
                        defer { seenDot = true }
                        return !seenDot
                    }
                    return true
                }
            }
            
            if let dotIndex = filtered.firstIndex(of: ".") {
                let decimalPart = filtered[filtered.index(after: dotIndex)...]
                if decimalPart.count > maxDecimalPlaces {
                    let allowedEnd = filtered.index(dotIndex, offsetBy: 1 + maxDecimalPlaces)
                    filtered = String(filtered[..<allowedEnd])
                }
            }
            
            return filtered
        }
    }
    
    fileprivate func maxLengthFormatter(limit: Int) -> (String, String) -> String {
        { _, newText in
            guard newText.count > limit else { return newText }
            let idx = newText.index(newText.startIndex, offsetBy: limit)
            return String(newText[..<idx])
        }
    }
    
    /// Extract length limit if this is `.maxLength`
    var maxLengthLimit: Int? {
        if case let .maxLength(limit) = self {
            return limit
        }
        return nil
    }
}
