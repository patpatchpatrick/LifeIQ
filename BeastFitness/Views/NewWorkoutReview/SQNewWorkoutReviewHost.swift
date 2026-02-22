//
//  SQNewWorkoutReviewHost.swift
//  BeastFitness
//

import SwiftUI
import SwiftData

struct SQNewWorkoutReviewHost: View {
    @Bindable var reviewState: SQNewWorkoutReviewState
    @Environment(\.modelContext) private var modelContext
    @State private var navigationPath = NavigationPath()
    @State private var summaryController: SQWorkoutSummaryController?

    var body: some View {
        ZStack {
            if let workout = reviewState.currentWorkout, let controller = summaryController {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    NavigationStack(path: $navigationPath) {
                        SQWorkoutSummaryView(
                            controller: controller,
                            customNavigationTitle: navigationTitle(for: workout)
                        )
                        .navigationDestination(for: SQNavRoute.WorkoutsList.self) { route in
                            switch route {
                            case .editWorkout(let editWorkout):
                                SQWorkoutSessionView(
                                    isBeingDisplayedWithinNavStack: true,
                                    controller: .default(
                                        for: editWorkout,
                                        onDismiss: { navigationPath.removeLast() }
                                    )
                                )
                            case .workoutView:
                                EmptyView()
                            }
                        }
                    }

                    actionBar
                }
                .background(SQColor.background.color)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal, .SQSpace.m)
                .padding(.top, 80)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .id(workout.id)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: reviewState.isPresented)
        .task(id: reviewState.currentWorkout?.id) {
            summaryController = nil
            navigationPath = NavigationPath()
            guard let workout = reviewState.currentWorkout else { return }
            let state = WorkoutSummaryState(hub: SQAppState.shared.hub)
            let controller = SQWorkoutSummaryController(
                state: state,
                onPushEditWorkoutView: { editWorkout in
                    navigationPath.append(SQNavRoute.WorkoutsList.editWorkout(workout: editWorkout))
                },
                onDismiss: {
                    reviewState.markCurrentAsProcessed(context: modelContext)
                }
            )
            summaryController = controller
            await controller.load(workout: workout)
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
                    title: "Review next",
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
        .background(SQColor.background.color)
    }

    // MARK: - Helpers

    private func navigationTitle(for workout: SQWorkoutSessionable) -> String {
        let dateString = workout.startDate?.formattedString(with: .medium) ?? ""
        return "New Workout · \(dateString)"
    }
}
