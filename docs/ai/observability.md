# Observability Guidance

LifeIQ should be understandable during development, TestFlight, and production. Logging, analytics, and metrics should help debug real behavior without exposing sensitive data.

## Logging

Use `SQLogger` for app logs.

Log important lifecycle events such as:

- HealthKit permission and sync milestones
- workout sync/import milestones
- daily check-in save failures
- subscription entitlement changes
- Remote Config app-disable or force-update states
- Firestore write failures
- major dashboard data refresh failures

Logs should include:

- feature context
- non-sensitive IDs when useful
- coarse error information
- durations for expensive flows when useful

Logs should not include:

- secrets
- auth tokens
- raw HealthKit samples unless explicitly needed
- sensitive notes
- full payment payloads
- unnecessarily detailed habit/vices content

## Analytics

Amplitude is part of user-facing implementation review.

Track product-significant behavior such as:

- onboarding completion
- dashboard route opens
- daily check-in completion
- metric creation/editing
- workout summary views
- insight opens
- subscription screen requests
- settings actions

When adding analytics:

- use clear event names and stable properties
- avoid raw sensitive health values
- avoid raw notes or private free text
- prefer counts, categories, source screens, and coarse state
- confirm with Patrick before adding new event families

## Firestore Metrics

Track Firestore reads and writes through `SQFirestoreMetricsManager`.

New direct Firestore operations should be routed through the existing network/service layer whenever possible so metrics and error handling stay consistent.

## Debuggability

For new feature work, consider:

- how to tell whether data loaded
- how to tell whether permissions are denied
- how to distinguish empty data from failed data
- how to reproduce with mock data
- whether Remote Config controls should affect the flow

## TestFlight and Production Readiness

Before user-facing releases, review:

- major error logs are actionable
- analytics events do not leak sensitive data
- subscription state changes can be debugged
- HealthKit missing/denied states are visible enough to diagnose
- Firestore write failures surface useful user-facing errors where needed
