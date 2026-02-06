# Dashboard Redesign Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Redesign the dashboard with hierarchical sections, sticky headers, and collapsible subsections with filtering.

**Architecture:** Replace current dashboard with ScrollView + LazyVStack with pinned section headers. Create reusable components (SQDashboardSectionHeader, SQDashboardSubsection, SQStatRow, SQStatRowSection) that handle layout, collapse states, and filtering. Integrate existing data sources without modification.

**Tech Stack:** SwiftUI, @Observable pattern, SQAppState, existing HealthKit/Firestore data sources

---

## Task 1: Add State Properties to DashboardState

**Files:**
- Modify: `BeastFitness/StateManagement/DashboardState.swift`

**Step 1: Read current DashboardState**

Read the file to understand the existing structure and where to add new properties.

**Step 2: Add collapse and filter state properties**

Add these properties to the `DashboardState` class (after existing properties):

```swift
// MARK: - Section Collapse States
var isDailyStatsCollapsed: Bool = false
var isWorkoutsCollapsed: Bool = false

// MARK: - Subsection Collapse States
var isMetricsCollapsed: Bool = false
var isPerformanceCollapsed: Bool = false
var isTotalsCollapsed: Bool = false
var isActivitiesCollapsed: Bool = false

// MARK: - Filter States
var metricsGroupFilter: String = "All"
var totalsTypeFilter: TotalsType = .time
var activitiesTypeFilter: String = "All"

enum TotalsType: String, CaseIterable {
    case time = "Time"
    case kilocalories = "Kilocalories"
}
```

**Step 3: Verify changes compile**

Build the project to ensure no compilation errors.

Run: Build in Xcode (⌘B)
Expected: Build succeeds

**Step 4: Commit**

```bash
git add BeastFitness/StateManagement/DashboardState.swift
git commit -m "Add collapse and filter state to DashboardState

- Add section collapse states (Daily Stats, Workouts)
- Add subsection collapse states (Metrics, Performance, Totals, Activities)
- Add filter states (metrics group, totals type, activities type)
- All default to expanded/default filter values"
```

---

## Task 2: Create SQSubsectionEmptyState Component

**Files:**
- Create: `BeastFitness/Views/Dashboard/Shared/SQSubsectionEmptyState.swift`

**Step 1: Create the directory**

```bash
mkdir -p BeastFitness/Views/Dashboard/Shared
```

**Step 2: Create empty state component**

```swift
//
//  SQSubsectionEmptyState.swift
//  BeastFitness
//

import SwiftUI

struct SQSubsectionEmptyState: View {
    let message: String
    let icon: SQImageSymbol

    init(message: String, icon: SQImageSymbol = .exclamationmarkCircle) {
        self.message = message
        self.icon = icon
    }

    var body: some View {
        VStack(spacing: 12) {
            SQImageView(image: .init(
                symbol: icon,
                symbolStyle: .colorWithFont(.textSecondary, font: .bodyMedium)
            ))

            Text(message)
                .sqFont(.bodyMedium)
                .sqForegroundColor(.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    SQSubsectionEmptyState(message: "No metrics in this group")
        .sqBackgroundColor(.background)
}
```

**Step 3: Verify it compiles**

Build the project.

Run: Build in Xcode (⌘B)
Expected: Build succeeds

**Step 4: Add file to Xcode project**

Add the new file to the BeastFitness target in Xcode.

**Step 5: Commit**

```bash
git add BeastFitness/Views/Dashboard/Shared/SQSubsectionEmptyState.swift
git commit -m "Add SQSubsectionEmptyState component

Shared empty state view for all dashboard subsections.
- Displays icon and message
- Uses textSecondary color
- Centered layout with consistent padding"
```

---

## Task 3: Create SQStatRowData Model

**Files:**
- Create: `BeastFitness/Models/Dashboard/SQStatRowData.swift`

**Step 1: Create directory**

```bash
mkdir -p BeastFitness/Models/Dashboard
```

**Step 2: Create data model**

```swift
//
//  SQStatRowData.swift
//  BeastFitness
//

import Foundation

struct SQStatRowData: Identifiable {
    let id: String
    let icon: String  // Emoji or SF Symbol name
    let title: String
    let avgValue: String
    let unit: String
    let sparklineData: [Double]
    let change14d: Double  // Percentage change

    init(
        id: String,
        icon: String,
        title: String,
        avgValue: String,
        unit: String,
        sparklineData: [Double],
        change14d: Double
    ) {
        self.id = id
        self.icon = icon
        self.title = title
        self.avgValue = avgValue
        self.unit = unit
        self.sparklineData = sparklineData
        self.change14d = change14d
    }
}
```

