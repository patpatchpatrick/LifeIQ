# New Workout Review Modal Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** When the app opens, show a dismissible overlay modal for any HealthKit workouts completed in the past 14 days that the user hasn't reviewed yet, with a queue-based flow and in-modal edit navigation.

**Architecture:** An AlertHost-style ZStack overlay lives in `SQRootTabView` (main UIWindow), so it automatically appears below the existing `SQOverlayWindow` (which holds alerts/toasts at `windowLevel = .alert + 1`). A new `SQNewWorkoutReviewState` subscribes to a `WorkoutReviewReadyEvent` emitted by `SQDashboardController` after its existing workout fetch. Processed state is tracked in a new `SQWorkoutProcessedEntity` SwiftData model, keyed by `sourceId`.

**Tech Stack:** SwiftUI, SwiftData, Combine, existing BeastFitness conventions (SQColor, SQFont, SQImageSymbol, SQUserDefaults, EventHub, SQWorkoutManaging)

---

### Task 1: Add `appInstallDate` to `SQUserDefaults` and seed it in `SQLaunchManager`

**Files:**
- Modify: `BeastFitness/Utility/SQUserDefaults.swift`
- Modify: `BeastFitness/Managers/SQLaunchManager.swift`

**Step 1: Add the key and accessors to `SQUserDefaults`**

In `SQUserDefaults.swift`, add after the `keyRecentExercisesLastUsedAt` key declaration (line 20):

```swift
/// Date the app was first installed on this device
private static let keyAppInstallDate = "app.install-date"
```

Add a new public section after the exercises recents section:

```swift
// MARK: - Public API (App Install Date)

/// Returns the date the app was first installed. Nil only before `recordInstallDateIfNeeded()` is called.
var appInstallDate: Date? {
    UserDefaults.standard.object(forKey: Self.keyAppInstallDate) as? Date
}

/// Writes the install date once. Subsequent calls are no-ops.
func recordInstallDateIfNeeded() {
    guard UserDefaults.standard.object(forKey: Self.keyAppInstallDate) == nil else { return }
    UserDefaults.standard.set(Date(), forKey: Self.keyAppInstallDate)
}
```

**Step 2: Call it in `SQLaunchManager.performLaunchTasks()`**

In `SQLaunchManager.swift`, add to the body of `performLaunchTasks()`:

```swift
SQUserDefaults.shared.recordInstallDateIfNeeded()
```

**Step 3: Commit**

```bash
git add BeastFitness/Utility/SQUserDefaults.swift BeastFitness/Managers/SQLaunchManager.swift
git commit -m "feat: record app install date in UserDefaults on first launch"
```

---

### Task 2: Create `SQWorkoutProcessedEntity` SwiftData model + register in model container

**Files:**
- Create: `BeastFitness/Models/Workouts/SQWorkoutProcessedEntity.swift`
- Modify: `BeastFitness/BeastFitnessApp.swift`

**Step 1: Create the model**

Create `BeastFitness/Models/Workouts/SQWorkoutProcessedEntity.swift`:

```swift
//
//  SQWorkoutProcessedEntity.swift
//  BeastFitness
//

import SwiftData
import Foundation

/// Records that a workout has been reviewed by the user in the "New Workout" modal.
/// Keyed by `sourceId` (the stable HealthKit UUID for HK workouts, or workoutId for manual workouts).
@Model
final class SQWorkoutProcessedEntity {
    @Attribute(.unique) var sourceId: String
    var processedAt: Date

    init(sourceId: String, processedAt: Date = .now) {
        self.sourceId = sourceId
        self.processedAt = processedAt
    }
}

extension SQWorkoutProcessedEntity {

    /// Upserts a processed record for the given sourceId. No-op if already exists.
    static func markAsProcessed(sourceId: String, context: ModelContext) {
        let descriptor = FetchDescriptor<SQWorkoutProcessedEntity>(
            predicate: #Predicate { $0.sourceId == sourceId }
        )
        guard (try? context.fetch(descriptor).first) == nil else { return }
        context.insert(SQWorkoutProcessedEntity(sourceId: sourceId))
        try? context.save()
    }

    /// Returns the set of all processed sourceIds.
    static func fetchProcessedSourceIds(context: ModelContext) -> Set<String> {
        let descriptor = FetchDescriptor<SQWorkoutProcessedEntity>()
        let entities = (try? context.fetch(descriptor)) ?? []
        return Set(entities.map { $0.sourceId })
    }
}
```

