//
//  SQWorkoutReviewView.swift
//  BeastFitness
//

import SwiftUI
import SwiftData

struct SQWorkoutReviewView: View {
    @State var reviewState: SQWorkoutReviewController
    @Environment(\.modelContext) private var modelContext
    
    @ViewBuilder
    func workoutView(workout: SQWorkoutSessionable) -> some View {
        SQWorkoutSummaryView(
            controller: .init(workout: workout, mode: .review)
        )
        .safeAreaInset(edge: .bottom, spacing: 0) {
            actionBar
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .id(workout.id)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: reviewState.isPresented)
    }

    var body: some View {
        if let workout = reviewState.currentWorkout {
            workoutView(workout: workout)
        } else {
            EmptyView()
        }
    }

    // MARK: - Bottom Action Bar

    @ViewBuilder
    var actionBar: some View {
        VStack(spacing: 0) {
            Divider()
                .sqTintColor(.glassStroke)

            HStack(spacing: .SQSpace.m) {
                if reviewState.queueCount > 1 {
                    SQButton(
                        style: .secondary,
                        shouldHugContent: false,
                        title: "Skip Remaining",
                        action: {
                            reviewState.markAllAsProcessed(context: modelContext)
                        }
                    )

                    SQButton(
                        style: .glassPrimary,
                        shouldHugContent: false,
                        title: "Review Next",
                        action: {
                            reviewState.markCurrentAsProcessed(context: modelContext)
                        }
                    )
                } else {
                    SQButton(
                        style: .glassPrimary,
                        shouldHugContent: false,
                        title: "Done",
                        action: {
                            reviewState.markCurrentAsProcessed(context: modelContext)
                        }
                    )
                }
            }
            .padding(.horizontal, .SQSpace.xl)
            .padding(.top, .SQSpace.m)
            .padding(.bottom, .SQSpace.l)
        }
        .background(.ultraThinMaterial)
        .interactiveDismissDisabled()
    }

}
