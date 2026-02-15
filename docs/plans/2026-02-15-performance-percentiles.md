# Performance Percentiles Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace performance row sparklines and 14-day percentage changes with best-score values and all-time percentile rankings displayed as "Top X%".

**Architecture:** Create separate view model (`SQDashboardMetricPerformanceRowViewModel`) and view (`SQDashboardPerformanceRow`) for performance metrics. Calculate percentiles by comparing current period's best value against all historical data points. Reuse similar structure to stats rows but optimize for performance-specific display.

**Tech Stack:** Swift, SwiftUI, HealthKit, BeastFitnessCore

---

## Task 1: Create SQPerformanceRowData Model

**Files:**
- Create: `BeastFitness/Models/Dashboard/SQPerformanceRowData.swift`

**Step 1: Create the data model**

Create new file with this content:

```swift
//
//  SQPerformanceRowData.swift
//  BeastFitness
//

import Foundation

struct SQPerformanceRowData: Identifiable {
    let id: String
    let icon: String  // Emoji or SF Symbol name
    let title: String
    let bestValue: String
    let unit: String
    let percentileRank: Double?  // 0.0 to 1.0, nil if insufficient data

    init(
        id: String,
        icon: String,
        title: String,
        bestValue: String,
        unit: String,
        percentileRank: Double?
    ) {
        self.id = id
        self.icon = icon
        self.title = title
        self.bestValue = bestValue
        self.unit = unit
        self.percentileRank = percentileRank
    }
}
```

**Step 2: Add to Xcode project**

Run: `open BeastFitness.xcodeproj` and add the file to the project under Models/Dashboard group.

**Step 3: Commit**

```bash
git add BeastFitness/Models/Dashboard/SQPerformanceRowData.swift
git commit -m "feat: add SQPerformanceRowData model

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 2: Create SQDashboardMetricPerformanceRowViewModel

**Files:**
- Create: `BeastFitness/ViewModels/Dashboard/DashboardRows/SQDashboardMetricPerformanceRowViewModel.swift`

**Step 1: Create the view model**

Create new file with this content:

```swift
//
//  SQDashboardMetricPerformanceRowViewModel.swift
//  BeastFitness
//
//  Created by Claude Code on 2026-02-15.
//

import SwiftUI
import HealthKit
import BeastFitnessCore

@Observable @MainActor
final class SQDashboardMetricPerformanceRowViewModel: SQDashboardRowViewModel {
    let metricId: String

    /// Emoji or SF Symbol name for the metric
    let icon: String

    /// Metric name (e.g., "VO2 Max", "Pace")
    let title: String

    /// Best value as formatted string (e.g., "7:30", "45.3")
    let bestValue: String

    /// Unit of measurement (e.g., "/mi", "mL/kg/min")
    let unit: String

    /// Percentile rank (0.0 to 1.0), nil if insufficient data
    let percentileRank: Double?

    /// Optional quantity type for performance metrics (used for leaderboard)
    let quantityType: SQQuantityType?

    /// Optional activity type for performance metrics (used for leaderboard)
    let activityType: HKWorkoutActivityType?

    init(
        metricId: String,
        icon: String,
        title: String,
        bestValue: String,
        unit: String,
        percentileRank: Double?,
        quantityType: SQQuantityType? = nil,
        activityType: HKWorkoutActivityType? = nil
    ) {
        self.metricId = metricId
        self.icon = icon
        self.title = title
        self.bestValue = bestValue
        self.unit = unit
        self.percentileRank = percentileRank
        self.quantityType = quantityType
        self.activityType = activityType

        super.init(rowId: .metricPerformance, rowType: .metricPerformance)
    }
}
```

**Step 2: Add to Xcode project**

Run: `open BeastFitness.xcodeproj` and add the file to the project under ViewModels/Dashboard/DashboardRows group.

**Step 3: Commit**

```bash
git add BeastFitness/ViewModels/Dashboard/DashboardRows/SQDashboardMetricPerformanceRowViewModel.swift
git commit -m "feat: add SQDashboardMetricPerformanceRowViewModel

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 3: Add .metricPerformance to SQDashboardRowType Enum

