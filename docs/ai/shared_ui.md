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
- Alerts should use the same dark blue, subtle surface family as dropdown menus and dashboard sheets. Avoid system-looking silver material backgrounds or high-contrast floating chrome for app alerts.
- Toasts should follow the same dark blue, subtle surface family as alerts and dropdown menus. Avoid silver material styling or saturated shadows for transient feedback.

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

## Empty States

Major screens and major dashboard sections should not render as blank or broken when data is unavailable.

Use empty states for:

- no user-created content yet
- missing HealthKit or app permissions
- no data in the selected time range
- locked premium surfaces
- first-run setup paths
- sync/load failures after the shared error surface is shown

Empty states should:

- use shared empty-state, CTA, card, or alert/modal patterns where possible
- name what is missing in plain language
- offer one clear action when there is a useful next step
- stay concise and avoid setup walls on the main dashboard
- distinguish empty data from failed data

## Loading States

Surfaces that depend on async or background data loading should show an intentional loading state whenever the visible content is being repopulated.

- Prefer redacted placeholders for existing rows/cards/sections so the layout remains stable while data refreshes.
- Disable interactive controls that would conflict with the in-flight refresh.
- Keep stable controls visible when useful, but avoid showing stale data as if it is final.
- Do not leave a sheet, dashboard, or detail screen visually unchanged while a time range, filter, or background data reload is still pending.

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

## Visual Hierarchy Direction

LifeIQ should use subtle containers and stronger content hierarchy. The screen background, section backgrounds, and card backgrounds should stay close in value so containers group content without competing with it. Important user data should be what pops.

- Prefer quiet card chrome: low-contrast fills, restrained borders, minimal shadows, and soft highlights.
- Let values, trends, selected states, and high-priority statuses carry emphasis.
- Use secondary or tertiary text for card titles, labels, helper copy, timestamps, and repeated chrome like `View more`.
- Use primary text, bolder weights, larger type, or accent color for the most important value or takeaway in a card.
- Avoid pairing card titles and card values at the same bold white weight; this makes the hierarchy unclear.
- Use accent color sparingly for signal: positive/negative trend, selected state, score state, confidence, or an actionable change.
- Keep dense surfaces closer to clean finance/market dashboards than decorative wellness cards: scannable rows, crisp values, muted labels, and low visual noise.
- Prefer shared surfaces such as `sqGlassSurface(level: .card)` over one-off card backgrounds so this restrained treatment stays consistent across screens.
- When a dashboard card or sheet shows averaged values for a non-`Today` time range, include a visible `Avg` label near the value or grouped content. Non-today averages should not look identical to today's point-in-time values.

## When to Add a New Shared Component

Add or extract a shared component when:

- the same pattern appears in multiple places
- a feature needs consistent alert/toast/modal/dropdown behavior
- a dashboard row pattern is reusable
- a control needs shared accessibility or layout handling

Do not add abstraction only to make a single file look smaller.
