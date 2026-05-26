# Shared UI Guidance

LifeIQ should use a consistent UI system. New screens should feel like they belong to the same app without duplicating one-off styling.

## Core Rule

Reuse shared UI components, tokens, and view models whenever possible. Add new shared primitives only when they remove real duplication or create a clearly reusable pattern.

## Required Tokens and Wrappers

- Use `SQColor` and `.sqForegroundColor()` / `.sqBackgroundColor()`.
- Use `SQFont` and `.sqFont()`.
- Use `SQImageSymbol` and `SQImageView` for SF Symbols.
- Check the actual available token cases before choosing a color, font, or symbol.
- Avoid hardcoded colors, fonts, and `Image(systemName:)` strings in app surfaces.

## Shared Components

Prefer existing shared components for:

- buttons
- alerts
- toasts
- modals
- dropdowns
- segmented controls
- settings rows
- dashboard section headers
- dashboard subsection cards
- empty states
- text fields
- sheet backgrounds

Before creating a new component, search for an existing pattern in `BeastFitness/UI`, `BeastFitness/Views/Shared`, `BeastFitness/ViewModels/Shared`, and nearby feature folders.

## Alerts, Toasts, and Errors

- Use `hub.alertEvents` for user-facing errors that need attention.
- Use `hub.toastEvents` for lightweight confirmation.
- Use existing `SQAlertViewModel` and toast view models.
- Do not build feature-specific alert/toast UI unless the shared system cannot support the need.
- User-facing failures should never be log-only or silently swallowed. Save, sync, purchase, permission, and loading failures should present a shared alert/modal when the user needs to know or act.
- Use modal/detail flows for complex recovery guidance; use alerts for focused blocking errors; use toasts only for non-blocking confirmations or transient status.

## Dashboard UI

Dashboard composition should follow the existing group/subsection model:

- section group: `SQDashboardSectionGroupViewModel`
- subsection card: `SQDashboardSubsectionViewModel`

Keep dashboard composition centralized in `SQDashboardController.buildSectionGroups(...)`.

For new dashboard rows:

- prefer extending existing row infrastructure first
- include the row/section in dashboard customization if it can appear on the dashboard
- use stable customization identifiers and ensure clone/copy behavior preserves new properties, order, and visibility
- update available layout/customization descriptors in the same change as the dashboard surface
- keep rows compact and scannable
- add mock data support when useful for simulator and performance testing
- explicitly test complex dashboard changes on `iPhone SE (2nd generation)`

## Forms and Inputs

- Default to `SQUITextField` for single-line inputs.
- Use `SQTextField` only for multiline input or when the UIKit-backed field is not appropriate.
- Keep onboarding and settings profile-edit fields in sync.
- Do not create duplicate forms for the same user data.

## Visual Restraint

- Avoid decorative filler.
- Avoid nested cards.
- Avoid adding new palettes or surface styles for one screen.
- Keep cards compact unless the content truly needs space.
- Use the orb/Que as a meaningful status or brand object, not random decoration.

## When to Add a New Shared Component

Add or extract a shared component when:

- the same pattern appears in multiple places
- a feature needs consistent alert/toast/modal/dropdown behavior
- a dashboard row pattern is reusable
- a control needs shared accessibility or layout handling

Do not add abstraction only to make a single file look smaller.
