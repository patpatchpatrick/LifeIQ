//
//  SQDailyCheckInRowViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/25/25.
//

import SwiftUI

@Observable @MainActor
class SQDailyCheckInRowViewModel: Identifiable {
    let id = UUID()
    let field: SQDailyCheckInField
    let title: String
    let subtitle: String?
    var attributedSubtitle: AttributedString?
    var accentSubtitle: String?
    var number: String = ""
    var isCompleted = false
    var isDisabled: Bool = false
    let onFocused: ((SQDailyCheckInRowViewModel) -> Void)?
    
    init(
        field: SQDailyCheckInField,
        title: String,
        subtitle: String? = nil,
        onFocused: ((SQDailyCheckInRowViewModel) -> Void)? = nil
    ) {
        self.field = field
        self.title = title
        self.subtitle = subtitle
        self.attributedSubtitle = nil
        self.accentSubtitle = nil
        self.onFocused = onFocused
    }
}
