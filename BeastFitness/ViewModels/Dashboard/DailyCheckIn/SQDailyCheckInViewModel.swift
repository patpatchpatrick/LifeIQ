//
//  SQDailyCheckInViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/25/25.
//

import SwiftUI

enum SQDailyCheckInField {
    case mood
    case sleep
    // future: case energy, stress, notes, etc.
}

struct SQDailyCheckInStats {
    let moodScore: Float? /// Scale out of 10
    let sleepHours: Float? /// Hours per day
}

@Observable @MainActor
final class SQDailyCheckInViewModel {
    private(set) var rows: [SQDailyCheckInRowViewModel] = []
    
    init() {
        self.rows = buildRows()
    }
    
    func buildRows() -> [SQDailyCheckInRowViewModel] {
        var rows = [SQDailyCheckInRowViewModel]()
        
        let moodRow = SQDailyCheckInRowSegmentedControlViewModel(
            field: .mood,
            title: "Mood",
            segments: SQCheckInMoodScale.allCases,
            onFocused: { [weak self] in
                self?.handleRowFocused($0)
            }
        )
        rows.append(moodRow)
        
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
            field: .sleep,
            title: "Sleep",
            textFieldViewModel: sleepEntryTextField,
            onFocused: { [weak self] in
                self?.handleRowFocused($0)
            }
        )
        rows.append(sleepRow)
        
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
        
        var moodScore: Float? = nil
        var sleepHours: Float? = nil
        
        for row in rows {
            switch row.field {
            case .mood:
                if
                    let segmentedRow = row as? SQDailyCheckInRowSegmentedControlViewModel,
                    let segment = segmentedRow.selectedSegment,
                    let mood = SQCheckInMoodScale.fromSegment(segment)
                {
                    moodScore = mood.scoreOutOf10
                }
                
            case .sleep:
                if let textRow = row as? SQDailyCheckInTextEntryViewModel {
                    let text = textRow.textFieldViewModel.text
                    sleepHours = Float(text)
                }
            }
        }
        
        let stats = SQDailyCheckInStats(
            moodScore: moodScore,
            sleepHours: sleepHours
        )
        
        print("PTD Handle Submission", stats.moodScore as Any, stats.sleepHours as Any)
        // TODO: pass `stats` on to your data layer
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
    
    /// Map 1–8 emoji scale to a 0–10 score
        var scoreOutOf10: Float {
            // 1 → 1/8 * 10, 8 → 8/8 * 10 = 10
            let index = Self.allCases.firstIndex(of: self) ?? 0
            return Float(index + 1) / Float(Self.allCases.count) * 10.0
        }
}

extension SQCheckInSegmentable where Self: CaseIterable {
    static func fromSegment(_ segment: SQSegmentedControlSegment) -> Self? {
        Self.allCases.first { $0.segmentId == segment.id }
    }
}
