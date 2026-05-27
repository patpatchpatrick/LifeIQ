# AGENTS.md (LifeIQ / BeastFitness Repo)

This file translates the existing `CLAUDE.md` guidance into a Codex-friendly operating guide for this repository.

## AI docs source of truth

- The canonical product-context doc for AI assistants in this repo is [docs/ai/product_context.md](/Users/patrickdoyle/Developer/mapps/BeastFitness/docs/ai/product_context.md).
- Use that file as the stable product brief when grounding product decisions, UX reasoning, naming, and feature intent.
- Product vision and prioritization live in [docs/ai/product_vision.md](/Users/patrickdoyle/Developer/mapps/BeastFitness/docs/ai/product_vision.md). Use it when deciding what a feature should optimize for.
- The source of truth for score and feature definitions is [docs/ai/Definitions.md](/Users/patrickdoyle/Developer/mapps/BeastFitness/docs/ai/Definitions.md). Keep Life Score, Recovery Score, Insights, Performance Score, Difficulty Score, and future score explainers aligned with that file.
- Durable AI-facing implementation/product rules live in [docs/ai/rules.md](/Users/patrickdoyle/Developer/mapps/BeastFitness/docs/ai/rules.md). Check that file before adding new UI patterns or product conventions.
- AI-facing architecture guidance lives in [docs/ai/architecture.md](/Users/patrickdoyle/Developer/mapps/BeastFitness/docs/ai/architecture.md). Check it before adding new state, controller/view model, service, manager, or long-lived listener patterns.
- UX and content-density guidance lives in [docs/ai/ux_content.md](/Users/patrickdoyle/Developer/mapps/BeastFitness/docs/ai/ux_content.md). Check it before adding prominent user-facing copy or new explanation surfaces.
- Shared UI guidance lives in [docs/ai/shared_ui.md](/Users/patrickdoyle/Developer/mapps/BeastFitness/docs/ai/shared_ui.md). Check it before adding new UI components or styles.
- Privacy/security guidance lives in [docs/ai/privacy_security.md](/Users/patrickdoyle/Developer/mapps/BeastFitness/docs/ai/privacy_security.md). Check it before touching HealthKit, check-ins, subscriptions, auth, Firestore writes, logging, or analytics.
- HealthKit/data guidance lives in [docs/ai/healthkit_data.md](/Users/patrickdoyle/Developer/mapps/BeastFitness/docs/ai/healthkit_data.md). Check it before adding or expanding HealthKit-backed functionality.
- Observability and testing guidance live in [docs/ai/observability.md](/Users/patrickdoyle/Developer/mapps/BeastFitness/docs/ai/observability.md) and [docs/ai/testing.md](/Users/patrickdoyle/Developer/mapps/BeastFitness/docs/ai/testing.md). Check them when adding user-facing flows, data sync, analytics, or fragile logic.
- Engine-planning docs for the shared `Insights` / `Life Score` direction live under [docs/ai/engines/insights-and-life-score/README.md](/Users/patrickdoyle/Developer/mapps/BeastFitness/docs/ai/engines/insights-and-life-score/README.md).
- When doing architecture or product-planning work for insights, the orb, score drivers, or relationship definitions, update the relevant docs in `docs/ai/engines/` so ChatGPT and Codex stay aligned.
- Keep `AGENTS.md` focused on implementation guidance and repo rules; put broader product context in `docs/ai/`.
- If score or feature definitions change materially, update `docs/ai/Definitions.md` alongside any related `AGENTS.md` or `docs/ai/product_context.md` edits so ChatGPT and Codex can stay aligned.
- If an implementation choice feels like a durable, rule-worthy architecture or product convention, mention it to Patrick in the AI prompt and ask whether it should be added to `docs/ai/rules.md`. Use judgment; do this for meaningful conventions, not one-off implementation details.

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
- Life Score is a daily snapshot of the user's recent momentum. It looks at signals like sleep, recovery, workouts, habits, and check-ins to estimate whether the user's life is trending in a healthy direction. It is not a medical score - it is a guide to help the user notice what's supporting them and what may need attention.
- Life Score should represent how on-track the user is and whether their life/health signals are headed in a positive direction. Healthy behaviors such as working out more, performing well, or having recent HealthKit activity should generally be supportive. Training should become a Life Score drag only when the broader context suggests overreaching, poor recovery, or repeated high-intensity strain. Too many days of inactivity can become a mild drag, but a normal rest day should not be treated as failure.

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
- Follow `docs/ai/architecture.md` for boundaries between views, controllers/view models, state, services, and managers.
- New feature state pattern:
  1. Define a `@MainActor` protocol for state interface
  2. Implement with `@Observable` state class that receives `hub`
  3. Register in `SQAppState`
  4. Access via `SQAppState.shared`
