# Leaderboard Performance Chart Design

**Date:** 2026-02-15
**Feature:** Add line chart visualization to leaderboard showing performance over time

## Overview

Add a line chart at the top of the leaderboard view that visualizes workout performance metrics over time. The chart displays all workouts included in the leaderboard, plotted chronologically, helping users visualize their performance trends at a glance.

## Requirements

### Chart Display
- Show metric values (same as `SQLeaderboardRowViewModel.formattedScore`) on Y-axis
- Show workout dates (chronological) on X-axis
- Plot all workouts that appear in the leaderboard
- Fixed height: 220pt for compact, readable visualization
- Include grid lines for easier value reading
- Use built-in CoolCharts tap interaction (no custom handling needed)

### Chart Header
- **Title:** Metric name (e.g., "Distance", "Pace") from `quantityType.displayTitle`
- **Subtitle:** Workout count and date range (e.g., "12 workouts • Jan 2025 - Feb 2026")

### Visual Styling
- Line color: `SQColor.accentPrimary` for brand consistency
- Fonts: Use `SQFont` system (`.bodyExtraSmall` and `.bodySmallBold`)
- Colors: Use `SQColor` system for all UI elements
- Padding only, no background container

### Visibility Rules
- Only show chart when 2+ workouts have valid start dates
- Hide chart entirely when insufficient data
- No error messages needed

## Architecture

### Approach: Controller-Managed Chart Model

All data logic remains centralized in `SQLeaderboardController`, following existing patterns.

**Component Structure:**
```
SQLeaderboardController
├── rows: [SQLeaderboardRowViewModel]  // existing
├── chartModel: LineChartModel?        // NEW - nil if < 2 workouts
├── chartTitle: String                 // NEW - computed property
└── chartSubtitle: String              // NEW - computed property

SQLeaderboardView
├── Chart Section (NEW)
│   ├── Header (title + subtitle)
│   └── LineChartView(model: chartModel)
└── List Section (existing, unchanged)
```

**Why This Approach:**
- Keeps all data/business logic in controller
- View remains purely presentational
- Simple to add chart creation alongside existing row creation
- Controller already has all necessary data

## Data Flow

### Chart Creation (in `SQLeaderboardController.loadUI()`)

**Sequence:**

1. **Fetch & rank workouts** (existing logic - unchanged)
   - Get all workouts for activity type
   - Calculate metrics and sort by aggregation type
   - Create `rows: [SQLeaderboardRowViewModel]`

2. **Build chart data** (NEW - after row creation):
   ```swift
   // Convert rows to CGPoints, filtering out any without start dates
   let points: [CGPoint] = rows.compactMap { row in
       guard let startDate = row.workout.startDate else { return nil }
       return CGPoint(
           x: startDate.timeIntervalSince1970,
           y: row.metric.value
       )
   }

   // Only create chart if we have 2+ valid data points
   guard points.count >= 2 else {
       chartModel = nil
       return
   }

   // Create LineChartModel with configuration
   chartModel = LineChartModel(
       width: 350,
       height: 220,
       lineTitle: quantityType.displayTitle,
       uiConfig: buildChartUIConfig(),
       inputPoints: points,
       gridConfig: GridConfig(),
       focusConfig: FocusConfig()
   )
   ```

3. **View renders**
   - If `chartModel` exists, show chart section with header
   - List section displays as before

**Data Mapping:**
- X-axis: `workout.startDate.timeIntervalSince1970` (only workouts with valid dates)
- Y-axis: `metric.value` (raw value behind `formattedScore`)

## Implementation Details

### SQLeaderboardController Changes

**New Properties:**
```swift
// Chart model - nil if insufficient data
private(set) var chartModel: LineChartModel?

// Computed properties for chart header
var chartTitle: String {
    quantityType.displayTitle
}

var chartSubtitle: String {
    guard let firstDate = rows.first?.workout.startDate,
          let lastDate = rows.last?.workout.startDate else {
        return "\(rows.count) workouts"
    }

    let dateRange = "\(firstDate.formattedString(with: .medium)) - \(lastDate.formattedString(with: .medium))"
    return "\(rows.count) workouts • \(dateRange)"
}
```

**New Helper Method:**
```swift
private func buildChartUIConfig() -> LineChartModel.UIConfig {
    let colorConfig = LineChartModel.ColorConfig(
        textPrimary: SQColor.textPrimary.color,
        textSecondary: SQColor.textSecondary.color,
        backgroundPrimary: SQColor.background.color,
        backgroundSecondary: SQColor.backgroundSecondary.color,
        lineColor: SQColor.accentPrimary.color
    )

    let fontConfig = LineChartModel.FontConfig(
        font: SQFont(type: .bodyExtraSmall).font,
        boldFont: SQFont(type: .bodySmallBold).font
    )

    return LineChartModel.UIConfig(
        colorConfig: colorConfig,
        fontConfig: fontConfig
    )
}
```

**Modified Method:**
- `loadUI(for:)` - Add chart creation logic after row creation (see Data Flow section)

### SQLeaderboardView Changes

**New Chart Section:**
```swift
@ViewBuilder
private func chartSection(_ chartModel: LineChartModel) -> some View {
    VStack(alignment: .leading, spacing: .SQSpace.m) {
        // Header
        VStack(alignment: .leading, spacing: .SQSpace.xs) {
            Text(controller.chartTitle)
                .sqFont(.bodyMediumBold)
                .sqForegroundColor(.textPrimary)

            Text(controller.chartSubtitle)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)
        }

        // Chart
        LineChartView(model: chartModel)
            .frame(height: 220)
    }
    .padding(.horizontal, .SQSpace.l)
    .padding(.vertical, .SQSpace.xl)
    .background(SQColor.background.color)
}
```

