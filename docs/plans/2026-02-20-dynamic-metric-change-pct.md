# Dynamic Metric Change % Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the metrics dashboard column show a real percentage change versus a meaningful prior period, with a dynamic header label that matches the selected time range.

**Architecture:** Add two computed vars to `AppTimeRange` for the comparison window and header label. Fetch prior-period check-ins in `loadUI` and pass them through to `buildMetricRow`, where the actual change calculation happens. Rename `change14d` → `changePercent` throughout.

**Tech Stack:** Swift, SwiftUI, SwiftData, `SQDailyCheckInEntity`, `SQDashboardController`

---

### Task 1: Add `dashboardChangePctTimeRange` and `dashboardChangePctHeader` to `AppTimeRange`

**Files:**
- Modify: `BeastFitness/Models/TimeRange/AppTimeRange.swift`

**Step 1: Open the file and add two new computed vars after `previousSqTimeRange`**

Add `dashboardChangePctTimeRange` — same as `previousSqTimeRange` for all cases except `.today`, which uses `.pastWeek` (7-day baseline) instead of `.yesterday`:

```swift
/// Comparison time range used for the dashboard change-% column.
/// For `.today`, compares against the last 7 days (not just yesterday).
var dashboardChangePctTimeRange: SQTimeRange? {
    switch self {
    case .today:        return .pastWeek
    case .pastSevenDays: return .weekBeforeLast
    case .past30Days:   return .thirtyDaysBeforeLast
    case .pastYear:     return .yearBeforeLast
    case .allTime:      return nil
    }
}
```

Add `dashboardChangePctHeader` — the column header label:

```swift
/// Column header label for the change-% column in the metrics table.
var dashboardChangePctHeader: String {
    switch self {
    case .today, .pastSevenDays: return "7d %"
    case .past30Days:            return "30d %"
    case .pastYear:              return "1y %"
    case .allTime:               return "—"
    }
}
```

**Step 2: Commit**

```bash
git add BeastFitness/Models/TimeRange/AppTimeRange.swift
git commit -m "feat: add dashboardChangePctTimeRange and dashboardChangePctHeader to AppTimeRange"
```

---

### Task 2: Rename `change14d` → `changePercent` in `SQStatRowData`

**Files:**
- Modify: `BeastFitness/Models/Dashboard/SQStatRowData.swift`

**Step 1: Rename the property and init parameter**

Replace:
```swift
let change14d: Double  // Percentage change

init(
    ...
    change14d: Double
) {
    ...
    self.change14d = change14d
}
```

With:
```swift
let changePercent: Double  // Fractional percentage change (e.g. 0.15 = +15%)

init(
    ...
    changePercent: Double
) {
    ...
    self.changePercent = changePercent
}
```

**Step 2: Commit**

```bash
git add BeastFitness/Models/Dashboard/SQStatRowData.swift
git commit -m "refactor: rename change14d -> changePercent in SQStatRowData"
```

---

### Task 3: Rename `change14d` → `changePercent` in `SQDashboardMetricStatsRowViewModel`

**Files:**
- Modify: `BeastFitness/ViewModels/Dashboard/DashboardRows/SQDashboardMetricStatsRowViewModel.swift`

**Step 1: Rename the stored property and init parameter**

Replace:
```swift
/// 14-day percentage change (e.g., 0.15 for +15%)
let change14d: Double
```

With:
```swift
/// Fractional percentage change vs comparison period (e.g., 0.15 for +15%)
let changePercent: Double
```

And update the `init` parameter and assignment to match (`change14d:` → `changePercent:`).

**Step 2: Commit**

```bash
git add BeastFitness/ViewModels/Dashboard/DashboardRows/SQDashboardMetricStatsRowViewModel.swift
git commit -m "refactor: rename change14d -> changePercent in SQDashboardMetricStatsRowViewModel"
```

---

### Task 4: Update `SQDashboardStatRow` to use `changePercent`

