//
//  SQDashboardActivityListRowView.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 2/7/26.
//

import SwiftUI

struct SQDashboardActivityListRowView: View {
    @Bindable var viewModel: SQDashboardActivityRowViewModel
    
    var workoutsStack: some View {
        VStack(spacing: .SQSpace.m) {
            ForEach(Array(viewModel.workoutGroupViewModels.enumerated()), id: \.1) { (index, workoutGroupViewModel) in
                
                
                SQDashboardWorkoutGroupView(viewModel: workoutGroupViewModel)
                    .padding(.top, index == 0 ? .SQSpace.s : 0)
                    .padding(.bottom, index == viewModel.workoutGroupViewModels.count - 1 ? .SQSpace.xl : 0)
                
                if index != viewModel.workoutGroupViewModels.count - 1 {
                    Divider()
                        .sqTintColor(.divider(1))
                        .padding(.top, .SQSpace.xl)
                        .padding(.bottom, .SQSpace.xl)
                }
            }
        }
    }
    
    var mainStack: some View {
        VStack(alignment: .leading, spacing: 0) {

            workoutsStack
            
            if let ctaViewModel = viewModel.ctaViewModel {
                SQCallToAction(viewModel: ctaViewModel)
            }

        }
    }
    
    var body: some View {
        mainStack
    }
}

//
//  SQDashboardWorkoutGroupView.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/13/25.
//

import SwiftUI

struct SQDashboardWorkoutGroupView: View {
    let viewModel: SQDashboardWorkoutGroupViewModel
    private let statColumns = [
        GridItem(.adaptive(minimum: 86), spacing: .SQSpace.s, alignment: .leading)
    ]

    @ViewBuilder
    var workoutImage: some View {
        RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
            .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.82 : 1))
            .frame(width: 38, height: 38)
            .overlay(
                RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                    .stroke(SQColor.glassStroke.color, lineWidth: 1)
            )
            .overlay(
                SQImageView(
                    image: .init(
                        symbol: viewModel.workoutImageSymbol,
                        symbolStyle: .colorWithFont(.dashboardGlowBlue, font: .body)
                    )
                )
                .frame(width: 18, height: 18)
            )
    }
    
    @ViewBuilder
    var workoutTitleAndDescription: some View {
        VStack(alignment: .leading, spacing: .SQSpace.s) {
            Text(viewModel.title)
                .sqFont(.bodyBold)
                .sqForegroundColor(.textPrimary)
            
            if let subtitle = viewModel.subtitle {
                Text(subtitle)
                    .sqFont(.body)
                    .sqForegroundColor(.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            if !viewModel.workoutStatsItems.isEmpty {
                LazyVGrid(columns: statColumns, alignment: .leading, spacing: .SQSpace.s) {
                    ForEach(viewModel.workoutStatsItems) { item in
                        workoutStatItem(item)
                    }
                }
                .padding(.top, .SQSpace.xs)
            }
        }
    }

    @ViewBuilder
    private func workoutStatItem(_ item: SQDashboardWorkoutGroupViewModel.WorkoutStatItem) -> some View {
        if item.isPremiumLocked {
            Button {
                SQSubscriptionManager.displaySubscriptionScreen(
                    source: "dashboard_activities_locked_stat",
                    feature: item.id
                )
            } label: {
                workoutStatItemContent(item)
            }
            .buttonStyle(.plain)
        } else {
            workoutStatItemContent(item)
        }
    }

    private func workoutStatItemContent(_ item: SQDashboardWorkoutGroupViewModel.WorkoutStatItem) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.title.uppercased())
                .sqFont(.headerSmall)
                .sqForegroundColor(.textSecondary)

            ZStack(alignment: .leading) {
                Text(item.value)
                    .sqFont(.bodySmall)
                    .sqForegroundColor(.textPrimary)
                    .blur(radius: item.isPremiumLocked ? 5 : 0)

                if item.isPremiumLocked {
                    Text(item.premiumLockText.isEmpty ? SQSubscriptionManager.weeklyScorePreviewCompactText : item.premiumLockText)
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, .SQSpace.s)
        .padding(.horizontal, .SQSpace.m)
        .background(
            RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                .fill(
                    (item.accentColor?.color ?? SQColor.glassCardTint.color)
                        .opacity(item.accentColor == nil
                            ? (SQColor.isDarkMode ? 0.65 : 0.95)
                            : (SQColor.isDarkMode ? 0.18 : 0.10))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                .stroke(
                    (item.accentColor?.color ?? SQColor.glassStroke.color)
                        .opacity(item.accentColor == nil ? 1 : 0.45),
                    lineWidth: 1
                )
        )
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
            .contentShape(Rectangle())
            .onTapGesture(perform: viewModel.displayWorkoutsSheet)
    }
}

#Preview {
    SQDashboardWorkoutGroupView(viewModel: .init(activityType: .running, workouts: .init(workouts: .mock)))
        .preferredColorScheme(.dark)
}
