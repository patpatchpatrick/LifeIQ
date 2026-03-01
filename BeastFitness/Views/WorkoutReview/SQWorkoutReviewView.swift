//
//  SQWorkoutReviewView.swift
//  BeastFitness
//

import SwiftUI
import SwiftData

struct SQWorkoutReviewView: View {
    @State var reviewState: SQWorkoutReviewController
    @Environment(\.modelContext) private var modelContext
    @State private var summaryController: SQWorkoutSummaryController?
    
    @ViewBuilder
    func workoutView(workout: SQWorkoutSessionable) -> some View {
        VStack(spacing: 0) {
            SQWorkoutSummaryView(
                controller: .init(workout: workout, mode: .review),
                backgroundColor: .backgroundSheet
            )
            .navigationBarTitleDisplayMode(.inline)
            
            Spacer()

            actionBar
        }
        .background(SQColor.backgroundSheet.color)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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
        HStack(spacing: .SQSpace.m) {
            if reviewState.queueCount > 1 {
                SQButton(
                    shouldHugContent: false,
                    title: "Skip Remaining",
                    action: {
                        reviewState.markAllAsProcessed(context: modelContext)
                    }
                )

                Spacer()

                SQButton(
                    shouldHugContent: false,
                    title: "Review Next",
                    action: {
                        reviewState.markCurrentAsProcessed(context: modelContext)
                    }
                )
            } else {
                Spacer()
                
                SQButton(
                    shouldHugContent: false,
                    title: "Done",
                    action: {
                        reviewState.markCurrentAsProcessed(context: modelContext)
                    }
                )
            }
        }
        .padding(.horizontal, .SQSpace.xl)
        .padding(.vertical, .SQSpace.l)
        .background(SQColor.backgroundSheet.color)
        .interactiveDismissDisabled()
    }

}
