# Dashboard Performance Percentiles Design

**Date:** 2026-02-15
**Status:** Approved

## Overview

Replace the current performance row display (average value + sparkline + 14-day percentage change) with a new system that shows best performance values and all-time percentile rankings. This provides more meaningful insights by showing how current performance compares to historical data.

## Goals

1. Show **best score** from the current time period instead of average
2. Display **all-time percentile rank** instead of 14-day percentage change
3. Create a clean separation between stats rows (for daily check-in metrics) and performance rows (for workout/VO2 metrics)

## Architecture Overview

### New Components

1. **SQDashboardMetricPerformanceRowViewModel**
   - View model for performance metrics
   - Contains: best value, percentile rank, metadata (icon, title, unit, quantityType, activityType)
   - Mirrors structure of `SQDashboardMetricStatsRowViewModel` but for performance data

2. **SQPerformanceRowData**
   - Data structure for rendering performance rows
   - Mirrors `SQStatRowData` but without sparklineData, adds percentileRank

3. **SQDashboardPerformanceRow**
   - SwiftUI view component for rendering performance rows
   - Identical layout to `SQDashboardStatRow` but shows "Top X%" instead of sparkline

### Updates to Existing Components

1. **SQDashboardRowType enum**
   - Add new `.metricPerformance` case
   - Distinguishes performance rows from stats rows

2. **SQDashboardController.buildPerformanceSubsection()**
   - Change from creating `SQDashboardMetricStatsRowViewModel` instances
   - Create `SQDashboardMetricPerformanceRowViewModel` instances instead
   - Update column headers: `["Stat", "Best Score", "Rank"]`

3. **SQDashboardSectionView**
   - Add switch case for `.metricPerformance` row type
   - Render `SQDashboardPerformanceRow` for performance metrics

## Data Flow

1. **Data Collection**
   - Controller fetches all historical workouts and VO2 max samples (all-time, not just past year)
   - Fetches current time period workouts/samples

2. **Best Value Calculation**
   - For each metric in current period, determine "best" based on aggregation type:
     - `.minimum` (pace metrics) → lowest/fastest value
     - `.maximum` (VO2, distance) → highest/furthest value
     - `.sum` (total distance) → highest sum
     - `.average` → highest average

3. **Percentile Calculation**
   - Compare best value from current period against ALL historical data points
   - Algorithm:
     ```
     percentile = (count of historical values worse than best) / (total historical count) * 100
     displayValue = 100 - percentile  // Convert to "Top X%"
     ```
   - Example:
     - Best pace this week: 7:30/mi
     - Historical paces: [8:00, 7:45, 7:30, 7:15, 7:00]
     - Values worse than 7:30: 3 (8:00, 7:45, 7:30)
     - Percentile: (3/5) * 100 = 60th percentile
     - Display: "Top 40%"

4. **View Model Creation**
   - Create `SQDashboardMetricPerformanceRowViewModel` with:
     - Best value (formatted string)
     - Percentile rank (as decimal, e.g., 0.40 for "Top 40%")
     - Metadata (icon, title, unit, quantityType, activityType)

5. **Rendering**
   - View converts view model to `SQPerformanceRowData`
   - Renders with "Top X%" in place of sparkline

## Percentile Calculation Details

### Algorithm

```swift
func calculatePercentile(currentBest: Double, historicalValues: [Double], isLowerBetter: Bool) -> Double? {
    guard historicalValues.count >= 2 else { return nil }

    let betterCount: Int
    if isLowerBetter {
        // For pace: lower is better
        betterCount = historicalValues.filter { $0 < currentBest }.count
    } else {
        // For VO2/distance: higher is better
        betterCount = historicalValues.filter { $0 > currentBest }.count
    }

    let percentile = Double(betterCount) / Double(historicalValues.count)
    return percentile // Return as decimal (0.0 to 1.0)
}
```

### Display Format

- Percentile stored as decimal (0.0 to 1.0)
- Displayed as "Top X%" where X = `(1 - percentile) * 100`
- Example: 0.40 percentile → "Top 60%"

### Direction Logic

- **Lower is better** (pace metrics):
  - Faster pace (lower number) = better performance
  - Count how many historical values are slower (higher)

- **Higher is better** (VO2, distance):
  - Higher value = better performance
  - Count how many historical values are lower

## Best Value Aggregation

Use existing `SQQuantityType.dashboardAggregationType` but interpret for "best":

- `.minimum` → Take minimum value (best for pace)
- `.maximum` → Take maximum value (best for VO2/distance)
- `.average` → Take maximum average
- `.sum` → Take maximum sum

## View Layer Design

### SQDashboardPerformanceRow

Mirrors `SQDashboardStatRow` structure exactly:

**Layout:**
- Column 1 (40%): Icon + Title
- Column 2 (30%): Best Value + Unit
- Column 3 (30%): "Top X%" text

**Styling:**
- Same fonts, colors, spacing as `SQDashboardStatRow`
- Percentile text color: green for top quartile (< 0.25), standard text color otherwise
- No sparkline component

**Differences from SQDashboardStatRow:**
- Shows "Top X%" instead of sparkline + percentage change
- Value represents "best" not "average"

### Column Headers

Performance subsection headers change from:
```swift
["Stat", "Avg Score", "14d %"]
```

To:
```swift
["Stat", "Best Score", "Rank"]
```

## Edge Cases & Error Handling

### Insufficient Historical Data

- **< 2 historical values:** Show "N/A" for rank
- **First-ever value:** Show "N/A" (cannot rank with single data point)
- **No current period data:** Don't create row at all

### Tied Values

- Values equal to current best count as "better or equal"
- Standard percentile calculation handles this naturally

### Empty States

- If no performance data exists for time period, subsection shows empty state
- Individual metrics with no data are simply not rendered (no row created)

## Implementation Notes

### Data Structure Definitions

```swift
// View Model
@Observable @MainActor
final class SQDashboardMetricPerformanceRowViewModel: SQDashboardRowViewModel {
    let metricId: String
    let icon: String
    let title: String
    let bestValue: String
    let unit: String
    let percentileRank: Double?  // 0.0 to 1.0, nil if insufficient data
    let quantityType: SQQuantityType?
    let activityType: HKWorkoutActivityType?
}

// Data for rendering
struct SQPerformanceRowData: Identifiable {
    let id: String
    let icon: String
    let title: String
    let bestValue: String
    let unit: String
    let percentileRank: Double?  // 0.0 to 1.0, nil if insufficient data
}
```

### Controller Changes

In `SQDashboardController.buildPerformanceSubsection()`:
1. Fetch all-time historical data (not just current time range)
2. For each metric, calculate best value from current period
3. Calculate percentile against all historical values
4. Create `SQDashboardMetricPerformanceRowViewModel` instead of stats view model
5. Update column headers

In `SQDashboardController.buildPerformanceMetricRow()`:
1. Rename to reflect new purpose (or create new method)
2. Change aggregation to find "best" instead of "average"
3. Add percentile calculation logic
4. Return performance view model instead of stats view model

## Testing Considerations

1. **Percentile calculation accuracy**
   - Test with known datasets
   - Verify "lower is better" vs "higher is better" logic

2. **Edge cases**
   - Empty datasets
   - Single data point
   - Tied values

3. **Display formatting**
   - "Top 0%" to "Top 100%" range
   - "N/A" display for insufficient data

## Future Enhancements

1. **Trend indicators:** Show if percentile is improving or declining over time
2. **Sparkline of percentile over time:** Show historical percentile rankings
3. **Configurable time ranges:** Allow user to choose all-time vs 1-year vs 6-month comparisons
