# AGENTS.md (LifeIQ / BeastFitness Repo)

This file translates the existing `CLAUDE.md` guidance into a Codex-friendly operating guide for this repository.

## Brand direction

- Product-facing app name is now `LifeIQ`.
- The brand mascot is a glowing orb.
- Prefer `LifeIQ` in user-facing copy, product discussion, and UI concepts.
- Internal code identifiers, module names, bundle ids, and target names may still use `BeastFitness` until an explicit technical rename is requested.

## Repo and project context

- This repository contains two apps:
  - `LifeIQ` (iOS app, primary UI/product focus; current target/repo naming still uses `BeastFitness`)
  - `LifeIQ Watch` (watchOS app; current target naming still uses `Beast Fitness Watch Watch App`)
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

## Onboarding/Profile Editing

- `SQOnboardingView` is the shared editor for both first-run onboarding and later profile-stat editing from Settings.
- Keep the editable fields in `SQOnboardingView`, `SQOnboardingController`, and the Settings entry point in sync. Do not create a separate profile-stats form that can drift from onboarding.
- If onboarding fields change, ensure the Settings-launched edit flow exposes the same fields and save behavior.

## Date formatting

- Always use `SQDateFormatters` (or Date extension helpers).
- Never create ad-hoc `DateFormatter` instances in feature code.

## Logging

- Always use `SQLogger`:
  - iOS: `log(...)`
  - watchOS: `logW(...)`
- Use appropriate contexts (e.g. `.dashboard`, `.dailyCheckIn`, `.workoutSession`, `.healthKit`).
- Use `isPriority: true` for important milestones.

## Analytics

- Treat Amplitude instrumentation as part of implementation review for any relevant product or flow change.
- When modifying an existing tracked flow, update the related Amplitude events/properties if the behavior or semantics changed.
- When adding a new feature or surface that seems worth tracking in Amplitude, confirm with Patrick before adding new analytics events.
- Do not silently skip analytics review on user-facing feature work; make an explicit call whether existing tracking should change, stay as-is, or a new event is worth proposing.

## Networking and Firestore

- Use route/service architecture:
  - `SQFirestoreRoute`
  - `SQNetworkService`
  - Domain services (example: `SQDailyCheckInService`)
- Use incremental sync with `afterDate` where applicable.

### Remote Config runtime controls

- `SQRemoteConfigManager` is the client control plane for runtime app behavior.
- Current critical keys include:
  - `app_disabled`
  - `app_disabled_message`
  - `min_supported_build`
  - `force_update_message`
  - `writes_disabled`
  - `writes_disabled_message`
  - `signup_disabled`
  - `signup_disabled_message`
- `min_supported_build` compares against `CFBundleVersion` (build number), not `CFBundleShortVersionString`.
- Use Remote Config for client messaging and gating UX. Do not use it as the backend enforcement layer for Firestore security.
- When changing any write flow, signup flow, or app-wide access behavior, review whether these runtime controls should affect the new code path.
- Prefer shared gating points for Remote Config-sensitive behavior:
  - shared Firestore write layer for server-write shutdowns
  - auth entry points for signup shutdowns
  - dashboard/root surfaces for user-facing status messaging
- If a new feature has a meaningful degraded/read-only/maintenance mode, account for Remote Config during implementation rather than treating it as a later patch.

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
- Dashboard layout customization clones section/subsection view models before applying order/visibility. Keep cloning centralized on the view models themselves (`cloned()` / copy API) rather than reconstructing them field-by-field in services, so new properties cannot be silently dropped.

Current intended dashboard structure:
- `Daily Stats`: `Metrics`, `Performance`
- `Sleep`: `Sleep Score`, `Sleep Summary`, `Sleep Phases`
- `Workouts`: `Totals`, `Activities`

Brand direction:
- The glowing orb can be treated as the primary brand object in dashboard/header concepts.
- If introducing orb-driven UI, prefer it as a focused status object or navigator rather than decorative filler.
- Avoid renaming or reframing `Body Battery` into an orb metaphor unless the product copy and score semantics are intentionally redesigned together.

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

- LifeIQ supports both `Imperial` and `Metric` unit systems.
- Always use `SQUnit` and `SQUnitType` for conversions and labels.
- Never add ad-hoc conversion formulas or unit strings in feature code.
- Store canonical units in persistence; convert only at input/output boundaries and in presentation.
- Current canonical storage conventions:
  - user height: `heightCentimeters`
  - user weight: `weightKilograms`
  - workout/manual temperature: `temperatureCelsius`
- Active unit-system resolution must follow this precedence:
  1. `SQUser.unitSystem`
  2. `SQUserDefaults.shared.preferredUnitSystem`
  3. `SQUnitSystem.defaultForCurrentLocale`
- Use `SQUnitSystemResolver.resolve(for:)` when user context is available.
- In shared presentation code without a loaded user, use the same fallback chain rather than assuming imperial defaults.
- Any new measurement-entry UI should collect values in the active display unit and convert back to canonical storage before saving.

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
7. Review whether relevant Amplitude events need to be added or updated.
8. If the change introduces a new feature that seems worth tracking, ask Patrick before adding new Amplitude events.
9. Keep shared logic in `BeastFitnessCore` and charts in `CoolCharts`.

## Source of truth

- `CLAUDE.md` remains intact as the original human-authored guide.
- This `AGENTS.md` is the Codex-optimized companion document for day-to-day implementation behavior.
