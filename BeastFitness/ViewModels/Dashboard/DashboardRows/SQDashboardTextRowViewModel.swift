//
//  SQDashboardTextRowViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/12/25.
//

import SwiftUI

@Observable @MainActor
final class SQDashboardTextRowViewModel: SQDashboardRowViewModel {
    let text: String
    
    init(rowId: SQDashboardRowIdentifier, text: String) {
        self.text = text
        super.init(rowId: rowId, rowType: .text)
    }
}
