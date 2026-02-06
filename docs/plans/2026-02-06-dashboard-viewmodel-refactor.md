# Dashboard ViewModel Architecture Refactor

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refactor dashboard to use proper view model architecture where business logic lives in view models, not views.

**Architecture:** Create hierarchical view model structure with SQDashboardSectionGroupViewModel (Daily Stats, Workouts) containing multiple SQDashboardSectionViewModel instances (Metrics, Performance, Totals, Activities). Each section manages its own state (collapse, filtering) and rows. Remove state management from DashboardState and move to view models.

**Tech Stack:** SwiftUI, @Observable pattern, existing view models, DashboardController

---

## Task 1: Create SQDashboardSectionGroupViewModel

**Files:**
- Create: `BeastFitness/ViewModels/Dashboard/SQDashboardSectionGroupViewModel.swift`

**Implementation:**

Create the section group view model that represents a collapsible group of sections (e.g., "Daily Stats" or "Workouts"):

```swift
//
//  SQDashboardSectionGroupViewModel.swift
//  BeastFitness
//

import Foundation

@MainActor
@Observable final class SQDashboardSectionGroupViewModel: Identifiable {
    let id: String
    let title: String
    var isExpanded: Bool
    var sections: [SQDashboardSectionViewModel]

    init(
        id: String,
        title: String,
        isExpanded: Bool = true,
        sections: [SQDashboardSectionViewModel]
    ) {
        self.id = id
        self.title = title
        self.isExpanded = isExpanded
        self.sections = sections
    }

    func toggleExpanded() {
        isExpanded.toggle()
    }
}
```

**Add to Xcode project:** Add the file to the BeastFitness target.

**Commit:**
```bash
git add BeastFitness/ViewModels/Dashboard/SQDashboardSectionGroupViewModel.swift
git commit -m "Add SQDashboardSectionGroupViewModel

Creates hierarchical section group for dashboard sections.
- Represents collapsible groups like 'Daily Stats' and 'Workouts'
- Contains array of SQDashboardSectionViewModel
- Manages expanded/collapsed state"
```

---

## Task 2: Add Filter Support to SQDashboardSectionViewModel

**Files:**
- Modify: `BeastFitness/ViewModels/Dashboard/SQDashboardSectionViewModel.swift`

**Find the existing SQDashboardSectionViewModel and add:**

1. Import statement for dropdown if needed
2. New properties for filtering:

```swift
// Add these properties to SQDashboardSectionViewModel
var dropdownViewModel: SQDropDownMenuViewModel?
var rowsByFilter: [String: [SQDashboardRowViewModel]]?
var currentFilter: String = "All"

// Add method to update rows when filter changes
func updateFilter(to filter: String) {
    guard let rowsByFilter = rowsByFilter else { return }

    currentFilter = filter

    if let filteredRows = rowsByFilter[filter] {
        rows = filteredRows
    } else if filter == "All", let allRows = rowsByFilter.values.flatMap({ $0 }).uniqued() {
        rows = Array(allRows)
    }
}

// Helper to get unique rows
private extension Array where Element == SQDashboardRowViewModel {
    func uniqued() -> [SQDashboardRowViewModel] {
        var seen = Set<String>()
        return filter { row in
            guard !seen.contains(row.id) else { return false }
            seen.insert(row.id)
            return true
        }
    }
}
```

**Note:** Read the existing file first to understand its structure. Add properties after existing properties, add method at the end.

**Commit:**
```bash
git add BeastFitness/ViewModels/Dashboard/SQDashboardSectionViewModel.swift
git commit -m "Add filter support to SQDashboardSectionViewModel

- Add dropdownViewModel property for filterable sections
- Add rowsByFilter dictionary to store rows per filter option
- Add currentFilter to track selected filter
- Add updateFilter method to change visible rows based on filter"
```

---

## Task 3: Create SQDashboardRowType for Stats

**Files:**
- Modify: `BeastFitness/ViewModels/Dashboard/SQDashboardRowType.swift` (or wherever row types are defined)

**Find SQDashboardRowType enum and add new case:**

