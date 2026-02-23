# Workout Performance Section Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a collapsible "Performance" section to `SQWorkoutSummaryView` showing VO2 max with all-time percentile rank for running/walking/hiking workouts, using `SQDashboardPerformanceRow` and `SQDashboardSubsection` to stay visually consistent with the dashboard.

**Architecture:** Mirror the existing route-loading pattern — `SQWorkoutSummaryController.loadPerformanceDataIfNeeded()` fetches VO2 max for the workout's calendar day and all-time values for percentile ranking via `SQPercentileCalculator`, then hands `[SQPerformanceRowData]` to a new `loadPerformanceData()` method on `WorkoutSummaryState`. The view switches all section wrappers from the custom `SQWorkoutSummarySection` to `SQDashboardSubsection` (collapsible, consistent with dashboard), and renders the performance rows with `SQDashboardPerformanceRow`. No changes to `SQWorkoutSessionVisibleStat` — trend/color indicators are a future task.

**Tech Stack:** HealthKit (`HKSampleQuery`), existing `SQVO2MaxSample` / `SQHealthKitManaging` / `SQPercentileCalculator` / `SQPerformanceRowData` / `SQDashboardPerformanceRow` / `SQDashboardSubsection`.

---

### Task 1: Add `fetchVO2MaxSamples(upTo:limit:)` to `SQHealthKitManaging` and `SQHealthKitManager`

**Files:**
- Modify: `BeastFitness/Utility/ThirdParty/SQHealthKitManager.swift`
- Modify: `BeastFitness/Utility/ThirdParty/SQHealthKitManager+VO2Max.swift`

**Context:**
The existing `fetchVO2MaxSamples(_ timeRange: SQTimeRange)` works for predefined ranges. We need a variant that returns the N most-recent samples whose `endDate` falls within or before the calendar day of a given `date`. Using "end of the next calendar day" as the strict upper bound ensures we catch samples recorded slightly after a workout ends without crossing into the next day's data.

**Step 1: Add method signature to `SQHealthKitManaging` protocol**

In `SQHealthKitManager.swift`, add to the protocol body:

```swift
/// The N most-recent VO₂ max samples recorded on or before the calendar day of `date`,
/// sorted descending by endDate.
func fetchVO2MaxSamples(upTo date: Date, limit: Int) async throws -> [SQVO2MaxSample]
```

**Step 2: Implement in `SQHealthKitManager+VO2Max.swift`**

Add a new extension block at the bottom of the file:

```swift
extension SQHealthKitManager {

    @MainActor
    func fetchVO2MaxSamples(upTo date: Date, limit: Int) async throws -> [SQVO2MaxSample] {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw SQHealthKitError.healthDataUnavailable
        }

        try await Self.healthStore.requestAuthorization(
            toShare: allTypesToReadWrite,
            read: allTypesToReadWrite
        )

        let vo2Type = HKQuantityType.quantityType(forIdentifier: .vo2Max)!

        // Include all samples through the end of the calendar day containing `date`
        let startOfNextDay = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: 1, to: date)!
        )
        let predicate = HKQuery.predicateForSamples(
            withStart: .distantPast,
            end: startOfNextDay,
            options: .strictEndDate
        )
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        let samples: [HKQuantitySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: vo2Type,
                predicate: predicate,
                limit: limit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: samples as? [HKQuantitySample] ?? [])
            }
            Self.healthStore.execute(query)
        }

        return samples.map(Self.mapVO2MaxSample)
    }
}
```

**Step 3: Commit**

```bash
git add "BeastFitness/Utility/ThirdParty/SQHealthKitManager.swift" \
        "BeastFitness/Utility/ThirdParty/SQHealthKitManager+VO2Max.swift"
git commit -m "feat: add fetchVO2MaxSamples(upTo:limit:) to HealthKit manager"
```

---

### Task 2: Add performance state to `WorkoutSummaryStating` and `WorkoutSummaryState`

**Files:**
- Modify: `BeastFitness/StateManagement/WorkoutsSummaryState.swift`

**Context:**
Both the protocol and concrete class live in this file. Add `performanceRowData: [SQPerformanceRowData]`, `shouldShowPerformanceSection: Bool`, and `loadPerformanceData(rowData:)` mirroring the existing route pattern. `reset()` must also clear performance data so re-opening a different workout doesn't show stale rows.

