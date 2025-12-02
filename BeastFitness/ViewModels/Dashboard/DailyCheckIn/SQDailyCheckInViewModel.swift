//
//  SQDailyCheckInViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/25/25.
//

import SwiftUI

enum SQDailyCheckInField {
    case mood
    case mentalClarity
    case energy
    case soreness
    case sleepHours
    case sleepQuality
    case notes
    // future: case tags, photo
}

struct SQDailyCheckInStats: Codable {
    let date: Date
    let moodScore: Float?              /// 0–10
    let mentalClarityScore: Float?     /// 0–10
    let energyScore: Float?            /// 0–10
    let sorenessScore: Float?          /// 0–10 (e.g. 0 very sore → 10 fresh)
    let sleepHours: Float?             /// Hours per day
    let sleepQualityScore: Float?      /// 1–5
    let notes: String?                 /// Free text
}

@Observable @MainActor
final class SQDailyCheckInViewModel {
    private let dailyCheckInService: SQDailyCheckInServicing.Type
    private(set) var rows: [SQDailyCheckInRowViewModel] = []
    
    init(dailyCheckInService: SQDailyCheckInServicing.Type = SQDailyCheckInService.self) {
        self.dailyCheckInService = dailyCheckInService
        self.rows = buildRows()
    }
    
