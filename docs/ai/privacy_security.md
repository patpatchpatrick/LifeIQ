# Privacy and Security Guidance

LifeIQ handles sensitive health, habit, workout, and account data. Treat privacy and security as product requirements, not cleanup tasks.

## Data Sensitivity

Sensitive data may include:

- HealthKit data
- workouts and locations/routes when present
- sleep and heart data
- reproductive health, symptoms, medication, or future HealthKit categories
- daily check-ins
- habits and vices
- notes
- account identifiers
- subscription and entitlement state

Avoid exposing sensitive data unnecessarily in logs, analytics, screenshots, sample data, or default public-facing examples.

## Health and Medical Safety

- Do not present LifeIQ as a medical diagnosis tool.
- Avoid diagnosis, treatment, or emergency guidance language.
- Use phrases like "may be associated with", "tends to", or "in your recent data" when appropriate.
- If a signal is weak or incomplete, say less rather than overstate it.
- Handle denied or missing HealthKit permissions gracefully.

## Authentication and Account Boundaries

- Do not trust client-provided user IDs, roles, subscription levels, or admin flags.
- Guest-mode write behavior must be explicit.
- Logged-out users should not be offered account-level actions such as restore purchases from Settings.
- User-facing Firestore writes should reject guest writes defensively even when UI controls are hidden.

## Subscriptions

- Apple entitlements are the runtime source of truth for subscription access.
- Firestore `subscriptionLevel` is an admin/debug mirror, not the access authority.
- Update subscription mirror fields with scoped field updates, not full user overwrites.
- `SQAdminConfig.subscriptionLevelOverride` is an explicit local/admin override and should be easy to reason about.
- Do not log raw App Store receipts, payment payloads, or sensitive transaction details.

## Firestore and Remote Config

- Use route/service architecture for Firestore.
- Track Firestore reads and writes through `SQFirestoreMetricsManager`.
- Respect Remote Config controls for disabled app states, write shutdowns, signup shutdowns, and force-update flows.
- Do not rely on Remote Config as the backend enforcement layer for security.

## Logging

Use `SQLogger` and include enough context to debug without leaking sensitive information.

Do log:

- lifecycle milestones
- non-sensitive IDs when useful
- error categories
- sync and permission state transitions

Do not log:

- secrets
- authentication tokens
- raw HealthKit samples when avoidable
- sensitive notes
- full payment payloads
- private habit/vices content unless clearly necessary and safe

## Analytics

- Treat Amplitude as product analytics, not a sensitive data warehouse.
- Avoid sending raw health values, notes, or sensitive habit/vices names unless explicitly reviewed.
- Prefer categories, counts, source screens, feature names, and coarse state.
- When a new event could include sensitive data, confirm with Patrick before adding it.

## Admin and Debug Tools

- Gate admin/debug tools behind explicit config or admin checks.
- Keep debug controls in `SQAdminConfig`.
- Never make debug bypasses available in production by accident.
- Screenshot and App Store demo modes should avoid sensitive default content.
