# SQWorkoutStatsManager + Real Workout Highlights Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Introduce `SQWorkoutStatsManager` to own workout metric definitions, performance data loading, and highlight generation — replacing mock highlights with real data on the workout review screen.

**Architecture:** A new `SQWorkoutStatsManager` (with protocol) is initialized with `healthKitManager` and `workoutManager`. Metric config moves from `SQWorkoutManager` into it. The manager generates `[SQWorkoutReviewHighlight]` from existing `performanceRowData`, using percentile thresholds for most metrics and a before/after VO2 Max delta for VO2-Max-supporting workouts. Always targets 3 highlights, sorted by best percentile. `SQWorkoutReviewHighlight` switches from a single `text: String` to `segments: [Segment]` so only the statistic portions are colored.

**Tech Stack:** Swift, HealthKit, SwiftData, Combine, `@Observable`

---

### Task 1: Add two VO2 Max fetch methods to `SQHealthKitManaging` + `SQHealthKitManager+VO2Max.swift`

**Files:**
- Modify: `BeastFitness/Utility/ThirdParty/SQHealthKitManager.swift` (protocol, lines 13–40)
- Modify: `BeastFitness/Utility/ThirdParty/SQHealthKitManager+VO2Max.swift`

**Step 1: Add two signatures to `SQHealthKitManaging` protocol**

In `SQHealthKitManager.swift`, inside `protocol SQHealthKitManaging`, add after `fetchVO2MaxSamples(upTo:limit:)`:

```swift
/// Most recent VO₂ max sample whose endDate is strictly before `date`.
func fetchLatestVO2MaxSample(strictlyBefore date: Date) async throws -> SQVO2MaxSample?

/// Most recent VO₂ max sample whose startDate is on or after `date` and
/// falls within the same calendar day as `endOfDay`.
func fetchLatestVO2MaxSample(onOrAfter date: Date, throughEndOfDay endOfDay: Date) async throws -> SQVO2MaxSample?
```

**Step 2: Implement both methods in `SQHealthKitManager+VO2Max.swift`**

Add two new `extension SQHealthKitManager` blocks at the bottom of the file:

```swift
extension SQHealthKitManager {

    func fetchLatestVO2MaxSample(strictlyBefore date: Date) async throws -> SQVO2MaxSample? {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw SQHealthKitError.healthDataUnavailable
        }
        try await Self.healthStore.requestAuthorization(
            toShare: allTypesToReadWrite,
            read: allTypesToReadWrite
        )
        guard let vo2Type = HKQuantityType.quantityType(forIdentifier: .vo2Max) else {
            throw SQHealthKitError.healthDataUnavailable
        }
        let predicate = HKQuery.predicateForSamples(
            withStart: .distantPast,
            end: date,
            options: .strictEndDate
        )
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let samples: [HKQuantitySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: vo2Type,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: samples as? [HKQuantitySample] ?? [])
            }
            Self.healthStore.execute(query)
        }
        return samples.first.map(Self.mapVO2MaxSample)
    }
}

extension SQHealthKitManager {

    func fetchLatestVO2MaxSample(onOrAfter date: Date, throughEndOfDay endOfDay: Date) async throws -> SQVO2MaxSample? {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw SQHealthKitError.healthDataUnavailable
        }
        try await Self.healthStore.requestAuthorization(
            toShare: allTypesToReadWrite,
            read: allTypesToReadWrite
        )
        guard let vo2Type = HKQuantityType.quantityType(forIdentifier: .vo2Max) else {
            throw SQHealthKitError.healthDataUnavailable
        }
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: endOfDay) ?? endOfDay.addingTimeInterval(86400)
        let startOfNextDay = Calendar.current.startOfDay(for: nextDay)
        let predicate = HKQuery.predicateForSamples(
            withStart: date,
            end: startOfNextDay,
            options: .strictStartDate
        )
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let samples: [HKQuantitySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: vo2Type,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: samples as? [HKQuantitySample] ?? [])
            }
            Self.healthStore.execute(query)
        }
        return samples.first.map(Self.mapVO2MaxSample)
    }
}
```

**Step 3: Commit**

```bash
git add BeastFitness/Utility/ThirdParty/SQHealthKitManager.swift \
        BeastFitness/Utility/ThirdParty/SQHealthKitManager+VO2Max.swift
git commit -m "feat: add strictlyBefore and onOrAfter VO2 Max fetch methods"
```

---

### Task 2: Update `SQWorkoutReviewHighlight` to use segments model

