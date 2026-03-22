# Locked Metrics Subsection (Blur + Preview)

**Date:** 2026-03-22
**Status:** Approved

## Summary

When a user is not logged in, the Metrics subsection on the dashboard shows a blurred preview of fake metric data with a "Log in to unlock your stats" CTA overlay. This gives unauthenticated users a feel for the value of the feature while prompting conversion.

---

## Goals

- Show the Metrics subsection UI structure to unauthenticated users
- Blur numeric values to create curiosity without revealing data
- Keep metric labels/icons sharp so users understand what they're missing
- Provide a single tap path to the login/profile screen
## Non-Goals

- Animating the unlock after login (deferred)
- Refreshing the dashboard after login (deferred — user must manually refresh or re-enter the tab)
- Locking other subsections (Performance, Sleep, Workouts) — this can use the same mechanism later
- Persisting or randomizing fake data across sessions

---

## Data Layer

### `SQDashboardSubsectionViewModel`

Add two new properties:

```swift
var isLocked: Bool = false
var onLockedTap: (() -> Void)? = nil
```

`isLocked` defaults to `false` — no existing subsections are affected. `onLockedTap` is a closure set by the controller at build time so the view never needs a direct reference to the controller.

### `SQDashboardController.buildMetricsSubsection(...)`

When `!userState.isLoggedIn`:

1. Use real metric definitions from `SQMetricsManager.shared.dailyCheckInMetrics()`, filtered to `isEnabled == true` only, to build rows with real names and icons — so the labels look authentic.
2. Populate `avgValue` with static fake strings (e.g. `"7.2"`, `"6.8"`) and `changePercent` with small fake values (e.g. `0.04`). Sparkline data should be a short static array of plausible values (e.g. `[6.0, 7.2, 6.5, 7.8, 7.2]`).
3. For each row's `unit`: derive it from the metric definition's `SQMetricUnit` using the same mapping used by real rows (e.g. `.hours` → `"hrs"`, `.none`/`.score` → `"/10"`). Do not hardcode unit strings.
4. Set `isLocked = true` on the subsection view model.
5. Set `onLockedTap = { [weak self] in self?.handleAuthButtonTap() }` on the subsection view model.
6. **Do not set a dropdown** (`dropDownViewModel = nil`) when locked — showing group filters over fake data is misleading.
7. Still set column headers normally (`["Metric", "Avg Score", ...]`).

If `SQMetricsManager` has no enabled metric definitions available (first launch before any sync), fall back to a hardcoded list using known `SQMetricId` values: mood, energy, sleepHours, soreness, clarity — so icon/emoji lookup still works via the existing metric infrastructure.

---

## View Layer

### `SQDashboardSectionView`

When `section.isLocked == true`:

**Blur target:** Wrap only the row `VStack` (the one containing `ForEach` over `section.activeRows`) in a `ZStack`. Do **not** blur the `SQColumnHeaderRow` — it sits outside this VStack and should remain sharp.

```
VStack {
    SQColumnHeaderRow(...)   ← unblurred, outside ZStack

    ZStack {
        VStack(spacing: ...) {  ← row list
            ForEach(activeRows) { ... }
        }
        .blur(radius: 6)        ← applied to row list only

        // Overlay on top
        lockedOverlayView
    }
}
```

**Overlay (`lockedOverlayView`):**
- Full-width, matches the height of the row `VStack` via `.frame(maxWidth: .infinity, maxHeight: .infinity)`
- Background: `.ultraThinMaterial`
- Content: `Text("Log in to unlock your stats")` using `SQFont` body style and `SQColor` primary text
- Entire overlay is a `Button` (or `.onTapGesture`) that calls `section.onLockedTap?()`
- The overlay sits on top of the row VStack in the ZStack, so it naturally blocks all touch events to the underlying blurred rows — do **not** add `.disabled(true)` or `.allowsHitTesting(false)` to the rows themselves; the ZStack layering is sufficient.

No changes to collapsed/expanded behavior — the section still collapses and expands normally when locked.

---

## Controller Wiring

`handleAuthButtonTap()` already exists in `SQDashboardController` and opens the profile/auth sheet. The `onLockedTap` closure on the subsection VM captures it weakly at build time — no new hub events or domain routes needed.

---

## Affected Files

| File | Change |
|------|--------|
| `SQDashboardSubsectionViewModel.swift` | Add `isLocked: Bool = false` and `onLockedTap: (() -> Void)?` |
| `SQDashboardController.swift` | In `buildMetricsSubsection`, gate on `userState.isLoggedIn`; set fake rows, `isLocked`, `onLockedTap`, hide dropdown. |
| `SQDashboardSectionView.swift` | Add locked overlay ZStack branch around the row VStack when `section.isLocked` |

---

## Out of Scope

- Unlock animation after login
- Locking other subsections
- A/B testing the CTA copy