**Step 2: Register in the model container**

In `BeastFitnessApp.swift`, add `SQWorkoutProcessedEntity.self` to the `.modelContainer` modifier:

```swift
.modelContainer(for: [
    SQDailyCheckInEntity.self,
    SQWorkoutSessionEntity.self,
    SQMetricDefinitionEntity.self,
    SQSyncMetadataEntity.self,
    SQWorkoutProcessedEntity.self   // ← add this
])
```

**Step 3: Commit**

```bash
git add BeastFitness/Models/Workouts/SQWorkoutProcessedEntity.swift BeastFitness/BeastFitnessApp.swift
git commit -m "feat: add SQWorkoutProcessedEntity SwiftData model to track reviewed workouts"
```

---

### Task 3: Add processed-workout helpers to `SQWorkoutManaging` + `SQWorkoutManager`

**Files:**
- Modify: `BeastFitness/Managers/SQWorkoutManager.swift`

**Step 1: Add methods to the `SQWorkoutManaging` protocol**

After the `getWorkouts(for:modelContext:)` declaration in the protocol (line 18), add:

```swift
func markWorkoutsAsProcessed(_ workouts: [SQWorkoutSessionable], context: ModelContext)
func fetchProcessedSourceIds(context: ModelContext) -> Set<String>
```

**Step 2: Implement in `SQWorkoutManager`**

Add a new extension or methods at the bottom of the class (before the closing `}`):

```swift
func markWorkoutsAsProcessed(_ workouts: [SQWorkoutSessionable], context: ModelContext) {
    for workout in workouts {
        let sourceId = workout.workoutSource.sourcableData.sourceId
        SQWorkoutProcessedEntity.markAsProcessed(sourceId: sourceId, context: context)
    }
    SQLogger.shared.log(
        "Marked \(workouts.count) workout(s) as processed",
        .debug,
        context: .workoutManager
    )
}

func fetchProcessedSourceIds(context: ModelContext) -> Set<String> {
    SQWorkoutProcessedEntity.fetchProcessedSourceIds(context: context)
}
```

**Step 3: Commit**

```bash
git add BeastFitness/Managers/SQWorkoutManager.swift
git commit -m "feat: add markWorkoutsAsProcessed and fetchProcessedSourceIds to SQWorkoutManager"
```

---

### Task 4: Add `WorkoutReviewEvent` to `EventHub`

**Files:**
- Modify: `BeastFitness/StateManagement/EventHub.swift`

**Step 1: Add the event enum**

After the `ModalEvent` enum (line 43), add:

```swift
enum WorkoutReviewEvent {
    case workoutsReadyForReview([SQWorkoutSessionable])
}
```

**Step 2: Add the subject to `EventHub`**

After `let modalEvents = PassthroughSubject<ModalEvent, Never>()` (line 52), add:

```swift
let workoutReviewEvents = PassthroughSubject<WorkoutReviewEvent, Never>()
```

**Step 3: Commit**

```bash
git add BeastFitness/StateManagement/EventHub.swift
git commit -m "feat: add WorkoutReviewEvent to EventHub"
```

---

### Task 5: Create `SQNewWorkoutReviewState`

**Files:**
- Create: `BeastFitness/Managers/SQNewWorkoutReviewState.swift`

**Step 1: Create the file**