**Files:**
- Modify: `BeastFitness/ViewModels/Workouts/WorkoutSummary/SQWorkoutSummaryController.swift` (lines 20–28)

**Step 1: Replace the model**

The current model (lines 20–28):
```swift
struct SQWorkoutReviewHighlight: Identifiable {
    let id = UUID()
    let text: String
    let sentiment: Sentiment

    enum Sentiment: Equatable {
        case positive, neutral, negative
    }
}
```

Replace with:
```swift
struct SQWorkoutReviewHighlight: Identifiable {
    let id = UUID()
    let segments: [Segment]
    let sentiment: Sentiment

    struct Segment {
        let text: String
        let isStatistic: Bool
    }

    enum Sentiment: Equatable {
        case positive, neutral, negative
    }
}
```

**Step 2: Commit**

```bash
git add BeastFitness/ViewModels/Workouts/WorkoutSummary/SQWorkoutSummaryController.swift
git commit -m "refactor: replace SQWorkoutReviewHighlight.text with segments model"
```

---

### Task 3: Create `SQWorkoutStatsManager`

**Files:**
- Create: `BeastFitness/Managers/SQWorkoutStatsManager.swift`

This file owns:
1. The metric config (moved from `SQWorkoutManager`)
2. `loadPerformanceData(for:)` (extracted from the controller)
3. `generateHighlights(for:performanceData:)`

**Step 1: Create the file**