**Files:**
- Modify: `BeastFitness/ViewModels/Dashboard/DashboardRows/SQDashboardRowViewModel.swift`

**Step 1: Find the enum definition**

Search for `enum SQDashboardRowType` in the file.

**Step 2: Add new case**

Add `.metricPerformance` case to the enum:

```swift
enum SQDashboardRowType {
    case metricStats
    case metricPerformance  // Add this line
    case workoutTotals
    case activityList
}
```

**Step 3: Commit**

```bash
git add BeastFitness/ViewModels/Dashboard/DashboardRows/SQDashboardRowViewModel.swift
git commit -m "feat: add metricPerformance row type

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 4: Create SQDashboardPerformanceRow View

**Files:**
- Create: `BeastFitness/Views/Dashboard/DashboardRows/SQDashboardPerformanceRow.swift`

**Step 1: Create the view component**

Create new file with this content:

```swift
//
//  SQDashboardPerformanceRow.swift
//  BeastFitness
//
//  Created by Claude Code on 2026-02-15.
//

import SwiftUI

struct SQDashboardPerformanceRow: View {
    let data: SQPerformanceRowData

    // Detect if icon is emoji (single character) vs SF Symbol name
    private var isEmoji: Bool {
        data.icon.count == 1
    }

    // Color for percentile rank based on performance
    private var rankColor: SQColor {
        guard let rank = data.percentileRank else {
            return .textSecondary
        }
        // Top quartile (< 0.25 percentile, meaning top 75%+) gets green
        return rank < 0.25 ? .colorFadedGreen : .textSecondary
    }

    // Format percentile as "Top X%"
    private var percentileText: String {
        guard let rank = data.percentileRank else {
            return "N/A"
        }
        let topPercent = Int((1.0 - rank) * 100)
        return "Top \(topPercent)%"
    }

    var mainBody: some View {
        HStack(spacing: 12) {
            // Column 1: Icon + Title (40%)
            HStack(spacing: 8) {
                if isEmoji {
                    Text(data.icon)
                        .font(.sqFont(.bodyLarge))
                } else {
                    // SF Symbol
                    if let symbol = SQImageSymbol(rawValue: data.icon) {
                        SQImageView(
                            image: .init(
                                symbol: symbol,
                                symbolStyle: .colorWithFont(.textSecondary, font: .bodySmall)
                            )
                        )
                        .frame(width: 16, height: 16)
                    } else {
                        // Fallback for missing symbols
                        Image(systemName: "questionmark.circle")
                            .font(.sqFont(.bodySmall))
                            .sqForegroundColor(.textSecondary)
                    }
                }

                Text(data.title)
                    .font(.sqFont(.body))
                    .sqForegroundColor(.textPrimary)

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Column 2: Best Value + Unit (30%)
            HStack(spacing: 4) {
                Text(data.bestValue)
                    .font(.sqFont(.bodySmallSemiBold))
                    .sqForegroundColor(.textPrimary)

                Text(data.unit)
                    .font(.sqFont(.bodyExtraSmall))
                    .sqForegroundColor(.textSecondary)
            }
            .frame(maxWidth: .infinity * 0.75, alignment: .trailing)

            // Column 3: Percentile Rank (30%)
            HStack(spacing: 8) {
                Text(percentileText)
                    .font(.sqFont(.bodyExtraSmall))
                    .sqForegroundColor(rankColor)
            }
            .frame(maxWidth: .infinity * 0.75, alignment: .trailing)
        }
    }

    var body: some View {
        mainBody
        .sqBackgroundColor(.backgroundSecondary)
    }
}

#Preview("With Good Performance") {
    SQDashboardPerformanceRow(
        data: SQPerformanceRowData(
            id: "vo2-max",
            icon: SQImageSymbol.heart.rawValue,
            title: "VO2 Max",
            bestValue: "45.3",
            unit: "mL/kg/min",
            percentileRank: 0.15  // Top 85%
        )
    )
    .sqBackgroundColor(.backgroundSecondary)
}

