# Leaderboard Time Range Selector Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add time range filtering to leaderboard view with dropdown selector, synced to dashboard's current time range.

**Architecture:** Create shared `AppTimeRange` enum to unify time range selection across dashboard and leaderboard. Controller manages time range state and triggers reloads when changed. Dashboard passes initial time range to leaderboard on navigation (Today → All Time exception).

**Tech Stack:** SwiftUI, Swift Observation, Combine

---

## Task 1: Create AppTimeRange Enum

**Files:**
- Create: `BeastFitness/Models/AppTimeRange.swift`

**Step 1: Create the AppTimeRange enum file**

```swift
//
//  AppTimeRange.swift
//  BeastFitness
//
//  Created by Claude on 2/17/26.
//

import Foundation

enum AppTimeRange: String, CaseIterable {
    case today = "Today"
    case pastSevenDays = "Past 7 Days"
    case past30Days = "Past 30 Days"
    case pastYear = "Past Year"
    case allTime = "All Time"

    /// Maps to the underlying SQTimeRange for data queries
    var sqTimeRange: SQTimeRange {
        switch self {
        case .today: return .today
        case .pastSevenDays: return .pastWeek
        case .past30Days: return .past30Days
        case .pastYear: return .pastYear
        case .allTime: return .allTime
        }
    }

    /// Returns the comparison period for trend calculations (nil for allTime)
    var previousSqTimeRange: SQTimeRange? {
        switch self {
        case .today: return .yesterday
        case .pastSevenDays: return .weekBeforeLast
        case .past30Days: return .thirtyDaysBeforeLast
        case .pastYear: return .yearBeforeLast
        case .allTime: return nil
        }
    }

    /// Sort order for display in dropdowns (0 = first)
    var sortOrder: Int {
        switch self {
        case .today: return 0
        case .pastSevenDays: return 1
        case .past30Days: return 2
        case .pastYear: return 3
        case .allTime: return 4
        }
    }
}
```

**Step 2: Add file to Xcode project**

- Open `BeastFitness.xcodeproj` in Xcode
- Right-click on `BeastFitness/Models` folder
- Select "Add Files to BeastFitness"
- Select `AppTimeRange.swift`
- Ensure "BeastFitness" target is checked
- Click "Add"

**Step 3: Build to verify no errors**

Run: Build the project (Cmd+B)
Expected: Build succeeds with no errors

**Step 4: Commit**

```bash
git add BeastFitness/Models/AppTimeRange.swift
git commit -m "Add AppTimeRange enum for unified time range selection

- Replaces DashboardTimeRange with shared enum
- Supports: Today, Past 7 Days, Past 30 Days, Past Year, All Time
- Includes sqTimeRange mapping, previousSqTimeRange, and sortOrder"
```

---

## Task 2: Update SQTimeRange Enum

**Files:**
- Modify: `BeastFitness/Models/SQTimeRange.swift`

**Step 1: Rename pastMonth to past30Days**

In `SQTimeRange.swift`, find:
```swift
case pastMonth = "Past Month"
```

Replace with:
```swift
case past30Days = "Past 30 Days"
```

**Step 2: Add thirtyDaysBeforeLast case**

After the `past30Days` case, add:
```swift
case thirtyDaysBeforeLast = "30 Days Before Last"
```

**Step 3: Update startDate for past30Days**

In the `startDate` computed property, find:
```swift
case .pastMonth:
    return calendar.date(byAdding: .month, value: -11, to: endDate)!
```

Replace with:
```swift
case .past30Days:
    return calendar.date(byAdding: .day, value: -30, to: endDate)!
case .thirtyDaysBeforeLast:
    return calendar.date(byAdding: .day, value: -60, to: endDate)!
```

**Step 4: Update endDate for new cases**

In the `endDate` computed property, find the switch statement and update:
```swift
case .pastWeek, .pastMonth, .pastYear, .allTime, .today:
    .now
```

Replace with:
```swift
case .pastWeek, .past30Days, .pastYear, .allTime, .today:
    .now
```

Then add the new case after `.yesterday`:
```swift
case .thirtyDaysBeforeLast:
    SQTimeRange.past30Days.startDate
```

**Step 5: Build to verify no errors**

