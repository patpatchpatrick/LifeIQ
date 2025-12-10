//
//  SQWorkoutsListItem.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/6/25.
//

import SwiftUI

struct SQWorkoutsListItem: View {
    let viewModel: SQWorkoutsListItemViewModel
    
    @ViewBuilder
    var workoutImage: some View {
        ZStack {
            Circle()
                .sqForegroundColor(.backgroundSecondaryLight)
                .frame(width: 40)
            
            SQImageView(image: .init(symbol: viewModel.workoutImageSymbol, symbolStyle: .colorWithFont(.textPrimary, font: .body)))
                .frame(width: 20)
        }
    }
    
    @ViewBuilder
    var workoutTitleAndDescription: some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            Text(viewModel.title)
                .sqFont(.bodyBold)
                .sqForegroundColor(.textPrimary)
            
            if let subtitle = viewModel.subtitle {
                Text(subtitle)
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textSecondary)
            }
        }
    }
    
    var mainHStack: some View {
        HStack(alignment: .top, spacing: 0) {
            
            workoutImage
                .padding(.horizontal, .SQSpace.m)
            
            workoutTitleAndDescription
            
            Spacer()
        }
    }
    
    var body: some View {
        mainHStack
    }
}
