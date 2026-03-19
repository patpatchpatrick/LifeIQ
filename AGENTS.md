# AGENTS.md (BeastFitness)

This file translates the existing `CLAUDE.md` guidance into a Codex-friendly operating guide for this repository.

## Repo and project context

- This repository contains two apps:
  - `BeastFitness` (iOS app, primary UI/product focus)
  - `Beast Fitness Watch Watch App` (watchOS app)
- Workout-related flows are cross-app. Keep iOS/watch payloads and state in sync when changing workout behavior.

## External reference project

- `SportsPulse` at `/Users/patrickdoyle/Code/mapps/SportsPulse` is read-only reference material.
- Do not edit SportsPulse unless explicitly asked.

## Current product focus

- Build a strong iOS dashboard that surfaces:
  - HealthKit stats and trends
  - Workout history and summaries
  - Self-tracked daily habits/stats (mood, alcohol, energy, etc.)
- Product goal: clear actionable insights, understandable trends, polished UI hierarchy.

## Daily Check-In metric groups

- `SQMetricDefinition.group` is dynamic, user-facing, and user-creatable.
- Defaults in `SQDefaultGroup` (`BeastFitness/Models/DailyCheckIn/SQMetric.swift`):
  - `.personal` -> `Self`
  - `.habit` -> `Habit`
  - `.general` -> `General`
- Dashboard behavior:
  - One collapsible section per group
  - Group order based on first metric `sortOrder` in that group
  - Metric form supports selecting existing group or entering a new one

## Shared modules and reuse

- Shared/reusable code belongs in `BeastFitnessCore` where possible.
- All charting should use the local package `CoolCharts`.

## Time range conventions

- Always use `SQTimeRange` date boundaries (e.g. `.today`, `.pastWeek`, `.pastYear`).
- Do not manually compute date ranges when `SQTimeRange` can be used.

## App state architecture

- App state is centralized in `SQAppState.shared`.
- New feature state pattern:
  1. Define a `@MainActor` protocol for state interface
  2. Implement with `@Observable` state class that receives `hub`
  3. Register in `SQAppState`
  4. Access via `SQAppState.shared`
- Prefer event-driven updates via `hub`.

## Routing and alerts

- Use `hub.domainEvents.send(.pushDashboardRoute(...))` for dashboard sheet routes and handle them in `SQRootTabView`.
- For user-facing errors, use `hub.alertEvents` with `SQAlertViewModel`, typically `hub.alertEvents.send(.present(.init(error as? SQUserFacingError ?? SQError.standard)))`.

## Date formatting

- Always use `SQDateFormatters` (or Date extension helpers).
- Never create ad-hoc `DateFormatter` instances in feature code.

## Logging

- Always use `SQLogger`:
  - iOS: `log(...)`
  - watchOS: `logW(...)`
- Use appropriate contexts (e.g. `.dashboard`, `.dailyCheckIn`, `.workoutSession`, `.healthKit`).
- Use `isPriority: true` for important milestones.

## Networking and Firestore

- Use route/service architecture:
  - `SQFirestoreRoute`
  - `SQNetworkService`
  - Domain services (example: `SQDailyCheckInService`)
- Use incremental sync with `afterDate` where applicable.

### Firestore metrics tracking (required)

- Track all reads/writes using `SQFirestoreMetricsManager` for cost visibility.
- Add tracking on any new direct Firestore operations.
- Standard query/collection decode paths are already tracked in network layer helpers.

## UI conventions (strict)

- Colors: use `SQColor` + `.sqForegroundColor()` / `.sqBackgroundColor()`.
- Fonts: use `SQFont` + `.sqFont()`.
- Text inputs:
  - Default to `SQUITextField` (UIKit-backed single-line)
  - Use `SQTextField` for multiline fallback
- Auth screens: use `SQUITextFieldViewModel` + `SQUITextField` for email/password with validation + error handlers, and disable the screen while auth is in progress.
- SF Symbols:
  - Use `SQImageSymbol` enum (no hardcoded `Image(systemName:)` strings)
  - Add new symbols to `BeastFitness/UI/SQImage.swift` before use
  - Prefer `SQImageView(image: .init(symbol: ...))`
- Reuse shared UI components for common patterns (e.g. `SQCollapsibleSectionHeader`).

## Dashboard composition conventions

- Use a two-level hierarchy:
  - Section group: `SQDashboardSectionGroupViewModel`
  - Subsection card: `SQDashboardSubsectionViewModel`
- Keep group composition logic centralized in `SQDashboardController.buildSectionGroups(...)`.
- Prefer extending existing row infrastructure (for example `SQDashboardMetricStatsRowViewModel`) before introducing custom row types.

Current intended dashboard structure:
- `Daily Stats`: `Metrics`, `Performance`
- `Sleep`: `Sleep Score`, `Sleep Summary`, `Sleep Phases`
- `Workouts`: `Totals`, `Activities`

Sleep-specific range semantics:
- Use completed nights only, anchored to the latest completed wake day.
- `Today` => last completed night.
- `Past 7/30/Year` => rolling completed-night windows ending with last night.
- Sleep phase metric rows show average duration for the selected window.
- Sleep phase timeline row should show the latest completed night.

Charts convention:
- Reusable timeline/interval charts should live in `CoolCharts` as generic components (for example `TimelineChartView`) so they can be reused by Sleep and future Heart Rate surfaces.

## Workout source architecture

- Supported sources are unified by `SQWorkoutSourceable`:
  - `SQHKWorkout` (most complete)
  - `SQManualWorkout`
  - `SQStravaWorkout` (in progress)
- `SQWorkoutSource` wraps sources and exposes source metadata/helpers.
- Implementation guidance for new capabilities:
  1. Add to protocol when source-agnostic behavior is needed
  2. Implement in `SQHKWorkout` first
  3. Return `nil` for unsupported sources
  4. Keep source-specific logic isolated

## Units

- Always use `SQUnit` and `SQUnitType` for conversions and labels.
- Never add ad-hoc conversion formulas or unit strings in feature code.
- Store canonical units in persistence; convert for display in presentation layer.

## Coding style

- Prefer stored properties over computed properties when values can be cached and updated via dependency changes.
- Never force unwrap (`!`); use safe optional handling.

## Workflow preferences in this repo

- Do not run Xcode builds during implementation unless explicitly requested.
- Do not invoke code-review subagents/skills unless explicitly requested.
- Optimize for direct iteration speed; user handles final build/review.

## Practical execution checklist

When implementing changes, default to this checklist:

1. Confirm whether change affects iOS-only or iOS + watchOS sync behavior.
2. Use existing app state/event architecture rather than introducing parallel patterns.
3. Use required wrappers (`SQColor`, `SQFont`, `SQUITextField`/`SQTextField`, `SQImageSymbol`).
4. Use `SQTimeRange` and `SQDateFormatters` for date handling.
5. Route Firestore operations through existing route/service layer and track metrics.
6. Use `SQLogger` with proper context and priority where useful.
7. Keep shared logic in `BeastFitnessCore` and charts in `CoolCharts`.

## Source of truth

- `CLAUDE.md` remains intact as the original human-authored guide.
- This `AGENTS.md` is the Codex-optimized companion document for day-to-day implementation behavior.