**Step 3: Add to Xcode project**

Add the file to the BeastFitness target.

**Step 4: Verify compilation**

Build the project.

Run: Build in Xcode (⌘B)
Expected: Build succeeds

**Step 5: Commit**

```bash
git add BeastFitness/Models/Dashboard/SQStatRowData.swift
git commit -m "Add SQStatRowData model

Data model for stat rows used in Metrics and Performance subsections.
Contains icon, title, average value, unit, sparkline data, and 14d change."
```

---

## Task 4: Create SQStatRow Component

**Files:**
- Create: `BeastFitness/Views/Dashboard/Shared/SQStatRow.swift`

**Step 1: Create stat row component**

```swift
//
//  SQStatRow.swift
//  BeastFitness
//

import SwiftUI
import CoolCharts

struct SQStatRow: View {
    let data: SQStatRowData

    var body: some View {
        HStack(spacing: 12) {
            // Icon + Title (40% width)
            HStack(spacing: 8) {
                if data.icon.count == 1 {
                    // Emoji
                    Text(data.icon)
                        .font(.system(size: 20))
                        .frame(width: 24, height: 24)
                } else {
                    // SF Symbol
                    SQImageView(image: .init(
                        symbol: SQImageSymbol(rawValue: data.icon) ?? .heart,
                        symbolStyle: .colorWithFont(.textPrimary, font: .bodyMedium)
                    ))
                    .frame(width: 24, height: 24)
                }

                Text(data.title)
                    .sqFont(.bodyMedium)
                    .sqForegroundColor(.textPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minWidth: 0)

            Spacer(minLength: 8)

            // Avg Value + Unit (30% width)
            HStack(spacing: 4) {
                Text(data.avgValue)
                    .sqFont(.bodyMedium)
                    .sqForegroundColor(.textPrimary)

                Text(data.unit)
                    .sqFont(.bodySmall)
                    .sqForegroundColor(.textSecondary)
            }
            .frame(minWidth: 0)

            // Sparkline + Change % (30% width)
            HStack(spacing: 8) {
                // Placeholder sparkline - will integrate CoolCharts later
                Rectangle()
                    .fill(data.change14d >= 0 ? SQColor.colorFadedGreen.color : SQColor.colorFadedRed.color)
                    .frame(width: 40, height: 20)
                    .cornerRadius(4)

                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 2) {
                        SQImageView(image: .init(
                            symbol: data.change14d >= 0 ? .arrowUp : .arrowDown,
                            symbolStyle: .colorWithFont(
                                data.change14d >= 0 ? .colorFadedGreen : .colorFadedRed,
                                font: .captionSmall
                            )
                        ))
                        .frame(width: 10, height: 10)

                        Text(String(format: "%.1f%%", abs(data.change14d)))
                            .sqFont(.captionSmall)
                            .sqForegroundColor(data.change14d >= 0 ? .colorFadedGreen : .colorFadedRed)
                    }
                }
            }
            .frame(minWidth: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.clear)
    }
}

#Preview {
    VStack(spacing: 0) {
        SQStatRow(data: .init(
            id: "mood",
            icon: "😊",
            title: "Mood",
            avgValue: "4.5",
            unit: "/ 10",
            sparklineData: [4.2, 4.5, 4.8, 4.3, 4.6],
            change14d: 35.28
        ))

        Divider()
            .sqBackgroundColor(.divider())

        SQStatRow(data: .init(
            id: "vo2max",
            icon: "heart",
            title: "VO2 Max",
            avgValue: "48.1",
            unit: "ml/kg/min",
            sparklineData: [47, 48, 49, 48, 48],
            change14d: -12.5
        ))
    }
    .sqBackgroundColor(.backgroundSecondary)
}
```

**Step 2: Check if required SF Symbols exist**

Read `BeastFitness/UI/SQImage.swift` to verify `arrowUp`, `arrowDown`, `heart`, and `exclamationmarkCircle` symbols exist. If not, add them.

**Step 3: Add to Xcode project**

Add the file to the BeastFitness target.

**Step 4: Build and verify**

Run: Build in Xcode (⌘B)
Expected: Build succeeds

