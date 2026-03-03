# Design: SQWorkoutStatsManager + Real Workout Highlights

**Date:** 2026-03-02

## Overview

Introduce `SQWorkoutStatsManager` — a new manager that takes ownership of all workout stat, metric, and highlight logic. It replaces the metric config currently embedded in `SQWorkoutManager` and adds real highlight generation for the workout review screen (replacing the current mock).

---

## Architecture

### New: `SQWorkoutStatsManager`

A singleton manager initialized with `healthKitManager` and `workoutManager`. Owns three responsibilities:

1. **Metric definitions** — which `SQQuantityType` values apply to each activity type (moved from `SQWorkoutManager`)
2. **Performance data loading** — fetches and assembles `[SQPerformanceRowData]` (extracted from `SQWorkoutSummaryController.loadPerformanceDataIfNeeded`)
3. **Highlight generation** — produces `[SQWorkoutReviewHighlight]` from a workout + its performance data

```swift
protocol SQWorkoutStatsManaging {
    func metrics(for activityType: HKWorkoutActivityType) -> [SQQuantityType]
    func loadPerformanceData(for workout: SQWorkoutSessionable, allTimeWorkouts: [SQWorkoutSessionable]) async -> [SQPerformanceRowData]
    func generateHighlights(for workout: SQWorkoutSessionable, performanceData: [SQPerformanceRowData]) async -> [SQWorkoutReviewHighlight]
}

final class SQWorkoutStatsManager: SQWorkoutStatsManaging {
    static let shared = SQWorkoutStatsManager()
    init(healthKitManager: SQHealthKitManaging = SQHealthKitManager.shared,
         workoutManager: SQWorkoutManaging = SQWorkoutManager.shared)
}
```

### Modified: `SQWorkoutManager`

Remove the `metrics(for:)` method and all metric config blocks (`metricsForAllActivityTypes`, `activitySpecificMetricsByActivityType`). Remove from `SQWorkoutManaging` protocol too.

### Modified: `SQWorkoutSummaryController`

- Replace `workoutManager.metrics(for:)` → `statsManager.metrics(for:)`
- Replace `mockHighlights()` → `await statsManager.generateHighlights(for:performanceData:)`, called after performance data loads
- The `loadPerformanceDataIfNeeded` body moves into `statsManager.loadPerformanceData(for:allTimeWorkouts:)`; the controller calls it and assigns the result

### Modified: `SQDashboardController`

Replace `workoutManager.metrics(for:)` → `statsManager.metrics(for:)`.

---

## Highlight Generation Logic

### Selection Strategy

Always target **3 highlights total**:

| Workout supports VO2 Max? | Slot 1 | Slots 2–3 |
|---|---|---|
| Yes | VO2 Max delta (or percentile fallback) | Top 2 rows by percentile desc |
| No | — | Top 3 rows by percentile desc |

Rows with `nil` percentile (insufficient history) are skipped. If fewer than the target count have data, show however many are available.

### VO2 Max Highlight (Delta)

Requires two new HealthKit fetch methods (see below):

- **Before**: most recent `SQVO2MaxSample` with `endDate < workout.startDate`
- **After**: most recent `SQVO2MaxSample` with `startDate >= workout.endDate` on the same calendar day

Text generation:
- Both exist, delta > 0: `"↑ VO2 Max went up X%: A → B"` → positive
- Both exist, delta < 0: `"↓ VO2 Max dropped X%: A → B"` → negative
- Both exist, delta == 0: `"VO2 Max unchanged at X mL/kg/min"` → neutral
- Either missing: fall back to percentile template using the row's `percentileRank`

### Percentile-Based Highlights

| `percentileRank` | Text template | Sentiment |
|---|---|---|
| ≥ 0.90 | `"Top X% for [metric] — you crushed it!"` | positive |
| ≥ 0.65 | `"Top X% for [metric]"` | positive |
| ≥ 0.35 | `"Standard [metric] (~Xth %ile)"` | neutral |
| < 0.35 | `"Below average [metric] (Xth %ile)"` | negative |
| `nil` | *(skipped)* | — |

Percentile displayed as a rounded integer (e.g. `0.07` → `"Top 7%"`, `0.52` → `"~52nd %ile"`).

---

## Highlight Model — Segments

Replace `SQWorkoutReviewHighlight.text: String` with `segments: [Segment]` to support per-statistic coloring. The base text renders in `.textPrimary`; only segments marked `isStatistic: true` get the sentiment color.

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

Example for "Top 7% for distance — you crushed it!":
```
Segment("Top ", isStatistic: false)
Segment("7%", isStatistic: true)
Segment(" for distance — you crushed it!", isStatistic: false)
```

### View Rendering

```swift
// In SQWorkoutSummaryView.reviewHighlightsSection
segments.reduce(Text("")) { result, segment in
    result + Text(segment.text)
        .sqForegroundColor(segment.isStatistic ? sentimentColor : .textPrimary)
}
```

---

## New HealthKit Methods

Add to `SQHealthKitManaging` protocol and `SQHealthKitManager+VO2Max.swift`:

```swift
func fetchLatestVO2MaxSample(strictlyBefore date: Date) async throws -> SQVO2MaxSample?
func fetchLatestVO2MaxSample(onOrAfter date: Date, throughEndOfDay endDate: Date) async throws -> SQVO2MaxSample?
```

- `strictlyBefore`: predicate `endDate < date`, sorted desc, limit 1
- `onOrAfter/throughEndOfDay`: predicate `startDate >= date AND startDate < startOfNextDay(endDate)`, sorted desc, limit 1

---

## Files Touched

| File | Change |
|---|---|
| `SQWorkoutStatsManager.swift` | **New** — protocol + implementation |
| `SQWorkoutReviewHighlight` (in `SQWorkoutSummaryController.swift`) | `text: String` → `segments: [Segment]` |
| `SQWorkoutManager.swift` | Remove `metrics(for:)` and metric config blocks |
| `SQHealthKitManager+VO2Max.swift` | Add two new fetch methods + protocol entries |
| `SQHealthKitManaging` (protocol) | Add two new VO2 Max method signatures |
| `SQWorkoutSummaryController.swift` | Use `statsManager`; extract perf loading; call `generateHighlights` |
| `SQDashboardController.swift` | Replace `workoutManager.metrics(for:)` with `statsManager.metrics(for:)` |
| `SQWorkoutSummaryView.swift` | Render highlight segments instead of single `Text(highlight.text)` |
