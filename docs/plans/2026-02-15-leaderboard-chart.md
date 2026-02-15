# Leaderboard Performance Chart Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a line chart at the top of the leaderboard showing performance metrics over time

**Architecture:** Controller-managed chart model approach - `SQLeaderboardController` creates `LineChartModel` during data loading, view conditionally renders chart section above the list. Uses CoolCharts `LineChartView` for visualization.

**Tech Stack:** SwiftUI, CoolCharts (local package), BeastFitnessCore

---

## Task 1: Add Chart Model Property to Controller

**Files:**
- Modify: `BeastFitness/ViewModels/Leaderboard/SQLeaderboardController.swift:14-31`

**Step 1: Add import for CoolCharts**

Add at the top of the file with other imports:

```swift
import CoolCharts
```

**Step 2: Add chartModel property**

Add after the `rows` property (around line 30):

```swift
private(set) var chartModel: LineChartModel?
```

**Step 3: Build the project to verify syntax**

Run: `⌘B` (Build) in Xcode
Expected: Build succeeds

**Step 4: Commit**

```bash
git add BeastFitness/ViewModels/Leaderboard/SQLeaderboardController.swift
git commit -m "feat(leaderboard): add chart model property to controller

Add LineChartModel property to store chart configuration.
Will be populated during loadUI if sufficient data exists.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 2: Add Chart Title and Subtitle Computed Properties

**Files:**
- Modify: `BeastFitness/ViewModels/Leaderboard/SQLeaderboardController.swift:32-34`

**Step 1: Add chartTitle computed property**

Add after the `title` property (around line 34):

```swift
var chartTitle: String {
    quantityType.displayTitle
}
```

**Step 2: Add chartSubtitle computed property**

Add after `chartTitle`:

```swift
var chartSubtitle: String {
    guard let firstDate = rows.first?.workout.startDate,
          let lastDate = rows.last?.workout.startDate else {
        return "\(rows.count) workouts"
    }

    let dateRange = "\(firstDate.formattedString(with: .medium)) - \(lastDate.formattedString(with: .medium))"
    return "\(rows.count) workouts • \(dateRange)"
}
```

**Step 3: Build the project to verify syntax**

Run: `⌘B` (Build) in Xcode
Expected: Build succeeds

**Step 4: Commit**

```bash
git add BeastFitness/ViewModels/Leaderboard/SQLeaderboardController.swift
git commit -m "feat(leaderboard): add chart header properties

Add computed properties for chart title and subtitle.
Title shows metric name, subtitle shows workout count and date range.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 3: Add Chart UI Configuration Builder

**Files:**
- Modify: `BeastFitness/ViewModels/Leaderboard/SQLeaderboardController.swift:166-168`

**Step 1: Add buildChartUIConfig helper method**

Add after the `loadUI` method (around line 166, before the closing brace):

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

**Step 2: Build the project to verify syntax**

Run: `⌘B` (Build) in Xcode
Expected: Build succeeds

**Step 3: Commit**

```bash
git add BeastFitness/ViewModels/Leaderboard/SQLeaderboardController.swift
git commit -m "feat(leaderboard): add chart UI configuration builder

Add helper method to build LineChartModel.UIConfig using SQColor
and SQFont for consistent app theming.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 4: Add Chart Data Creation to loadUI

**Files:**
- Modify: `BeastFitness/ViewModels/Leaderboard/SQLeaderboardController.swift:150-158`

**Step 1: Add chart creation logic**

Add just before `isLoading = false` (around line 158):

```swift
// Build chart data from rows
let points: [CGPoint] = rows.compactMap { row in
    guard let startDate = row.workout.startDate else { return nil }
    return CGPoint(
        x: startDate.timeIntervalSince1970,
        y: row.metric.value
    )
}

// Only create chart if we have 2+ valid data points
if points.count >= 2 {
    chartModel = LineChartModel(
        width: 350,
        height: 220,
        lineTitle: quantityType.displayTitle,
        uiConfig: buildChartUIConfig(),
        inputPoints: points,
        gridConfig: GridConfig(),
        focusConfig: FocusConfig()
    )

    SQLogger.shared.log(
        "Created chart with \(points.count) data points",
        .debug,
        context: .workoutList
    )
} else {
    chartModel = nil
    SQLogger.shared.log(
        "Insufficient data for chart (\(points.count) points, need 2+)",
        .debug,
        context: .workoutList
    )
}
```

**Step 2: Build the project to verify syntax**

Run: `⌘B` (Build) in Xcode
Expected: Build succeeds

**Step 3: Commit**

```bash
git add BeastFitness/ViewModels/Leaderboard/SQLeaderboardController.swift
git commit -m "feat(leaderboard): add chart data creation to loadUI

Create LineChartModel from workout rows if 2+ workouts have valid
start dates. Maps workout dates to X-axis and metric values to Y-axis.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 5: Add Chart Section to View

**Files:**
- Modify: `BeastFitness/Views/Leaderboard/SQLeaderboardView.swift:1-10`

**Step 1: Add CoolCharts import**

Add with other imports at the top:

```swift
import CoolCharts
```

**Step 2: Add chartSection view builder**

Add after the `rowView` method (around line 58, before the `leaderboardList` property):

