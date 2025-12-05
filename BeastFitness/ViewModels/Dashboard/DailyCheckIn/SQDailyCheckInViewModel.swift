//
//  SQDailyCheckInViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/25/25.
//

import SwiftUI
import SwiftData

@Observable @MainActor
final class SQDailyCheckInViewModel: Identifiable {
    let id = UUID()
    let dashboardInterface: SQDashboardInterface = SQDashboardController.default
    private let dailyCheckInManager: SQDailyCheckInManaging
    private(set) var rows: [SQDailyCheckInRowViewModel] = []
    let onDismiss: () -> Void
    private(set) var isLoading: Bool = false
    
    init(stats: SQDailyCheckInStats?, dailyCheckInManager: SQDailyCheckInManaging = SQDailyCheckInManager(), onDismiss: @escaping () -> Void) {
        self.dailyCheckInManager = dailyCheckInManager
        self.onDismiss = onDismiss
        self.rows = buildRows(for: stats)
    }
    
    func buildRows(for stats: SQDailyCheckInStats?) -> [SQDailyCheckInRowViewModel] {
        var rows: [SQDailyCheckInRowViewModel] = []
        
        // Mood / feeling
        let initialMood = Self.moodSegment(for: stats)
        let moodRow = SQDailyCheckInRowSegmentedControlViewModel(
            field: .mood,
            title: "Mood",
            segments: SQCheckInMoodScale.allCases,
            initialSelection: initialMood,
            onFocused: { [weak self] in
                self?.handleRowFocused($0)
            }
        )
        rows.append(moodRow)
        
        // Mental clarity
        let initialClarity = Self.claritySegment(for: stats)
        let clarityRow = SQDailyCheckInRowSegmentedControlViewModel(
            field: .mentalClarity,
            title: "Mental Clarity",
            segments: SQCheckInClarityScale.allCases,
            initialSelection: initialClarity,
            onFocused: { [weak self] in
                self?.handleRowFocused($0)
            }
        )
        rows.append(clarityRow)
        
        // Energy
        let initialEnergy = Self.energySegment(for: stats)
        let energyRow = SQDailyCheckInRowSegmentedControlViewModel(
            field: .energy,
            title: "Energy Level",
            segments: SQCheckInEnergyScale.allCases,
            initialSelection: initialEnergy,
            onFocused: { [weak self] in
                self?.handleRowFocused($0)
            }
        )
        rows.append(energyRow)
        
        // Soreness / recovery
        let initialSoreness = Self.sorenessSegment(for: stats)
        let sorenessRow = SQDailyCheckInRowSegmentedControlViewModel(
            field: .soreness,
            title: "Soreness / Recovery",
            segments: SQCheckInSorenessScale.allCases,
            initialSelection: initialSoreness,
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
        if let sleepHours = stats?.sleepHours {
            sleepHoursRow.initialize(with: String(format: "%.1f", sleepHours))
        }
        rows.append(sleepHoursRow)
        
        // Sleep quality (1–5)
        let initialSleepQuality = Self.sleepQualitySegment(for: stats)
        let sleepQualityRow = SQDailyCheckInRowSegmentedControlViewModel(
            field: .sleepQuality,
            title: "Sleep Quality",
            segments: SQCheckInSleepQualityScale.allCases,
            initialSelection: initialSleepQuality,
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
            errorHandler: { _ in nil }
        )
        
        let notesRow = SQDailyCheckInTextEntryViewModel(
            field: .notes,
            title: "Notes",
            textFieldViewModel: notesTextField,
            onFocused: { [weak self] in
                self?.handleRowFocused($0)
            }
        )
        notesRow.initialize(with: stats?.notes)
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
    
    func submitTapped(modelContext: ModelContext) async {
        isLoading = true
        rows.forEach { $0.isDisabled = true }
        
        defer {
            isLoading = false
            rows.forEach { $0.isDisabled = false }
        }
        
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
        
        do {
            try await dailyCheckInManager.saveDailyCheckInStats(stats: stats, to: modelContext)
        } catch {
            print("PTD Surface this error", error)
        }
        
        /// Refresh the dashboard data
        await dashboardInterface.refreshUI(for: modelContext)
        
        onDismiss()
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

// MARK: - Initial value helpers

private extension SQDailyCheckInViewModel {
    
    /// Returns the mood segment whose `scoreOutOf10` is closest to the stored mood score.
    ///
    /// Concept:
    /// - Each mood enum case has a numeric value (`scoreOutOf10`).
    /// - The saved `moodScore` (0–10) may not match an exact segment.
    /// - We compute the absolute difference between the saved score and every segment.
    /// - `min(by:)` picks the segment with the smallest difference → the closest match.
    static func moodSegment(for stats: SQDailyCheckInStats?) -> SQCheckInMoodScale? {
        guard let score = stats?.moodScore else { return nil }
        return SQCheckInMoodScale.allCases.min {
            abs($0.scoreOutOf10 - score) < abs($1.scoreOutOf10 - score)
        }
    }
    
    /// Same logic as `moodSegment`: finds the clarity segment whose `scoreOutOf10`
    /// is numerically closest to the saved mental clarity score.
    static func claritySegment(for stats: SQDailyCheckInStats?) -> SQCheckInClarityScale? {
        guard let score = stats?.mentalClarityScore else { return nil }
        return SQCheckInClarityScale.allCases.min {
            abs($0.scoreOutOf10 - score) < abs($1.scoreOutOf10 - score)
        }
    }
    
    /// Finds the energy segment whose `scoreOutOf10` is closest to the stored energy score.
    ///
    /// This allows partial scores (e.g., 6.7/10) to map naturally back
    /// to the nearest discrete UI segment.
    static func energySegment(for stats: SQDailyCheckInStats?) -> SQCheckInEnergyScale? {
        guard let score = stats?.energyScore else { return nil }
        return SQCheckInEnergyScale.allCases.min {
            abs($0.scoreOutOf10 - score) < abs($1.scoreOutOf10 - score)
        }
    }
    
    /// Finds the soreness segment whose `scoreOutOf10` is closest to the stored soreness score.
    ///
    /// The same nearest-value comparison is used to restore the user’s previous selection.
    static func sorenessSegment(for stats: SQDailyCheckInStats?) -> SQCheckInSorenessScale? {
        guard let score = stats?.sorenessScore else { return nil }
        return SQCheckInSorenessScale.allCases.min {
            abs($0.scoreOutOf10 - score) < abs($1.scoreOutOf10 - score)
        }
    }
    
    /// Maps the saved sleep quality (1–5) back to the nearest enum case.
    ///
    /// `SQCheckInSleepQualityScale` uses an integer `rating` rather than a 0–10 scale,
    /// but the same distance-minimization logic applies.
    static func sleepQualitySegment(for stats: SQDailyCheckInStats?) -> SQCheckInSleepQualityScale? {
        guard let rating = stats?.sleepQualityScore else { return nil }
        return SQCheckInSleepQualityScale.allCases.min {
            abs(Float($0.rating) - rating) < abs(Float($1.rating) - rating)
        }
    }
}
