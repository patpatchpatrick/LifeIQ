//
//  SQDashboardTextRow.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/12/25.
//

import SwiftUI

struct SQDashboardTextRow: View {
    @Bindable var viewModel: SQDashboardTextRowViewModel
    
    var body: some View {
        Text(viewModel.text)
            .sqFont(.title3)
            .sqForegroundColor(.textPrimary)
    }
}
