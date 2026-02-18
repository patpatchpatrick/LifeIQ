# Leaderboard Time Range Selector Design

**Date:** 2026-02-17
**Status:** Approved

## Overview

Add a time range dropdown to the leaderboard view that allows users to filter workouts by time period. The time range selection should:
- Mirror the dashboard's time range selector UI pattern
- Default to the dashboard's current time range when navigating (with exception: Today → All Time)
- Support unified time ranges across both dashboard and leaderboard
- Trigger data reload when the time range changes

## Goals

1. Add time range filtering to leaderboard (currently shows all-time data only)
2. Create shared `AppTimeRange` enum for both dashboard and leaderboard
3. Sync initial time range from dashboard to leaderboard on navigation
4. Add "Past 30 Days" and "All Time" options to dashboard and leaderboard
5. Provide fallback logic if a time range is unavailable

## Non-Goals

- Time range persistence across leaderboard dismissals (may add later)
- Per-metric time range preferences
- Automatic time range suggestions based on data availability

---

## Data Model Changes

### AppTimeRange Enum

Create a new shared enum to replace `DashboardTimeRange`:

**Location:** `BeastFitness/Models/AppTimeRange.swift` (new file)

```swift
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

### SQTimeRange Updates

Add new cases to support 30-day windows:

**Location:** `BeastFitness/Models/SQTimeRange.swift`

**Changes:**
1. Rename `.pastMonth` → `.past30Days`
2. Add `.thirtyDaysBeforeLast` for comparison period
3. Update date calculations:

```swift
enum SQTimeRange: String {
    case today = "Today"
    case yesterday = "Yesterday"
    case pastWeek = "Past 7 Days"
    case weekBeforeLast = "Week Before Last"
    case past30Days = "Past 30 Days"  // RENAMED from pastMonth
    case thirtyDaysBeforeLast = "30 Days Before Last"  // NEW
    case pastYear = "Past Year"
    case yearBeforeLast = "Year Before Last"
    case allTime = "All Time"

    var startDate: Date {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())

        switch self {
        // ... existing cases ...
        case .past30Days:  // UPDATED
            return calendar.date(byAdding: .day, value: -30, to: endDate)!
        case .thirtyDaysBeforeLast:  // NEW
            return calendar.date(byAdding: .day, value: -60, to: endDate)!
        }
    }

    var endDate: Date {
        switch self {
        // ... existing cases ...
        case .past30Days:  // UPDATED
            return .now
        case .thirtyDaysBeforeLast:  // NEW
            return SQTimeRange.past30Days.startDate
        }
    }
}
```

---

## Architecture Changes

### SQLeaderboardController

**Changes:**
1. Add `selectedTimeRange` property
2. Add `timeRangeMenuViewModel` for dropdown
3. Accept `initialTimeRange` in init (defaults to `.allTime`)
4. Store `ModelContext` weakly for reloads
5. Update `loadUI` to use `selectedTimeRange` instead of hardcoded `.allTime`
6. Add `reloadUI()` method for time range changes

**Key methods:**

```swift
@Observable @MainActor
final class SQLeaderboardController: SQLeaderboardInterface {
    // NEW: Time range state
    private(set) var selectedTimeRange: AppTimeRange
    let timeRangeMenuViewModel: SQDropDownMenuViewModel
    private weak var modelContext: ModelContext?