**Step 5: Commit**

```bash
git add BeastFitness/Views/Dashboard/Shared/SQStatRow.swift
git commit -m "Add SQStatRow component

Shared row component for displaying metrics and performance stats.
- Displays icon, title, avg value, sparkline placeholder, and 14d change
- Column layout with 40/30/30 proportions
- Color codes positive/negative changes
- Placeholder for sparkline chart (to be integrated later)"
```

---

## Task 5: Create SQStatRowSection Component

**Files:**
- Create: `BeastFitness/Views/Dashboard/Shared/SQStatRowSection.swift`

**Step 1: Create stat row section component**

```swift
//
//  SQStatRowSection.swift
//  BeastFitness
//

import SwiftUI

struct SQStatRowSection: View {
    let rows: [SQStatRowData]

    var body: some View {
        VStack(spacing: 0) {
            // Column headers
            HStack(spacing: 12) {
                // Stat column (40%)
                Text("Stat")
                    .sqFont(.captionMedium)
                    .sqForegroundColor(.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 8)

                // Avg Score column (30%)
                Text("Avg Score")
                    .sqFont(.captionMedium)
                    .sqForegroundColor(.textSecondary)
                    .frame(minWidth: 0, alignment: .leading)

                // 14d % column (30%)
                Text("14d %")
                    .sqFont(.captionMedium)
                    .sqForegroundColor(.textSecondary)
                    .frame(minWidth: 0, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            // Stat rows
            ForEach(rows) { row in
                VStack(spacing: 0) {
                    Divider()
                        .sqBackgroundColor(.divider())

                    SQStatRow(data: row)
                }
            }
        }
    }
}

#Preview {
    SQStatRowSection(rows: [
        .init(
            id: "mood",
            icon: "😊",
            title: "Mood",
            avgValue: "4.5",
            unit: "/ 10",
            sparklineData: [4.2, 4.5, 4.8],
            change14d: 35.28
        ),
        .init(
            id: "energy",
            icon: "⚡️",
            title: "Energy",
            avgValue: "8.1",
            unit: "/ 10",
            sparklineData: [7.8, 8.0, 8.3],
            change14d: -5.2
        )
    ])
    .sqBackgroundColor(.backgroundSecondary)
    .cornerRadius(12)
    .padding()
    .sqBackgroundColor(.background)
}
```

**Step 2: Add to Xcode project**

**Step 3: Build and verify**

Run: Build in Xcode (⌘B)
Expected: Build succeeds

**Step 4: Commit**

```bash
git add BeastFitness/Views/Dashboard/Shared/SQStatRowSection.swift
git commit -m "Add SQStatRowSection component

Wrapper component that ensures column alignment between headers and rows.
- Displays column headers (Stat, Avg Score, 14d %)
- Renders list of SQStatRow components
- Maintains consistent column proportions"
```

---

## Task 6: Create SQDashboardSectionHeader Component

**Files:**
- Create: `BeastFitness/Views/Dashboard/Shared/SQDashboardSectionHeader.swift`

**Step 1: Create section header component**

```swift
//
//  SQDashboardSectionHeader.swift
//  BeastFitness
//

import SwiftUI

struct SQDashboardSectionHeader: View {
    let title: String
    @Binding var isCollapsed: Bool

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isCollapsed.toggle()
            }
        } label: {
            HStack {
                Text(title)
                    .sqFont(.titleLarge)
                    .sqForegroundColor(.textPrimary)

                Spacer()

                SQImageView(image: .init(
                    symbol: isCollapsed ? .chevronDown : .chevronUp,
                    symbolStyle: .colorWithFont(.textSecondary, font: .bodyMedium)
                ))
                .frame(width: 20, height: 20)
                .rotationEffect(.degrees(0))
            }
            .padding(.horizontal, 16)
            .frame(height: 44)
            .frame(maxWidth: .infinity)
            .sqBackgroundColor(.background)
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        SQDashboardSectionHeader(
            title: "Daily Stats",
            isCollapsed: .constant(false)
        )

        SQDashboardSectionHeader(
            title: "Workouts",
            isCollapsed: .constant(true)
        )
    }
    .sqBackgroundColor(.background)
}
```

**Step 2: Verify chevron symbols exist**

Check `BeastFitness/UI/SQImage.swift` for `chevronDown` and `chevronUp`. Add if missing.

**Step 3: Add to Xcode project**

**Step 4: Build and verify**