    func buildRows() -> [SQDailyCheckInRowViewModel] {
        var rows: [SQDailyCheckInRowViewModel] = []
        
        // Mood / feeling
        let moodRow = SQDailyCheckInRowSegmentedControlViewModel(
            field: .mood,
            title: "Mood",
            segments: SQCheckInMoodScale.allCases,
            onFocused: { [weak self] in
                self?.handleRowFocused($0)
            }
        )
        rows.append(moodRow)
        
        // Mental clarity
        let clarityRow = SQDailyCheckInRowSegmentedControlViewModel(
            field: .mentalClarity,
            title: "Mental Clarity",
            segments: SQCheckInClarityScale.allCases,
            onFocused: { [weak self] in
                self?.handleRowFocused($0)
            }
        )
        rows.append(clarityRow)
        
        // Energy
        let energyRow = SQDailyCheckInRowSegmentedControlViewModel(
            field: .energy,
            title: "Energy Level",
            segments: SQCheckInEnergyScale.allCases,
            onFocused: { [weak self] in
                self?.handleRowFocused($0)
            }
        )
        rows.append(energyRow)
        
        // Soreness / recovery
        let sorenessRow = SQDailyCheckInRowSegmentedControlViewModel(
            field: .soreness,
            title: "Soreness / Recovery",
            segments: SQCheckInSorenessScale.allCases,
            onFocused: { [weak self] in
                self?.handleRowFocused($0)
            }
        )
        rows.append(sorenessRow)
        
        // Sleep hours (numeric)
        let sleepEntryTextField = SQTextFieldViewModel(
            lineLimit: 1,
            placeholder: "8 hours",
            keyboardType: .decimalPad,
            textChangeFormatter: .decimal(maxDecimalPlaces: 1),
            validationRule: .decimal(maxDecimalPlaces: 1, range: 0...24),
            errorHandler: { text in
                guard !text.isEmpty else { return nil }
                guard let value = Double(text) else { return nil }
                
                if value > 24.0 {
                    return "Enter a value less than or equal to 24 hours"
                }
                
                return nil
            }
        )
        
        let sleepHoursRow = SQDailyCheckInTextEntryViewModel(
            field: .sleepHours,
            title: "Sleep (hours)",
            textFieldViewModel: sleepEntryTextField,
            onFocused: { [weak self] in
                self?.handleRowFocused($0)
            }
        )
        rows.append(sleepHoursRow)
        
        // Sleep quality (1–5)
        let sleepQualityRow = SQDailyCheckInRowSegmentedControlViewModel(
            field: .sleepQuality,
            title: "Sleep Quality",
            segments: SQCheckInSleepQualityScale.allCases,
            onFocused: { [weak self] in
                self?.handleRowFocused($0)
            }
        )
        rows.append(sleepQualityRow)
        
        // Notes (free text)
        let notesMaxCharacterCount: Int = 2500
        let notesTextField = SQTextFieldViewModel(
            uiConfig: .standard,
            axis: .vertical,
            lineLimit: 4,
            placeholder: "Notes (optional: drank, stress, travel, etc.)",
            keyboardType: .default,
            textAutoCap: .sentences,
            autoCorrectionEnabled: true,
            textChangeFormatter: .maxLength(notesMaxCharacterCount),
            validationRule: .length(max: notesMaxCharacterCount),
            errorHandler: { _ in nil } // no validation errors here
        )
        
        let notesRow = SQDailyCheckInTextEntryViewModel(
            field: .notes,
            title: "Notes",
            textFieldViewModel: notesTextField,
            onFocused: { [weak self] in
                self?.handleRowFocused($0)
            }
        )
        rows.append(notesRow)
        
        // Numbering
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
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
    
    // MARK: - Form Submission

    var canSubmit: Bool {
        rows.allSatisfy { $0.isCompleted }
    }
    
    func submitTapped() {
        guard canSubmit else {
            SQLogger.shared.log(
                "Should not be able to submit check-in if fields aren't valid",
                .error,
                context: .dailyCheckIn
            )
            return
        }
        
        var moodScore: Float? = nil
        var mentalClarityScore: Float? = nil
        var energyScore: Float? = nil
        var sorenessScore: Float? = nil
        var sleepHours: Float? = nil
        var sleepQualityScore: Float? = nil
        var notes: String? = nil
        
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
                
            case .mentalClarity:
                if
                    let segmentedRow = row as? SQDailyCheckInRowSegmentedControlViewModel,
                    let segment = segmentedRow.selectedSegment,
                    let clarity = SQCheckInClarityScale.fromSegment(segment)
                {
                    mentalClarityScore = clarity.scoreOutOf10
                }
                
            case .energy:
                if
                    let segmentedRow = row as? SQDailyCheckInRowSegmentedControlViewModel,
                    let segment = segmentedRow.selectedSegment,
                    let energy = SQCheckInEnergyScale.fromSegment(segment)
                {
                    energyScore = energy.scoreOutOf10
                }
                
            case .soreness:
                if
                    let segmentedRow = row as? SQDailyCheckInRowSegmentedControlViewModel,
                    let segment = segmentedRow.selectedSegment,
                    let soreness = SQCheckInSorenessScale.fromSegment(segment)
                {
                    sorenessScore = soreness.scoreOutOf10
                }
                
            case .sleepHours:
                if let textRow = row as? SQDailyCheckInTextEntryViewModel {
                    let text = textRow.textFieldViewModel.text
                    sleepHours = Float(text)
                }
                
            case .sleepQuality:
                if
                    let segmentedRow = row as? SQDailyCheckInRowSegmentedControlViewModel,
                    let segment = segmentedRow.selectedSegment,
                    let quality = SQCheckInSleepQualityScale.fromSegment(segment)
                {
                    sleepQualityScore = quality.rating
                }
                
            case .notes:
                if let textRow = row as? SQDailyCheckInTextEntryViewModel {
                    let text = textRow.textFieldViewModel.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    notes = text.isEmpty ? nil : text
                }
            }
        }
        
        let stats = SQDailyCheckInStats(
            date: .now,
            moodScore: moodScore,
            mentalClarityScore: mentalClarityScore,
            energyScore: energyScore,
            sorenessScore: sorenessScore,
            sleepHours: sleepHours,
            sleepQualityScore: sleepQualityScore,
            notes: notes
        )
        
        SQLogger.shared.log("Submitting daily stats: \(stats)", .debug, context: .dailyCheckIn)
        
        print("PTD Handle Submission", stats)
        
