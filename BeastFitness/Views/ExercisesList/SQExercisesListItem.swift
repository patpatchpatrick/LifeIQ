//
//  SQExercisesListItem.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/8/25.
//

import SwiftUI

struct SQExercisesListItem: View {
    let viewModel: SQExercisesListItemViewModel
    
    @ViewBuilder
    var workoutImage: some View {
        ZStack {
            Circle()
                .sqForegroundColor(.backgroundSecondaryLight)
                .frame(width: 40)
            
            SQImageView(image: .init(symbol: .baseball, symbolStyle: .colorWithFont(.textPrimary, font: .body)))
                .frame(width: 20)
        }
    }
    
    @ViewBuilder
    var workoutTitleAndDescription: some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            Text(viewModel.title)
                .sqFont(.bodyBold)
                .sqForegroundColor(.textPrimary)
            
            Text("Camelback, etc...")
                .sqFont(.body)
                .sqForegroundColor(.textSecondary)
        }
    }
    
    var mainHStack: some View {
        HStack(alignment: .top, spacing: .SQSpace.m) {
            
            workoutImage
            
            workoutTitleAndDescription
            
            Spacer()
        }
    }
    
    var body: some View {
        mainHStack
    }
}