```swift
// MARK: - Chart Section

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

**Step 3: Build the project to verify syntax**

Run: `⌘B` (Build) in Xcode
Expected: Build succeeds

**Step 4: Commit**

```bash
git add BeastFitness/Views/Leaderboard/SQLeaderboardView.swift
git commit -m "feat(leaderboard): add chart section view builder

Add chartSection view that displays chart header (title + subtitle)
and LineChartView with proper spacing and styling.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 6: Update View Layout to Include Chart

**Files:**
- Modify: `BeastFitness/Views/Leaderboard/SQLeaderboardView.swift:86-95`

**Step 1: Replace navView with new layout**

Replace the current `navView` computed property (around line 86-95) with:

```swift
var navView: some View {
    VStack(spacing: 0) {
        // Chart Section (only if chartModel exists)
        if let chartModel = controller.chartModel {
            chartSection(chartModel)
        }

        // Content (list or empty state)
        contentView
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .navigationTitle(controller.title)
    .navigationBarTitleDisplayMode(.inline)
    .background(SQColor.background.color)
    .task {
        await controller.loadUI(for: modelContext)
    }
}
```

**Step 2: Build the project to verify syntax**

Run: `⌘B` (Build) in Xcode
Expected: Build succeeds

**Step 3: Run the app in simulator to verify chart appears**

Run: `⌘R` (Run) in Xcode
Expected: Leaderboard shows chart at top if 2+ workouts exist

**Step 4: Commit**

```bash
git add BeastFitness/Views/Leaderboard/SQLeaderboardView.swift
git commit -m "feat(leaderboard): integrate chart into view layout

Update navView to conditionally display chart section above list.
Chart only shows when chartModel exists (2+ workouts with dates).

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 7: Manual Testing

**Files:**
- No file changes

**Step 1: Test with sufficient data (10+ workouts)**

Actions:
1. Open leaderboard for activity type with many workouts (e.g., running)
2. Verify chart appears at top
3. Verify chart shows all workout points
4. Tap chart to verify focus interaction works
5. Verify header shows correct metric name and date range

Expected:
- Chart renders with line connecting points
- Grid lines visible
- Tap interaction highlights focused point
- Title shows metric name (e.g., "Distance")
- Subtitle shows count and date range (e.g., "15 workouts • Jan 2025 - Feb 2026")

**Step 2: Test with minimum data (exactly 2 workouts)**

Actions:
1. Find or create activity type with exactly 2 workouts
2. Open leaderboard
3. Verify chart appears with 2 points connected

Expected:
- Chart renders correctly with 2 data points
- Line connects the 2 points

**Step 3: Test with insufficient data (< 2 workouts)**

Actions:
1. Find or create activity type with 0 or 1 workout
2. Open leaderboard
3. Verify chart section doesn't appear

Expected:
- No chart section visible
- List or empty state shows normally
- No errors or warnings

**Step 4: Test with mixed data (some workouts missing dates)**

Note: This is harder to test in real app since HealthKit workouts always have dates.
Consider this covered by edge case handling in code.

Expected:
- Chart only plots workouts with valid dates
- Chart hidden if < 2 workouts have valid dates

**Step 5: Test different metric types**

Actions:
1. View distance leaderboard - verify chart shows distance values
2. View pace leaderboard - verify chart shows pace values
3. View other metric leaderboards as available

Expected:
- Chart adapts to show correct metric values
- Y-axis scales appropriately for different metric ranges

**Step 6: Test chart appearance on different devices**

Actions:
1. Run on iPhone SE (small screen)
2. Run on iPhone 15 Pro Max (large screen)
3. Run on iPad (if supported)

Expected:
- Chart renders properly on all screen sizes
- Width/height proportions look good
- Text remains readable

**Step 7: Document any issues found**

If issues are found during testing, create new tasks to fix them.
Otherwise, testing is complete.

---

## Edge Cases Verified by Implementation

The following edge cases are handled by the implementation and don't require separate testing tasks:

1. **< 2 workouts total** - `chartModel` stays nil, chart hidden
2. **< 2 workouts with valid dates** - `compactMap` filters, chart hidden if < 2 points
3. **Empty state (0 workouts)** - Existing empty state shows, no chart
4. **Loading state** - Chart appears after loading, redacted list shows during load
5. **Date range formatting** - Graceful fallback if dates missing
6. **LineChartModel init failure** - Optional return handled, chart hidden if nil

---

## Completion Checklist

- [ ] Task 1: Chart model property added
- [ ] Task 2: Chart title/subtitle properties added
- [ ] Task 3: Chart UI config builder added
- [ ] Task 4: Chart creation in loadUI implemented
- [ ] Task 5: Chart section view added
- [ ] Task 6: View layout updated
- [ ] Task 7: Manual testing completed
- [ ] All commits made
- [ ] No build errors
- [ ] Chart displays correctly in app

---

## Notes

**SwiftUI Preview Testing:**
- Previews may not work well for this feature since it requires real workout data
- Prefer simulator testing with actual HealthKit workouts or mock data

**Performance:**
- Chart creation happens once during loadUI, not on every render
- LineChartModel does coordinate calculations on init, then caches them
- Should perform well even with 100+ workouts in leaderboard

**Future Improvements (out of scope):**
- Time range selector
- Metric switcher
- Export chart as image
- Trend line overlay
