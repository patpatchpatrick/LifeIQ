# Workout Review UI Enhancement — Design

**Date:** 2026-03-01

## Overview

Enhance `SQWorkoutReviewView` / `SQWorkoutSummaryView` to show a rich review experience when a new workout is first reviewed. Instead of jumping straight into the raw workout data, the user sees a motivating header, quick insights, a notes field, and performance/difficulty ratings — then the full workout summary below in one unified scroll.

## Architecture

### Mode Enum

```swift
enum SQWorkoutSummaryMode {
    case standard
    case review
}
```

Added to `BeastFitness` target (alongside the controller).

### `SQWorkoutSummaryController` changes

- Add `mode: SQWorkoutSummaryMode` parameter to `init` (defaults to `.standard` — all existing call sites unaffected)
- Add stored review state properties:
  - `selectedPerformance: SQSegmentedControlSegment?`
  - `selectedDifficulty: SQSegmentedControlSegment?`
  - `workoutNotes: String`
  - `reviewHighlights: [SQWorkoutReviewHighlight]` — populated with mock data for now
- Mock highlights are computed once during `load()` when `mode == .review`

### `SQWorkoutReviewView` changes

- Pass `mode: .review` when constructing `SQWorkoutSummaryController`
- Remove `customNavigationTitle` — review mode suppresses the nav bar title in favor of the in-body heading

### Data persistence

Out of scope for this pass. Ratings and notes are held in-memory on the controller only.

## Highlight Data Model

```swift
struct SQWorkoutReviewHighlight: Identifiable {
    let id = UUID()
    let text: String
    let sentiment: Sentiment

    enum Sentiment { case positive, neutral, negative }
}
```

- `.positive` → green (`SQColor.textSuccess` or equivalent)
- `.negative` → red (`SQColor.textError` or equivalent)
- `.neutral` → `SQColor.textPrimary`

## View Layout (Review Mode)

When `mode == .review`, `SQWorkoutSummaryView.mainStack` prepends the following before the existing content:

```
"Nice workout! 💪"               sqFont .title1, textPrimary
[activity type name]             sqFont .bodySmall, textSecondary

── Highlights ───────────────────
• ↑ VO2 Max went up 1%: 50.5 → 50.7        green
• You burned a standard amount (~50th %)    textPrimary
• Top 7% for distance — you crushed it!    green

── Questions ────────────────────
"A couple quick questions to help track your progress"   sqFont .bodySmall, textSecondary

[Multiline text editor]  placeholder: "How'd it go? Any notes..."

"How did you perform?"           sqFont .bodySmall, textPrimary
[😞][😐][🙂][😄][🔥]            SQSegmentedControl
  Very low ——————————— Very high

"How hard was it?"               sqFont .bodySmall, textPrimary
[😴][🙂][😤][💪][💀]            SQSegmentedControl
  Easy ————————————— Max effort

Divider

[existing summary content: route map, stats, performance sections]
```

## Nav Title in Review Mode

- `navigationTitle("")` with `.navigationBarTitleDisplayMode(.inline)`
- Keeps the toolbar (edit/delete menu) visible but hides the title text
- The in-body "Nice workout!" heading serves as the page title

## Rating Controls

Use `SQSegmentedControl` directly — no `SQDailyCheckInSegmentedControl` / `SQDailyCheckInRowSegmentedControlViewModel` to avoid domain coupling. State binds directly to controller stored properties.

**Performance segments:** 😞 😐 🙂 😄 🔥 (ids: "1"–"5")
**Difficulty segments:** 😴 🙂 😤 💪 💀 (ids: "1"–"5")

Scale labels:
- Performance: "Very low" → "Very high"
- Difficulty: "Easy" → "Max effort"
