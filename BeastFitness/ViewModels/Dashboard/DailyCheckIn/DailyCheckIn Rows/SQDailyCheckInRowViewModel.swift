//
//  SQDailyCheckInRowViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/25/25.
//

import SwiftUI

@Observable @MainActor
class SQDailyCheckInRowViewModel: Identifiable {
    let title: String
    var number: String = ""
    var isCompleted = false
    
    init(title: String) {
        self.title = title
    }
}
