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
        
        rows.append(SQDailyCheckInRowSegmentedControlViewModel(title: "Mood", number: "1", segments: SQCheckInMoodScale.allCases))
        
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
