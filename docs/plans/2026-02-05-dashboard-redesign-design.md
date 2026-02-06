# Dashboard Redesign - Hierarchical Section Layout

**Date:** 2026-02-05
**Status:** Design Complete, Ready for Implementation

## Overview

Redesign the BeastFitness dashboard to use a hierarchical section-based layout with collapsible main sections and subsections. The new design improves information hierarchy, adds filtering capabilities, and maximizes code reuse through shared components.

## Goals

1. Create clear visual hierarchy with main sections (Daily Stats, Workouts) and subsections
2. Add sticky section headers that pin while scrolling (iOS Settings pattern)
3. Enable individual collapse/expand for all sections and subsections
4. Add filtering capabilities to subsections (metrics by group, activities by type, totals by metric)
5. Maximize code reuse with shared components for sections, subsections, and stat rows
6. Maintain existing data sources and functionality while improving organization

## Design Inspiration

- iOS Settings app (sticky section headers)
- CoinMarketCap app (sparkline visualizations)
- Clean, modern UI with strong information hierarchy

## Architecture

### Hierarchy Structure

```
Dashboard (ScrollView with sticky headers)
├── Time Range Picker (top)
├── Daily Stats (main section, collapsible, sticky header)
│   └── Metrics (subsection, collapsible, filterable by group)
│       ├── Column Headers (Stat, Avg Score, 14d %)
│       └── Stat Rows (mood, mental clarity, etc.)
└── Workouts (main section, collapsible, sticky header)
    ├── Performance (subsection, collapsible)
    │   ├── Column Headers (Stat, Avg Score, 14d %)
    │   └── Stat Rows (VO2 Max, etc.)
    ├── Totals (subsection, collapsible, filterable by time/kcal)
    │   └── Bar Chart
    └── Activities (subsection, collapsible, filterable by type)
        └── Activity List
```

### State Management

Add to `DashboardState`:

```swift
// Main section collapse states
var isDailyStatsCollapsed: Bool = false
var isWorkoutsCollapsed: Bool = false

// Subsection collapse states
var isMetricsCollapsed: Bool = false
var isPerformanceCollapsed: Bool = false
var isTotalsCollapsed: Bool = false
var isActivitiesCollapsed: Bool = false

// Filter states (non-persisted, reset to defaults)
var metricsGroupFilter: String = "All"  // "All", "Self", "Habits", custom groups
var totalsTypeFilter: TotalsType = .time  // .time or .kilocalories
var activitiesTypeFilter: String = "All"  // "All" or specific workout type
```

**Note:** Collapse and filter states are NOT persisted. All sections start expanded, filters start at defaults.

## Component Specifications

### SQDashboardSectionHeader

Main section headers (Daily Stats, Workouts) with collapse functionality.

**Props:**
- `title: String` - Section title
- `isCollapsed: Binding<Bool>` - Collapse state

**Layout:**
- HStack: title (left) + chevron button (right)
- Height: 44pt (standard iOS touch target)
- Background: `SQColor.backgroundPrimary`
- Chevron rotates based on collapse state
- Full-width, sticky when scrolling

### SQDashboardSubsection

Reusable container for all subsections.

**Props:**
- `title: String` - Subsection title
- `isCollapsed: Binding<Bool>` - Collapse state
- `dropdownMenu: SQDropDownMenu?` - Optional filter dropdown
- `content: () -> Content` - ViewBuilder for subsection content

**Layout:**
- Header: HStack with title (left) and optional dropdown (right)
- Chevron button in header
- Content: Hidden when collapsed
- Background: `SQColor.backgroundSecondary` (creates visual hierarchy)
- Corner radius: 12pt
- Padding: 16pt horizontal, 12pt vertical

### SQStatRowSection

Wrapper that ensures column alignment between headers and data rows.

**Props:**
- `rows: [SQStatRowData]` - Array of stat data to display

**Layout:**
- Column headers row (Stat, Avg Score, 14d %)
- List of stat rows
- Shared column proportions:
  - Icon + Stat name: 40% width
  - Avg Score: 30% width
  - Sparkline + 14d %: 30% width

**Usage:**
- Used by Metrics and Performance subsections
- Guarantees header/row alignment
- Not used by Totals or Activities (different layouts)

### SQStatRow

Shared component for individual metrics and performance stats.

**Props:**
- `icon: String` - Emoji or SF Symbol name
- `title: String` - Stat name
- `avgValue: String` - Average value (e.g., "4.5", "48.1")
- `unit: String` - Unit suffix (e.g., "/ 10", "ml/kg/min")
- `sparklineData: [Double]` - Data points for mini chart
- `change14d: Double` - Percentage change over 14 days

**Layout (HStack):**
- Icon (24x24pt)
- Title (left-aligned, bodyMedium)
- Spacer
- Avg Value + Unit (bodySmall)
- Sparkline (40x20pt mini line chart)
- Change % (red/green based on sign)
- Height: ~60pt (flexible)
- Background: transparent (inherits from subsection)
- Dividers between rows: `SQColor.borderSubtle`

### SQSubsectionEmptyState

Shared empty state component.

**Props:**
- `message: String` - Empty state message
- `icon: SQImageSymbol` - Optional icon

**Layout:**
- Centered text with subtle icon
- Uses `SQColor.textSecondary`
- Consistent padding

**Usage Examples:**
- "No metrics in this group"
- "No performance data available"
- "No workouts recorded"
- "No activities recorded"

## Visual Hierarchy

### Background Colors