Run: Build in Xcode (⌘B)
Expected: Build succeeds

**Step 5: Commit**

```bash
git add BeastFitness/Views/Dashboard/Shared/SQDashboardSectionHeader.swift
git commit -m "Add SQDashboardSectionHeader component

Main section header for Daily Stats and Workouts sections.
- Displays title and chevron button
- Toggles collapse state with animation
- 44pt height (standard iOS touch target)
- Uses backgroundPrimary color"
```

---

## Task 7: Create SQDashboardSubsection Component

**Files:**
- Create: `BeastFitness/Views/Dashboard/Shared/SQDashboardSubsection.swift`

**Step 1: Create subsection component**

```swift
//
//  SQDashboardSubsection.swift
//  BeastFitness
//

import SwiftUI

struct SQDashboardSubsection<Content: View>: View {
    let title: String
    @Binding var isCollapsed: Bool
    let dropdownMenu: AnyView?
    @ViewBuilder let content: () -> Content

    init(
        title: String,
        isCollapsed: Binding<Bool>,
        dropdownMenu: SQDropDownMenu? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self._isCollapsed = isCollapsed
        self.dropdownMenu = dropdownMenu.map { AnyView($0) }
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isCollapsed.toggle()
                }
            } label: {
                HStack {
                    Text(title)
                        .sqFont(.titleMedium)
                        .sqForegroundColor(.textPrimary)

                    Spacer()

                    if let dropdown = dropdownMenu {
                        dropdown
                    }

                    SQImageView(image: .init(
                        symbol: isCollapsed ? .chevronDown : .chevronUp,
                        symbolStyle: .colorWithFont(.textSecondary, font: .bodySmall)
                    ))
                    .frame(width: 16, height: 16)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            // Content
            if !isCollapsed {
                content()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .sqBackgroundColor(.backgroundSecondary)
        .cornerRadius(12)
    }
}

#Preview {
    VStack(spacing: 16) {
        SQDashboardSubsection(
            title: "Metrics",
            isCollapsed: .constant(false)
        ) {
            Text("Content goes here")
                .padding()
        }

        SQDashboardSubsection(
            title: "Performance",
            isCollapsed: .constant(true)
        ) {
            Text("Collapsed content")
                .padding()
        }
    }
    .padding()
    .sqBackgroundColor(.background)
}
```

**Step 2: Add to Xcode project**

**Step 3: Build and verify**

Run: Build in Xcode (⌘B)
Expected: Build succeeds

**Step 4: Commit**

```bash
git add BeastFitness/Views/Dashboard/Shared/SQDashboardSubsection.swift
git commit -m "Add SQDashboardSubsection component

Reusable container for all dashboard subsections.
- Header with title, optional dropdown, and chevron
- Collapsible content with animation
- backgroundSecondary color for visual hierarchy
- 12pt corner radius"
```

---

## Task 8: Update DashboardView Structure

**Files:**
- Modify: `BeastFitness/Views/Dashboard/DashboardView.swift` (or wherever the main dashboard view is)

**Step 1: Find current dashboard view**

Search for the main dashboard view file.

```bash
find BeastFitness/Views -name "*Dashboard*.swift" -type f
```

**Step 2: Read the current dashboard view**

Understand the existing structure before modifying.

**Step 3: Create new dashboard structure**

Replace the current dashboard body with the new hierarchical structure:

```swift
var body: some View {
    ScrollView {
        VStack(spacing: 0) {
            // Dashboard header with time range picker
            HStack {
                Text("Dashboard")
                    .sqFont(.displayLarge)
                    .sqForegroundColor(.textPrimary)

                Spacer()

                SQDropDownMenu(
                    selectedOption: Binding(
                        get: { dashboardState.selectedTimeRange.rawValue },
                        set: { newValue in
                            if let timeRange = DashboardTimeRange(rawValue: newValue) {
                                dashboardState.selectedTimeRange = timeRange
                            }
                        }
                    ),
                    options: DashboardTimeRange.allCases.map { $0.rawValue }
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Sections with sticky headers
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                // Daily Stats Section
                Section {
                    if !dashboardState.isDailyStatsCollapsed {
                        dailyStatsSection
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                    }
                } header: {
                    SQDashboardSectionHeader(
                        title: "Daily Stats",
                        isCollapsed: $dashboardState.isDailyStatsCollapsed
                    )
                }

                // Workouts Section
                Section {
                    if !dashboardState.isWorkoutsCollapsed {
                        workoutsSection
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                    }
                } header: {
                    SQDashboardSectionHeader(
                        title: "Workouts",
                        isCollapsed: $dashboardState.isWorkoutsCollapsed
                    )
                }
            }
        }
    }
    .sqBackgroundColor(.background)
}

// MARK: - Daily Stats Section
private var dailyStatsSection: some View {
    VStack(spacing: 16) {
        // Metrics subsection
        metricsSubsection
    }
}

// MARK: - Workouts Section
private var workoutsSection: some View {
    VStack(spacing: 16) {
        // Performance subsection
        performanceSubsection

        // Totals subsection
        totalsSubsection

        // Activities subsection
        activitiesSubsection
    }
}
```