- Prefer event-driven updates via `hub`.
- Keep state focused on observable values and narrow mutations. Put durable side effects and app-lifetime listeners in services or established domain managers, and have controllers/view models delegate to those services.

## Routing and alerts

- Use `hub.domainEvents.send(.pushDashboardRoute(...))` for dashboard sheet routes and handle them in `SQRootTabView`.
- For user-facing errors, use `hub.alertEvents` with `SQAlertViewModel`, typically `hub.alertEvents.send(.present(.init(error as? SQUserFacingError ?? SQError.standard)))`.
- All user-facing failures should resolve through the shared alert/modal/toast systems. Do not leave visible save, sync, purchase, permission, or loading failures as console-only logs or silent no-ops. Use alerts/modals for errors that require attention or a decision, and toasts only for lightweight status/confirmation.

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
- `SQLogger` lives in `BeastFitnessCore`; when adding logger usage in app-target files, make sure `import BeastFitnessCore` is present.
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

## Admin/debug controls

- `SQAdminConfig` is the repo home for controllable code-level admin/dev settings.
- Internal debug tooling gates should live there rather than scattered feature flags.
- Current example: the internal scenario/gallery `View Lab` is gated by `SQAdminConfig.viewLabEnabled`.

### Guest-mode write behavior

- Any user-facing flow that writes Firestore-backed data must explicitly account for guest mode.
- Do not allow guest users to silently save local data that can later be ambiguously attached to an account.
- For guest users, update the UI accordingly:
  - hide or disable write/edit controls when appropriate
  - or replace them with a login-required CTA/message
- Shared save/write entry points should still defensively reject guest writes even if the UI is already gated.
- When adding a new write flow, review both:
  - the backend/write path guard
  - the guest/read-only UI state for that surface

### Firestore metrics tracking (required)

- Track all reads/writes using `SQFirestoreMetricsManager` for cost visibility.
- Add tracking on any new direct Firestore operations.
- Standard query/collection decode paths are already tracked in network layer helpers.

## UI conventions (strict)

- Colors: use `SQColor` + `.sqForegroundColor()` / `.sqBackgroundColor()`.
- Fonts: use `SQFont` + `.sqFont()`.
- Before choosing a font or color token, check the actual available cases in `SQFont` and `SQColor` rather than guessing token names. Prefer explicit verification over assumptions when selecting `sqFont` / `sqForegroundColor` values.
- Text inputs:
  - Default to `SQUITextField` (UIKit-backed single-line)
  - Use `SQTextField` for multiline fallback
- Auth screens: use `SQUITextFieldViewModel` + `SQUITextField` for email/password with validation + error handlers, and disable the screen while auth is in progress.
- SF Symbols:
  - Use `SQImageSymbol` enum (no hardcoded `Image(systemName:)` strings)
  - Add new symbols to `BeastFitness/UI/SQImage.swift` before use
  - Prefer `SQImageView(image: .init(symbol: ...))`
- Reuse shared UI components for common patterns (e.g. `SQCollapsibleSectionHeader`).
- Major screens and major dashboard sections must define empty states for no data, missing permissions, locked access, or first-run setup where applicable. Empty states should be brief, helpful, and use shared UI patterns rather than leaving a blank screen/card.

## Dashboard composition conventions

- Use a two-level hierarchy:
  - Section group: `SQDashboardSectionGroupViewModel`
  - Subsection card: `SQDashboardSubsectionViewModel`