**Files:**
- Modify: `BeastFitness/Views/Dashboard/Shared/SQDashboardStatRow.swift`

**Step 1: Update the `changeColor` computed var**

Replace:
```swift
private var changeColor: SQColor {
    data.change14d >= 0 ? .colorFadedGreen : .colorFadedRed
}
```

With:
```swift
private var changeColor: SQColor {
    data.changePercent >= 0 ? .colorFadedGreen : .colorFadedRed
}
```

**Step 2: Update the percentage Text**

Replace:
```swift
Text(String(format: "%.1f%%", abs(data.change14d)))
```

With:
```swift
Text(String(format: "%.1f%%", abs(data.changePercent * 100)))
```

> Note: `changePercent` is stored as a fraction (0.15 = 15%), so multiply by 100 for display.

**Step 3: Update all `#Preview` blocks**

In all three `#Preview` blocks, rename `change14d:` to `changePercent:` in the `SQStatRowData` init calls. Keep the numeric values as-is — they'll now be interpreted as fractions, which is fine for previews.

**Step 4: Commit**

```bash
git add BeastFitness/Views/Dashboard/Shared/SQDashboardStatRow.swift
git commit -m "refactor: update SQDashboardStatRow to use changePercent"
```

---

### Task 5: Fetch prior-period check-ins in `loadUI` and pass to `buildMetricsSubsection`

**Files:**
- Modify: `BeastFitness/ViewModels/Dashboard/SQDashboardController.swift`

**Step 1: Fetch prior check-ins for each comparison window**

In `loadUI`, after the existing check-in fetches (around line 173), add:

```swift
let weekBeforeLastCheckIns = try SQDailyCheckInEntity.getAll(
    from: SQTimeRange.weekBeforeLast.startDate,
    to: SQTimeRange.weekBeforeLast.endDate,
    context: context
)

let thirtyDaysBeforeLastCheckIns = try SQDailyCheckInEntity.getAll(
    from: SQTimeRange.thirtyDaysBeforeLast.startDate,
    to: SQTimeRange.thirtyDaysBeforeLast.endDate,
    context: context
)

let yearBeforeLastCheckIns = try SQDailyCheckInEntity.getAll(
    from: SQTimeRange.yearBeforeLast.startDate,
    to: SQTimeRange.yearBeforeLast.endDate,
    context: context
)
```

**Step 2: Build `priorCheckIns` in the switch statement**

In the `switch state.selectedTimeRange` block (around line 199), add a `priorCheckIns` variable alongside the existing variables:

```swift
let currentCheckIns: [SQDailyCheckInStats]
let priorCheckIns: [SQDailyCheckInStats]   // <-- add this
// ... existing vars ...

switch state.selectedTimeRange {
case .today:
    currentCheckIns = todaysCheckIns
    priorCheckIns = past7DaysCheckIns          // compare today vs last 7 days
    // ... existing assignments ...
case .pastSevenDays:
    currentCheckIns = past7DaysCheckIns
    priorCheckIns = weekBeforeLastCheckIns     // compare this week vs prior week
    // ...
case .past30Days:
    currentCheckIns = past30DaysCheckIns
    priorCheckIns = thirtyDaysBeforeLastCheckIns
    // ...
case .pastYear:
    currentCheckIns = pastYearCheckIns
    priorCheckIns = yearBeforeLastCheckIns
    // ...
case .allTime:
    currentCheckIns = pastYearCheckIns
    priorCheckIns = []                         // no comparison for all time
    // ...
}
```

**Step 3: Pass `priorCheckIns` to `buildSectionGroups`**

In the `buildSectionGroups(...)` call (around line 232), add `priorCheckIns: priorCheckIns`.

**Step 4: Update `buildSectionGroups` signature**

Find the `buildSectionGroups` function and add `priorCheckIns: [SQDailyCheckInStats]` as a parameter. Pass it through to `buildMetricsSubsection`.

