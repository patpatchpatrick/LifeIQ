# Workout Temperature Feature — Design

**Date:** 2026-03-02

## Overview

Display temperature data on the workout review screen. For HealthKit workouts recorded on Apple Watch, auto-populate from `HKMetadataKeyWeatherTemperature`. If missing (non-HK workouts, or HK workouts without weather metadata), allow the user to enter it manually. The field is optional — users are never required to fill it in.

## Storage

Temperature is stored internally as **Celsius** (canonical unit), matching how HealthKit stores it. Display converts to the active display unit (Fahrenheit for now) at the presentation layer via `SQUnit`. When Celsius display is added in the future, only the display layer changes — nothing in the model or entity changes.

## Components Changed

### `SQUnit` + `SQUnitType`

Add two new cases and a new unit type:

- `SQUnit.degreesCelsius` — `unitString: "°C"`, `hkUnit: .degreeCelsius()`
- `SQUnit.degreesFahrenheit` — `unitString: "°F"`, `hkUnit: .degreeFahrenheit()`
- `SQUnitType.temperature`
- Conversion logic: `(celsius × 9/5) + 32` and `(fahrenheit − 32) × 5/9`

`SQUnit` is the standard tool for all unit handling across the app.

### `SQWorkoutSessionable` protocol

- Add `var temperatureCelsius: Double? { get }`
- Extend `setReviewData(...)` to include `temperature: Double?`
- Protocol extension provides `nil` default for all non-`SQWorkoutSession` sources

### `SQWorkoutSession`

- Add `var temperatureCelsius: Double?` as a stored review field alongside `reviewNotes`, `ratingUserPerformance`, `ratingDifficulty`
- Update `setReviewData(...)` to set this field

### `SQWorkoutSessionEntity`

- Add `var temperatureCelsius: Double?` (SwiftData column)
- Update `init(from:)`, `update(from:)`, and `toSession(workoutSource:)` to carry this field through

### `SQHealthKitManager`

- Add `weatherTemperatureCelsius(from: HKWorkout) -> Double?`
- Reads `hkWorkout.metadata?[HKMetadataKeyWeatherTemperature]` as `HKQuantity`
- Returns `quantity.doubleValue(for: .degreeCelsius())`

### `SQWorkoutSummaryController`

- Add `let temperatureViewModel: SQUITextFieldViewModel` — numeric keyboard, placeholder `"e.g. 72"`, `textChangeFormatter: .decimal`
- On load in review mode:
  1. If workout has a stored `temperatureCelsius`, convert to °F and pre-populate the field
  2. Else if it's an HK workout, try `weatherTemperatureCelsius(from:)` and pre-populate if found
  3. Else leave blank
- Wire up debounced save subscription (0.8s, same pattern as `titleViewModel`)
- In `persistReviewDataIfNeeded()`: parse the field value, convert °F → °C via `SQUnit`, pass into `setReviewData(...)`

### `SQWorkoutSummaryView`

- Add temperature field to `reviewQuestionsSection`, below the notes field and above the segmented controls
- Layout: label `"Temperature"` + `SQUITextField` + `"°F"` suffix in an `HStack`

## Unit Conversion Flow

```
HealthKit read  →  HKQuantity.doubleValue(.degreeCelsius())  →  store as temperatureCelsius
User input (°F) →  SQUnit.degreesFahrenheit.convert(to: .degreesCelsius)  →  store as temperatureCelsius
Display         →  SQUnit.degreesCelsius.convert(to: .degreesFahrenheit)  →  show in text field
```

## Future Celsius Support

To add Celsius display: check user preference in the controller and swap `.degreesFahrenheit` for `.degreesCelsius` in all display/input conversions. The entity and model layer require zero changes.