```swift
// Add to SQDashboardRowType enum
case metricStats
```

**Find SQDashboardRowIdentifier enum and add:**

```swift
// Add to SQDashboardRowIdentifier enum
case metrics
case performance
```

**Note:** If these enums don't exist, search for where row types are defined. They might be in a different file or pattern.

**Commit:**
```bash
git add [file with row types]
git commit -m "Add metricStats row type and identifiers

- Add metricStats to SQDashboardRowType for metric/performance rows
- Add metrics and performance identifiers"
```

---

## Task 4: Create SQDashboardMetricStatsRow ViewModel

**Files:**
- Create: `BeastFitness/ViewModels/Dashboard/Rows/SQDashboardMetricStatsRow.swift`

**Create directory if needed:**
```bash
mkdir -p BeastFitness/ViewModels/Dashboard/Rows
```

**Create the view model:**

```swift
//
//  SQDashboardMetricStatsRow.swift
//  BeastFitness
//

import Foundation

@MainActor
final class SQDashboardMetricStatsRow: SQDashboardRowViewModel {
    let statsData: [SQStatRowData]

    init(
        id: String,
        statsData: [SQStatRowData]
    ) {
        self.statsData = statsData
        super.init(
            id: id,
            type: .metricStats,
            identifier: .metrics
        )
    }
}
```

**Note:** Check the SQDashboardRowViewModel base class to see what init parameters are needed. Adjust accordingly.

**Add to Xcode project**

**Commit:**
```bash
git add BeastFitness/ViewModels/Dashboard/Rows/SQDashboardMetricStatsRow.swift
git commit -m "Add SQDashboardMetricStatsRow view model

Row view model for displaying metric/performance stats.
- Extends SQDashboardRowViewModel
- Holds array of SQStatRowData
- Uses metricStats row type"
```

---

## Task 5: Update DashboardState - Remove Filter and Collapse State

**Files:**
- Modify: `BeastFitness/StateManagement/DashboardState.swift`

**Remove these properties from both DashboardStating protocol and DashboardState class:**

```swift
// REMOVE these from protocol:
var isDailyStatsCollapsed: Bool { get set }
var isWorkoutsCollapsed: Bool { get set }
var isMetricsCollapsed: Bool { get set }
var isPerformanceCollapsed: Bool { get set }
var isTotalsCollapsed: Bool { get set }
var isActivitiesCollapsed: Bool { get set }
var metricsGroupFilter: String { get set }
var totalsTypeFilter: TotalsType { get set }
var activitiesTypeFilter: String { get set }

// REMOVE these from class:
var isDailyStatsCollapsed: Bool = false
var isWorkoutsCollapsed: Bool = false
var isMetricsCollapsed: Bool = false
var isPerformanceCollapsed: Bool = false
var isTotalsCollapsed: Bool = false
var isActivitiesCollapsed: Bool = false
var metricsGroupFilter: String = "All"
var totalsTypeFilter: TotalsType = .time
var activitiesTypeFilter: String = "All"
```

**Also remove the TotalsType enum** (will be handled in section view model instead)

**Commit:**
```bash
git add BeastFitness/StateManagement/DashboardState.swift
git commit -m "Remove filter and collapse state from DashboardState

State now managed in view models instead of centralized state.
- Remove section/subsection collapse booleans
- Remove filter state properties
- Remove TotalsType enum"
```

---

## Task 6: Update DashboardController to Build Section Groups

**Files:**
- Modify: `BeastFitness/Controllers/SQDashboardController.swift` (or wherever controller is)

**Find the `loadUI()` function or similar where sectionViewModels are built.**

**Add new method to build section groups:**