```swift
//
//  SQNewWorkoutReviewState.swift
//  BeastFitness
//

import Foundation
import Observation
import Combine
import SwiftData

@MainActor
@Observable
final class SQNewWorkoutReviewState {
    private let hub: EventHub
    private let workoutManager: SQWorkoutManaging
    private var cancellables = Set<AnyCancellable>()

    private(set) var queue: [SQWorkoutSessionable] = []
    var currentWorkout: SQWorkoutSessionable? { queue.first }
    var isPresented: Bool { currentWorkout != nil }
    var queueCount: Int { queue.count }

    init(hub: EventHub, workoutManager: SQWorkoutManaging = SQWorkoutManager()) {
        self.hub = hub
        self.workoutManager = workoutManager
        subscribeToEvents()
    }

    private func subscribeToEvents() {
        hub.workoutReviewEvents.sink { [weak self] event in
            guard let self else { return }
            switch event {
            case .workoutsReadyForReview(let workouts):
                // Only update if queue is empty — don't disrupt an in-progress review
                guard queue.isEmpty else { return }
                queue = workouts
                SQLogger.shared.log(
                    "Workout review queue loaded with \(workouts.count) workout(s)",
                    .info,
                    context: .workoutManager
                )
            }
        }.store(in: &cancellables)
    }

    /// Marks the current (first) workout as processed and advances the queue.
    func markCurrentAsProcessed(context: ModelContext) {
        guard let workout = currentWorkout else { return }
        workoutManager.markWorkoutsAsProcessed([workout], context: context)
        queue.removeFirst()
    }

    /// Marks every workout in the queue as processed and clears it.
    func markAllAsProcessed(context: ModelContext) {
        workoutManager.markWorkoutsAsProcessed(queue, context: context)
        queue.removeAll()
    }
}
```

**Step 2: Commit**

```bash
git add BeastFitness/Managers/SQNewWorkoutReviewState.swift
git commit -m "feat: add SQNewWorkoutReviewState for workout review queue management"
```

---

### Task 6: Add `newWorkoutReviewState` to `SQAppState`

**Files:**
- Modify: `BeastFitness/StateManagement/SQAppState.swift`

**Step 1: Add the property**

After `let dropDownMenuState: SQDropDownMenuState` (line 36), add:

```swift
let newWorkoutReviewState: SQNewWorkoutReviewState
```

**Step 2: Initialize in `init()`**

After `self.dropDownMenuState = .init()` (line 53), add:

```swift
self.newWorkoutReviewState = .init(hub: hub)
```

**Step 3: Commit**

```bash
git add BeastFitness/StateManagement/SQAppState.swift
git commit -m "feat: add newWorkoutReviewState to SQAppState"
```

---

### Task 7: Hook into `SQDashboardController.loadUI` to emit `WorkoutReviewReadyEvent`

**Files:**
- Modify: `BeastFitness/ViewModels/Dashboard/SQDashboardController.swift`

**Step 1: Add the `processNewWorkoutReviews` helper method**

Add a new private method to `SQDashboardController` (before the closing `}`):

```swift
private func processNewWorkoutReviews(
    workouts: [SQWorkoutSessionable],
    context: ModelContext
) {
    guard let installDate = SQUserDefaults.shared.appInstallDate else {
        SQLogger.shared.log("appInstallDate missing — skipping workout review processing", .debug, context: .dashboard)
        return
    }

    let fourteenDaysAgo = Calendar.current.date(byAdding: .day, value: -14, to: .now) ?? .now
    let processedIds = workoutManager.fetchProcessedSourceIds(context: context)

    let reviewableWorkouts = workouts.filter { workout in
        guard let startDate = workout.startDate else { return false }
        let sourceId = workout.workoutSource.sourcableData.sourceId
        return startDate >= fourteenDaysAgo
            && startDate >= installDate
            && !processedIds.contains(sourceId)
    }

    guard !reviewableWorkouts.isEmpty else { return }

    let sorted = reviewableWorkouts.sorted {
        ($0.startDate ?? .distantPast) > ($1.startDate ?? .distantPast)
    }

    SQLogger.shared.log(
        "Emitting \(sorted.count) workout(s) ready for review",
        .info,
        context: .dashboard
    )
    state.hub.workoutReviewEvents.send(.workoutsReadyForReview(sorted))
}
```

**Step 2: Call it from `loadUI` after `state.setLoading(false)`**

In `loadUI`, after `state.setLoading(false)` (line 271) and before the catch block, add:

```swift
// Emit any unreviewed recent workouts for the new workout review modal
processNewWorkoutReviews(workouts: past30DaysWorkouts, context: context)
```

