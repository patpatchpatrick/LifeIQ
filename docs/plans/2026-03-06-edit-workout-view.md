# Edit Workout View Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create `SQEditWorkoutView` — a metadata-editing form for existing workouts — and route `.editWorkout` navigation to it, while deprecating `SQWorkoutSessionView` and `SQExercisesListView` for future removal.

**Architecture:** `SQEditWorkoutController` owns all form state (title, notes, temperature, performance, difficulty) and auto-saves changes via debounced Combine subscriptions, mirroring the `SQWorkoutSummaryController` review-save pattern. `SQEditWorkoutView` renders the form using the same style as `reviewQuestionsSection` in `SQWorkoutSummaryView`. No new state class is needed — the controller holds everything directly.

**Tech Stack:** SwiftUI, SwiftData, Combine, BeastFitnessCore (SQLogger), existing UI components (SQUITextField, SQTextField, SQSegmentedControl, SQImageSymbol, SQColor, SQFont, SQUnit)

---

### Task 1: Deprecate SQWorkoutSessionView and SQExercisesListView

**Files:**
- Modify: `BeastFitness/Views/WorkoutsScreen/WorkoutSession/SQWorkoutSessionView.swift`
- Modify: `BeastFitness/Views/ExercisesList/SQExercisesListView.swift`
- Modify: `BeastFitness/Views/Root/SQRootTabView.swift` (temporary — keep `.editWorkout` pointing to deprecated view until Task 4)

**Step 1: Rename the struct in SQWorkoutSessionView.swift**

In `BeastFitness/Views/WorkoutsScreen/WorkoutSession/SQWorkoutSessionView.swift`, rename the struct from `SQWorkoutSessionView` to `SQDeprecatedWorkoutSessionView` and add the deprecation annotation directly above the struct declaration:

```swift
@available(*, deprecated, message: "Use SQEditWorkoutView instead. Kept for potential future reuse of exercise tracking logic.")
struct SQDeprecatedWorkoutSessionView: View {
```

Also rename the file on disk. The file should be renamed from `SQWorkoutSessionView.swift` to `SQDeprecatedWorkoutSessionView.swift`. You can just leave the filename as-is if Xcode doesn't require it — the struct name change is what matters for clarity. (Xcode projects use `.xcodeproj` references, not filesystem names, so a Swift file rename requires updating the project file. Skip the file rename — just rename the struct.)

**Step 2: Add deprecation annotation to SQExercisesListView**

In `BeastFitness/Views/ExercisesList/SQExercisesListView.swift`, add above the struct:

```swift
@available(*, deprecated, message: "Only used by SQDeprecatedWorkoutSessionView. Not used in active app flows.")
struct SQExercisesListView: View {
```

**Step 3: Fix the reference in SQRootTabView.swift**

`SQRootTabView.swift` line 27 references `SQWorkoutSessionView`. Update it to use the renamed struct:

```swift
case .editWorkout(workout: let workout):
    SQDeprecatedWorkoutSessionView(isBeingDisplayedWithinNavStack: true, controller: .build(for: workout))
```

This will compile with a deprecation warning, which is intentional. Task 4 will replace this with `SQEditWorkoutView`.

**Step 4: Commit**

```bash
git add BeastFitness/Views/WorkoutsScreen/WorkoutSession/SQWorkoutSessionView.swift
git add BeastFitness/Views/ExercisesList/SQExercisesListView.swift
git add BeastFitness/Views/Root/SQRootTabView.swift
git commit -m "deprecate: rename SQWorkoutSessionView to SQDeprecatedWorkoutSessionView, deprecate SQExercisesListView"
```

---

### Task 2: Create SQEditWorkoutController

**Files:**
- Create: `BeastFitness/ViewModels/Workouts/EditWorkout/SQEditWorkoutController.swift`