```swift
private func buildSectionGroups(for timeRange: DashboardTimeRange) -> [SQDashboardSectionGroupViewModel] {
    var groups: [SQDashboardSectionGroupViewModel] = []

    // Get section for time range
    let sectionIndex = DashboardTimeRange.allCases.firstIndex(of: timeRange) ?? 0
    guard sectionIndex < state.sectionViewModels.count else { return [] }

    let currentSection = state.sectionViewModels[sectionIndex]

    // Build Daily Stats group
    let dailyStatsGroup = buildDailyStatsGroup(from: currentSection)
    groups.append(dailyStatsGroup)

    // Build Workouts group
    let workoutsGroup = buildWorkoutsGroup(from: currentSection)
    groups.append(workoutsGroup)

    return groups
}

private func buildDailyStatsGroup(from section: SQDashboardSectionViewModel) -> SQDashboardSectionGroupViewModel {
    var sections: [SQDashboardSectionViewModel] = []

    // Build Metrics section
    if let metricsSection = buildMetricsSection(from: section) {
        sections.append(metricsSection)
    }

    return SQDashboardSectionGroupViewModel(
        id: "daily-stats",
        title: "Daily Stats",
        isExpanded: true,
        sections: sections
    )
}

private func buildWorkoutsGroup(from section: SQDashboardSectionViewModel) -> SQDashboardSectionGroupViewModel {
    var sections: [SQDashboardSectionViewModel] = []

    // Build Performance section
    if let performanceSection = buildPerformanceSection(from: section) {
        sections.append(performanceSection)
    }

    // Build Totals section
    if let totalsSection = buildTotalsSection(from: section) {
        sections.append(totalsSection)
    }

    // Build Activities section
    if let activitiesSection = buildActivitiesSection(from: section) {
        sections.append(activitiesSection)
    }

    return SQDashboardSectionGroupViewModel(
        id: "workouts",
        title: "Workouts",
        isExpanded: true,
        sections: sections
    )
}
```

**Commit:**
```bash
git add BeastFitness/Controllers/SQDashboardController.swift
git commit -m "Add section group building methods to controller

- Add buildSectionGroups to create hierarchical structure
- Add buildDailyStatsGroup for Daily Stats sections
- Add buildWorkoutsGroup for Workouts sections
- Placeholder methods for individual section builders"
```

---

## Task 7: Implement buildMetricsSection

**Files:**
- Modify: `BeastFitness/Controllers/SQDashboardController.swift`

**Add method to build metrics section with filtering:**

```swift
private func buildMetricsSection(from section: SQDashboardSectionViewModel) -> SQDashboardSectionViewModel? {
    // Find check-in row
    guard let checkInRow = section.rows.compactMap({ $0 as? SQDashboardDailyCheckInRowViewModel }).first else {
        return nil
    }

    // Extract all metric groups
    var rowsByFilter: [String: [SQDashboardRowViewModel]] = [:]
    var allMetrics: [SQStatRowData] = []

    for group in checkInRow.groups {
        var groupMetrics: [SQStatRowData] = []

        for vitalRow in group.rows {
            let metricData = SQStatRowData(
                id: vitalRow.id,
                icon: vitalRow.emoji,
                title: vitalRow.title,
                avgValue: vitalRow.value,
                unit: vitalRow.subtitle ?? "",
                sparklineData: vitalRow.sparklineData,
                change14d: 0.0
            )
            groupMetrics.append(metricData)
            allMetrics.append(metricData)
        }

        // Create row for this group
        let groupRow = SQDashboardMetricStatsRow(
            id: "metrics-\(group.name)",
            statsData: groupMetrics
        )
        rowsByFilter[group.name] = [groupRow]
    }

    // Create "All" filter with all metrics
    let allRow = SQDashboardMetricStatsRow(
        id: "metrics-all",
        statsData: allMetrics
    )
    rowsByFilter["All"] = [allRow]

    // Build dropdown options
    let filterOptions = ["All"] + checkInRow.groups.map { $0.name }.sorted()
    let dropdownViewModel = SQDropDownMenuViewModel(
        options: filterOptions,
        selectedOption: "All"
    ) { [weak self] newFilter in
        // Update filter when selection changes
        self?.updateMetricsFilter(to: newFilter)
    }

    // Create section
    let metricsSection = SQDashboardSectionViewModel(
        id: "metrics",
        title: "Metrics",
        identifier: .metrics,
        isExpanded: true,
        rows: rowsByFilter["All"] ?? []
    )
    metricsSection.dropdownViewModel = dropdownViewModel
    metricsSection.rowsByFilter = rowsByFilter

    return metricsSection
}

private func updateMetricsFilter(to filter: String) {
    // Find metrics section and update its filter
    // This will be called when dropdown changes
    // Implementation depends on how you store section groups in state
}
```

