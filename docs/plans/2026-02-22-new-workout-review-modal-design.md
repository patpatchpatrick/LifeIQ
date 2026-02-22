# New Workout Review Modal — Design

**Date:** 2026-02-22
**Status:** Approved

## Overview

When the app is opened, any HealthKit workouts completed in the past 14 days that the user hasn't yet reviewed are surfaced in a dismissible overlay modal. The user can view a workout summary, optionally edit the workout, and step through a queue of unreviewed workouts one at a time. Alerts can still appear on top of this modal.

---

## Architecture & Components

### New files

- **`SQNewWorkoutReviewState`** — Queue-based `@Observable` state class added to `SQAppState`. Subscribes to `WorkoutReviewReadyEvent` on the `EventHub`. Owns the queue of unprocessed workouts, exposes `isPresented`, and handles mark-as-processed + queue advancement.
- **`SQNewWorkoutReviewHost`** — Overlay view registered at the root alongside `SQAlertHost`. Renders dark scrim + modal panel at `zIndex(5000)` (below alerts at `10000`). Contains a `NavigationStack` wrapping `SQWorkoutSummaryView`.
- **`SQNewWorkoutReviewController`** — Per-session controller. Wraps `SQWorkoutSummaryController` and wires the "Done / Review Next / Skip Remaining" bottom action area into `SQNewWorkoutReviewState`.

### Modified files

- **`SQWorkoutSessionEntity`** — Add `processedAt: Date?` field.
- **`SQWorkoutManager`** — Add `markWorkoutsAsProcessed(_ workouts: [SQWorkoutSession])` helper.
- **`SQDashboardController`** — After workout fetch: auto-mark old workouts as processed, filter for reviewable workouts, emit `WorkoutReviewReadyEvent` if any found.
- **`SQAppState`** — Add `newWorkoutReviewState: SQNewWorkoutReviewState`.
- **Root view** — Register `SQNewWorkoutReviewHost` alongside `SQAlertHost`.
- **App startup** — Write `appInstallDate` to `UserDefaults` on first launch (key: `"appInstallDate"`).

---

## Data Model

### `SQWorkoutSessionEntity` — new field

```swift
var processedAt: Date?
```

A workout is **reviewable** if ALL conditions are true:
1. `processedAt == nil`
2. `startDate >= appInstallDate` (prevents surfacing workouts that predate the install)
3. `startDate >= now - 14 days`

### `appInstallDate` — UserDefaults

Written once on first launch. No SwiftData needed — it's a single global timestamp.

```swift
// On first launch:
if UserDefaults.standard.object(forKey: "appInstallDate") == nil {
    UserDefaults.standard.set(Date(), forKey: "appInstallDate")
}
```

---

## App Launch Flow

1. App opens → `SQDashboardController` fetches workouts as it already does.
2. After fetch, the dashboard controller runs a processing step:
   - **Auto-mark stale:** any fetched workouts with `processedAt == nil` and `startDate < now - 14 days` are marked processed immediately (keeps the entity table clean).
   - **Filter reviewable:** workouts with `processedAt == nil` AND `startDate >= appInstallDate` AND within past 14 days.
   - If any reviewable workouts found → emit `WorkoutReviewReadyEvent(workouts: sorted)` on `EventHub` (sorted most-recent first by `startDate`).
3. `SQNewWorkoutReviewState` receives the event → populates `queue` → sets `isPresented = true`.
4. `SQNewWorkoutReviewHost` renders the overlay.

**No duplicate fetches.** The dashboard's existing fetch does double duty. Future caching improvements to `SQWorkoutManager` automatically benefit both systems.

---

## Modal UI/UX

### Presentation
- Dark scrim overlay
- Modal panel: ~90–95% of screen height, rounded top corners
- Appears and disappears with scale + opacity animation (same as `SQAlertHost`)

### Navigation
- `NavigationStack` inside the panel, root is `SQWorkoutSummaryView`
- Edit button in summary toolbar → pushes `SQWorkoutSessionView` within the same stack
- Back from edit → returns to summary

### Nav title
`"New Workout · [date]"` using medium date format
Example: `"New Workout · Feb 22, 2026"`

### Bottom action area (fixed, outside scroll)

| Queue size | Buttons |
|---|---|
| 1 workout | "Done" |
| 2+ workouts (not last) | "Review Next Workout" (primary) + "Skip Remaining" (secondary) |
| Last workout in multi-workout queue | "Done" |

**Button behavior:**
- **"Done"** — marks current as `processedAt = now`, dismisses modal
- **"Review Next Workout"** — marks current as processed, advances to next workout in queue
- **"Skip Remaining"** — marks ALL remaining workouts as processed, dismisses modal

---

## Z-Index Layering

| Layer | Z-Index |
|---|---|
| App content | 0 |
| `SQNewWorkoutReviewHost` | 5000 |
| `SQAlertHost` | 10000 |

Alerts fire on top of the review modal without any changes to the alert system.