Run: Build the project (Cmd+B)
Expected: Build succeeds (may have warnings about DashboardTimeRange using old .pastMonth - we'll fix this next)

**Step 6: Commit**

```bash
git add BeastFitness/Models/SQTimeRange.swift
git commit -m "Rename pastMonth to past30Days and add thirtyDaysBeforeLast

- pastMonth now correctly represents 30 days (was 11 months)
- Add thirtyDaysBeforeLast for Past 30 Days comparison period
- Update date calculations for new cases"
```

---

## Task 3: Update DashboardState to Use AppTimeRange

**Files:**
- Modify: `BeastFitness/StateManagement/DashboardState.swift`

**Step 1: Remove DashboardTimeRange enum**

Delete the entire `DashboardTimeRange` enum (lines 13-28):
```swift
enum DashboardTimeRange: String, CaseIterable {
    case today = "Today"
    case pastSevenDays = "Past 7 Days"
    case pastYear = "Past Year"

    func toSQTimeRange() -> SQTimeRange {
        switch self {
        case .today:
            return .today
        case .pastSevenDays:
            return .pastWeek
        case .pastYear:
            return .pastYear
        }
    }
}
```

**Step 2: Update DashboardStating protocol**

In the `DashboardStating` protocol, change:
```swift
var selectedTimeRange: DashboardTimeRange { get set }
var selectedTimeRangePublisher: AnyPublisher<DashboardTimeRange, Never> { get }
```

To:
```swift
var selectedTimeRange: AppTimeRange { get set }
var selectedTimeRangePublisher: AnyPublisher<AppTimeRange, Never> { get }
```

**Step 3: Update DashboardState implementation**

Change the selectedTimeRange property type and publisher:
```swift
private let selectedTimeRangeSubject = PassthroughSubject<AppTimeRange, Never>()
var selectedTimeRangePublisher: AnyPublisher<AppTimeRange, Never> {
    selectedTimeRangeSubject.eraseToAnyPublisher()
}

var selectedTimeRange: AppTimeRange = .today {
    didSet {
        selectedTimeRangeSubject.send(selectedTimeRange)
    }
}
```

**Step 4: Update displayLeaderboardSheet with initial time range logic**

Find the `displayLeaderboardSheet` method and update it:

```swift
func displayLeaderboardSheet(quantityType: SQQuantityType, activityType: HKWorkoutActivityType) {
    // Determine initial time range based on dashboard selection
    let initialTimeRange: AppTimeRange = {
        // Exception: Today → All Time (not enough data for meaningful leaderboard)
        if selectedTimeRange == .today {
            return .allTime
        }

        // Fallback: If time range not available, use last (largest) time range
        if !AppTimeRange.allCases.contains(selectedTimeRange) {
            return AppTimeRange.allCases
                .sorted(by: { $0.sortOrder < $1.sortOrder })
                .last ?? .allTime
        }

        return selectedTimeRange
    }()

    leaderboardController = .init(
        state: SQAppState.shared.leaderboardState,
        quantityType: quantityType,
        activityType: activityType,
        initialTimeRange: initialTimeRange
    )
    toggleLeaderboardSheetVisibility(true)
}
```

**Step 5: Build to verify no errors**

Run: Build the project (Cmd+B)
Expected: Build will fail - DashboardController still uses old DashboardTimeRange

**Step 6: Commit**

```bash
git add BeastFitness/StateManagement/DashboardState.swift
git commit -m "Update DashboardState to use AppTimeRange

- Remove DashboardTimeRange enum (replaced by AppTimeRange)
- Update selectedTimeRange property type
- Add initial time range logic in displayLeaderboardSheet
- Implement Today → All Time exception for leaderboard"
```

---

## Task 4: Update DashboardController to Use AppTimeRange

**Files:**
- Modify: `BeastFitness/ViewModels/Dashboard/SQDashboardController.swift`

**Step 1: Update timeRangeMenuViewModel initialization**

In the `init` method (around line 46), find:
```swift
let items = DashboardTimeRange.allCases.map {
    SQDropDownMenuViewModel.Item(title: $0.rawValue)
}
```

Replace with:
```swift
let items = AppTimeRange.allCases
    .sorted(by: { $0.sortOrder < $1.sortOrder })
    .map { SQDropDownMenuViewModel.Item(title: $0.rawValue) }
```

**Step 2: Update itemSelectionHandler**

Find:
```swift
if let selectedRange = DashboardTimeRange.allCases.first(where: { $0.rawValue == selectedTitle }) {
    state.selectedTimeRange = selectedRange
}
```

Replace with:
```swift
if let selectedRange = AppTimeRange.allCases.first(where: { $0.rawValue == selectedTitle }) {
    state.selectedTimeRange = selectedRange
}
```

**Step 3: Update loadUI to use sqTimeRange**

In the `loadUI` method (around line 109), find:
```swift
let timeRange = state.selectedTimeRange.toSQTimeRange()
```

Replace with:
```swift
let timeRange = state.selectedTimeRange.sqTimeRange
```

**Step 4: Update buildSectionGroups to use previousSqTimeRange**

In the `loadUI` method, update the switch statement for determining prior time ranges:

Find:
```swift
switch state.selectedTimeRange {
case .today:
    currentWorkouts = todaysWorkouts
    priorTimeRange = .yesterday
    priorWorkouts = yesterdaysWorkouts
    currentCheckIns = todaysCheckIns
    currentVO2MaxSamples = vo2MaxPast7Days
case .pastSevenDays:
    currentWorkouts = lastWeekWorkouts
    priorWorkouts = weekBeforeLastWorkouts
    priorTimeRange = .weekBeforeLast
    currentCheckIns = past7DaysCheckIns
    currentVO2MaxSamples = vo2MaxPast7Days
case .pastYear:
    currentWorkouts = lastYearWorkouts
    priorWorkouts = yearBeforeLastWorkouts
    priorTimeRange = .yearBeforeLast
    currentCheckIns = pastYearCheckIns
    currentVO2MaxSamples = vo2MaxPastYear
}
```

Replace with:
```swift
switch state.selectedTimeRange {
case .today:
    currentWorkouts = todaysWorkouts
    priorTimeRange = .yesterday
    priorWorkouts = yesterdaysWorkouts
    currentCheckIns = todaysCheckIns
    currentVO2MaxSamples = vo2MaxPast7Days
case .pastSevenDays:
    currentWorkouts = lastWeekWorkouts
    priorWorkouts = weekBeforeLastWorkouts
    priorTimeRange = .weekBeforeLast
    currentCheckIns = past7DaysCheckIns
    currentVO2MaxSamples = vo2MaxPast7Days
case .past30Days:
    // TODO: Need to fetch past30Days and thirtyDaysBeforeLast workouts
    currentWorkouts = lastWeekWorkouts  // Temporary placeholder
    priorWorkouts = weekBeforeLastWorkouts  // Temporary placeholder
    priorTimeRange = .thirtyDaysBeforeLast
    currentCheckIns = past7DaysCheckIns  // Temporary placeholder
    currentVO2MaxSamples = vo2MaxPast7Days  // Temporary placeholder
case .pastYear:
    currentWorkouts = lastYearWorkouts
    priorWorkouts = yearBeforeLastWorkouts
    priorTimeRange = .yearBeforeLast
    currentCheckIns = pastYearCheckIns
    currentVO2MaxSamples = vo2MaxPastYear
case .allTime:
    currentWorkouts = allTimeWorkouts
    priorWorkouts = []  // No comparison for all time
    priorTimeRange = .allTime  // Placeholder, won't be used
    currentCheckIns = pastYearCheckIns  // Use past year as proxy
    currentVO2MaxSamples = vo2MaxAllTime
}
```

**Note:** We're adding temporary placeholders for `.past30Days` and `.allTime`. These will need proper data fetching in a future task, but for now we'll use existing data to avoid breaking the build.

**Step 5: Update buildMetricsSubsection signature**

Find the method signature:
```swift
private func buildMetricsSubsection(
    checkIns: [SQDailyCheckInStats],
    timeRange: DashboardTimeRange,
    context: ModelContext
) -> SQDashboardSubsectionViewModel {
```

Replace with:
```swift
private func buildMetricsSubsection(
    checkIns: [SQDailyCheckInStats],
    timeRange: AppTimeRange,
    context: ModelContext
) -> SQDashboardSubsectionViewModel {
```

**Step 6: Build to verify no errors**

Run: Build the project (Cmd+B)
Expected: Build succeeds

**Step 7: Commit**

```bash
git add BeastFitness/ViewModels/Dashboard/SQDashboardController.swift
git commit -m "Update DashboardController to use AppTimeRange

- Update dropdown to use AppTimeRange with sortOrder
- Replace toSQTimeRange() with sqTimeRange property
- Add support for past30Days and allTime cases (with placeholders)
- Update method signatures to use AppTimeRange"
```

---

## Task 5: Update SQLeaderboardController for Time Range Management

**Files:**
- Modify: `BeastFitness/ViewModels/Leaderboard/SQLeaderboardController.swift`

**Step 1: Add selectedTimeRange and timeRangeMenuViewModel properties**

After the existing properties (around line 33), add:
```swift
private(set) var selectedTimeRange: AppTimeRange
let timeRangeMenuViewModel: SQDropDownMenuViewModel
private weak var modelContext: ModelContext?
```

**Step 2: Update init to accept initialTimeRange**

Find the `init` signature:
```swift
init(
    state: LeaderboardStating,
    quantityType: SQQuantityType,
    activityType: HKWorkoutActivityType,
    workoutManager: SQWorkoutManaging = SQWorkoutManager()
) {
```

Replace with:
```swift
init(
    state: LeaderboardStating,
    quantityType: SQQuantityType,
    activityType: HKWorkoutActivityType,
    initialTimeRange: AppTimeRange = .allTime,
    workoutManager: SQWorkoutManaging = SQWorkoutManager()
) {
    self.selectedTimeRange = initialTimeRange
```

**Step 3: Add timeRangeMenuViewModel initialization in init**

After the existing init code (before `handleEventSubscriptions`), add:

```swift
// Create time range dropdown (sorted by sortOrder)
let items = AppTimeRange.allCases
    .sorted(by: { $0.sortOrder < $1.sortOrder })
    .map { SQDropDownMenuViewModel.Item(title: $0.rawValue) }

self.timeRangeMenuViewModel = SQDropDownMenuViewModel(
    defaultItem: .init(title: initialTimeRange.rawValue),
    items: items
) { [weak self] selectedTitle in
    guard let self else { return }
    if let selectedRange = AppTimeRange.allCases.first(where: { $0.rawValue == selectedTitle }) {
        self.selectedTimeRange = selectedRange
        Task { @MainActor in
            await self.reloadUI()
        }
    }
}
```

**Step 4: Store ModelContext in loadUI**

At the beginning of the `loadUI` method (around line 83), add:
```swift
// Store context for reloads
if self.modelContext == nil {
    self.modelContext = context
}
```

**Step 5: Update workout fetching to use selectedTimeRange**

Find (around line 131):
```swift
let allWorkouts = try await workoutManager.getWorkouts(
    for: .allTime,
    modelContext: context
)
```

Replace with:
```swift
let allWorkouts = try await workoutManager.getWorkouts(
    for: selectedTimeRange.sqTimeRange,
    modelContext: context
)
```

**Step 6: Update chart subtitle to include time range**

Find the chart subtitle setting (around line 192):
```swift
let dateRange = "\(earliestDate.formattedString(with: .medium)) - \(latestDate.formattedString(with: .medium))"
chartSubtitle = "\(rows.count) workouts • \(dateRange)"
```

Replace with:
```swift
let dateRange = "\(earliestDate.formattedString(with: .medium)) - \(latestDate.formattedString(with: .medium))"
chartSubtitle = "\(rows.count) workouts • \(dateRange) • \(selectedTimeRange.rawValue)"
```

And the else case:
```swift
chartSubtitle = "\(rows.count) workouts"
```

Replace with:
```swift
chartSubtitle = "\(rows.count) workouts • \(selectedTimeRange.rawValue)"
```

**Step 7: Add reloadUI method**

At the end of the class (before the closing brace), add:

```swift
// MARK: - Reload

private func reloadUI() async {
    guard let context = modelContext else {
        SQLogger.shared.log(
            "Cannot reload leaderboard: ModelContext not available",
            .error,
            context: .workoutList
        )
        return
    }

    hasLoadedUI = false  // Allow re-loading
    await loadUI(for: context)
}
```

**Step 8: Update default controller**

Find:
```swift
@MainActor
static let `default` = SQLeaderboardController(
    state: SQAppState.shared.leaderboardState,
    quantityType: .distanceWalkingRunning,
    activityType: .running
)
```

Replace with:
```swift
@MainActor
static let `default` = SQLeaderboardController(
    state: SQAppState.shared.leaderboardState,
    quantityType: .distanceWalkingRunning,
    activityType: .running,
    initialTimeRange: .allTime
)
```

**Step 9: Build to verify no errors**

Run: Build the project (Cmd+B)
Expected: Build succeeds

**Step 10: Commit**

```bash
git add BeastFitness/ViewModels/Leaderboard/SQLeaderboardController.swift
git commit -m "Add time range management to SQLeaderboardController

- Accept initialTimeRange parameter in init
- Add selectedTimeRange property and timeRangeMenuViewModel
- Store ModelContext weakly for reloads
- Update loadUI to use selectedTimeRange.sqTimeRange
- Add reloadUI() method for time range changes
- Update chart subtitle to include time range"
```

---

## Task 6: Update SQLeaderboardView to Add Dropdown

**Files:**
- Modify: `BeastFitness/Views/Leaderboard/SQLeaderboardView.swift`

**Step 1: Add toolbar with time range dropdown**

In the `navView` computed property, find:
```swift
var navView: some View {
    mainView
        .redacted(controller.isLoading, reason: .placeholder)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(controller.title)
        .navigationBarTitleDisplayMode(.inline)
        .background(SQColor.background.color)
        .task {
            await controller.loadUI(for: modelContext)
        }
}
```

Replace with:
```swift
var navView: some View {
    mainView
        .redacted(controller.isLoading, reason: .placeholder)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(controller.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                SQDropDownMenu(
                    menuViewModel: controller.timeRangeMenuViewModel,
                    isDisabled: controller.isLoading
                )
            }
        }
        .background(SQColor.background.color)
        .task {
            await controller.loadUI(for: modelContext)
        }
}
```

**Step 2: Build to verify no errors**

Run: Build the project (Cmd+B)
Expected: Build succeeds

**Step 3: Commit**

```bash
git add BeastFitness/Views/Leaderboard/SQLeaderboardView.swift
git commit -m "Add time range dropdown to leaderboard toolbar

- Add SQDropDownMenu to trailing toolbar position
- Disable dropdown during loading state
- Matches dashboard UI pattern"
```

---

## Task 7: Manual Testing

**Files:**
- None (testing only)

**Step 1: Test dashboard time range changes**

1. Run the app
2. Navigate to Dashboard
3. Change time range dropdown between: Today, Past 7 Days, Past Year
4. Verify data updates for each selection

Expected: Dashboard shows correct data for each time range

**Step 2: Test leaderboard initial time range (Today → All Time)**

1. Set dashboard to "Today"
2. Tap a performance metric row to open leaderboard
3. Verify leaderboard dropdown shows "All Time" (not "Today")

Expected: Leaderboard opens with "All Time" selected

**Step 3: Test leaderboard initial time range (other ranges)**

1. Set dashboard to "Past 7 Days"
2. Tap a performance metric row to open leaderboard
3. Verify leaderboard dropdown shows "Past 7 Days"
4. Repeat for "Past Year"

Expected: Leaderboard inherits dashboard's time range (except Today)

**Step 4: Test leaderboard time range changes**

1. Open leaderboard
2. Change time range dropdown between different options
3. Verify:
   - Loading indicator appears
   - Dropdown is disabled during loading
   - Chart and rows update with new data
   - Chart subtitle includes time range

Expected: Leaderboard reloads with new time range data

**Step 5: Test empty states**

1. Change to a time range with no workouts (if possible)
2. Verify "No data available" message appears
3. Verify chart doesn't render (less than 2 data points)

Expected: Empty state shows gracefully

**Step 6: Test new time ranges in dashboard**

1. Set dashboard to "Past 30 Days"
2. Verify data loads (may be same as Past 7 Days due to placeholder)
3. Set dashboard to "All Time"
4. Verify data loads

Expected: No crashes, data displays (even if placeholders)

**Step 7: Document any issues**

Create a list of any bugs, unexpected behavior, or missing functionality

**Step 8: Final commit**

If any bug fixes were made during testing:
```bash
git add -A
git commit -m "Fix issues found during manual testing

[List any fixes made]"
```

---

## Success Criteria

✅ AppTimeRange enum created with 5 time ranges
✅ SQTimeRange updated with past30Days and thirtyDaysBeforeLast
✅ Dashboard uses AppTimeRange instead of DashboardTimeRange
✅ Dashboard dropdown sorted by sortOrder
✅ Leaderboard accepts initialTimeRange parameter
✅ Leaderboard has time range dropdown in toolbar
✅ Leaderboard reloads when time range changes
✅ Dashboard → Leaderboard navigation passes correct time range
✅ Today → All Time exception works
✅ Empty states display correctly
✅ Chart subtitle includes time range
✅ No build errors or warnings

---

## Known Limitations

1. **Past 30 Days and All Time data fetching**: Dashboard currently uses placeholder data for these ranges. Full implementation requires:
   - Fetching `past30DaysWorkouts` and `thirtyDaysBeforeLastWorkouts`
   - Fetching `past30DaysCheckIns`
   - Fetching appropriate VO2 Max samples
   - This is out of scope for this plan but should be addressed in a follow-up task

2. **No persistence**: Time range selection is not persisted across app launches

3. **No unit tests**: This plan focuses on implementation. Unit tests for AppTimeRange logic should be added separately

---

## Follow-Up Tasks

1. Add proper data fetching for Past 30 Days time range in dashboard
2. Add proper data fetching for All Time time range in dashboard
3. Add unit tests for AppTimeRange mapping logic
4. Add unit tests for time range fallback logic
5. Consider adding time range persistence to UserDefaults