**Note:** Adjust based on actual SQDashboardSectionViewModel initializer and SQDropDownMenuViewModel API.

**Commit:**
```bash
git add BeastFitness/Controllers/SQDashboardController.swift
git commit -m "Implement buildMetricsSection with filtering

- Extract metrics from check-in row
- Build rowsByFilter dictionary with metrics per group
- Create dropdown view model with filter options
- Handle filter changes to update visible rows"
```

---

## Task 8: Implement buildPerformanceSection

**Files:**
- Modify: `BeastFitness/Controllers/SQDashboardController.swift`

**Add method:**

```swift
private func buildPerformanceSection(from section: SQDashboardSectionViewModel) -> SQDashboardSectionViewModel? {
    // Find performance row
    guard let performanceRow = section.rows.compactMap({ $0 as? SQDashboardDailyPerformanceRowViewModel }).first,
          let vitalRow = performanceRow.vitalRow else {
        return nil
    }

    // Parse VO2 Max value
    let components = vitalRow.value.components(separatedBy: " • ")
    let valueComponents = components.first?.components(separatedBy: " ") ?? []
    let avgValue = valueComponents.first ?? "N/A"
    let unit = valueComponents.dropFirst().joined(separator: " ")

    // Create stat data
    let metricData = SQStatRowData(
        id: "vo2max",
        icon: "❤️",
        title: "VO2 Max",
        avgValue: avgValue,
        unit: unit,
        sparklineData: vitalRow.sparklineData,
        change14d: 0.0
    )

    // Create row
    let statsRow = SQDashboardMetricStatsRow(
        id: "performance-stats",
        statsData: [metricData]
    )

    // Create section (no filtering needed)
    let performanceSection = SQDashboardSectionViewModel(
        id: "performance",
        title: "Performance",
        identifier: .performance,
        isExpanded: true,
        rows: [statsRow]
    )

    return performanceSection
}
```

**Commit:**
```bash
git add BeastFitness/Controllers/SQDashboardController.swift
git commit -m "Implement buildPerformanceSection

- Extract VO2 Max from performance row
- Create SQStatRowData for performance metrics
- No filtering needed for performance section"
```

---

## Task 9: Implement buildTotalsSection and buildActivitiesSection

**Files:**
- Modify: `BeastFitness/Controllers/SQDashboardController.swift`

**Add methods:**

```swift
private func buildTotalsSection(from section: SQDashboardSectionViewModel) -> SQDashboardSectionViewModel? {
    // Find workout summary row
    guard let workoutRow = section.rows.compactMap({ $0 as? SQDashboardWorkoutSummaryRowViewModel }).first,
          let totalsSection = workoutRow.totalsSection else {
        return nil
    }

    // Create section with the existing totals section view model as a row
    // Note: May need to wrap this differently based on your row structure
    let totalsRow = workoutRow // Or create wrapper row

    let section = SQDashboardSectionViewModel(
        id: "totals",
        title: "Totals",
        identifier: .totals,
        isExpanded: true,
        rows: [totalsRow]
    )

    // Add dropdown for Time/Kilocalories filter
    let dropdownViewModel = SQDropDownMenuViewModel(
        options: ["Time", "Kilocalories"],
        selectedOption: "Time"
    ) { [weak totalsSection] newFilter in
        // Update totals section metric
        // totalsSection.updateMetric(...)
    }
    section.dropdownViewModel = dropdownViewModel

    return section
}

private func buildActivitiesSection(from section: SQDashboardSectionViewModel) -> SQDashboardSectionViewModel? {
    // Find workout summary row
    guard let workoutRow = section.rows.compactMap({ $0 as? SQDashboardWorkoutSummaryRowViewModel }).first,
          let workoutsSection = workoutRow.workoutsSection else {
        return nil
    }

    // Build rowsByFilter for different workout types
    var rowsByFilter: [String: [SQDashboardRowViewModel]] = [:]

    // All activities
    rowsByFilter["All"] = workoutsSection.workoutGroupViewModels.map { $0 as SQDashboardRowViewModel }

    // By workout type
    let workoutTypes = workoutRow.workouts.workoutsByActivityType.keys.map { $0.name }
    for workoutType in workoutTypes {
        let filtered = workoutsSection.workoutGroupViewModels.filter { group in
            group.title.contains(workoutType)
        }
        rowsByFilter[workoutType] = filtered.map { $0 as SQDashboardRowViewModel }
    }

    // Build dropdown
    let filterOptions = ["All"] + workoutTypes.sorted()
    let dropdownViewModel = SQDropDownMenuViewModel(
        options: filterOptions,
        selectedOption: "All"
    ) { [weak self] newFilter in
        self?.updateActivitiesFilter(to: newFilter)
    }

    let activitiesSection = SQDashboardSectionViewModel(
        id: "activities",
        title: "Activities",
        identifier: .activities,
        isExpanded: true,
        rows: rowsByFilter["All"] ?? []
    )
    activitiesSection.dropdownViewModel = dropdownViewModel
    activitiesSection.rowsByFilter = rowsByFilter

    return activitiesSection
}

private func updateActivitiesFilter(to filter: String) {
    // Update activities filter
}
```