**Context:** Mirror the pattern from `SQWorkoutSummaryController`. Key references:
- `persistReviewDataIfNeeded()` at `BeastFitness/ViewModels/Workouts/WorkoutSummary/SQWorkoutSummaryController.swift:279`
- `setupReviewSaveSubscriptions()` at line 254
- `performanceSegments` / `difficultySegments` static constants at lines 76–90
- `SQWorkoutSession.setReviewData(...)` — used to persist notes/ratings/temperature
- `SQWorkoutManager.saveWorkout(workout:to:saveToCloud:)` — used to save changes
- `SQAppState.shared.modelContext` — used to get the SwiftData context
- `SQUnit.degreesFahrenheit` / `SQUnit.degreesCelsius` — for temperature conversion (store in Celsius, display in Fahrenheit)
- `SQWorkoutSession.titleMaxChars` — max title length constant

**Step 1: Create the file**

Create `BeastFitness/ViewModels/Workouts/EditWorkout/SQEditWorkoutController.swift`:

```swift
//
//  SQEditWorkoutController.swift
//  BeastFitness
//

import SwiftUI
import SwiftData
import Combine
import BeastFitnessCore

@Observable @MainActor
final class SQEditWorkoutController: Identifiable {
    let id = UUID().uuidString
    var dismissKeyboard: Bool = false

    // MARK: - Form ViewModels

    let titleViewModel: SQUITextFieldViewModel
    let notesViewModel: SQTextFieldViewModel = .init(
        axis: .vertical,
        lineLimit: 5,
        placeholder: "How'd it go? Any notes...",
        textAutoCap: .sentences,
        autoCorrectionEnabled: true
    )
    let temperatureViewModel: SQUITextFieldViewModel = SQUITextFieldViewModel(
        placeholder: "Temperature (e.g. 72)",
        font: SQFont(type: .body).uiFont,
        keyboardType: .decimalPad,
        autocapitalizationType: .none,
        autocorrectionType: .no,
        textChangeFormatter: .decimal(maxDecimalPlaces: 1)
    )
    var selectedPerformance: SQSegmentedControlSegment? = nil {
        didSet { persistIfNeeded() }
    }
    var selectedDifficulty: SQSegmentedControlSegment? = nil {
        didSet { persistIfNeeded() }
    }

    // MARK: - Segments

    static let performanceSegments: [SQSegmentedControlSegment] = [
        .init(id: "perf-1", title: "😞", ratingValue: 2),
        .init(id: "perf-2", title: "😐", ratingValue: 4),
        .init(id: "perf-3", title: "🙂", ratingValue: 6),
        .init(id: "perf-4", title: "😄", ratingValue: 8),
        .init(id: "perf-5", title: "🔥", ratingValue: 10),
    ]

    static let difficultySegments: [SQSegmentedControlSegment] = [
        .init(id: "diff-1", title: "😴", ratingValue: 2),
        .init(id: "diff-2", title: "🙂", ratingValue: 4),
        .init(id: "diff-3", title: "😤", ratingValue: 6),
        .init(id: "diff-4", title: "💪", ratingValue: 8),
        .init(id: "diff-5", title: "💀", ratingValue: 10),
    ]

    // MARK: - Private

    private let workout: SQWorkoutSessionable
    private let workoutManager: SQWorkoutManaging
    private var cancellables = Set<AnyCancellable>()
    private var isLoaded = false

    // MARK: - Init

    init(
        workout: SQWorkoutSessionable,
        workoutManager: SQWorkoutManaging = SQWorkoutManager.shared
    ) {
        self.workout = workout
        self.workoutManager = workoutManager
        self.titleViewModel = SQUITextFieldViewModel(
            placeholder: workout.visibleTitle,
            font: SQFont(type: .body).uiFont,
            autocapitalizationType: .sentences,
            autocorrectionType: .yes,
            textChangeFormatter: .maxLength(SQWorkoutSession.titleMaxChars)
        )
    }

    // MARK: - Lifecycle

    func onAppear() {
        guard !isLoaded else { return }
        isLoaded = true

        titleViewModel.setText(workout.visibleTitle)
        notesViewModel.initializeText(workout.reviewNotes ?? "")

        let fahrenheitDecimalPlaces = 0
        if let celsius = workout.temperatureCelsius,
           let fahrenheit = SQUnit.degreesCelsius.convert(celsius, to: .degreesFahrenheit) {
            temperatureViewModel.setText(fahrenheit.sqStringRoundedTo(places: fahrenheitDecimalPlaces))
        }

        selectedPerformance = workout.ratingUserPerformance.flatMap { rating in
            Self.performanceSegments.first { $0.ratingValue == rating }
        }
        selectedDifficulty = workout.ratingDifficulty.flatMap { rating in
            Self.difficultySegments.first { $0.ratingValue == rating }
        }

        setupSaveSubscriptions()
    }

    func dismiss() {
        SQAppState.shared.hub.domainEvents.send(.popDashboardRoute)
    }

    // MARK: - Save Subscriptions

    private func setupSaveSubscriptions() {
        titleViewModel.$text
            .dropFirst()
            .removeDuplicates()
            .debounce(for: .seconds(0.8), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.persistIfNeeded() }
            .store(in: &cancellables)

        notesViewModel.$text
            .dropFirst()
            .removeDuplicates()
            .debounce(for: .seconds(0.8), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.persistIfNeeded() }
            .store(in: &cancellables)

        temperatureViewModel.$text
            .dropFirst()
            .removeDuplicates()
            .debounce(for: .seconds(0.8), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.persistIfNeeded() }
            .store(in: &cancellables)
    }

    // MARK: - Persistence

    private func persistIfNeeded() {
        guard isLoaded,
              let modelContext = SQAppState.shared.modelContext else { return }

        let titleText = titleViewModel.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let temperatureFahrenheit = Double(temperatureViewModel.text.trimmingCharacters(in: .whitespacesAndNewlines))
        let temperatureCelsius = temperatureFahrenheit.flatMap {
            SQUnit.degreesFahrenheit.convert($0, to: .degreesCelsius)
        }

        workout.setReviewData(
            notes: notesViewModel.text.isEmpty ? nil : notesViewModel.text,
            ratingUserPerformance: selectedPerformance?.ratingValue,
            ratingDifficulty: selectedDifficulty?.ratingValue,
            temperature: temperatureCelsius
        )

        if let session = workout as? SQWorkoutSession {
            session.title = titleText.isEmpty ? nil : titleText
        }

        Task {
            do {
                try await workoutManager.saveWorkout(workout: workout, to: modelContext, saveToCloud: false)
                SQLogger.shared.log("Auto-saved edit workout data", .debug, context: .workoutSession)
            } catch {
                SQLogger.shared.log(
                    "Failed to auto-save edit workout: \(error.localizedDescription)",
                    .error,
                    context: .workoutSession
                )
            }
        }
    }
}
```

