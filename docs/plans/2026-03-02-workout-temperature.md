# Workout Temperature Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Display workout temperature on the review screen, auto-populated from HealthKit metadata when available, with a manual text field fallback.

**Architecture:** Temperature is stored internally as Celsius (canonical unit) and converted to °F at the display layer via `SQUnit`. HealthKit workouts recorded on Apple Watch may carry `HKMetadataKeyWeatherTemperature` — we read this on load and pre-populate the field. The text field follows the same debounced-save pattern already used for title and notes.

**Tech Stack:** SwiftUI, SwiftData, HealthKit, `SQUnit` (unit conversion), `SQUITextField` (single-line numeric input), `SQWorkoutSessionEntity` (persistence)

---

### Task 1: Add temperature unit cases to `SQUnit`

**Files:**
- Modify: `BeastFitness/Models/Workouts/Workout Session/Metrics/SQUnit.swift`

**Step 1: Add `.temperature` to `SQUnitType`**

In `SQUnitType`, add:
```swift
case temperature
```

**Step 2: Add `.degreesCelsius` and `.degreesFahrenheit` to `SQUnit`**

Add the two cases to the enum declaration:
```swift
case degreesCelsius
case degreesFahrenheit
```

**Step 3: Add temperature conversion to `convert(_:from:to:)`**

In the `switch fromUnit` block, add before `case .unknown`:
```swift
case .degreesCelsius:
    switch toUnit {
    case .degreesFahrenheit:
        return value * 9.0 / 5.0 + 32.0
    default:
        return value
    }
case .degreesFahrenheit:
    switch toUnit {
    case .degreesCelsius:
        return (value - 32.0) * 5.0 / 9.0
    default:
        return value
    }
```

**Step 4: Add `.temperature` to `unitType`**

In the `unitType` computed property, add before `case .unknown`:
```swift
case .degreesCelsius, .degreesFahrenheit:
    return .temperature
```

**Step 5: Add `hkUnit` mappings**

In the `hkUnit` computed property, add before `case .unknown`:
```swift
case .degreesCelsius:
    .degreeCelsius()
case .degreesFahrenheit:
    .degreeFahrenheit()
```

**Step 6: Add `unitString` mappings**

In the `unitString` computed property, update the existing switch to handle the new cases. Replace the current `switch` with explicit cases (add before `case .unknown`):
```swift
case .degreesCelsius:
    return "°C"
case .degreesFahrenheit:
    return "°F"
```

**Step 7: Commit**
```bash
git add BeastFitness/Models/Workouts/Workout\ Session/Metrics/SQUnit.swift
git commit -m "feat: add degreesCelsius and degreesFahrenheit to SQUnit"
```

---

### Task 2: Add `temperatureCelsius` to the workout session model

**Files:**
- Modify: `BeastFitness/Models/Workouts/Workout Session/SQWorkoutSession.swift`

**Step 1: Add `temperatureCelsius` to the protocol**

In `SQWorkoutSessionable`, add below `ratingDifficulty`:
```swift
var temperatureCelsius: Double? { get }
```

Update `setReviewData` signature to include temperature:
```swift
func setReviewData(notes: String?, ratingUserPerformance: Float?, ratingDifficulty: Float?, temperature: Double?)
```

**Step 2: Update the protocol extension default implementations**

In the `extension SQWorkoutSessionable` at the bottom of the file, add:
```swift
var temperatureCelsius: Double? { nil }
```

Update the default no-op `setReviewData` signature to match:
```swift
func setReviewData(notes: String?, ratingUserPerformance: Float?, ratingDifficulty: Float?, temperature: Double?) {}
```

**Step 3: Add the stored property and update `setReviewData` on `SQWorkoutSession`**

In `SQWorkoutSession`, add below `var ratingDifficulty: Float?`:
```swift
var temperatureCelsius: Double?
```