**Note:** The row wrapping might need adjustment based on actual row types.

**Commit:**
```bash
git add BeastFitness/Controllers/SQDashboardController.swift
git commit -m "Implement buildTotalsSection and buildActivitiesSection

- Build totals section with Time/Kilocalories filter
- Build activities section with workout type filtering
- Create rowsByFilter for activities by type"
```

---

## Task 10: Add sectionGroups to DashboardState

**Files:**
- Modify: `BeastFitness/StateManagement/DashboardState.swift`

**Add new property:**

```swift
// Add to DashboardStating protocol:
var sectionGroups: [SQDashboardSectionGroupViewModel] { get }

// Add to DashboardState class:
private(set) var sectionGroups: [SQDashboardSectionGroupViewModel] = []

// Add method to update section groups:
func updateSectionGroups(to groups: [SQDashboardSectionGroupViewModel]) {
    self.sectionGroups = groups
}
```

**Commit:**
```bash
git add BeastFitness/StateManagement/DashboardState.swift
git commit -m "Add sectionGroups to DashboardState

- Add sectionGroups array property
- Add updateSectionGroups method
- Section groups will replace flat sectionViewModels in UI"
```

---

## Task 11: Call buildSectionGroups in DashboardController

**Files:**
- Modify: `BeastFitness/Controllers/SQDashboardController.swift`

**Find where `loadUI()` is called or where sections are built, and add:**

```swift
// In loadUI() or similar method, after sectionViewModels are loaded:
let groups = buildSectionGroups(for: state.selectedTimeRange)
state.updateSectionGroups(to: groups)
```

**Also add observation for time range changes:**

```swift
// Observe time range changes and rebuild groups
// This might be in init or setupObservers method
state.selectedTimeRangePublisher
    .sink { [weak self] newTimeRange in
        guard let self = self else { return }
        let groups = self.buildSectionGroups(for: newTimeRange)
        self.state.updateSectionGroups(to: groups)
    }
    .store(in: &cancellables)
```

**Commit:**
```bash
git add BeastFitness/Controllers/SQDashboardController.swift
git commit -m "Build section groups in controller

- Call buildSectionGroups after sections load
- Update state with built section groups
- Observe time range changes and rebuild groups"
```

---

## Task 12: Create SQDashboardSectionGroupView

**Files:**
- Create: `BeastFitness/Views/Dashboard/SQDashboardSectionGroupView.swift`

**Create the view:**