**Step 2: Commit**

```bash
git add BeastFitness/ViewModels/Workouts/EditWorkout/SQEditWorkoutController.swift
git commit -m "feat: add SQEditWorkoutController with auto-save for title/notes/temperature/ratings"
```

---

### Task 3: Create SQEditWorkoutView

**Files:**
- Create: `BeastFitness/Views/WorkoutsScreen/EditWorkout/SQEditWorkoutView.swift`

**Context:** Mirror `reviewQuestionsSection` layout from `SQWorkoutSummaryView.swift`. Key patterns to replicate:
- `questionTitle(title:)` helper for section labels
- `reviewRatingRow(title:segments:selection:scaleMin:scaleMax:)` for segmented controls
- `SQUITextField` for title and temperature, `SQTextField` for notes
- `.dismissKeyboardOnBackgroundTap()` on the scroll view
- `.onChange(of: controller.dismissKeyboard)` to programmatically hide keyboard
- `sqHideKeyboard()` function — already available in the project

**Step 1: Create the file**

Create `BeastFitness/Views/WorkoutsScreen/EditWorkout/SQEditWorkoutView.swift`:

```swift
//
//  SQEditWorkoutView.swift
//  BeastFitness
//

import SwiftUI

struct SQEditWorkoutView: View {
    @State var controller: SQEditWorkoutController

    // MARK: - Helpers

    @ViewBuilder
    func questionTitle(_ title: String) -> some View {
        Text(title)
            .sqFont(.body)
            .sqForegroundColor(.textSecondary)
            .padding(.bottom, .SQSpace.s)
    }

    @ViewBuilder
    func ratingRow(
        title: String,
        segments: [SQSegmentedControlSegment],
        selection: Binding<SQSegmentedControlSegment?>,
        scaleMin: String,
        scaleMax: String
    ) -> some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            questionTitle(title)

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

    // MARK: - Form

    @ViewBuilder
    var formContent: some View {
        let bindable = Bindable(controller)

        VStack(alignment: .leading, spacing: 0) {

            SQUITextField(viewModel: controller.titleViewModel)
                .padding(.bottom, .SQSpace.xxl)

            SQTextField(viewModel: controller.notesViewModel)
                .padding(.bottom, .SQSpace.xxl)

            HStack(spacing: .SQSpace.s) {
                SQUITextField(viewModel: controller.temperatureViewModel, width: 100)

                Text(SQUnit.degreesFahrenheit.unitString ?? "°F")
                    .sqFont(.body)
                    .sqForegroundColor(.textSecondary)

                Spacer()
            }
            .padding(.bottom, .SQSpace.xxl)

            ratingRow(
                title: "How did you perform?",
                segments: SQEditWorkoutController.performanceSegments,
                selection: bindable.selectedPerformance,
                scaleMin: "Very low",
                scaleMax: "Very high"
            )
            .padding(.bottom, .SQSpace.xxl)

            ratingRow(
                title: "How hard was it?",
                segments: SQEditWorkoutController.difficultySegments,
                selection: bindable.selectedDifficulty,
                scaleMin: "Easy",
                scaleMax: "Max effort"
            )
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            formContent
                .padding(.SQSpace.xxl)
        }
        .dismissKeyboardOnBackgroundTap()
        .sqBackgroundColor(.background)
        .navigationTitle("Edit Workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    controller.dismiss()
                } label: {
                    Image(systemName: SQImageSymbol.checkmark.rawValue)
                }
            }
        }
        .onAppear {
            controller.onAppear()
        }
        .onChange(of: controller.dismissKeyboard) {
            sqHideKeyboard()
        }
    }
}
```

