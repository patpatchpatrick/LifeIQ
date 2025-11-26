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
    let number: String
    var isCompleted = false
    
    init(title: String, number: String) {
        self.title = title
        self.number = number
    }
}