**Modified Layout:**
```swift
var body: some View {
    NavigationStack(path: $controller.navigationPath) {
        VStack(spacing: 0) {
            // NEW: Chart Section (only if chartModel exists)
            if let chartModel = controller.chartModel {
                chartSection(chartModel)
            }

            // Existing: List Section
            leaderboardList
        }
        .navigationTitle(controller.title)
        .navigationBarTitleDisplayMode(.inline)
        .background(SQColor.background.color)
        .task {
            await controller.loadUI(for: modelContext)
        }
    }
}
```

**Spacing:**
- Horizontal padding: `.SQSpace.l` around entire chart section
- Vertical padding: `.SQSpace.xl` above/below chart section
- Gap between header and chart: `.SQSpace.m`
- Gap between title and subtitle: `.SQSpace.xs`

## Chart Configuration

### LineChartModel Parameters

| Parameter | Value | Notes |
|-----------|-------|-------|
| width | 350pt | Fits most devices with padding |
| height | 220pt | Compact but readable |
| lineTitle | `quantityType.displayTitle` | Used by focus feature |
| lineColor | `SQColor.accentPrimary` | Brand consistency |
| inputPoints | Array of CGPoint | X = timestamp, Y = metric value |
| gridConfig | `GridConfig()` | Default grid lines |
| focusConfig | `FocusConfig()` | Built-in tap interaction |
| uiConfig | Custom config | Uses SQColor and SQFont systems |

### Color Configuration
- **Text Primary:** `SQColor.textPrimary`
- **Text Secondary:** `SQColor.textSecondary`
- **Background Primary:** `SQColor.background`
- **Background Secondary:** `SQColor.backgroundSecondary`
- **Line Color:** `SQColor.accentPrimary`

### Font Configuration
- **Regular:** `SQFont(type: .bodyExtraSmall).font`
- **Bold:** `SQFont(type: .bodySmallBold).font`

## Edge Cases & Error Handling

### Edge Cases

1. **< 2 workouts total**
   - `chartModel` remains `nil`
   - Chart section doesn't render
   - Only list (or empty state) shows

2. **< 2 workouts with valid start dates**
   - Some workouts in rows, but < 2 have dates
   - `chartModel` set to `nil`
   - Chart section hidden, list shows all rows

3. **Empty state (0 workouts)**
   - Existing empty state view shows
   - No chart section
   - No changes to empty state logic

4. **Loading state**
   - During `isLoading`, chart section hidden
   - Only redacted list rows show (existing behavior)
   - Chart appears after loading completes

5. **Date range formatting**
   - If dates missing: subtitle shows just count
   - Example: "5 workouts" vs "5 workouts • Jan 2025 - Feb 2026"
   - Graceful degradation

6. **LineChartModel initialization failure**
   - `LineChartModel.init` can return `nil`
   - Controller sets `chartModel = nil`
   - Chart section doesn't render

### Error Handling Strategy

**No explicit error messages needed** - all edge cases gracefully degrade to hiding the chart. This provides clean UX without cluttering the interface with error states. The list always shows (or empty state if no workouts).

## Testing Considerations

### Test Cases

1. **Happy path:** 10+ workouts with dates → chart renders
2. **Minimum data:** Exactly 2 workouts → chart renders
3. **Insufficient data:** 1 workout → no chart
4. **Missing dates:** 5 workouts, only 1 has date → no chart
5. **Mixed dates:** 5 workouts, 3 have dates → chart shows 3 points
6. **Empty state:** 0 workouts → empty state, no chart
7. **Loading state:** Chart hidden during load, appears after

### Manual Testing

- Test with different metric types (distance, pace, heart rate)
- Test with different activity types (running, cycling)
- Verify tap interaction works (built-in CoolCharts behavior)
- Verify chart scales properly on different screen sizes
- Check date range formatting edge cases

## Files Modified

### Modified Files
- `BeastFitness/ViewModels/Leaderboard/SQLeaderboardController.swift`
  - Add `chartModel` property
  - Add `chartTitle` and `chartSubtitle` computed properties
  - Add `buildChartUIConfig()` helper method
  - Update `loadUI(for:)` to create chart

- `BeastFitness/Views/Leaderboard/SQLeaderboardView.swift`
  - Add `chartSection(_:)` view builder
  - Update body to conditionally show chart section
  - Wrap existing content in VStack

### No Changes Required
- `SQLeaderboardRowViewModel.swift` - unchanged
- `SQLeaderboardRowView.swift` - unchanged
- CoolCharts package - unchanged

## Future Enhancements

Potential future improvements (not in scope for this design):

- Time range selector (last week, month, year, all time)
- Metric type switcher (view different metrics without navigating)
- Highlight personal bests on the chart
- Compare multiple metrics on same chart
- Export chart as image
- Trend line or moving average overlay

## Summary

This design adds a performance visualization to the leaderboard while maintaining the existing architecture patterns. By keeping chart logic in the controller and using CoolCharts' LineChartView, we get a robust, well-styled chart with minimal complexity. The chart enhances the leaderboard by providing visual context for performance trends without interfering with the existing list-based view.
