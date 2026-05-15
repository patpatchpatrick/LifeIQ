# LifeIQ Architecture Guidance

This document defines the intended responsibilities of common app layers so future code stays consistent. Prefer existing local patterns, but use these boundaries when adding or refactoring features.

## High-Level Shape

```text
View
  -> Controller / ViewModel
  -> Service / Manager
  -> Route / Network / StoreKit / HealthKit / Persistence
  -> State updates through SQAppState + hub events
```

`SQAppState.shared` is the app-level container for shared state and app-lifetime services. Views and route-specific controllers should not create their own source of truth for shared app data.

## Views

Views render UI and connect user gestures to controller actions.

- Keep views declarative and presentation-focused.
- Views may own local UI state such as text field focus, animation state, expanded rows, and temporary presentation state.
- Views should not perform Firestore writes, StoreKit entitlement checks, HealthKit queries, analytics decisions, or subscription business logic directly.
- Views should call controller methods for user intent, for example `purchaseTapped`, `restorePurchases`, `save`, or `refresh`.
- Views should receive stable view models or controllers rather than reconstructing domain logic inline.

## Controllers / ViewModels

Controllers and view models own screen or flow behavior. They translate app/domain state into UI-ready models and turn user actions into service calls.

- Use controllers for screen-specific business flow, validation, UI loading states, routing decisions, and analytics attached to user actions.
- Controllers may hold short-lived tasks related to the screen they represent.
- Controllers should not be the source of truth for app-wide state.
- Controllers should not own app-lifetime listeners such as StoreKit transaction streams, notification observers, or HealthKit observer queries unless the controller itself is app-lifetime and clearly named for that role.
- Controllers should delegate durable domain work to services or established managers.
- Route-created controllers should be safe to create and discard without losing app-wide behavior.

## State

State objects expose observable app state. They should be boring, stable, and easy to reason about.

- State objects should hold current values, derived presentation-safe values, and narrow mutation methods.
- State should not perform network calls, Firestore writes, StoreKit purchases, HealthKit reads, or analytics tracking.
- State should not start long-lived listeners or background tasks.
- Define a `@MainActor` protocol for state interfaces when the state is consumed outside its owning feature.
- Register shared state in `SQAppState`.
- Prefer event-driven state updates through `hub` when multiple features need to react.

## Services

Services own durable domain logic and side effects.

- Use services for Firestore-backed writes, StoreKit entitlement refreshes, purchases, restores, HealthKit reads, sync flows, cache refreshes, and other non-UI domain work.
- Services may own app-lifetime listeners when the domain requires them.
- App-lifetime services should be registered in `SQAppState` and configured from launch/root app setup.
- Services should update state through explicit methods and publish cross-feature events through `hub`.
- Services should use route/service architecture for Firestore and track Firestore metrics through the existing network layer.
- Services should avoid depending on views.

## Managers

Managers are existing app-wide utilities or facades. Use them when the codebase already has an established manager for a cross-cutting concern.

- Keep managers focused on shared infrastructure or compatibility facades.
- Prefer a domain service for new feature-specific business logic unless the existing codebase already uses a manager for that domain.
- Avoid turning managers into miscellaneous dumping grounds.

## App-Lifetime Listeners

Long-lived listeners belong in app-lifetime services or narrowly named app coordinators, not in state or disposable route controllers.

Examples:

- StoreKit transaction updates
- HealthKit observer queries
- Auth/profile sync listeners
- Foreground/background refresh observers
- Remote config listeners

The owner should be created once, usually by `SQAppState`, and configured once during app launch or root setup.

## Subscription Architecture

Subscription access should follow these boundaries:

- `SQSubscriptionState`: observable subscription values only, such as Apple entitlement level, products, loading flags, and restore/purchase flags.
- Subscription service: StoreKit product loading, purchases, restores, transaction listener, entitlement refresh, and Firestore mirror sync.
- `SQSubscriptionController`: paywall/settings flow behavior, user-action analytics, routing, and delegation to the subscription service.
- `SQSubscriptionManager`: lightweight compatibility facade for existing call sites such as `hasPremiumAccess`, `effectiveSubscriptionLevel`, product IDs, and paywall routing.

Apple entitlements are the runtime source of truth. Firestore `subscriptionLevel` is an admin/debug mirror and must be updated with a partial field update rather than saving the entire user document.

`SQAdminConfig.subscriptionLevelOverride` remains the explicit local/admin override. If it is non-nil, access checks should use it. If it is nil, access checks should fall back to the Apple entitlement level.

## Refactor Checklist

When changing a feature boundary, ask:

- Is this object app-lifetime or route/screen-lifetime?
- Is this data source-of-truth state or UI projection?
- Is this operation a side effect that belongs in a service?
- Can this controller be discarded without breaking background behavior?
- Are Firestore writes routed through the service/network layer and scoped to the needed fields?
- Does the change need a durable rule in `docs/ai/rules.md`?