```swift
//
//  SQWorkoutStatsManager.swift
//  BeastFitness
//

import Foundation
import HealthKit
import SwiftData
import BeastFitnessCore

// MARK: - Protocol

protocol SQWorkoutStatsManaging {
    func metrics(for activityType: HKWorkoutActivityType) -> [SQQuantityType]
    func loadPerformanceData(for workout: SQWorkoutSessionable) async -> [SQPerformanceRowData]
    func generateHighlights(for workout: SQWorkoutSessionable, performanceData: [SQPerformanceRowData]) async -> [SQWorkoutReviewHighlight]
}

// MARK: - Implementation

final class SQWorkoutStatsManager: SQWorkoutStatsManaging {
    static let shared = SQWorkoutStatsManager()

    private let healthKitManager: SQHealthKitManaging
    private let workoutManager: SQWorkoutManaging

    init(
        healthKitManager: SQHealthKitManaging = SQHealthKitManager.shared,
        workoutManager: SQWorkoutManaging = SQWorkoutManager.shared
    ) {
        self.healthKitManager = healthKitManager
        self.workoutManager = workoutManager
    }
}

// MARK: - Metric Definitions

extension SQWorkoutStatsManager {

    private var metricsForAllActivityTypes: [SQQuantityType] {
        [
            .activeKilocaloriesBurned,
            .heartRate
        ]
    }

    private var activitySpecificMetricsByActivityType: [HKWorkoutActivityType: [SQQuantityType]] {
        [
            .running: [
                .sqFastestPace(.mile),
                .sqFastestPace(.fiveK),
                .sqPaceRunning,
                .distanceWalkingRunning
            ],
            .cycling: [
                .sqFastestPace(.fiveK),
                .distanceCycling
            ]
        ]
    }

    func metrics(for activityType: HKWorkoutActivityType) -> [SQQuantityType] {
        let specific = activitySpecificMetricsByActivityType[activityType] ?? []
        return metricsForAllActivityTypes + specific
    }
}

// MARK: - Performance Data Loading

extension SQWorkoutStatsManager {

    func loadPerformanceData(for workout: SQWorkoutSessionable) async -> [SQPerformanceRowData] {
        guard case .hkWorkout = workout.workoutSource else { return [] }
        guard let workoutEndDate = workout.endDate else { return [] }
        guard let modelContext = SQAppState.shared.modelContext else { return [] }

        var rows: [SQPerformanceRowData] = []

        do {
            let allTimeWorkouts = try await workoutManager.getWorkouts(for: .allTime, modelContext: modelContext)
            let sameActivityWorkouts = allTimeWorkouts.filter { $0.activityType == workout.activityType }
            let activityIcon = workout.activityType.imageSymbol.rawValue

            // VO2 Max — special case, not a workout metric
            if workout.activityType.impactsVO2MaxData {
                let recentSamples = try await healthKitManager.fetchVO2MaxSamples(upTo: workoutEndDate, limit: 1)
                if let sample = recentSamples.first {
                    let allTimeSamples = try await healthKitManager.fetchVO2MaxSamples(.allTime)
                    let calendar = Calendar.current
                    var bestByDay: [Date: Double] = [:]
                    for s in allTimeSamples {
                        let dayStart = calendar.startOfDay(for: s.startDate)
                        bestByDay[dayStart] = max(bestByDay[dayStart] ?? 0, s.value)
                    }
                    let percentile = SQPercentileCalculator.calculatePercentile(
                        currentBest: sample.value,
                        historicalValues: Array(bestByDay.values),
                        isLowerBetter: false
                    )
                    rows.append(SQPerformanceRowData(
                        id: "vo2-max",
                        icon: SQImageSymbol.heart.rawValue,
                        title: "VO2 Max",
                        bestValue: String(format: "%.1f", sample.value),
                        unit: "mL/kg/min",
                        percentileRank: percentile,
                        leaderboardMode: .vo2Max
                    ))
                }
            }

            // Workout metrics
            let metricTypes = metrics(for: workout.activityType)
            for quantityType in metricTypes {
                guard let currentMetric = await workout.getMetric(for: quantityType) else { continue }

                let historicalValues = await withTaskGroup(of: Double?.self) { group in
                    for w in sameActivityWorkouts {
                        group.addTask { await w.getMetric(for: quantityType)?.value }
                    }
                    var results: [Double] = []
                    for await value in group { if let v = value { results.append(v) } }
                    return results
                }

                let isLowerBetter = quantityType.dashboardAggregationType == .minimum
                let percentile = SQPercentileCalculator.calculatePercentile(
                    currentBest: currentMetric.value,
                    historicalValues: historicalValues,
                    isLowerBetter: isLowerBetter
                )

                rows.append(SQPerformanceRowData(
                    id: "\(workout.activityType.name.lowercased())-\(quantityType.id)",
                    icon: activityIcon,
                    title: currentMetric.displayName,
                    bestValue: currentMetric.displayableValue(for: quantityType, value: currentMetric.value),
                    unit: currentMetric.unit.unitString ?? "",
                    percentileRank: percentile,
                    leaderboardMode: .workoutQuantity(quantityType, workout.activityType)
                ))
            }

        } catch {
            SQLogger.shared.log(
                "Failed to load performance data: \(error.localizedDescription)",
                .error,
                context: .workoutSummary
            )
        }

        return rows
    }
}

// MARK: - Highlight Generation

extension SQWorkoutStatsManager {

    func generateHighlights(for workout: SQWorkoutSessionable, performanceData: [SQPerformanceRowData]) async -> [SQWorkoutReviewHighlight] {
        let supportsVO2Max = workout.activityType.impactsVO2MaxData
        let targetCount = 3

        var highlights: [SQWorkoutReviewHighlight] = []

        // Slot 1: VO2 Max delta (if supported)
        if supportsVO2Max {
            if let vo2Highlight = await buildVO2MaxHighlight(for: workout, performanceData: performanceData) {
                highlights.append(vo2Highlight)
            }
        }

        // Fill remaining slots with top-percentile rows (excluding VO2 Max if already shown)
        let remainingSlots = targetCount - highlights.count
        let candidateRows = performanceData
            .filter { supportsVO2Max ? $0.id != "vo2-max" : true }
            .filter { $0.percentileRank != nil }
            .sorted { ($0.percentileRank ?? 0) > ($1.percentileRank ?? 0) }
            .prefix(remainingSlots)

        for row in candidateRows {
            highlights.append(buildPercentileHighlight(for: row))
        }

        return highlights
    }

    // MARK: VO2 Max delta highlight

    private func buildVO2MaxHighlight(for workout: SQWorkoutSessionable, performanceData: [SQPerformanceRowData]) async -> SQWorkoutReviewHighlight? {
        guard let startDate = workout.startDate, let endDate = workout.endDate else { return nil }

        do {
            let beforeSample = try await healthKitManager.fetchLatestVO2MaxSample(strictlyBefore: startDate)
            let afterSample = try await healthKitManager.fetchLatestVO2MaxSample(onOrAfter: endDate, throughEndOfDay: endDate)

            if let before = beforeSample, let after = afterSample {
                let beforeVal = before.value
                let afterVal = after.value
                let beforeStr = String(format: "%.1f", beforeVal)
                let afterStr = String(format: "%.1f", afterVal)

                if afterVal > beforeVal {
                    let deltaPercent = Int(round(abs(afterVal - beforeVal) / beforeVal * 100))
                    return SQWorkoutReviewHighlight(
                        segments: [
                            .init(text: "↑ VO2 Max went up ", isStatistic: false),
                            .init(text: "\(deltaPercent)%: \(beforeStr) → \(afterStr)", isStatistic: true)
                        ],
                        sentiment: .positive
                    )
                } else if afterVal < beforeVal {
                    let deltaPercent = Int(round(abs(beforeVal - afterVal) / beforeVal * 100))
                    return SQWorkoutReviewHighlight(
                        segments: [
                            .init(text: "↓ VO2 Max dropped ", isStatistic: false),
                            .init(text: "\(deltaPercent)%: \(beforeStr) → \(afterStr)", isStatistic: true)
                        ],
                        sentiment: .negative
                    )
                } else {
                    return SQWorkoutReviewHighlight(
                        segments: [
                            .init(text: "VO2 Max unchanged at ", isStatistic: false),
                            .init(text: "\(afterStr) mL/kg/min", isStatistic: true)
                        ],
                        sentiment: .neutral
                    )
                }
            }
        } catch {
            SQLogger.shared.log(
                "Failed to fetch VO2 Max samples for highlight: \(error.localizedDescription)",
                .debug,
                context: .workoutSummary
            )
        }

        // Fallback: use percentile rank from performance data
        if let vo2Row = performanceData.first(where: { $0.id == "vo2-max" }) {
            return buildPercentileHighlight(for: vo2Row)
        }
        return nil
    }

    // MARK: Percentile highlight

    private func buildPercentileHighlight(for row: SQPerformanceRowData) -> SQWorkoutReviewHighlight {
        guard let percentile = row.percentileRank else {
            return SQWorkoutReviewHighlight(
                segments: [.init(text: row.title, isStatistic: false)],
                sentiment: .neutral
            )
        }

        let topPercent = Int(round((1.0 - percentile) * 100))
        let pctileInt = Int(round(percentile * 100))
        let ordinal = ordinalString(for: pctileInt)

        switch percentile {
        case 0.90...:
            return SQWorkoutReviewHighlight(
                segments: [
                    .init(text: "Top ", isStatistic: false),
                    .init(text: "\(topPercent)%", isStatistic: true),
                    .init(text: " for \(row.title) — you crushed it!", isStatistic: false)
                ],
                sentiment: .positive
            )
        case 0.65...:
            return SQWorkoutReviewHighlight(
                segments: [
                    .init(text: "Top ", isStatistic: false),
                    .init(text: "\(topPercent)%", isStatistic: true),
                    .init(text: " for \(row.title)", isStatistic: false)
                ],
                sentiment: .positive
            )
        case 0.35...:
            return SQWorkoutReviewHighlight(
                segments: [
                    .init(text: "Standard \(row.title) (", isStatistic: false),
                    .init(text: "~\(ordinal) %ile", isStatistic: true),
                    .init(text: ")", isStatistic: false)
                ],
                sentiment: .neutral
            )
        default:
            return SQWorkoutReviewHighlight(
                segments: [
                    .init(text: "Below average \(row.title) (", isStatistic: false),
                    .init(text: "\(ordinal) %ile", isStatistic: true),
                    .init(text: ")", isStatistic: false)
                ],
                sentiment: .negative
            )
        }
    }

    private func ordinalString(for n: Int) -> String {
        let suffix: String
        switch n % 100 {
        case 11, 12, 13:
            suffix = "th"
        default:
            switch n % 10 {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(n)\(suffix)"
    }
}
```

