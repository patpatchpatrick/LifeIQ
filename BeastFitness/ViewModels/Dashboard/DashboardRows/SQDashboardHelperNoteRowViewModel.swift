//
//  SQDashboardHelperNoteRowViewModel.swift
//  BeastFitness
//
//  Created by Codex on 6/3/26.
//

import Foundation

final class SQDashboardHelperNoteRowViewModel: SQDashboardRowViewModel {
    let message: String
    let icon: SQImageSymbol

    init(message: String, icon: SQImageSymbol = .infoCircle) {
        self.message = message
        self.icon = icon
        super.init(rowId: .helperNote, rowType: .helperNote)
    }
}