**Step 4: Add placeholder subsection views**

Add temporary placeholder views for each subsection:

```swift
private var metricsSubsection: some View {
    SQDashboardSubsection(
        title: "Metrics",
        isCollapsed: $dashboardState.isMetricsCollapsed,
        dropdownMenu: SQDropDownMenu(
            selectedOption: $dashboardState.metricsGroupFilter,
            options: ["All", "Self", "Habits", "General"]
        )
    ) {
        Text("Metrics content - TODO")
            .padding()
    }
}

private var performanceSubsection: some View {
    SQDashboardSubsection(
        title: "Performance",
        isCollapsed: $dashboardState.isPerformanceCollapsed
    ) {
        Text("Performance content - TODO")
            .padding()
    }
}

private var totalsSubsection: some View {
    SQDashboardSubsection(
        title: "Totals",
        isCollapsed: $dashboardState.isTotalsCollapsed,
        dropdownMenu: SQDropDownMenu(
            selectedOption: Binding(
                get: { dashboardState.totalsTypeFilter.rawValue },
                set: { dashboardState.totalsTypeFilter = DashboardState.TotalsType(rawValue: $0) ?? .time }
            ),
            options: DashboardState.TotalsType.allCases.map { $0.rawValue }
        )
    ) {
        Text("Totals content - TODO")
            .padding()
    }
}

private var activitiesSubsection: some View {
    SQDashboardSubsection(
        title: "Activities",
        isCollapsed: $dashboardState.isActivitiesCollapsed,
        dropdownMenu: SQDropDownMenu(
            selectedOption: $dashboardState.activitiesTypeFilter,
            options: ["All", "Running", "Cycling"]  // TODO: Make dynamic
        )
    ) {
        Text("Activities content - TODO")
            .padding()
    }
}
```

**Step 5: Build and test**

Run: Build and run in simulator
Expected: Dashboard displays with new structure, sections collapsible

**Step 6: Commit**

```bash
git add BeastFitness/Views/Dashboard/DashboardView.swift
git commit -m "Restructure dashboard with hierarchical sections

- Add ScrollView with LazyVStack for sticky headers
- Create Daily Stats and Workouts main sections
- Add placeholder subsections (Metrics, Performance, Totals, Activities)
- Wire up collapse states and filter dropdowns
- All subsections use temporary placeholder content"
```

---

## Task 9: Implement Metrics Subsection

**Files:**
- Modify: `BeastFitness/Views/Dashboard/DashboardView.swift`
- May need to read: Current dashboard metric views

**Step 1: Find existing metrics data**

Search for how metrics are currently fetched and displayed in the dashboard.

**Step 2: Create computed property for filtered metrics**

Add to DashboardView or DashboardState:

```swift
var filteredMetrics: [SQStatRowData] {
    // Get all metrics from dashboard state
    let allMetrics = dashboardState.sectionViewModels
        .compactMap { $0 as? /* existing metric section type */ }
        .flatMap { /* extract metrics */ }

    // Filter by selected group
    if dashboardState.metricsGroupFilter == "All" {
        return allMetrics
    } else {
        return allMetrics.filter { $0.group == dashboardState.metricsGroupFilter }
    }
}

var availableMetricGroups: [String] {
    // Extract unique groups from all metrics
    let groups = Set(dashboardState.sectionViewModels
        .compactMap { /* extract group names */ })

    return ["All"] + groups.sorted()
}
```

**Step 3: Update metricsSubsection**

Replace placeholder with actual implementation:

```swift
private var metricsSubsection: some View {
    SQDashboardSubsection(
        title: "Metrics",
        isCollapsed: $dashboardState.isMetricsCollapsed,
        dropdownMenu: SQDropDownMenu(
            selectedOption: $dashboardState.metricsGroupFilter,
            options: availableMetricGroups
        )
    ) {
        if filteredMetrics.isEmpty {
            SQSubsectionEmptyState(message: "No metrics in this group")
        } else {
            SQStatRowSection(rows: filteredMetrics)
        }
    }
}
```

**Step 4: Build and test filtering**

Run: Build and run in simulator
Expected: Metrics display, filtering works, empty state shows for empty groups

**Step 5: Commit**

```bash
git add BeastFitness/Views/Dashboard/DashboardView.swift
git commit -m "Implement Metrics subsection with filtering

- Convert existing metrics to SQStatRowData format
- Add computed property for filtered metrics
- Build dropdown options from available groups
- Display SQStatRowSection with filtered metrics
- Show empty state when no metrics match filter"
```

---

## Task 10: Implement Performance Subsection

**Files:**
- Modify: `BeastFitness/Views/Dashboard/DashboardView.swift`

**Step 1: Find existing performance data**

Search for how HealthKit performance metrics (VO2 Max, etc.) are currently displayed.

**Step 2: Create computed property for performance stats**

```swift
var performanceStats: [SQStatRowData] {
    // Extract VO2 Max and other performance metrics from dashboard state
    // Convert to SQStatRowData format
    []
}
```

**Step 3: Update performanceSubsection**

```swift
private var performanceSubsection: some View {
    SQDashboardSubsection(
        title: "Performance",
        isCollapsed: $dashboardState.isPerformanceCollapsed
    ) {
        if performanceStats.isEmpty {
            SQSubsectionEmptyState(
                message: "No performance data available",
                icon: .heart
            )
        } else {
            SQStatRowSection(rows: performanceStats)
        }
    }
}
```

**Step 4: Build and test**

Run: Build and run in simulator
Expected: Performance metrics display in stat rows format

**Step 5: Commit**

```bash
git add BeastFitness/Views/Dashboard/DashboardView.swift
git commit -m "Implement Performance subsection

- Convert HealthKit performance data to SQStatRowData format
- Display using SQStatRowSection
- Show empty state when no data available"
```

---

## Task 11: Implement Totals Subsection

**Files:**
- Modify: `BeastFitness/Views/Dashboard/DashboardView.swift`

**Step 1: Find existing totals chart component**

Locate the current totals bar chart view.

**Step 2: Update totalsSubsection to wrap existing component**

```swift
private var totalsSubsection: some View {
    SQDashboardSubsection(
        title: "Totals",
        isCollapsed: $dashboardState.isTotalsCollapsed,
        dropdownMenu: SQDropDownMenu(
            selectedOption: Binding(
                get: { dashboardState.totalsTypeFilter.rawValue },
                set: { dashboardState.totalsTypeFilter = DashboardState.TotalsType(rawValue: $0) ?? .time }
            ),
            options: DashboardState.TotalsType.allCases.map { $0.rawValue }
        )
    ) {
        if /* has workout data */ {
            // Existing totals chart component
            // Pass filtered data based on totalsTypeFilter
            ExistingTotalsChartView(type: dashboardState.totalsTypeFilter)
        } else {
            SQSubsectionEmptyState(
                message: "No workouts recorded",
                icon: .figureWalk
            )
        }
    }
}
```

**Step 3: Build and test**

Run: Build and run in simulator
Expected: Totals chart displays, filter switches between time/kcal

**Step 4: Commit**

```bash
git add BeastFitness/Views/Dashboard/DashboardView.swift
git commit -m "Implement Totals subsection

- Wrap existing totals chart component
- Wire up time/kilocalories filter
- Show empty state when no workout data"
```

---

## Task 12: Implement Activities Subsection

**Files:**
- Modify: `BeastFitness/Views/Dashboard/DashboardView.swift`

**Step 1: Find existing activities list**

Locate the current activities/workouts list view.

**Step 2: Create computed properties for filtering**

```swift
var availableWorkoutTypes: [String] {
    // Extract unique workout types from current time range
    let types = Set(/* workout types from dashboard state */)
    return ["All"] + types.sorted()
}

var filteredActivities: [/* Activity type */] {
    let allActivities = /* get from dashboard state */

    if dashboardState.activitiesTypeFilter == "All" {
        return allActivities
    } else {
        return allActivities.filter { $0.workoutType == dashboardState.activitiesTypeFilter }
    }
}
```