#Preview("With Average Performance") {
    SQDashboardPerformanceRow(
        data: SQPerformanceRowData(
            id: "pace",
            icon: SQImageSymbol.run.rawValue,
            title: "Pace",
            bestValue: "7:30",
            unit: "/mi",
            percentileRank: 0.50  // Top 50%
        )
    )
    .sqBackgroundColor(.backgroundSecondary)
}

#Preview("Insufficient Data") {
    SQDashboardPerformanceRow(
        data: SQPerformanceRowData(
            id: "distance",
            icon: SQImageSymbol.run.rawValue,
            title: "Distance",
            bestValue: "5.2",
            unit: "mi",
            percentileRank: nil  // N/A
        )
    )
    .sqBackgroundColor(.backgroundSecondary)
}
```

**Step 2: Add to Xcode project**

Run: `open BeastFitness.xcodeproj` and add the file to the project under Views/Dashboard/DashboardRows group.

**Step 3: Commit**

```bash
git add BeastFitness/Views/Dashboard/DashboardRows/SQDashboardPerformanceRow.swift
git commit -m "feat: add SQDashboardPerformanceRow view

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 5: Add Percentile Calculation Utility

**Files:**
- Create: `BeastFitness/Utilities/SQPercentileCalculator.swift`

**Step 1: Create the calculator utility**

Create new file with this content:

```swift
//
//  SQPercentileCalculator.swift
//  BeastFitness
//
//  Created by Claude Code on 2026-02-15.
//

import Foundation

struct SQPercentileCalculator {
    /// Calculate percentile rank for a value against historical data
    ///
    /// - Parameters:
    ///   - currentBest: The best value from the current time period
    ///   - historicalValues: All historical values to compare against
    ///   - isLowerBetter: True for metrics where lower is better (e.g., pace), false for higher is better (e.g., VO2 max)
    ///
    /// - Returns: Percentile as decimal (0.0 to 1.0), or nil if insufficient data
    ///
    /// - Note: Returns nil if there are fewer than 2 historical values
    static func calculatePercentile(
        currentBest: Double,
        historicalValues: [Double],
        isLowerBetter: Bool
    ) -> Double? {
        // Need at least 2 data points to calculate percentile
        guard historicalValues.count >= 2 else { return nil }

        let betterCount: Int
        if isLowerBetter {
            // For pace: count how many historical values are slower (higher)
            betterCount = historicalValues.filter { $0 > currentBest }.count
        } else {
            // For VO2/distance: count how many historical values are lower
            betterCount = historicalValues.filter { $0 < currentBest }.count
        }

        // Calculate percentile (0.0 = worst, 1.0 = best)
        let percentile = Double(betterCount) / Double(historicalValues.count)
        return percentile
    }
}
```

**Step 2: Add to Xcode project**

Run: `open BeastFitness.xcodeproj` and add the file to the project under Utilities group.

**Step 3: Commit**