- Keep group composition logic centralized in `SQDashboardController.buildSectionGroups(...)`.
- Prefer extending existing row infrastructure (for example `SQDashboardMetricStatsRowViewModel`) before introducing custom row types.
- Any new dashboard section, subsection, or row that can appear on the dashboard must participate in dashboard customization. Make sure it has stable layout/customization identifiers, is included in the available customization descriptors, and preserves visibility/order through cloning.
- Dashboard layout customization clones section/subsection view models before applying order/visibility. Keep cloning centralized on the view models themselves (`cloned()` / copy API) rather than reconstructing them field-by-field in services, so new properties cannot be silently dropped.
- Keep dashboard subsections compositionally simple. Avoid letting a single top-level group accumulate multiple heavy/rich subsections if they can be split into separate groups instead.
- Be especially careful with dashboard subsection complexity on `iPhone SE (2nd generation)`. Complex subsection combinations have caused hangs there even when each subsection worked fine in isolation.
- When adding a new dashboard subsection, significantly expanding an existing subsection, or combining multiple rich subsections in one group, explicitly tell Patrick to test that surface on `iPhone SE (2nd generation)` for scroll performance and hangs.
- Keep `SQAdminConfig.useMockDashboardHealthData` in mind when adding dashboard or Health-driven functionality. If a new surface can reasonably be represented with mock dashboard data, extend the mock path too so SE/perf debugging does not depend on populated HealthKit data.
- `SQAdminConfig` is the home for controllable code-level admin/dev config settings when a runtime or build-time knob is needed. Prefer putting temporary app-wide admin overrides there instead of scattering them across feature files.

Current intended dashboard structure:
- `Daily Stats`: `Metrics`, `Performance`
- `Sleep`: `Sleep Score`, `Sleep Summary`, `Sleep Phases`
- `Workouts`: `Totals`, `Activities`

Brand direction:
- The glowing orb can be treated as the primary brand object in dashboard/header concepts.
- If introducing orb-driven UI, prefer it as a focused status object or navigator rather than decorative filler.
- Avoid renaming or reframing `Body Battery` into an orb metaphor unless the product copy and score semantics are intentionally redesigned together.
- Score explanation surfaces should follow the `Life Score` detail-screen pattern: use a dedicated sheet/detail view with clear section spacing and hierarchy, not a dense alert.
- Keep all score pages visually consistent where possible, including `Life Score`, `Recovery Score`, `Performance Score`, `Difficulty Score`, and future score explainers. Reuse the same section hierarchy, spacing style, and explanation patterns unless there is a strong product reason to diverge.

Sleep-specific range semantics:
- Use completed nights only, anchored to the latest completed wake day.
- `Today` => last completed night.
- `Past 7/30/Year` => rolling completed-night windows ending with last night.
- Sleep phase metric rows show average duration for the selected window.
- Sleep phase timeline row should show the latest completed night.
- When comparing a daytime/evening metric to a sleep metric, always compare against that night's sleep, not the sleep that ended that morning. Because sleep values are anchored to wake day in code, same-day input -> sleep outcome usually means input day + 1 wake-day snapshot. In Insight Explorer, `Same day` means that night's sleep, `Next day` means the next night's sleep, and `2 days later` means the sleep night two nights later.

Charts convention:
- Reusable timeline/interval charts should live in `CoolCharts` as generic components (for example `TimelineChartView`) so they can be reused by Sleep and future Heart Rate surfaces.

Tutorial/example sync convention:
- Tutorial/example surfaces should reuse the real app components where possible so they do not drift visually or behaviorally.
- Current launch tutorial examples are expected to stay aligned with the actual Daily Check-In rows, insight card, and dashboard check-in CTA.
- If you modify any real app surface that is mirrored in the tutorial, update the tutorial preview or shared helper in the same change.
- When you make one of those changes, explicitly tell Patrick that the launch tutorial should be re-tested for sync/regression as part of your user-facing update/final response.

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
10. For dashboard subsection work, consider whether `SQAdminConfig.useMockDashboardHealthData` should be extended so the new UI can be exercised without real HealthKit data.
11. For dashboard subsection additions or complexity increases, remind Patrick to test on `iPhone SE (2nd generation)` to catch hangs/regressions early.

## Source of truth

- `CLAUDE.md` remains intact as the original human-authored guide.
- This `AGENTS.md` is the Codex-optimized companion document for day-to-day implementation behavior.
