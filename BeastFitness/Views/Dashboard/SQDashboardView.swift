//
//  SQDashboardView.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/11/25.
//

import SwiftUI

struct SQDashboardView: View {
    @Bindable var viewModel: SQDashboardViewModel
    
    var mainScroll: some View {
        Text("Hi")
    }

    var body: some View {
        mainScroll
            .background(SQColor.background.color.ignoresSafeArea())
    }
}
