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
    @State private var controllerCache: [String: SQWorkoutSummaryController] = [:]

    var body: some View {
        ZStack {
            if let workout = reviewState.currentWorkout {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    NavigationStack(path: $navigationPath) {
                        SQWorkoutSummaryView(
                            controller: cachedController(for: workout),
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
        .onChange(of: reviewState.currentWorkout?.id) { _, _ in
            navigationPath = NavigationPath()
        }
    }

    // MARK: - Bottom Action Bar

    @ViewBuilder
    var actionBar: some View {
        HStack(spacing: .SQSpace.m) {
            if reviewState.queueCount > 1 {
                Button("Skip Remaining") {
                    reviewState.markAllAsProcessed(context: modelContext)
                }
                .sqFont(.bodySmall)
                .sqForegroundColor(.textSecondary)

                Spacer()

                Button("Review Next Workout") {
                    reviewState.markCurrentAsProcessed(context: modelContext)
                }
                .sqFont(.bodySmallBold)
                .sqForegroundColor(.textPrimary)
            } else {
                Spacer()
                Button("Done") {
                    reviewState.markCurrentAsProcessed(context: modelContext)
                }
                .sqFont(.bodySmallBold)
                .sqForegroundColor(.textPrimary)
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

    /// Creates a fresh SQWorkoutSummaryController per workout (not the .default singleton)
    /// to avoid corrupting SQWorkoutsListView's cached controllers.
    private func cachedController(for workout: SQWorkoutSessionable) -> SQWorkoutSummaryController {
        let key = workout.id
        if let cached = controllerCache[key] { return cached }

        let summaryState = WorkoutSummaryState(hub: SQAppState.shared.hub)
        let controller = SQWorkoutSummaryController(
            state: summaryState,
            onPushEditWorkoutView: { editWorkout in
                navigationPath.append(SQNavRoute.WorkoutsList.editWorkout(workout: editWorkout))
            },
            onDismiss: {
                reviewState.markCurrentAsProcessed(context: modelContext)
            }
        )
        Task { await controller.load(workout: workout) }

        controllerCache[key] = controller
        return controller
    }
}