```swift
//
//  SQDashboardSectionGroupView.swift
//  BeastFitness
//

import SwiftUI

struct SQDashboardSectionGroupView: View {
    @Bindable var sectionGroup: SQDashboardSectionGroupViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Group header
            SQDashboardSectionHeader(
                title: sectionGroup.title,
                isCollapsed: Binding(
                    get: { !sectionGroup.isExpanded },
                    set: { sectionGroup.isExpanded = !$0 }
                )
            )

            // Sections within the group
            if sectionGroup.isExpanded {
                VStack(spacing: 16) {
                    ForEach(sectionGroup.sections) { section in
                        SQDashboardSectionView(section: section)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
        }
    }
}
```

**Add to Xcode project**

**Commit:**
```bash
git add BeastFitness/Views/Dashboard/SQDashboardSectionGroupView.swift
git commit -m "Add SQDashboardSectionGroupView

Renders a collapsible section group with child sections.
- Uses SQDashboardSectionHeader for group header
- Renders child sections when expanded
- Binds to view model's isExpanded state"
```

---

## Task 13: Create SQDashboardSectionView

**Files:**
- Create: `BeastFitness/Views/Dashboard/SQDashboardSectionView.swift`

**Create the view:**

```swift
//
//  SQDashboardSectionView.swift
//  BeastFitness
//

import SwiftUI

struct SQDashboardSectionView: View {
    @Bindable var section: SQDashboardSectionViewModel

    var body: some View {
        SQDashboardSubsection(
            title: section.title,
            isCollapsed: Binding(
                get: { !section.isExpanded },
                set: { section.isExpanded = !$0 }
            ),
            dropdownMenu: section.dropdownViewModel.map { dropdown in
                SQDropDownMenu(viewModel: dropdown)
            }
        ) {
            // Render rows based on type
            ForEach(section.rows) { row in
                rowView(for: row)
            }
        }
    }

    @ViewBuilder
    private func rowView(for row: SQDashboardRowViewModel) -> some View {
        switch row.type {
        case .metricStats:
            if let statsRow = row as? SQDashboardMetricStatsRow {
                SQStatRowSection(rows: statsRow.statsData)
            }
        default:
            // Render other row types
            // Use existing row rendering logic
            EmptyView()
        }
    }
}
```

**Note:** Adjust based on actual SQDropDownMenu API and row types.

**Add to Xcode project**

**Commit:**
```bash
git add BeastFitness/Views/Dashboard/SQDashboardSectionView.swift
git commit -m "Add SQDashboardSectionView

Renders individual section with optional dropdown filter.
- Uses SQDashboardSubsection for container
- Renders rows based on row type
- Handles metricStats row type with SQStatRowSection"
```

---

## Task 14: Update SQDashboardView to Use Section Groups

**Files:**
- Modify: `BeastFitness/Views/Dashboard/SQDashboardView.swift`

**Replace the current section rendering with:**

```swift
// Find where sections are currently rendered and replace with:

LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
    ForEach(controller.state.sectionGroups) { sectionGroup in
        Section {
            if sectionGroup.isExpanded {
                VStack(spacing: 16) {
                    ForEach(sectionGroup.sections) { section in
                        SQDashboardSectionView(section: section)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
        } header: {
            SQDashboardSectionHeader(
                title: sectionGroup.title,
                isCollapsed: Binding(
                    get: { !sectionGroup.isExpanded },
                    set: { sectionGroup.isExpanded = !$0 }
                )
            )
        }
    }
}
```

**Remove all the old computed properties:**
- Remove `filteredMetrics`
- Remove `availableMetricGroups`
- Remove `performanceStats`
- Remove `availableWorkoutTypes`
- Remove `filteredActivities`
- Remove `getTotalsViewModel`
- Remove all filter menu creation methods
- Remove all subsection computed vars

**Commit:**
```bash
git add BeastFitness/Views/Dashboard/SQDashboardView.swift
git commit -m "Update SQDashboardView to use section groups

- Replace section rendering with SQDashboardSectionGroupView
- Remove all business logic from view
- Remove computed properties for filtering
- Remove subsection computed vars
- Simplify to just rendering section groups from state"
```

---

## Task 15: Update CLAUDE.md with ViewModel Patterns

**Files:**
- Modify: `CLAUDE.md`

**Add new section after "State Management Architecture":**