**Step 1: Add to `WorkoutSummaryStating` protocol**

```swift
var performanceRowData: [SQPerformanceRowData] { get }
var shouldShowPerformanceSection: Bool { get }
func loadPerformanceData(rowData: [SQPerformanceRowData])
```

**Step 2: Add stored property and computed property to `WorkoutSummaryState`**

```swift
private(set) var performanceRowData: [SQPerformanceRowData] = []

var shouldShowPerformanceSection: Bool { !performanceRowData.isEmpty }
```

**Step 3: Implement `loadPerformanceData` on `WorkoutSummaryState`**

```swift
func loadPerformanceData(rowData: [SQPerformanceRowData]) {
    performanceRowData = rowData
}
```

**Step 4: Clear in `reset()`**

Add this line to the `reset()` method body:

```swift
performanceRowData = []
```

**Step 5: Commit**

```bash
git add "BeastFitness/StateManagement/WorkoutsSummaryState.swift"
git commit -m "feat: add performance state to WorkoutSummaryState"
```

---

### Task 3: Add `loadPerformanceDataIfNeeded()` to `SQWorkoutSummaryController`

**Files:**
- Modify: `BeastFitness/ViewModels/Workouts/WorkoutSummary/SQWorkoutSummaryController.swift`

**Context:**
Add a new `// MARK: - Performance Handling` extension, mirroring `// MARK: - Route Handling`. The method guards on: HK workout, running/walking/hiking activity, and valid `endDate`. It fetches 1 VO2 max sample for the workout's calendar day (using the new method from Task 1) and validates it actually falls on that day. If found, it fetches all-time values for percentile ranking, deduplicates by calendar day (best per day, matching leaderboard logic), and builds a single `SQPerformanceRowData` row using `SQPercentileCalculator`. Errors are swallowed — the section just doesn't appear.

Call `loadPerformanceDataIfNeeded()` from `load(workout:)` after `loadRouteIfNeeded()`.

**Step 1: Update `load(workout:)`**

```swift
func load(workout: any SQWorkoutSessionable) async {
    state.reset()
    await state.load(workout: workout)
    await loadRouteIfNeeded()
    await loadPerformanceDataIfNeeded()
}
```

**Step 2: Add the new extension**

```swift
// MARK: - Performance Handling

extension SQWorkoutSummaryController {

    func loadPerformanceDataIfNeeded() async {
        guard let workout = state.currentWorkout else { return }
        guard case .hkWorkout = workout.workoutSource else { return }

        switch workout.activityType {
        case .running, .walking, .hiking:
            break
        default:
            return
        }

        guard let workoutEndDate = workout.endDate else { return }

        do {
            // Fetch the most recent VO2 max sample on the workout's calendar day
            let daySamples = try await healthKitManager.fetchVO2MaxSamples(upTo: workoutEndDate, limit: 1)
            guard let sample = daySamples.first,
                  Calendar.current.isDate(sample.endDate, inSameDayAs: workoutEndDate) else {
                return
            }

            // Fetch all-time values for percentile ranking, deduped by calendar day
            let allTimeSamples = try await healthKitManager.fetchVO2MaxSamples(.allTime)
            let calendar = Calendar.current
            var bestByDay: [Date: Double] = [:]
            for s in allTimeSamples {
                let dayStart = calendar.startOfDay(for: s.startDate)
                bestByDay[dayStart] = max(bestByDay[dayStart] ?? 0, s.value)
            }
            let historicalValues = Array(bestByDay.values)

            let percentileRank = SQPercentileCalculator.calculatePercentile(
                currentBest: sample.value,
                historicalValues: historicalValues,
                isLowerBetter: false
            )

            let rowData = SQPerformanceRowData(
                id: "vo2-max",
                icon: SQImageSymbol.heart.rawValue,
                title: "VO2 Max",
                bestValue: String(format: "%.1f", sample.value),
                unit: "mL/kg/min",
                percentileRank: percentileRank
            )

            state.loadPerformanceData(rowData: [rowData])
        } catch {
            SQLogger.shared.log(
                "Failed to load VO2 max for performance section: \(error.localizedDescription)",
                .error,
                context: .workoutSummary
            )
        }
    }
}
```

**Step 3: Commit**