**Step 5: Update `buildMetricsSubsection` signature**

Change:
```swift
private func buildMetricsSubsection(
    checkIns: [SQDailyCheckInStats],
    timeRange: AppTimeRange,
    context: ModelContext
) -> SQDashboardSubsectionViewModel {
```

To:
```swift
private func buildMetricsSubsection(
    checkIns: [SQDailyCheckInStats],
    priorCheckIns: [SQDailyCheckInStats],
    timeRange: AppTimeRange,
    context: ModelContext
) -> SQDashboardSubsectionViewModel {
```

**Step 6: Use dynamic column header**

Replace the hardcoded `"14d %"` in `buildMetricsSubsection` (line 338):

```swift
columnHeaders: ["Metric", "Avg Score", "14d %"]
```

With:

```swift
columnHeaders: ["Metric", "Avg Score", timeRange.dashboardChangePctHeader]
```

**Step 7: Pass `priorCheckIns` to `buildMetricRow`**

In `buildMetricsSubsection`, update the `rows(for:)` closure:

```swift
func rows(for definitions: [SQMetricDefinition]) -> [SQDashboardMetricStatsRowViewModel] {
    definitions.compactMap { buildMetricRow(for: $0, from: stats, priorStats: priorCheckIns) }
}
```

**Step 8: Commit**

```bash
git add BeastFitness/ViewModels/Dashboard/SQDashboardController.swift
git commit -m "feat: fetch prior check-ins and thread through to metrics subsection"
```

---

### Task 6: Calculate `changePercent` in `buildMetricRow`

**Files:**
- Modify: `BeastFitness/ViewModels/Dashboard/SQDashboardController.swift`

**Step 1: Update `buildMetricRow` signature**

Change:
```swift
private func buildMetricRow(for definition: SQMetricDefinition, from stats: [SQDailyCheckInStats]) -> SQDashboardMetricStatsRowViewModel?
```

To:
```swift
private func buildMetricRow(for definition: SQMetricDefinition, from stats: [SQDailyCheckInStats], priorStats: [SQDailyCheckInStats]) -> SQDashboardMetricStatsRowViewModel?
```

**Step 2: Calculate `changePercent` before the return statement**

After the `sparklineData` line and before the `return`, add:

```swift
// Calculate percentage change vs comparison period
let priorValues = priorStats.compactMap { $0.values[definition.id] }
let priorAverage = priorValues.isEmpty ? nil : priorValues.reduce(0, +) / Float(priorValues.count)

let changePercent: Double
if let prior = priorAverage, prior != 0 {
    changePercent = Double((average - prior) / prior)
} else {
    changePercent = 0.0
}
```

**Step 3: Replace `change14d: 0.0` with `changePercent: changePercent`**

Replace:
```swift
return SQDashboardMetricStatsRowViewModel(
    ...
    change14d: 0.0  // Placeholder for now
)
```

With:
```swift
return SQDashboardMetricStatsRowViewModel(
    ...
    changePercent: changePercent
)
```

**Step 4: Commit**

```bash
git add BeastFitness/ViewModels/Dashboard/SQDashboardController.swift
git commit -m "feat: calculate real changePercent in buildMetricRow vs prior period"
```

---

### Task 7: Wire `changePercent` from view model to `SQStatRowData`

**Files:**
- Modify: `BeastFitness/Views/Dashboard/SQDashboardSectionView.swift` (or wherever `SQStatRowData` is built from the view model)

**Step 1: Find where `SQStatRowData` is constructed from `SQDashboardMetricStatsRowViewModel`**

Search for `SQStatRowData(` in the codebase. The constructor is likely in `SQDashboardSectionView.swift` or nearby.

**Step 2: Update the `SQStatRowData` init call**

Replace `change14d: viewModel.change14d` with `changePercent: viewModel.changePercent`.

**Step 3: Commit**

```bash
git add <modified file>
git commit -m "feat: pass changePercent from view model to SQStatRowData"
```