    // UPDATED: Accept initial time range
    init(
        state: LeaderboardStating,
        quantityType: SQQuantityType,
        activityType: HKWorkoutActivityType,
        initialTimeRange: AppTimeRange = .allTime,
        workoutManager: SQWorkoutManaging = SQWorkoutManager()
    ) {
        self.selectedTimeRange = initialTimeRange
        // ... existing setup ...

        // NEW: Create time range dropdown (sorted by sortOrder)
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
                Task { await self.reloadUI() }
            }
        }
    }

    func loadUI(for context: ModelContext) async {
        // NEW: Store context for reloads
        if self.modelContext == nil {
            self.modelContext = context
        }

        guard !hasLoadedUI else { return }
        hasLoadedUI = true
        isLoading = true

        // UPDATED: Use selectedTimeRange instead of .allTime
        let allWorkouts = try await workoutManager.getWorkouts(
            for: selectedTimeRange.sqTimeRange,
            modelContext: context
        )

        // ... rest of existing logic ...

        // UPDATED: Add time range to chart subtitle
        if let earliestDate = allDates.min(),
           let latestDate = allDates.max() {
            let dateRange = "\(earliestDate.formattedString(with: .medium)) - \(latestDate.formattedString(with: .medium))"
            chartSubtitle = "\(rows.count) workouts • \(dateRange) • \(selectedTimeRange.rawValue)"
        } else {
            chartSubtitle = "\(rows.count) workouts • \(selectedTimeRange.rawValue)"
        }
    }

    // NEW: Reload with current time range
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
}
```

### DashboardState

**Changes:**
1. Replace `DashboardTimeRange` with `AppTimeRange`
2. Update `displayLeaderboardSheet` to pass initial time range

```swift
@Observable final class DashboardState: DashboardStating {
    var selectedTimeRange: AppTimeRange = .today  // UPDATED type

    func displayLeaderboardSheet(
        quantityType: SQQuantityType,
        activityType: HKWorkoutActivityType
    ) {
        // NEW: Determine initial time range
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
            initialTimeRange: initialTimeRange  // NEW
        )
        toggleLeaderboardSheetVisibility(true)
    }
}
```

### DashboardController

**Changes:**
1. Update time range menu creation to use `AppTimeRange` (sorted by `sortOrder`)
2. Replace `DashboardTimeRange` references with `AppTimeRange`

```swift
@Observable final class SQDashboardController {
    init(state: DashboardStating, ...) {
        // UPDATED: Use AppTimeRange with sortOrder
        let items = AppTimeRange.allCases
            .sorted(by: { $0.sortOrder < $1.sortOrder })
            .map { SQDropDownMenuViewModel.Item(title: $0.rawValue) }

        self.timeRangeMenuViewModel = SQDropDownMenuViewModel(
            defaultItem: .init(title: state.selectedTimeRange.rawValue),
            items: items
        ) { [weak state] selectedTitle in
            guard let state else { return }
            if let selectedRange = AppTimeRange.allCases.first(where: { $0.rawValue == selectedTitle }) {
                state.selectedTimeRange = selectedRange
            }
        }
    }

    // UPDATED: Use AppTimeRange.sqTimeRange instead of .toSQTimeRange()
    func loadUI(for context: ModelContext, shouldForceRefresh: Bool = false) async {
        let timeRange = state.selectedTimeRange.sqTimeRange
        // ... rest of logic ...
    }
}
```

---

## UI Changes

### SQLeaderboardView

**Add time range dropdown to navigation toolbar:**

```swift
struct SQLeaderboardView: View {
    @Bindable var controller: SQLeaderboardController
    @Environment(\.modelContext) private var modelContext

    var navView: some View {
        mainView
            .redacted(controller.isLoading, reason: .placeholder)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(controller.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // NEW: Add time range dropdown to toolbar
                ToolbarItem(placement: .topBarTrailing) {
                    SQDropDownMenu(
                        menuViewModel: controller.timeRangeMenuViewModel,
                        isDisabled: controller.isLoading  // Disable during loading
                    )
                }
            }
            .background(SQColor.background.color)
            .task {
                await controller.loadUI(for: modelContext)
            }
    }
}
```

**Empty state:** No changes needed - existing `emptyStateView` handles empty data for any time range.

---

## Data Flow

### Time Range Change Flow

```
User taps dropdown → Selects "Past 7 Days"
  ↓
SQDropDownMenuViewModel.itemSelectionHandler triggered
  ↓
Controller updates selectedTimeRange property
  ↓
Controller calls reloadUI() in Task
  ↓
reloadUI() resets hasLoadedUI and calls loadUI()
  ↓
