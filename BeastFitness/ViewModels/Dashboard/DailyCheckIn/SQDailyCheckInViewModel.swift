//
//  SQDailyCheckInViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/25/25.
//

import SwiftUI

@Observable @MainActor
final class SQDailyCheckInViewModel {
    private(set) var rows: [SQDailyCheckInRowViewModel] = []
    
    init() {
        self.rows = buildRows()
    }
    
    func buildRows() -> [SQDailyCheckInRowViewModel] {
        var rows = [SQDailyCheckInRowViewModel]()
        
        rows.append(SQDailyCheckInRowSegmentedControlViewModel(title: "Mood", segments: SQCheckInMoodScale.allCases))
        
        let sleepEntryTextField = SQTextFieldViewModel(
            lineLimit: 1,
            placeholder: "8 hours",
            keyboardType: .decimalPad,
            textChangeFormatter: .decimal(maxDecimalPlaces: 1),
            validationRule: .decimal(maxDecimalPlaces: 1, range: 0...24),
            errorHandler: { text in
                guard !text.isEmpty else { return nil }
                guard let value = Double(text) else {
                    return nil
                }
                
                if value > 24.0 {
                    return "Enter a value less than or equal to 24 hours"
                }
                
                return nil
                })
        rows.append(SQDailyCheckInTextEntryViewModel(
            title: "Sleep",
            textFieldViewModel: sleepEntryTextField))
        
        for (idx, row) in rows.enumerated() {
            row.number = String(idx + 1)
        }
        
        return rows
    }
}

// MARK: - Check In Row Enums

protocol SQCheckInSegmentable: Hashable {
    var segmentTitle: String { get }
    var segmentId: String { get }
}

enum SQCheckInMoodScale: String, SQCheckInSegmentable, CaseIterable {
    case one
    case two
    case three
    case four
    case five
    case six
    case seven
    case eight
    
    var segmentId: String { self.rawValue }
    
    var segmentTitle: String {
        switch self {
        case .one:   return "😡"
        case .two:   return "😕"
        case .three: return "😐"
        case .four:  return "🙂"
        case .five:  return "😌"
        case .six:   return "😀"
        case .seven: return "😄"
        case .eight: return "🤩"
        }
    }
}