`past30DaysWorkouts` is already fetched unconditionally (line 145). No additional fetch needed.

**Step 3: Commit**

```bash
git add BeastFitness/ViewModels/Dashboard/SQDashboardController.swift
git commit -m "feat: emit WorkoutReviewReadyEvent from dashboard after workout fetch"
```

---

### Task 8: Add `customNavigationTitle` parameter to `SQWorkoutSummaryView`

**Files:**
- Modify: `BeastFitness/Views/WorkoutSummary/SQWorkoutSummaryView.swift`

**Step 1: Add the parameter**

In `SQWorkoutSummaryView`, add a new stored property after `let mainStackHorizPadding` (line 15):

```swift
var customNavigationTitle: String? = nil
```

**Step 2: Use it in `body`**

Replace `.navigationTitle("Workout summary")` (line 80) with:

```swift
.navigationTitle(customNavigationTitle ?? "Workout summary")
```

**Step 3: Commit**

```bash
git add BeastFitness/Views/WorkoutSummary/SQWorkoutSummaryView.swift
git commit -m "feat: add customNavigationTitle parameter to SQWorkoutSummaryView"
```

---

### Task 9: Create `SQNewWorkoutReviewHost`

**Files:**
- Create: `BeastFitness/Views/NewWorkoutReview/SQNewWorkoutReviewHost.swift`

**Step 1: Create the file**

```swift
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
                .id(workout.id) // force redraw when workout changes
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
```

**Note on `SQWorkoutSummaryController` instantiation:** The host creates a fresh `WorkoutSummaryState` and `SQWorkoutSummaryController` per workout (not the `.default` singleton) to avoid corrupting `SQWorkoutsListView`'s cached controllers, which also reference `.default`.

**Step 2: Commit**

```bash
git add BeastFitness/Views/NewWorkoutReview/SQNewWorkoutReviewHost.swift
git commit -m "feat: add SQNewWorkoutReviewHost overlay view for new workout review flow"
```

---

### Task 10: Register `SQNewWorkoutReviewHost` in `SQRootTabView`

**Files:**
- Modify: `BeastFitness/Views/Root/SQRootTabView.swift`

**Step 1: Wrap `body` in a ZStack and add the host**

The current `body` is:
```swift
var body: some View {
    mainTabViewWithSheets
        .frame(maxHeight: .infinity)
        .background(Color.purple)
        .accentColor(SQColor.textPrimary.color)
        .onOpenURL(perform: { url in
            viewModel.deepLinkManager.handleUriDeepLink(for: url)
        })
}
```

Replace `body` with:

```swift
var body: some View {
    ZStack {
        mainTabViewWithSheets

        SQNewWorkoutReviewHost(
            reviewState: SQAppState.shared.newWorkoutReviewState
        )
    }
    .frame(maxHeight: .infinity)
    .background(Color.purple)
    .accentColor(SQColor.textPrimary.color)
    .onOpenURL(perform: { url in
        viewModel.deepLinkManager.handleUriDeepLink(for: url)
    })
}
```

Because `SQNewWorkoutReviewHost` is in the **main UIWindow** (not `SQOverlayWindow`), the `SQOverlayWindow` (which holds alerts/toasts at `windowLevel = .alert + 1`) automatically renders on top of it — no z-index management needed.

**Step 2: Commit**

```bash
git add BeastFitness/Views/Root/SQRootTabView.swift
git commit -m "feat: register SQNewWorkoutReviewHost in SQRootTabView"
```

---

## Testing the full flow

1. Delete `SQWorkoutProcessedEntity` records from the simulator (or reinstall the app) to clear processed state
2. Open the app on a device/simulator that has HealthKit workouts within the past 14 days
3. The dashboard should load, `processNewWorkoutReviews` fires, and the review modal appears
4. Tap "Review Next Workout" to step through the queue
5. Tap the edit button in the summary toolbar → `SQWorkoutSessionView` should push within the modal's `NavigationStack`
6. Save the edit → pop back to summary → tap "Done"
7. Re-open the app → verified workouts should no longer appear (they're in `SQWorkoutProcessedEntity`)
8. Alert presented during modal → verify it renders above the modal (overlay window takes precedence)
