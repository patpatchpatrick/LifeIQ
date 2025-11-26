//
//  SQTextValidationRule.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/26/25.
//

enum SQTextValidationRule {
    case none
    case decimal(maxDecimalPlaces: Int, range: ClosedRange<Double>)
    case length(max: Int)
    case custom((String) -> Bool)
}

extension SQTextValidationRule {
    func isValid(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch self {
        case .none:
            // e.g. treat any non-empty text as valid
            return !trimmed.isEmpty
            
        case .decimal(let maxDecimalPlaces, let range):
            guard !trimmed.isEmpty else { return false }
            guard let value = Double(trimmed) else { return false }
            guard range.contains(value) else { return false }
            
            // Enforce decimal places
            let components = trimmed.split(separator: ".", omittingEmptySubsequences: false)
            if components.count == 2 {
                let fractional = components[1]
                if fractional.count > maxDecimalPlaces {
                    return false
                }
            } else if components.count > 2 {
                // e.g. "1.2.3"
                return false
            }
            
            return true
            
        case .length(let max):
            return !trimmed.isEmpty && trimmed.count <= max
            
        case .custom(let block):
            return block(trimmed)
        }
    }
}