Replace the existing `setReviewData` implementation with:
```swift
func setReviewData(notes: String?, ratingUserPerformance: Float?, ratingDifficulty: Float?, temperature: Double?) {
    self.reviewNotes = notes
    self.ratingUserPerformance = ratingUserPerformance
    self.ratingDifficulty = ratingDifficulty
    self.temperatureCelsius = temperature
}
```

**Step 4: Commit**
```bash
git add BeastFitness/Models/Workouts/Workout\ Session/SQWorkoutSession.swift
git commit -m "feat: add temperatureCelsius to SQWorkoutSessionable and SQWorkoutSession"
```

---

### Task 3: Persist `temperatureCelsius` in `SQWorkoutSessionEntity`

**Files:**
- Modify: `BeastFitness/Models/Workouts/Workout Session/Entities/SQWorkoutSessionEntity.swift`

**Step 1: Add the SwiftData column**

In `SQWorkoutSessionEntity`, add below `var ratingDifficulty: Float?`:
```swift
var temperatureCelsius: Double?
```

**Step 2: Update `init(from:)`**

Below `self.ratingDifficulty = session.ratingDifficulty`, add:
```swift
self.temperatureCelsius = session.temperatureCelsius
```

**Step 3: Update `update(from:)`**

Below `ratingDifficulty = session.ratingDifficulty`, add:
```swift
temperatureCelsius = session.temperatureCelsius
```

**Step 4: Update `toSession(workoutSource:)`**

The `toSession` method calls `session.setReviewData(...)`. Update that call to pass temperature:
```swift
session.setReviewData(
    notes: reviewNotes,
    ratingUserPerformance: ratingUserPerformance,
    ratingDifficulty: ratingDifficulty,
    temperature: temperatureCelsius
)
```

**Step 5: Commit**
```bash
git add BeastFitness/Models/Workouts/Workout\ Session/Entities/SQWorkoutSessionEntity.swift
git commit -m "feat: persist temperatureCelsius in SQWorkoutSessionEntity"
```

---

### Task 4: Read weather temperature from HealthKit metadata

**Files:**
- Modify: `BeastFitness/Utility/ThirdParty/SQHealthKitManager.swift`

**Step 1: Add to the protocol**

In `SQHealthKitManaging`, add below `fetchRouteLocations(for:)`:
```swift
/// Reads the weather temperature (in °C) recorded by Apple Watch during a workout.
/// Returns nil if the workout has no weather metadata.
func weatherTemperatureCelsius(from workout: HKWorkout) -> Double?
```

**Step 2: Add the implementation**

In `SQHealthKitManager`, add a new method (alongside the other fetch methods):
```swift
func weatherTemperatureCelsius(from workout: HKWorkout) -> Double? {
    guard let quantity = workout.metadata?[HKMetadataKeyWeatherTemperature] as? HKQuantity else {
        return nil
    }
    return quantity.doubleValue(for: .degreeCelsius())
}
```

**Step 3: Commit**
```bash
git add BeastFitness/Utility/ThirdParty/SQHealthKitManager.swift
git commit -m "feat: add weatherTemperatureCelsius(from:) to SQHealthKitManager"
```

---

### Task 5: Wire temperature into `SQWorkoutSummaryController`

**Files:**
- Modify: `BeastFitness/ViewModels/Workouts/WorkoutSummary/SQWorkoutSummaryController.swift`

**Step 1: Add the text field view model**

In `SQWorkoutSummaryController`, add alongside `titleViewModel` and `notesViewModel`:
```swift
let temperatureViewModel: SQUITextFieldViewModel = SQUITextFieldViewModel(
    placeholder: "e.g. 72",
    font: SQFont(type: .body).uiFont,
    keyboardType: .decimalPad,
    autocapitalizationType: .none,
    autocorrectionType: .no,
    textChangeFormatter: .decimal(maxDecimalPlaces: 1)
)
```

**Step 2: Pre-populate on load**

In the `load(workout:)` method, inside the `if mode == .review` block, add after the `notesViewModel.initializeText(...)` call:

