//
//  SQTextValidationRule.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/26/25.
//

enum SQTextValidationRule {
    case none
    case decimal(maxDecimalPlaces: Int, range: ClosedRange<Double>)
    case length(max: Int, includingWhitespace: Bool = true)
    case custom((String) -> Bool)
}

extension SQTextValidationRule {
    func isValid(_ text: String) -> Bool {
        switch self {
        case .none:
            return !text.isEmpty
            
        case .decimal(let maxDecimalPlaces, let range):
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return false }
            guard let value = Double(trimmed) else { return false }
            guard range.contains(value) else { return false }
            
            let components = trimmed.split(separator: ".", omittingEmptySubsequences: false)
            if components.count == 2 {
                let fractional = components[1]
                if fractional.count > maxDecimalPlaces {
                    return false
                }
            } else if components.count > 2 {
                return false
            }
            
            return true
            
        case .length(let max, let includingWhitespace):
            let count = includingWhitespace
                ? text.count
                : text.trimmingCharacters(in: .whitespacesAndNewlines).count
            
            return count > 0 && count <= max
            
        case .custom(let block):
            return block(text)
        }
    }
    
    /// Extract the length limit if this is a `.length` rule.
    var lengthLimit: Int? {
        if case let .length(max, _) = self {
            return max
        }
        return nil
    }
}