```bash
git add BeastFitness/Utilities/SQPercentileCalculator.swift
git commit -m "feat: add percentile calculation utility

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 6: Update SQDashboardController - Add Historical Data Fetching

**Files:**
- Modify: `BeastFitness/ViewModels/Dashboard/SQDashboardController.swift:100-230`

**Step 1: Add all-time workout fetching in loadUI**

In the `loadUI` method, after fetching yearly workouts (around line 142), add:

```swift
// Fetch all-time workouts for percentile calculations
let allTimeWorkouts = try await workoutManager.getWorkouts(for: .allTime, modelContext: context)
```

**Step 2: Add all-time VO2 max fetching**

After fetching yearly VO2 max samples (around line 128), add:

```swift
let vo2MaxAllTime = try await healthKitManager.fetchVO2MaxSamples(
    .allTime
)
```

**Step 3: Pass all-time data to buildSectionGroups**

Update the `buildSectionGroups` call (around line 207) to include all-time data:

```swift
let sectionGroups = await buildSectionGroups(
    checkIns: currentCheckIns,
    vo2MaxSamples: currentVO2MaxSamples,
    vo2MaxAllTime: vo2MaxAllTime,  // Add this
    workouts: currentWorkouts,
    priorWorkouts: priorWorkouts,
    allTimeWorkouts: allTimeWorkouts,  // Add this
    timeRange: state.selectedTimeRange.toSQTimeRange(),
    priorTimeRange: priorTimeRange,
    context: context
)
```

**Step 4: Update buildSectionGroups signature**

Update the method signature (around line 584):

```swift
private func buildSectionGroups(
    checkIns: [SQDailyCheckInStats],
    vo2MaxSamples: [SQVO2MaxSample],
    vo2MaxAllTime: [SQVO2MaxSample],  // Add this
    workouts: [SQWorkoutSessionable],
    priorWorkouts: [SQWorkoutSessionable],
    allTimeWorkouts: [SQWorkoutSessionable],  // Add this
    timeRange: SQTimeRange,
    priorTimeRange: SQTimeRange,
    context: ModelContext
) async -> [SQDashboardSectionGroupViewModel] {
```

**Step 5: Pass all-time data to buildPerformanceSubsection**

Update the call to `buildPerformanceSubsection` (around line 607):

```swift
if let performanceSection = await buildPerformanceSubsection(
    vo2MaxSamples: vo2MaxSamples,
    vo2MaxAllTime: vo2MaxAllTime,  // Add this
    workouts: workouts,
    allTimeWorkouts: allTimeWorkouts,  // Add this
    timeRange: timeRange
) {
    dailyStatsSections.append(performanceSection)
}
```

**Step 6: Commit**

```bash
git add BeastFitness/ViewModels/Dashboard/SQDashboardController.swift
git commit -m "feat: add all-time data fetching for percentile calculations

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 7: Update buildPerformanceSubsection to Create Performance Rows

**Files:**
- Modify: `BeastFitness/ViewModels/Dashboard/SQDashboardController.swift:323-420`

**Step 1: Update buildPerformanceSubsection signature**

Replace the method signature (around line 324):

```swift
private func buildPerformanceSubsection(
    vo2MaxSamples: [SQVO2MaxSample],
    vo2MaxAllTime: [SQVO2MaxSample],  // Add this
    workouts: [SQWorkoutSessionable],
    allTimeWorkouts: [SQWorkoutSessionable],  // Add this
    timeRange: SQTimeRange
) async -> SQDashboardSubsectionViewModel? {
```

**Step 2: Update VO2 Max row creation**

Replace the VO2 Max row creation (around lines 331-353) with:

```swift
// Add VO2 Max row if we have samples
if !vo2MaxSamples.isEmpty {
    // Calculate best VO2 Max (highest value)
    let bestVO2Max = vo2MaxSamples.map { $0.value }.max() ?? 0.0

    // Format best value (e.g., "45.3")
    let bestValueString = String(format: "%.1f", bestVO2Max)

    // Calculate percentile rank
    let historicalValues = vo2MaxAllTime.map { $0.value }
    let percentileRank = SQPercentileCalculator.calculatePercentile(
        currentBest: bestVO2Max,
        historicalValues: historicalValues,
        isLowerBetter: false  // Higher VO2 max is better
    )

    let vo2MaxRow = SQDashboardMetricPerformanceRowViewModel(
        metricId: "vo2-max",
        icon: SQImageSymbol.heart.rawValue,
        title: "VO2 Max",
        bestValue: bestValueString,
        unit: "mL/kg/min",
        percentileRank: percentileRank
    )
    rows.append(vo2MaxRow)
}
```

**Step 3: Update row type declaration**

Change the rows array type declaration (around line 329):

```swift
var rows: [SQDashboardMetricPerformanceRowViewModel] = []
```

**Step 4: Update column headers**

Update the column headers (around line 418):

```swift
columnHeaders: ["Stat", "Best Score", "Rank"]
```

**Step 5: Update rowsByFilter type**

Update the rowsByFilter declaration (around line 410):

```swift
let rowsByFilter: [String: [SQDashboardMetricPerformanceRowViewModel]] = ["All": rows]
```

**Step 6: Commit**

```bash
git add BeastFitness/ViewModels/Dashboard/SQDashboardController.swift
git commit -m "feat: update performance subsection to use performance view models

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 8: Update buildPerformanceMetricRow

**Files:**
- Modify: `BeastFitness/ViewModels/Dashboard/SQDashboardController.swift:424-484`

**Step 1: Add allTimeWorkouts parameter**

Update the method signature (around line 424):

```swift
private func buildPerformanceMetricRow(
    quantityType: SQQuantityType,
    activityType: HKWorkoutActivityType,
    metrics: [SQWorkoutMetric],
    allTimeWorkouts: [SQWorkoutSessionable]  // Add this
) -> SQDashboardMetricPerformanceRowViewModel? {
```

**Step 2: Replace aggregation logic with "best" logic**

Replace the aggregation switch statement (around lines 432-445) with:

```swift
// Calculate best value based on the quantity type's aggregation strategy
let bestValue: Double
switch quantityType.dashboardAggregationType {
case .minimum:
    // For pace: lower (faster) is better
    bestValue = metrics.map { $0.value }.min() ?? 0

case .maximum:
    // For VO2/distance: higher is better
    bestValue = metrics.map { $0.value }.max() ?? 0

case .sum:
    // For total distance: highest sum is best
    bestValue = metrics.reduce(0.0) { $0 + $1.value }

case .average:
    // For average metrics: highest average is best
    bestValue = metrics.reduce(0.0) { $0 + $1.value } / Double(metrics.count)
}
```

**Step 3: Add percentile calculation**

After calculating bestValue, add:

```swift
// Get all historical metrics for this quantity type and activity type
let historicalMetrics = await withTaskGroup(of: SQWorkoutMetric?.self) { group in
    // Filter all-time workouts by activity type
    let relevantWorkouts = allTimeWorkouts.filter { $0.activityType == activityType }

    for workout in relevantWorkouts {
        group.addTask {
            await workout.getMetric(for: quantityType)
        }
    }

    var results: [SQWorkoutMetric] = []
    for await metric in group {
        if let metric = metric {
            results.append(metric)
        }
    }
    return results
}

// Calculate percentile rank
let historicalValues = historicalMetrics.map { $0.value }
let isLowerBetter = quantityType.dashboardAggregationType == .minimum
let percentileRank = SQPercentileCalculator.calculatePercentile(
    currentBest: bestValue,
    historicalValues: historicalValues,
    isLowerBetter: isLowerBetter
)
```

**Step 4: Update return statement**

Replace the return statement (around line 473) with:

```swift
return SQDashboardMetricPerformanceRowViewModel(
    metricId: metricId,
    icon: icon,
    title: quantityType.displayTitle,
    bestValue: valueString,
    unit: unitString,
    percentileRank: percentileRank,
    quantityType: quantityType,
    activityType: activityType
)
```

**Step 5: Update call sites in buildPerformanceSubsection**

In `buildPerformanceSubsection`, update the call to `buildPerformanceMetricRow` (around line 396):

```swift
if let row = buildPerformanceMetricRow(
    quantityType: quantityType,
    activityType: activityType,
    metrics: metrics,
    allTimeWorkouts: allTimeWorkouts  // Add this
) {
    rows.append(row)
}
```

**Step 6: Commit**

```bash
git add BeastFitness/ViewModels/Dashboard/SQDashboardController.swift
git commit -m "feat: update performance metric row to calculate best value and percentile

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 9: Update SQDashboardSectionView to Render Performance Rows

**Files:**
- Modify: `BeastFitness/Views/Dashboard/SQDashboardSectionView.swift:41-66`

**Step 1: Add case for .metricPerformance**

In the switch statement (around line 43), add a new case after `.metricStats`:

```swift
case .metricPerformance:
    if let performanceViewModel = row as? SQDashboardMetricPerformanceRowViewModel {
        Button(action: {
            handleMetricRowTap(performanceViewModel)
        }) {
            SQDashboardPerformanceRow(
                data: .init(
                    id: performanceViewModel.metricId,
                    icon: performanceViewModel.icon,
                    title: performanceViewModel.title,
                    bestValue: performanceViewModel.bestValue,
                    unit: performanceViewModel.unit,
                    percentileRank: performanceViewModel.percentileRank
                )
            )
        }
        .buttonStyle(.plain)
    }
```

**Step 2: Update handleMetricRowTap to accept base type**

Update the method signature (around line 78) to accept `SQDashboardRowViewModel`:

```swift
private func handleMetricRowTap(_ viewModel: SQDashboardRowViewModel) {
    // Try to extract quantityType and activityType
    let quantityType: SQQuantityType?
    let activityType: HKWorkoutActivityType?
    let title: String

    if let statsViewModel = viewModel as? SQDashboardMetricStatsRowViewModel {
        quantityType = statsViewModel.quantityType
        activityType = statsViewModel.activityType
        title = statsViewModel.title
    } else if let performanceViewModel = viewModel as? SQDashboardMetricPerformanceRowViewModel {
        quantityType = performanceViewModel.quantityType
        activityType = performanceViewModel.activityType
        title = performanceViewModel.title
    } else {
        return
    }

    // Only performance metrics have quantityType and activityType
    guard let quantityType = quantityType,
          let activityType = activityType else {
        SQLogger.shared.log(
            "Cannot display leaderboard: metric '\(title)' does not have quantityType and activityType",
            .debug,
            context: .dashboard
        )
        return
    }

    SQLogger.shared.log(
        "Displaying leaderboard for \(quantityType.displayTitle) - \(activityType.name)",
        .debug,
        context: .dashboard
    )

    // Display leaderboard sheet
    SQAppState.shared.dashboardState.displayLeaderboardSheet(
        quantityType: quantityType,
        activityType: activityType
    )
}
```

**Step 3: Update call site**

Update the call in the `.metricStats` case (around line 48):

```swift
Button(action: {
    handleMetricRowTap(metricStatsViewModel)
}) {
```

**Step 4: Commit**

```bash
git add BeastFitness/Views/Dashboard/SQDashboardSectionView.swift
git commit -m "feat: add rendering support for performance rows

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 10: Verify Build and Test

**Step 1: Build the project**

Run: `xcodebuild -project BeastFitness.xcodeproj -scheme BeastFitness -destination 'platform=iOS Simulator,name=iPhone 15' build`

Expected: Build succeeds with no errors

**Step 2: Run the app in simulator**

Run: `open -a Simulator && xcodebuild -project BeastFitness.xcodeproj -scheme BeastFitness -destination 'platform=iOS Simulator,name=iPhone 15' run`

**Step 3: Visual verification checklist**

Navigate to Dashboard and verify:
- [ ] Performance subsection shows "Best Score" column header instead of "Avg Score"
- [ ] Performance subsection shows "Rank" column header instead of "14d %"
- [ ] VO2 Max row shows best value (not average)
- [ ] VO2 Max row shows "Top X%" (not sparkline)
- [ ] Pace rows show best value (not average)
- [ ] Pace rows show "Top X%" (not sparkline)
- [ ] "Top X%" is green for top-quartile performance
- [ ] "N/A" appears when insufficient historical data
- [ ] Tapping performance rows still opens leaderboard

**Step 4: Test with different time ranges**

Switch between "Today", "Past 7 Days", and "Past Year" time ranges and verify:
- [ ] Best values update correctly
- [ ] Percentile ranks remain consistent (all-time comparison)
- [ ] No crashes or errors

**Step 5: Commit verification notes**

```bash
git add -A
git commit -m "test: verify performance percentiles implementation

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Completion Checklist

- [ ] All new files created and added to Xcode project
- [ ] All existing files updated with new logic
- [ ] Column headers updated to "Best Score" and "Rank"
- [ ] Percentile calculation working correctly
- [ ] "Top X%" display format implemented
- [ ] Color coding for top-quartile performance
- [ ] Edge cases handled (insufficient data shows "N/A")
- [ ] Build succeeds with no errors
- [ ] Visual verification completed
- [ ] All commits made with proper messages

## Notes

- **SQTimeRange.allTime**: Ensure this case exists in the `SQTimeRange` enum. If not, add it or use an alternative approach (e.g., fetching from `.distantPast` to `.now`).
- **Performance consideration**: Fetching all-time workouts may be slow for users with many workouts. Consider caching or optimizing this in future iterations.
- **Testing**: Manual testing is sufficient for this feature. Automated tests can be added in a follow-up task if desired.