        Task {
            do {
                try await dailyCheckInService.saveDailyCheckInStats(stats)
            } catch {
                
                SQLogger.shared.log("Submitting daily stats failed with error: \(error)", .debug, context: .dailyCheckIn)
            }
        }
        
        // TODO: hand `stats` off to your data layer / HealthKit sync / analytics
    }
}


// MARK: - Check In Row Enums

protocol SQCheckInSegmentable: Hashable {
    var segmentTitle: String { get }
    var segmentId: String { get }
}

extension SQCheckInSegmentable where Self: CaseIterable {
    static func fromSegment(_ segment: SQSegmentedControlSegment) -> Self? {
        Self.allCases.first { $0.segmentId == segment.id }
    }
}

// MARK: - Mood (1–8 emoji → 0–10)

enum SQCheckInMoodScale: String, SQCheckInSegmentable, CaseIterable {
    case one, two, three, four, five, six, seven, eight
    
    var segmentId: String { rawValue }
    
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
    
    var scoreOutOf10: Float {
        let index = Self.allCases.firstIndex(of: self) ?? 0
        return Float(index + 1) / Float(Self.allCases.count) * 10.0
    }
}

// MARK: - Mental clarity (1–8, text labels)

enum SQCheckInClarityScale: String, SQCheckInSegmentable, CaseIterable {
    case one, two, three, four, five, six, seven, eight
    
    var segmentId: String { rawValue }
    
    var segmentTitle: String {
            switch self {
            case .one:   return "😵‍💫"   // Foggy
            case .two:   return "😕"     // Distracted
            case .three: return "😐"     // Meh
            case .four:  return "🙂"     // Okay
            case .five:  return "🧘"     // Focused
            case .six:   return "🧠"     // Sharp
            case .seven: return "⚡️"     // Dialed In
            case .eight: return "🎯"     // Laser
            }
    }
    
    var scoreOutOf10: Float {
        let index = Self.allCases.firstIndex(of: self) ?? 0
        return Float(index + 1) / Float(Self.allCases.count) * 10.0
    }
}

// MARK: - Energy (5-point: Exhausted → Energized)

enum SQCheckInEnergyScale: String, SQCheckInSegmentable, CaseIterable {
    case exhausted
    case low
    case ok
    case good
    case energized
    
    var segmentId: String { rawValue }
    
    var segmentTitle: String {
            switch self {
            case .exhausted: return "🥱"
            case .low:       return "😴"
            case .ok:        return "😐"
            case .good:      return "🙂"
            case .energized: return "⚡️"
            }
        }
    
    var scoreOutOf10: Float {
        let index = Self.allCases.firstIndex(of: self) ?? 0
        return Float(index + 1) / Float(Self.allCases.count) * 10.0
    }
}

// MARK: - Soreness / recovery (5-point: Very sore → Fresh)

enum SQCheckInSorenessScale: String, SQCheckInSegmentable, CaseIterable {
    case verySore
    case sore
    case ok
    case good
    case fresh
    
    var segmentId: String { rawValue }
    
    var segmentTitle: String {
            switch self {
            case .verySore: return "🤕"
            case .sore:     return "😣"
            case .ok:       return "😐"
            case .good:     return "🙂"
            case .fresh:    return "💪"
            }
        }
    
    /// 0 = very sore, 10 = fresh
    var scoreOutOf10: Float {
        let index = Self.allCases.firstIndex(of: self) ?? 0
        return Float(index + 1) / Float(Self.allCases.count) * 10.0
    }
}

// MARK: - Sleep quality (1–5)

enum SQCheckInSleepQualityScale: String, SQCheckInSegmentable, CaseIterable {
    case one, two, three, four, five
    
    var segmentId: String { rawValue }
    
    var segmentTitle: String {
            switch self {
            case .one:   return "💤"
            case .two:   return "😴"
            case .three: return "😐"
            case .four:  return "🙂"
            case .five:  return "😌"
            }
        }
    
    var rating: Float {
        let index = Self.allCases.firstIndex(of: self) ?? 0
        return Float(index + 1) // 1…5
    }
}