```markdown
## Dashboard ViewModel Architecture

For dashboard sections and lists, use a hierarchical view model structure:

### Hierarchy

```
SQDashboardSectionGroupViewModel
├── title: String
├── isExpanded: Bool
└── sections: [SQDashboardSectionViewModel]
    ├── title: String
    ├── isExpanded: Bool
    ├── dropdownViewModel: SQDropDownMenuViewModel? (for filterable sections)
    ├── rows: [SQDashboardRowViewModel] (current visible rows)
    ├── rowsByFilter: [String: [SQDashboardRowViewModel]]? (for filterable sections)
    └── currentFilter: String
```

### Principles

- **Business logic in view models, not views**: Filtering, data transformation, and state management belong in view models
- **Section groups**: Use `SQDashboardSectionGroupViewModel` for collapsible groups (Daily Stats, Workouts)
- **Individual sections**: Use `SQDashboardSectionViewModel` for subsections (Metrics, Performance, etc.)
- **Row types**: Define specific row types using `SQDashboardRowType` enum
- **Filter handling**: Sections with filters store `rowsByFilter` dictionary and update `rows` when filter changes
- **State ownership**: Each view model owns its state (isExpanded, currentFilter, etc.)

### Building Section Groups

Section groups are built in `DashboardController.loadUI()`:
- Extract data from existing `sectionViewModels`
- Transform into hierarchical structure
- Store in `state.sectionGroups`
- Rebuild when time range changes

### View Rendering

Views render based on view model structure:
- `SQDashboardSectionGroupView` renders groups
- `SQDashboardSectionView` renders individual sections
- Row views dispatch based on `row.type`
```

**Commit:**
```bash
git add CLAUDE.md
git commit -m "Document dashboard view model architecture patterns

- Add section on hierarchical view model structure
- Document principles: business logic in view models
- Explain section groups, sections, and rows
- Document filter handling approach
- Add examples of building and rendering"
```

---

## Task 16: Test and Debug

**Manual testing checklist:**

1. **App launches without crash**
   - Section groups load correctly
   - Data displays in correct sections

2. **Section group collapse/expand**
   - Daily Stats expands/collapses
   - Workouts expands/collapses
   - Chevrons update correctly

3. **Individual section collapse/expand**
   - Each subsection collapses/expands independently
   - State persists within session

4. **Filtering - Metrics**
   - Dropdown shows all available groups
   - Selecting filter updates visible metrics
   - "All" shows all metrics

5. **Filtering - Totals**
   - Dropdown switches between Time/Kilocalories
   - Chart updates when filter changes

6. **Filtering - Activities**
   - Dropdown shows available workout types
   - Filtering updates visible activities

7. **Time range changes**
   - Switching time range rebuilds section groups
   - Data updates correctly

**Debug any issues found and commit fixes:**

```bash
git add [files]
git commit -m "Fix: [describe issue and fix]"
```

---

## Task 17: Remove Old Components (Cleanup)

**Files:**
- Delete or archive old components that are no longer needed

**Components to evaluate for removal:**
- Any old subsection views that are now handled by view models
- Old filter state management code
- Temporary debug logging

**Clean up:**

```bash
# Remove debug logging from SQDashboardView if any exists
# Remove any unused imports
# Remove commented-out code
```

**Commit:**
```bash
git add .
git commit -m "Clean up unused code after refactor

- Remove debug logging
- Remove unused imports
- Clean up commented code"
```

---

## Notes

**Key principles for this refactor:**
- **Separation of concerns**: Business logic in view models, views just render
- **Single source of truth**: View models own state, not DashboardState
- **Composition**: Section groups contain sections, sections contain rows
- **Type safety**: Use enums for row types and identifiers
- **Reactivity**: @Observable makes UI update automatically when view models change

**Testing strategy:**
- Manual testing for UI behavior
- Verify all existing functionality still works
- Test edge cases (empty states, no data, filter changes)

**Future improvements:**
- Add persistence for collapse states
- Add persistence for filter selections
- Implement proper row type handling for all existing row types
- Add animations for filter changes
