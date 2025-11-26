//
//  SQDailyCheckInViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/25/25.
//

import SwiftUI

struct DailyCheckInStats {
    let moodScore: Float /// Scale out of 10
    let sleepHours: Float /// Hours per day
}

@Observable @MainActor
final class SQDailyCheckInViewModel {
    private(set) var rows: [SQDailyCheckInRowViewModel] = []
    
    private var moodRow: SQDailyCheckInRowSegmentedControlViewModel?
    private var sleepRow: SQDailyCheckInTextEntryViewModel?
    
    init() {
        self.rows = buildRows()
    }
    
    func buildRows() -> [SQDailyCheckInRowViewModel] {
        var rows = [SQDailyCheckInRowViewModel]()
        
        let moodRow = SQDailyCheckInRowSegmentedControlViewModel(
            title: "Mood",
            segments: SQCheckInMoodScale.allCases,
            onFocused: { [weak self] in
                self?.handleRowFocused($0)
            }
        )
        rows.append(moodRow)
        self.moodRow = moodRow
        
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
        
        let sleepRow = SQDailyCheckInTextEntryViewModel(
            title: "Sleep",
            textFieldViewModel: sleepEntryTextField,
            onFocused: { [weak self] in
                self?.handleRowFocused($0)
            }
        )
        rows.append(sleepRow)
        self.sleepRow = sleepRow
        
        for (idx, row) in rows.enumerated() {
            row.number = String(idx + 1)
        }
        
        return rows
    }
    
    private func handleRowFocused(_ row: SQDailyCheckInRowViewModel) {
        
        let rowIsTextField = row is SQDailyCheckInTextEntryViewModel
        if !rowIsTextField {
            hideKeyboard()
        }
        
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    // MARK: - Form Submission

    var canSubmit: Bool {
        var canSubmit = true
        rows.forEach {
            canSubmit = canSubmit && $0.isCompleted
        }
        return canSubmit
    }
    
    func submitTapped() {
        
        guard canSubmit else {
            SQLogger.shared.log("Should not be able to submit check-in if fields aren't valid", .error, context: .dailyCheckIn)
            return
        }
        
        print("PTD Handle Submission")
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
