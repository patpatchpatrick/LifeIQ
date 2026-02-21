# Design: Dynamic Metric Change % on Dashboard

**Date:** 2026-02-20
**Status:** Approved

## Problem

The dashboard metrics table has a hardcoded `"14d %"` column header and a `change14d: 0.0` placeholder that never calculates anything real. The column should show an actual percentage change relative to a meaningful comparison period, and both the header label and the comparison window should adapt to the currently selected time range.

## Requirements

| Selected Time Range | Comparison Period | Column Header |
|---|---|---|
| Today | Last 7 days avg | `7d %` |
| Past 7 Days | Prior week avg | `7d %` |
| Past 30 Days | Prior 30 days avg | `30d %` |
| Past Year | Prior year avg | `1y %` |
| All Time | — | hidden / `—` |

- If `changePercent > 0` → green text
- If `changePercent < 0` → red text
- Sparkline data already scoped to current time range — no changes needed

## Approach

### 1. Add `dashboardChangePctTimeRange` to `AppTimeRange`

New computed var that returns the correct `SQTimeRange?` for the comparison fetch:

- `.today` → `.pastWeek` (7-day baseline, **not** `.yesterday`)
- `.pastSevenDays` → `.weekBeforeLast`
- `.past30Days` → `.thirtyDaysBeforeLast`
- `.pastYear` → `.yearBeforeLast`
- `.allTime` → `nil`

This differs from the existing `previousSqTimeRange` only for `.today`.

### 2. Add `dashboardChangePctHeader` to `AppTimeRange`

Returns the column header string:
- `.today` / `.pastSevenDays` → `"7d %"`
- `.past30Days` → `"30d %"`
- `.pastYear` → `"1y %"`
- `.allTime` → `"—"`

### 3. Rename `change14d` → `changePercent`

In `SQDashboardMetricStatsRowViewModel` and `SQStatRowData`. Represents the fractional change (e.g. `0.15` = +15%).

### 4. Fetch previous-period check-ins in `loadUI`

Using `dashboardChangePctTimeRange`, fetch the comparison check-ins alongside the current ones. Store as `previousCheckIns: [SQDailyCheckInStats]` on the controller (or pass directly to `buildMetricRow`).

### 5. Calculate `changePercent` in `buildMetricRow`

```
currentAvg  = avg of current metric values
previousAvg = avg of comparison metric values
changePercent = (currentAvg - previousAvg) / previousAvg
```

If `previousAvg == 0` or previous data is empty → `changePercent = nil` / `0.0`.

### 6. Use `dashboardChangePctHeader` for the column header

Replace the hardcoded `"14d %"` in `buildMetricsSubsection` with `selectedTimeRange.dashboardChangePctHeader`.

## Files to Change

| File | Change |
|---|---|
| `AppTimeRange.swift` | Add `dashboardChangePctTimeRange` and `dashboardChangePctHeader` |
| `SQDashboardMetricStatsRowViewModel.swift` | Rename `change14d` → `changePercent` |
| `SQStatRowData` (in `SQDashboardStatRow.swift`) | Rename `change14d` → `changePercent` |
| `SQDashboardController.swift` | Fetch previous check-ins; calculate `changePercent`; use dynamic header |