```bash
git add "BeastFitness/ViewModels/Workouts/WorkoutSummary/SQWorkoutSummaryController.swift"
git commit -m "feat: load VO2 max performance data in SQWorkoutSummaryController"
```

---

### Task 4: Update `SQWorkoutSummaryView` — collapsible sections + Performance

**Files:**
- Modify: `BeastFitness/Views/WorkoutSummary/SQWorkoutSummaryView.swift`

**Context:**
Three changes in one file:

1. **Remove `SQWorkoutSummarySection`** — it was a non-collapsible custom wrapper added recently. `SQDashboardSubsection` replaces it entirely.

2. **Switch all sections to `SQDashboardSubsection`** — Route, Stats, and Performance all use the same collapsible wrapper with `backgroundSecondary` card, chevron, and fade+slide animation. Each section needs a `@State var <name>Collapsed = false` binding. All start expanded.

3. **Add Performance section** — rendered as `ForEach(controller.state.performanceRowData) { SQDashboardPerformanceRow(data: $0) }` inside a `SQDashboardSubsection`. Guard on `controller.state.shouldShowPerformanceSection`. Placed between Route and Stats.

**`statColumnWidth` stays correct:** `SQDashboardSubsection` applies `sectionRowHorizPadding = .SQSpace.l` (12pt) on each side — the same value already subtracted in the formula.

**Step 1: Add `@State` collapse properties to `SQWorkoutSummaryView`**

Add after the existing stored properties:

```swift
@State private var routeSectionCollapsed = false
@State private var performanceSectionCollapsed = false
@State private var statsSectionCollapsed = false
```

**Step 2: Replace `mainStack` content**

Replace the route and stats blocks with:

```swift
if controller.state.shouldShowRouteView {
    SQDashboardSubsection(title: "Route", isCollapsed: $routeSectionCollapsed) {
        SQWorkoutRouteMapView(
            isLoading: controller.state.isLoadingRoute,
            locations: controller.state.routeLocations,
            errorMessage: controller.state.routeLoadErrorMessage
        )
    }
    .padding(.bottom, .SQSpace.xl)
}

if controller.state.shouldShowPerformanceSection {
    SQDashboardSubsection(title: "Performance", isCollapsed: $performanceSectionCollapsed) {
        VStack(spacing: SQDashboardView.uiConfig.sectionRowSpacing) {
            ForEach(controller.state.performanceRowData) { row in
                SQDashboardPerformanceRow(data: row)
            }
        }
    }
    .padding(.bottom, .SQSpace.xl)
}

SQDashboardSubsection(title: "Stats", isCollapsed: $statsSectionCollapsed) {
    VStack(spacing: .SQSpace.l) {
        ForEach(controller.state.workoutStatsRows) { row in
            SQWorkoutSummaryStatsRow(row: row, columnWidth: statColumnWidth)
        }
    }
}
```

**Step 3: Delete `SQWorkoutSummarySection`**

Remove the entire `SQWorkoutSummarySection<Content: View>` struct (added in the prior session). It's no longer used.

**Step 4: Commit**

```bash
git add "BeastFitness/Views/WorkoutSummary/SQWorkoutSummaryView.swift"
git commit -m "feat: collapsible sections + Performance section in SQWorkoutSummaryView"
```

---

## Summary of changed files

| File | Change |
|------|--------|
| `BeastFitness/Utility/ThirdParty/SQHealthKitManager.swift` | Add `fetchVO2MaxSamples(upTo:limit:)` to protocol |
| `BeastFitness/Utility/ThirdParty/SQHealthKitManager+VO2Max.swift` | Implement `fetchVO2MaxSamples(upTo:limit:)` |
| `BeastFitness/StateManagement/WorkoutsSummaryState.swift` | Add `performanceRowData`, `shouldShowPerformanceSection`, `loadPerformanceData()`, clear in `reset()` |
| `BeastFitness/ViewModels/Workouts/WorkoutSummary/SQWorkoutSummaryController.swift` | Add `loadPerformanceDataIfNeeded()`, call from `load(workout:)` |
| `BeastFitness/Views/WorkoutSummary/SQWorkoutSummaryView.swift` | Remove `SQWorkoutSummarySection`, switch to `SQDashboardSubsection`, add Performance section, add collapse `@State` vars |
