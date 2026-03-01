# Workout Review UI Enhancement — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a motivating review header with mock insights, a notes field, and performance/difficulty ratings to the workout review sheet — all inside one unified scroll via `SQWorkoutSummaryView`.

**Architecture:** A new `SQWorkoutSummaryMode` enum (`.standard` / `.review`) is passed into `SQWorkoutSummaryController`. The controller holds all review state (highlights, ratings, notes). `SQWorkoutSummaryView` conditionally renders a review header section at the top of its existing `mainStack` scroll when the mode is `.review`. `SQWorkoutReviewView` simply passes `.review` at controller init.

**Tech Stack:** SwiftUI, `@Observable`, `SQSegmentedControl` (direct, no daily check-in VM coupling), `SQColor`, `SQFont`

---

### Task 1: Add `SQWorkoutSummaryMode` and `SQWorkoutReviewHighlight` to the controller file

**Files:**
- Modify: `BeastFitness/ViewModels/Workouts/WorkoutSummary/SQWorkoutSummaryController.swift`

**Step 1: Add the two new types at the top of the file, just before the `SQWorkoutSummaryInterface` protocol**

Insert this block after the imports and before line 15 (the `@MainActor protocol SQWorkoutSummaryInterface`):

```swift
enum SQWorkoutSummaryMode: Equatable {
    case standard
    case review
}

struct SQWorkoutReviewHighlight: Identifiable {
    let id = UUID()
    let text: String
    let sentiment: Sentiment

    enum Sentiment {
        case positive, neutral, negative
    }
}
```

**Step 2: Commit**

```bash
git add BeastFitness/ViewModels/Workouts/WorkoutSummary/SQWorkoutSummaryController.swift
git commit -m "feat: add SQWorkoutSummaryMode enum and SQWorkoutReviewHighlight model"
```

---

### Task 2: Update `SQWorkoutSummaryController` with review mode state

**Files:**
- Modify: `BeastFitness/ViewModels/Workouts/WorkoutSummary/SQWorkoutSummaryController.swift`

**Step 1: Add `mode` and review state properties to the class**

Add these stored properties to `SQWorkoutSummaryController`, immediately after the existing `let state: WorkoutSummaryStating` line:

```swift
let mode: SQWorkoutSummaryMode

// Review state — only populated when mode == .review
var selectedPerformance: SQSegmentedControlSegment? = nil
var selectedDifficulty: SQSegmentedControlSegment? = nil
var workoutNotes: String = ""
var reviewHighlights: [SQWorkoutReviewHighlight] = []

static let performanceSegments: [SQSegmentedControlSegment] = [
    .init(id: "1", title: "😞"),
    .init(id: "2", title: "😐"),
    .init(id: "3", title: "🙂"),
    .init(id: "4", title: "😄"),
    .init(id: "5", title: "🔥"),
]

static let difficultySegments: [SQSegmentedControlSegment] = [
    .init(id: "1", title: "😴"),
    .init(id: "2", title: "🙂"),
    .init(id: "3", title: "😤"),
    .init(id: "4", title: "💪"),
    .init(id: "5", title: "💀"),
]
```

**Step 2: Update `init` to accept `mode`**

The current `init` signature is:
```swift
init(workoutManager: SQWorkoutManaging = SQWorkoutManager.shared, healthKitManager: SQHealthKitManaging = SQHealthKitManager.shared, workout: SQWorkoutSessionable) {
```

Change it to (add `mode` after `workout`, defaulting to `.standard` so all existing call sites compile unchanged):
```swift
init(workoutManager: SQWorkoutManaging = SQWorkoutManager.shared, healthKitManager: SQHealthKitManaging = SQHealthKitManager.shared, workout: SQWorkoutSessionable, mode: SQWorkoutSummaryMode = .standard) {
```

Inside `init`, after `self.healthKitManager = healthKitManager`, add:
```swift
self.mode = mode
```