- **Level 1 - Main Section Headers:** `SQColor.backgroundPrimary`
- **Level 2 - Subsection Containers:** `SQColor.backgroundSecondary`
- **Level 3 - Stat Rows:** Transparent (inherits from subsection)

### Typography

- **Section Headers:** Large, bold
- **Subsection Headers:** Medium, semibold
- **Column Headers:** Small, medium weight, `textSecondary`
- **Stat Rows:** Body fonts from `SQFont`

### Spacing

- **Between sections:** 24pt
- **Between subsections:** 16pt
- **Between rows:** 0pt (dividers separate)

## Subsection Details

### Metrics Subsection

**Filter:** Group dropdown (All, Self, Habits, General, + custom groups)

**Behavior:**
- Default filter: "All"
- Dropdown dynamically built from existing groups in data
- When "All": show all metrics in flat list
- When specific group: show only metrics from that group
- Empty state: "No metrics in this group"

**Data Source:**
- Existing daily check-in metrics
- Uses `SQMetricDefinition.group` property
- Filters data based on selected group

### Performance Subsection

**Filter:** None

**Behavior:**
- Displays HealthKit performance metrics (VO2 Max, etc.)
- Uses `SQStatRowSection` for consistent layout with Metrics
- Empty state: "No performance data available"

**Data Source:**
- Existing HealthKit performance data
- Same data as current dashboard performance section

### Totals Subsection

**Filter:** Type dropdown (Time, Kilocalories)

**Behavior:**
- Default filter: Time
- Shows bar chart of workout totals
- Empty state: "No workouts recorded"

**Data Source:**
- Existing workout totals data
- Same functionality as current dashboard totals section

### Activities Subsection

**Filter:** Type dropdown (All, + workout types)

**Behavior:**
- Default filter: "All"
- Dropdown dynamically built from workout types in current time range
- Shows only workout types that exist in selected time range
- Empty state: "No activities recorded"
- When no activities exist, dropdown shows only "All"

**Data Source:**
- Existing workout/activity data
- Same list as current dashboard activities section

## Sticky Header Implementation

Use SwiftUI's native sticky header support:

```swift
ScrollView {
    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
        Section {
            // Daily Stats subsections
        } header: {
            SQDashboardSectionHeader(
                title: "Daily Stats",
                isCollapsed: $dashboardState.isDailyStatsCollapsed
            )
        }

        Section {
            // Workouts subsections
        } header: {
            SQDashboardSectionHeader(
                title: "Workouts",
                isCollapsed: $dashboardState.isWorkoutsCollapsed
            )
        }
    }
}
```

This provides iOS Settings-style sticky behavior where the current section's header pins at the top while scrolling.

## Dropdown Standardization

All dropdowns use `SQDropDownMenu`:
- Time range picker (top of dashboard)
- Metrics group filter
- Totals type filter
- Activities type filter

**Default Values:**
- Time range: Past 7 Days
- Metrics filter: All
- Totals filter: Time
- Activities filter: All

**Note:** Dropdown UI refinement deferred to later iteration. Focus on functionality first.

## Edge Cases & Data Handling

### Empty States

Each subsection handles empty data gracefully using `SQSubsectionEmptyState`:
- Metrics (filtered): "No metrics in this group"
- Performance: "No performance data available"
- Totals: "No workouts recorded"
- Activities: "No activities recorded"

### Dynamic Dropdown Options

**Metrics Group Filter:**
- Always includes "All"
- Dynamically adds groups from current data
- Sorted alphabetically after "All"

**Activities Type Filter:**
- Always includes "All"
- Builds from unique workout types in time range
- Sorted alphabetically after "All"
- Updates when time range changes

### Loading States

- Use skeleton/placeholder UI for subsections during data load
- Disable dropdown interactions until data is ready
- Leverage existing dashboard loading patterns

### Collapse State

- All sections and subsections start expanded on app launch
- No persistence of collapse states (deferred to later iteration)

## Implementation Notes

### Code Reuse

- `SQStatRow` shared between Metrics and Performance subsections
- `SQDashboardSubsection` used by all four subsections
- `SQSubsectionEmptyState` used for all empty states
- Existing data fetching and processing logic remains unchanged

### Existing Code Integration

- Totals subsection wraps existing totals chart component
- Activities subsection wraps existing activity list component
- Performance subsection uses existing HealthKit data source
- Metrics subsection uses existing daily check-in data

### SwiftUI Conventions

- Use `@Binding` for collapse states
- Use `@ViewBuilder` for content closures
- Follow existing SQColor and SQFont conventions
- Use SQImageSymbol for all icons

## Out of Scope (Future Work)

- Persisting collapse states across sessions
- Persisting filter selections across sessions
- "Fastest Mile" stat in Performance section
- Sparkline/chart visual refinements to match CoinMarketCap style exactly
- Custom dropdown UI design (using standard SQDropDownMenu for now)

## Success Criteria

- Dashboard displays hierarchical section structure
- Main section headers pin while scrolling
- All sections and subsections can collapse/expand independently
- Filters work correctly for Metrics, Totals, and Activities
- Empty states display appropriately
- Stat rows shared between Metrics and Performance
- Code is well-organized and reusable
- Visual hierarchy clear through background colors and typography

## Next Steps

1. Create isolated git worktree for development
2. Write detailed implementation plan
3. Implement shared components first (SQStatRow, SQDashboardSubsection, etc.)
4. Build main dashboard structure with sticky headers
5. Integrate subsections one at a time
6. Test collapse/expand and filter functionality
7. Verify empty states and edge cases
8. Review and merge