```swift
// Temperature: prefer stored value, then try HealthKit metadata
if let stored = workout.temperatureCelsius,
   let fahrenheit = SQUnit.degreesCelsius.convert(stored, to: .degreesFahrenheit) {
    temperatureViewModel.setText(String(format: "%g", fahrenheit))
} else if case .hkWorkout(let hk) = workout.workoutSource,
          let celsius = healthKitManager.weatherTemperatureCelsius(from: hk.hkWorkout),
          let fahrenheit = SQUnit.degreesCelsius.convert(celsius, to: .degreesFahrenheit) {
    temperatureViewModel.setText(String(format: "%g", fahrenheit))
}
```

**Step 3: Wire up the debounced save subscription**

In `setupReviewSaveSubscriptions()`, add alongside the title and notes subscriptions:
```swift
temperatureViewModel.$text
    .dropFirst()
    .removeDuplicates()
    .debounce(for: .seconds(0.8), scheduler: RunLoop.main)
    .sink { [weak self] _ in self?.persistReviewDataIfNeeded() }
    .store(in: &cancellables)
```

**Step 4: Include temperature in `persistReviewDataIfNeeded()`**

In `persistReviewDataIfNeeded()`, compute the Celsius value before calling `setReviewData`:
```swift
let temperatureFahrenheit = Double(temperatureViewModel.text.trimmingCharacters(in: .whitespacesAndNewlines))
let temperatureCelsius = temperatureFahrenheit.flatMap {
    SQUnit.degreesFahrenheit.convert($0, to: .degreesCelsius)
}
```

Then update the `setReviewData(...)` call to include it:
```swift
workout.setReviewData(
    notes: notesViewModel.text.isEmpty ? nil : notesViewModel.text,
    ratingUserPerformance: selectedPerformance?.ratingValue,
    ratingDifficulty: selectedDifficulty?.ratingValue,
    temperature: temperatureCelsius
)
```

**Step 5: Commit**
```bash
git add BeastFitness/ViewModels/Workouts/WorkoutSummary/SQWorkoutSummaryController.swift
git commit -m "feat: add temperature text field to workout review controller"
```

---

### Task 6: Add temperature field to the review UI

**Files:**
- Modify: `BeastFitness/Views/WorkoutSummary/SQWorkoutSummaryView.swift`

**Step 1: Add the temperature row below the notes field**

In `reviewQuestionsSection`, add after `SQTextField(viewModel: controller.notesViewModel)` and before the `reviewRatingRow(title: "How did you perform?", ...)` call:

```swift
VStack(alignment: .leading, spacing: .SQSpace.s) {
    Text("Temperature")
        .sqFont(.bodySmall)
        .sqForegroundColor(.textPrimary)
    HStack(spacing: .SQSpace.s) {
        SQUITextField(viewModel: controller.temperatureViewModel)
        Text(SQUnit.degreesFahrenheit.unitString ?? "°F")
            .sqFont(.body)
            .sqForegroundColor(.textSecondary)
    }
}
```

**Step 2: Commit**
```bash
git add BeastFitness/Views/WorkoutSummary/SQWorkoutSummaryView.swift
git commit -m "feat: add temperature input field to workout review UI"
```

---

## Completion Checklist

- [ ] `SQUnit` has `.degreesCelsius`, `.degreesFahrenheit`, `.temperature` unit type, correct conversion, `hkUnit`, `unitString`
- [ ] `SQWorkoutSessionable` protocol has `temperatureCelsius` and updated `setReviewData` signature
- [ ] `SQWorkoutSession` stores and sets `temperatureCelsius`
- [ ] `SQWorkoutSessionEntity` persists `temperatureCelsius` and round-trips through `toSession`
- [ ] `SQHealthKitManager` protocol + implementation has `weatherTemperatureCelsius(from:)`
- [ ] Controller pre-populates from stored value or HealthKit metadata, debounce-saves on change
- [ ] UI shows labeled field with `°F` suffix in review questions section