**Step 2: Commit**

```bash
git add BeastFitness/Managers/SQWorkoutStatsManager.swift
git commit -m "feat: add SQWorkoutStatsManager with metrics, performance loading, and highlight generation"
```

---

### Task 4: Remove `metrics(for:)` from `SQWorkoutManager`

**Files:**
- Modify: `BeastFitness/Managers/SQWorkoutManager.swift`

**Step 1: Remove from protocol**

In `protocol SQWorkoutManaging`, delete:
```swift
func metrics(for activityType: HKWorkoutActivityType) -> [SQQuantityType]
```

**Step 2: Remove the implementation**

Delete the entire `// MARK: - Global Config` extension at the bottom of `SQWorkoutManager.swift` (lines 196–227). This includes `metricsForAllActivityTypes`, `activitySpecificMetricsByActivityType`, and `metrics(for:)`.

**Step 3: Commit**

```bash
git add BeastFitness/Managers/SQWorkoutManager.swift
git commit -m "refactor: remove metrics(for:) from SQWorkoutManager — moved to SQWorkoutStatsManager"
```

---

### Task 5: Update `SQWorkoutSummaryController`

**Files:**
- Modify: `BeastFitness/ViewModels/Workouts/WorkoutSummary/SQWorkoutSummaryController.swift`

**Step 1: Add `statsManager` property**