loadUI() fetches workouts for selectedTimeRange.sqTimeRange
  ↓
UI updates with new data (rows, chart, subtitle)
```

### Navigation Flow (Dashboard → Leaderboard)

```
User taps performance metric row
  ↓
DashboardState.displayLeaderboardSheet() called
  ↓
Determine initialTimeRange:
  - If dashboard shows "Today" → use "All Time"
  - Otherwise → use dashboard's selectedTimeRange
  - Fallback → use last (largest) time range
  ↓
Create SQLeaderboardController with initialTimeRange
  ↓
Present leaderboard sheet
  ↓
Leaderboard loads workouts for initialTimeRange
```

---

## Edge Cases & Error Handling

### Edge Case 1: Time Range Fallback

**Scenario:** Dashboard has a time range not in `AppTimeRange.allCases` (future-proofing).

**Solution:** Default to the last (largest) time range using `sortOrder`:

```swift
let fallbackTimeRange = AppTimeRange.allCases
    .sorted(by: { $0.sortOrder < $1.sortOrder })
    .last ?? .allTime
```

### Edge Case 2: Empty State

**Already handled:** Existing empty state logic works for any time range:
- Chart: Returns `nil` if fewer than 2 data points
- Rows: Shows "No data available" when `rows.isEmpty && !isLoading`

### Edge Case 3: Rapid Time Range Changes

**Prevention:** Dropdown is disabled when `isLoading` to prevent rapid changes.

### Edge Case 4: ModelContext Unavailable

**Solution:** Log error and gracefully fail (UI stays in current state):

```swift
guard let context = modelContext else {
    SQLogger.shared.log(
        "Cannot reload leaderboard: ModelContext not available",
        .error,
        context: .workoutList
    )
    return
}
```

### Edge Case 5: Chart Subtitle With No Workouts

**Already handled:**
```swift
if allDates.isEmpty {
    chartSubtitle = "0 workouts • \(selectedTimeRange.rawValue)"
}
```

---

## Migration Path

### Code Changes Required

1. **Create new file:** `BeastFitness/Models/AppTimeRange.swift`
2. **Update `SQTimeRange.swift`:** Rename `.pastMonth` → `.past30Days`, add `.thirtyDaysBeforeLast`
3. **Update `DashboardState.swift`:** Replace `DashboardTimeRange` with `AppTimeRange`
4. **Update `DashboardController.swift`:** Use `AppTimeRange`, sort by `sortOrder`, use `.sqTimeRange` and `.previousSqTimeRange`
5. **Update `SQLeaderboardController.swift`:** Add time range management
6. **Update `SQLeaderboardView.swift`:** Add toolbar dropdown
7. **Delete:** `DashboardTimeRange` enum from `DashboardState.swift`

### Breaking Changes

**None** - This is purely additive. Existing leaderboard behavior (all-time data) becomes the default fallback.

---

## Testing Considerations

### Manual Testing Checklist

1. **Dashboard time range changes** - Verify dropdown updates data
2. **Leaderboard initial time range** - Verify inherits from dashboard (except Today → All Time)
3. **Leaderboard time range changes** - Verify dropdown triggers reload
4. **Empty states** - Verify each time range shows "No data available" when appropriate
5. **Chart updates** - Verify chart subtitle includes time range
6. **Loading states** - Verify dropdown is disabled during loading
7. **Edge case: Today → All Time** - Verify exception works when navigating from dashboard

### Unit Testing Opportunities

1. `AppTimeRange.sqTimeRange` mapping correctness
2. `AppTimeRange.previousSqTimeRange` comparison period logic
3. `AppTimeRange.sortOrder` uniqueness and order
4. Initial time range fallback logic in `DashboardState`

---

## Future Enhancements

- **Time range persistence:** Remember user's last selected time range per metric
- **Smart defaults:** Suggest optimal time ranges based on workout frequency
- **Comparison view:** Show current vs previous period side-by-side
- **Custom date ranges:** Allow user to pick arbitrary start/end dates
