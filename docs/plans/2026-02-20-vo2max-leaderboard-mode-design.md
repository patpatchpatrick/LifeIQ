# VO2 Max Leaderboard + Mode-Based Leaderboard Design

**Date:** 2026-02-20

## Overview

Add VO2 max data to the leaderboard and make the VO2 max dashboard row tappable for navigation. Achieved by introducing a `SQLeaderboardMode` enum that owns the "what are we ranking?" decision, replacing the current ad-hoc `(quantityType, activityType)` pair threaded through the stack.

## Goals

- VO2 max dashboard row navigates to a leaderboard sheet when tapped
- Leaderboard ranks VO2 max samples by day (one entry per day, highest value wins)
- Same `AppTimeRange` time range dropdown used for both workout and VO2 max modes
- Controller, row view model, and navigation all handle both modes cleanly via the enum

## Non-Goals

- No new leaderboard view or separate controller for VO2 max — one controller handles both modes
- No changes to the chart UI or time range dropdown behavior

---

## Design

### 1. `SQLeaderboardMode` (new file)

```swift
enum SQLeaderboardMode {
    case workoutQuantity(SQQuantityType, HKWorkoutActivityType)
    case vo2Max
}
```

Computed properties on the enum provide mode-specific metadata used by the controller:

- `title: String` — navigation title ("VO2 Max Leaderboard", "Distance Leaderboard", etc.)
- `isSortAscending: Bool` — false for VO2 max and distance (higher = better), true for pace (lower = better)

### 2. `SQLeaderboardController`

Replace `let quantityType: SQQuantityType` + `let activityType: HKWorkoutActivityType` with `let mode: SQLeaderboardMode`.

Add `healthKitManager` param to init (defaulting to `SQHealthKitManager.shared`) for VO2 max fetching.

`loadUI` switches on `mode`:
- `.workoutQuantity(quantityType, activityType)` — existing path, unchanged behavior
- `.vo2Max` — fetch `[SQVO2MaxSample]` for the selected time range, group by calendar day (take max per day), sort descending, build rows

Both modes produce the same `[SQLeaderboardRowViewModel]` output and the same chart data shape `(id, date, value)`, so chart, focus, and time range logic require no changes.

### 3. `SQLeaderboardRowViewModel`

Decouple from `SQWorkoutSessionable` by replacing `workout`, `metric`, and `quantityType` with explicit stored properties:

| Property | Type | Example |
|---|---|---|
| `title` | `String` | "Morning Run" / "VO2 Max" |
| `dateString` | `String` | "Jan 28, 2026" |
| `formattedScore` | `String` | "7:30" / "45.3" |
| `unitString` | `String` | "/mi" / "mL/kg/min" |
| `warningText` | `String?` | nil for VO2 max |

`scoreAttributedString` builder is unchanged. The controller creates rows with the right values for each mode.

### 4. `DashboardState` protocol + implementation

Replace:
```swift
func displayLeaderboardSheet(quantityType: SQQuantityType, activityType: HKWorkoutActivityType)
```

With:
```swift
func displayLeaderboardSheet(mode: SQLeaderboardMode)
```

The initial-time-range logic (today → allTime fallback) applies identically for both modes.

### 5. `SQDashboardMetricPerformanceRowViewModel`

Replace the two optional navigation properties (`quantityType: SQQuantityType?`, `activityType: HKWorkoutActivityType?`) with:

```swift
var leaderboardMode: SQLeaderboardMode?
```

VO2 max row gets `leaderboardMode: .vo2Max`. Workout rows get `leaderboardMode: .workoutQuantity(quantityType, activityType)`.

### 6. `SQDashboardSectionView` tap handler

Extract `leaderboardMode` from the row VM and pass directly to `displayLeaderboardSheet(mode:)`. No more separate nil-check on two properties.

### 7. `SQDashboardController.buildPerformanceSubsection`

Add `leaderboardMode: .vo2Max` to the VO2 max row construction.

---

## Files Changed

| File | Change |
|---|---|
| `SQLeaderboardMode.swift` | **New** — mode enum with metadata |
| `SQLeaderboardController.swift` | Replace quantityType/activityType with mode; add VO2 max load path |
| `SQLeaderboardRowViewModel.swift` | Remove SQWorkoutSessionable coupling; store explicit display strings |
| `DashboardState.swift` | Update protocol + impl to `displayLeaderboardSheet(mode:)` |
| `SQDashboardMetricPerformanceRowViewModel.swift` | Replace two optional nav props with `leaderboardMode` |
| `SQDashboardSectionView.swift` | Update tap handler to use `leaderboardMode` |
| `SQDashboardController.swift` | Pass `leaderboardMode: .vo2Max` on VO2 max row |