**Step 3: Update activitiesSubsection**

```swift
private var activitiesSubsection: some View {
    SQDashboardSubsection(
        title: "Activities",
        isCollapsed: $dashboardState.isActivitiesCollapsed,
        dropdownMenu: SQDropDownMenu(
            selectedOption: $dashboardState.activitiesTypeFilter,
            options: availableWorkoutTypes
        )
    ) {
        if filteredActivities.isEmpty {
            SQSubsectionEmptyState(
                message: "No activities recorded",
                icon: .figureWalk
            )
        } else {
            // Existing activities list component
            // Pass filtered activities
            ExistingActivitiesListView(activities: filteredActivities)
        }
    }
}
```

**Step 4: Build and test**

Run: Build and run in simulator
Expected: Activities display, filtering works, dropdown updates with time range

**Step 5: Commit**

```bash
git add BeastFitness/Views/Dashboard/DashboardView.swift
git commit -m "Implement Activities subsection with filtering

- Wrap existing activities list component
- Build dynamic workout type filter from data
- Filter activities by selected type
- Show empty state when no activities match"
```

---

## Task 13: Add Required SF Symbols

**Files:**
- Modify: `BeastFitness/UI/SQImage.swift`

**Step 1: Read SQImage.swift to check existing symbols**

Identify which symbols are missing: `chevronUp`, `chevronDown`, `arrowUp`, `arrowDown`, `exclamationmarkCircle`, `heart`, `figureWalk`

**Step 2: Add missing symbols to SQImageSymbol enum**

```swift
// In SQImageSymbol enum
case chevronUp = "chevron.up"
case chevronDown = "chevron.down"
case arrowUp = "arrow.up"
case arrowDown = "arrow.down"
case exclamationmarkCircle = "exclamationmark.circle"
case heart = "heart.fill"
case figureWalk = "figure.walk"
```

**Step 3: Build and verify**

Run: Build in Xcode (⌘B)
Expected: Build succeeds

**Step 4: Commit**

```bash
git add BeastFitness/UI/SQImage.swift
git commit -m "Add SF Symbols for dashboard redesign

- Add chevronUp, chevronDown for collapse controls
- Add arrowUp, arrowDown for change indicators
- Add exclamationmarkCircle for empty states
- Add heart, figureWalk for subsection icons"
```

---

## Task 14: Test and Polish

**Files:**
- Test in Xcode simulator

**Step 1: Test all collapse/expand functionality**

- Collapse/expand Daily Stats section
- Collapse/expand Workouts section
- Collapse/expand all subsections individually

**Step 2: Test all filters**

- Metrics group filter (All, Self, Habits, etc.)
- Totals type filter (Time, Kilocalories)
- Activities type filter (All, Running, etc.)
- Verify filters update when time range changes

**Step 3: Test empty states**

- Filter metrics to empty group
- Test with no HealthKit data
- Test with no workouts
- Test with no activities

**Step 4: Test sticky headers**

- Scroll and verify Daily Stats header pins at top
- Scroll further and verify Workouts header takes over
- Verify sticky behavior works with collapsed sections

**Step 5: Document any issues**

Note any bugs or visual issues for future refinement.

---

## Task 15: Final Commit and Review

**Step 1: Review all changes**

```bash
git log --oneline -15
git diff main..feature/dashboard-redesign
```

**Step 2: Test full user flow**

- Open app
- Navigate to dashboard
- Interact with all sections and filters
- Verify data displays correctly

**Step 3: Create final commit if any polish changes**

```bash
git add .
git commit -m "Polish dashboard redesign

- Fix any minor visual issues
- Adjust spacing/padding
- Verify all animations work smoothly"
```

**Step 4: Push branch**

```bash
git push -u origin feature/dashboard-redesign
```

---

## Notes

- **DRY**: All subsections use `SQDashboardSubsection`, all stat rows use `SQStatRow`
- **YAGNI**: Not implementing persistence, just basic functionality
- **Frequent commits**: Each task should result in a commit
- **Existing data**: No changes to data fetching, only UI organization
- **Testing**: Build and run after each major task to catch issues early

## Future Work

- Replace sparkline placeholder with actual CoolCharts implementation
- Add persistence for collapse/filter states
- Refine dropdown UI styling
- Add "Fastest Mile" to Performance section
- Match CoinMarketCap sparkline visual style exactly
