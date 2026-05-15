# LifeIQ AI Rules

This file tracks durable implementation and product rules for AI assistants working in this repository. Add rules here when a decision should consistently shape future code, UI, docs, or product reasoning.

## UI Controls

- Prefer the shared `SQDropDownMenu` / `SQDropDownMenuViewModel` style for dropdowns and multi-value single-selection fields. Avoid introducing native SwiftUI picker/menu styling for app surfaces unless there is a specific product reason.

## Definitions

- Keep score and feature definitions in `docs/ai/Definitions.md`. Life Score, Recovery Score, Insights, Performance Score, Difficulty Score, and future feature explainers should use that file as the source of truth before in-app copy or AI guidance is changed.

## Product Direction

- Use `docs/ai/product_context.md` and `docs/ai/product_vision.md` to ground product decisions.
- LifeIQ should turn HealthKit, workouts, sleep, and check-ins into actionable personal health intelligence, not just display raw data.
- Prefer features that improve trustworthiness, actionability, clarity, reliable data handling, and daily usefulness before monetization or extra visual polish.
- Do not duplicate detailed Insights or Life Score engine definitions here; keep those in `docs/ai/Definitions.md` and `docs/ai/engines/`.

## Architecture Boundaries

- Follow `docs/ai/architecture.md` for layer responsibilities when adding or refactoring features.
- Keep observable state objects focused on state exposure and narrow mutations; do not put network calls, StoreKit purchases, Firestore writes, analytics, or long-lived listeners in state.
- Put durable domain logic and side effects in services or established domain managers.
- Use controllers/view models for screen and flow behavior: validation, UI-ready models, routing, analytics tied to user actions, and delegation to services.
- Keep views declarative and presentation-focused; views should call controller actions instead of reaching into services directly.

## UX and Content

- Follow `docs/ai/ux_content.md` for content density and tone.
- Use the least text that helps the user make the next useful decision.
- Keep dashboards and cards scannable; move deeper explanation into detail screens.
- Avoid medical diagnosis language, generic wellness filler, and overconfident insight claims.

## Shared UI

- Follow `docs/ai/shared_ui.md` before creating new UI patterns.
- Reuse shared components for alerts, toasts, modals, dropdowns, buttons, text fields, settings rows, and dashboard sections.
- Use `SQColor`, `SQFont`, and `SQImageSymbol` wrappers rather than hardcoded visual values or system image strings.

## Privacy and Security

- Follow `docs/ai/privacy_security.md` for sensitive data handling.
- Do not log or send analytics for raw HealthKit samples, notes, secrets, payment payloads, or sensitive habit/vices content unless explicitly reviewed.
- Guest-mode write behavior and subscription access must be explicit and defensively enforced.

## HealthKit and Data

- Follow `docs/ai/healthkit_data.md` when adding or expanding HealthKit-backed features.
- Check the latest official Apple HealthKit documentation before adding new HealthKit categories or APIs.
- Handle missing, denied, delayed, and partial data gracefully.

## Observability and Testing

- Follow `docs/ai/observability.md` for logging, analytics, Firestore metrics, and debuggability.
- Follow `docs/ai/testing.md` for test and manual verification priorities.
- For dashboard changes, keep `iPhone SE (2nd generation)` performance and layout risk in mind.
