# Testing Guidance

Testing should scale with risk. Do not slow down every small UI change with broad test work, but do protect fragile data, scoring, sync, and entitlement behavior.

## Priority Areas

Prioritize tests and manual verification for:

- score calculations
- insight surfacing and confidence behavior
- HealthKit data aggregation
- date boundary logic
- workout source behavior
- Firestore write paths
- subscription entitlement checks
- guest-mode write restrictions
- onboarding/profile editing consistency
- dashboard composition changes

## Dashboard Testing

Dashboard changes need extra care because the surface is dense and device-sensitive.

- Test complex dashboard changes on `iPhone SE (2nd generation)`.
- Verify scroll performance when adding rich subsections.
- Use mock dashboard data when HealthKit data is missing.
- Check empty, partial, and loaded states.
- Confirm locked/free-user states cannot expose premium-only controls.

## Subscription Testing

For subscription work:

- use StoreKit local testing for fast iteration when practical
- use App Store Connect sandbox testers for real product IDs
- verify purchase, restore, auto-renew disabled, expiration, and entitlement refresh
- confirm Firestore `subscriptionLevel` is only a mirror
- confirm free-user gates use Apple entitlement through `SQSubscriptionManager`

## HealthKit Testing

HealthKit tests should cover:

- permission denied
- no samples
- partial samples
- multiple sources
- simulator/mock data
- expected date range boundaries

When adding support for a new HealthKit category, include a manual test note if automated coverage is impractical.

## Regression Tests

Add regression tests when:

- a bug touched score logic
- a bug caused a locked premium feature to leak
- date windows were wrong
- sync behavior duplicated or dropped data
- a user-facing save flow failed silently

## Builds

Repo workflow preference: do not run Xcode builds during normal implementation unless Patrick explicitly asks. Use focused parse checks and lightweight validation when useful, and leave final build/review to Patrick unless requested.