After `private let healthKitManager: SQHealthKitManaging`, add:
```swift
private let statsManager: SQWorkoutStatsManaging
```

**Step 2: Update `init` to accept and store `statsManager`**

Add `statsManager: SQWorkoutStatsManaging = SQWorkoutStatsManager.shared` to the `init` parameters and assign `self.statsManager = statsManager`.

**Step 3: Replace `loadPerformanceDataIfNeeded` body**

The entire method currently contains ~70 lines of data fetching logic. Replace it with a delegation call:

```swift
func loadPerformanceDataIfNeeded(workout: SQWorkoutSessionable) async {
    let rows = await statsManager.loadPerformanceData(for: workout)
    if !rows.isEmpty {
        state.loadPerformanceData(rowData: rows)
    }
}
```

**Step 4: Replace `mockHighlights()` call with real generation**

In `load(workout:)`, find:
```swift
reviewHighlights = Self.mockHighlights()
```

Replace with:
```swift
reviewHighlights = await statsManager.generateHighlights(
    for: workout,
    performanceData: state.performanceRowData
)
```

Note: `generateHighlights` must be called *after* `loadPerformanceDataIfNeeded` completes (it already is — check call order in `load`).

**Step 5: Delete `mockHighlights()` static method**

Remove the entire `// MARK: - Review Highlights` extension at the bottom of the file.

**Step 6: Commit**

```bash
git add BeastFitness/ViewModels/Workouts/WorkoutSummary/SQWorkoutSummaryController.swift
git commit -m "feat: wire SQWorkoutSummaryController to SQWorkoutStatsManager for real highlights"
```

---

### Task 6: Update `SQDashboardController`

**Files:**
- Modify: `BeastFitness/ViewModels/Dashboard/SQDashboardController.swift` (around line 459)

**Step 1: Add `statsManager` property**

Find the `private let workoutManager: SQWorkoutManaging` property and add below it:
```swift
private let statsManager: SQWorkoutStatsManaging
```

**Step 2: Update `init` to accept and store `statsManager`**

Add `statsManager: SQWorkoutStatsManaging = SQWorkoutStatsManager.shared` to the `init` and assign `self.statsManager = statsManager`.

**Step 3: Replace `workoutManager.metrics(for:)` call**

At line ~459, change:
```swift
let metricTypes = workoutManager.metrics(for: activityType)
```
to:
```swift
let metricTypes = statsManager.metrics(for: activityType)
```

**Step 4: Commit**

```bash
git add BeastFitness/ViewModels/Dashboard/SQDashboardController.swift
git commit -m "refactor: SQDashboardController uses statsManager.metrics(for:)"
```

---

### Task 7: Update `SQWorkoutSummaryView` to render highlight segments

**Files:**
- Modify: `BeastFitness/Views/WorkoutSummary/SQWorkoutSummaryView.swift` (lines 68–82)

**Step 1: Replace `reviewHighlightsSection`**

Current implementation renders `Text(highlight.text)` in a single color. Replace with segment rendering:

```swift
@ViewBuilder
var reviewHighlightsSection: some View {
    VStack(alignment: .leading, spacing: .SQSpace.m) {
        ForEach(controller.reviewHighlights) { highlight in
            HStack(alignment: .top, spacing: .SQSpace.s) {
                Text("•")
                    .sqFont(.body)
                    .sqForegroundColor(highlightColor(for: highlight.sentiment))

                highlight.segments.reduce(Text("")) { result, segment in
                    result + Text(segment.text)
                        .foregroundColor(
                            segment.isStatistic
                                ? highlightColor(for: highlight.sentiment).color
                                : SQColor.textPrimary.color
                        )
                }
                .sqFont(.body)
            }
        }
    }
}
```

Note: `Text + Text` concatenation in SwiftUI doesn't support `.sqForegroundColor()` (a custom modifier) — use `.foregroundColor(SQColor.xxx.color)` directly when concatenating `Text` segments. The `.sqFont(.body)` applied to the combined `Text` covers the whole run.

**Step 2: Commit**

```bash
git add BeastFitness/Views/WorkoutSummary/SQWorkoutSummaryView.swift
git commit -m "feat: render workout highlight segments with per-statistic coloring"
```

---

### Done

At this point:
- `SQWorkoutStatsManager` owns all metric/highlight logic
- `SQWorkoutManager` no longer has `metrics(for:)`
- The review screen shows real, data-driven highlights with colored statistics
- VO2 Max shows a before/after delta (or falls back to percentile if samples aren't available)
- Always up to 3 highlights, sorted by best percentile