**Step 3: Populate mock highlights during `load`**

In the `private func load(workout:)` method, after `state.isLoading = false`, add:

```swift
if mode == .review {
    reviewHighlights = Self.mockHighlights()
}
```

**Step 4: Add the private mock highlights factory**

Add this as a private extension on `SQWorkoutSummaryController` at the bottom of the file (or in the existing extension block):

```swift
// MARK: - Review Highlights

extension SQWorkoutSummaryController {
    private static func mockHighlights() -> [SQWorkoutReviewHighlight] {
        [
            .init(text: "↑ VO2 Max went up 1%: 50.5 → 50.7", sentiment: .positive),
            .init(text: "You burned a standard amount of calories (~50th %ile)", sentiment: .neutral),
            .init(text: "Top 7% for distance — you crushed it!", sentiment: .positive),
        ]
    }
}
```

**Step 5: Commit**

```bash
git add BeastFitness/ViewModels/Workouts/WorkoutSummary/SQWorkoutSummaryController.swift
git commit -m "feat: add review mode state and mock highlights to SQWorkoutSummaryController"
```

---

### Task 3: Update `SQWorkoutReviewView` to pass `.review` mode

**Files:**
- Modify: `BeastFitness/Views/WorkoutReview/SQWorkoutReviewView.swift`

**Step 1: Update `workoutView` to pass `.review` and remove the custom nav title**

The current call to `SQWorkoutSummaryView` inside `workoutView(workout:)` is:
```swift
SQWorkoutSummaryView(
    controller: .init(workout: workout),
    customNavigationTitle: navigationTitle(for: workout),
    backgroundColor: .backgroundSheet
)
.navigationBarTitleDisplayMode(.inline)
```

Replace it with:
```swift
SQWorkoutSummaryView(
    controller: .init(workout: workout, mode: .review),
    backgroundColor: .backgroundSheet
)
.navigationBarTitleDisplayMode(.inline)
```

**Step 2: Remove the now-unused `navigationTitle(for:)` helper**

Delete the entire private helper method:
```swift
private func navigationTitle(for workout: SQWorkoutSessionable) -> String {
    let dateString = workout.startDate?.formattedString(with: .medium) ?? ""
    return "New Workout · \(dateString)"
}
```

**Step 3: Commit**

```bash
git add BeastFitness/Views/WorkoutReview/SQWorkoutReviewView.swift
git commit -m "feat: pass .review mode to SQWorkoutSummaryController from SQWorkoutReviewView"
```

---

### Task 4: Add the review header UI to `SQWorkoutSummaryView`

**Files:**
- Modify: `BeastFitness/Views/WorkoutSummary/SQWorkoutSummaryView.swift`

**Step 1: Suppress the nav bar title in review mode**

Find the `.navigationTitle(customNavigationTitle ?? "Workout summary")` modifier in `body` and replace it with:

```swift
.navigationTitle(controller.mode == .review ? "" : (customNavigationTitle ?? "Workout summary"))
```

**Step 2: Prepend the review header in `mainStack`**

At the very top of the `mainStack` `VStack`, before `userNameAndDateRow`, add:

```swift
if controller.mode == .review {
    reviewHeader
        .padding(.bottom, .SQSpace.xl)
}
```

**Step 3: Add the `reviewHeader` view builder**

Add this block as new `@ViewBuilder` properties on `SQWorkoutSummaryView`, before the `mainStack` property:

```swift
// MARK: - Review Header

@ViewBuilder
var reviewHeader: some View {
    VStack(alignment: .leading, spacing: .SQSpace.xl) {
        reviewTitleSection
        if !controller.reviewHighlights.isEmpty {
            reviewHighlightsSection
        }
        Divider()
        reviewQuestionsSection
        Divider()
    }
}

@ViewBuilder
var reviewTitleSection: some View {
    VStack(alignment: .leading, spacing: .SQSpace.xs) {
        Text("Nice workout! 💪")
            .sqFont(.title1)
            .sqForegroundColor(.textPrimary)

        if let title = controller.state.workoutTitle {
            Text(title)
                .sqFont(.bodySmall)
                .sqForegroundColor(.textSecondary)
        }
    }
}

@ViewBuilder
var reviewHighlightsSection: some View {
    VStack(alignment: .leading, spacing: .SQSpace.m) {
        ForEach(controller.reviewHighlights) { highlight in
            HStack(alignment: .top, spacing: .SQSpace.s) {
                Text("•")
                    .sqFont(.body)
                    .sqForegroundColor(highlightColor(for: highlight.sentiment))
                Text(highlight.text)
                    .sqFont(.body)
                    .sqForegroundColor(highlightColor(for: highlight.sentiment))
            }
        }
    }
}

private func highlightColor(for sentiment: SQWorkoutReviewHighlight.Sentiment) -> SQColor {
    switch sentiment {
    case .positive: return .colorGreenPct(percent: 1, base: .textPrimary)
    case .negative: return .textError
    case .neutral:  return .textPrimary
    }
}

@ViewBuilder
var reviewQuestionsSection: some View {
    let bindable = Bindable(controller)
    VStack(alignment: .leading, spacing: .SQSpace.xl) {
        Text("A couple quick questions to help track your progress")
            .sqFont(.bodySmall)
            .sqForegroundColor(.textSecondary)

        TextField("How'd it go? Any notes...", text: bindable.workoutNotes, axis: .vertical)
            .lineLimit(3...6)
            .sqFont(.body)
            .sqForegroundColor(.textPrimary)
            .padding(.SQSpace.m)
            .sqBackgroundColor(.backgroundSecondary)
            .cornerRadius(.SQCornerRadius.s)

        reviewRatingRow(
            title: "How did you perform?",
            segments: SQWorkoutSummaryController.performanceSegments,
            selection: bindable.selectedPerformance,
            scaleMin: "Very low",
            scaleMax: "Very high"
        )

        reviewRatingRow(
            title: "How hard was it?",
            segments: SQWorkoutSummaryController.difficultySegments,
            selection: bindable.selectedDifficulty,
            scaleMin: "Easy",
            scaleMax: "Max effort"
        )
    }
}

@ViewBuilder
func reviewRatingRow(
    title: String,
    segments: [SQSegmentedControlSegment],
    selection: Binding<SQSegmentedControlSegment?>,
    scaleMin: String,
    scaleMax: String
) -> some View {
    VStack(alignment: .leading, spacing: .SQSpace.m) {
        Text(title)
            .sqFont(.bodySmall)
            .sqForegroundColor(.textPrimary)

        SQSegmentedControl(segments: segments, selection: selection) { segment in
            Text(segment.title)
                .sqFont(.title3)
                .sqForegroundColor(.textPrimary)
        }

        HStack {
            Text(scaleMin)
                .sqFont(.bodySmall)
                .sqForegroundColor(.textSecondary)
            Spacer()
            Text(scaleMax)
                .sqFont(.bodySmall)
                .sqForegroundColor(.textSecondary)
        }
    }
}
```

**Step 4: Commit**

```bash
git add BeastFitness/Views/WorkoutSummary/SQWorkoutSummaryView.swift
git commit -m "feat: add workout review header UI with highlights, notes, and rating controls"
```

---

## Done

Build and run the app. Trigger the workout review flow (new unreviewed workout on the dashboard). You should see:
- "Nice workout! 💪" large title with the workout name below
- Three mock insight lines (two green, one neutral)
- A divider
- "A couple quick questions..." prompt with a multiline notes field
- "How did you perform?" with 😞😐🙂😄🔥 segments + scale labels
- "How hard was it?" with 😴🙂😤💪💀 segments + scale labels
- A second divider
- The existing workout summary content below (route, stats, performance)
- No nav bar title (empty string)
- The edit/delete toolbar menu still present