**Step 2: Commit**

```bash
git add BeastFitness/Views/WorkoutsScreen/EditWorkout/SQEditWorkoutView.swift
git commit -m "feat: add SQEditWorkoutView with title/notes/temperature/performance/difficulty editing"
```

---

### Task 4: Wire SQEditWorkoutView into navigation

**Files:**
- Modify: `BeastFitness/Views/Root/SQRootTabView.swift:26-27`

**Step 1: Update the .editWorkout case**

In `SQRootTabView.swift`, find the `view(for route:)` function and update the `.editWorkout` case (currently at line 26–27) from:

```swift
case .editWorkout(workout: let workout):
    SQDeprecatedWorkoutSessionView(isBeingDisplayedWithinNavStack: true, controller: .build(for: workout))
```

To:

```swift
case .editWorkout(workout: let workout):
    SQEditWorkoutView(controller: .init(workout: workout))
```

The `SQEditWorkoutView` does not need `isBeingDisplayedWithinNavStack` since it always lives inside the nav stack (no `NavigationStack` wrapper in the view itself — it just uses `.navigationTitle` and `.toolbar` like `SQWorkoutSummaryView`).

**Step 2: Verify SQWorkoutSummaryController already sends .editWorkout**

Confirm `SQWorkoutSummaryController.pushEditWorkoutView()` at `BeastFitness/ViewModels/Workouts/WorkoutSummary/SQWorkoutSummaryController.swift:192` already sends `.pushDashboardRoute(.editWorkout(workout: baseWorkout))` — no changes needed there.

**Step 3: Commit**

```bash
git add BeastFitness/Views/Root/SQRootTabView.swift
git commit -m "feat: route .editWorkout navigation to SQEditWorkoutView"
```

---

### Task 5: Commit docs

```bash
git add docs/plans/2026-03-06-edit-workout-view.md
git commit -m "docs: add edit workout view implementation plan"
```
