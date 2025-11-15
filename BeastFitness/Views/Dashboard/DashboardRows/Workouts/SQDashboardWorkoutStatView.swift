//
//  SQDashboardWorkoutStatView.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/14/25.
//

import SwiftUI

struct SQDashboardWorkoutStatView: View {
    let attributedTitle: AttributedString
    
    var body: some View {
        Text(attributedTitle)
            .padding(.top, .SQSpace.m) /// Subtract a bit to center the text since we typically use 2 different size fonts here which makes the text sit towards the bottom
            .padding(.bottom, .SQSpace.m)
            .padding(.horizontal, .SQSpace.m)
            .sqBackgroundColor(.backgroundTertiaryLight)
            .cornerRadius(.SQSpace.s)
    }
}

#Preview {
    SQDashboardWorkoutStatView(attributedTitle: .init("Test"))
        .preferredColorScheme(.dark)
}
