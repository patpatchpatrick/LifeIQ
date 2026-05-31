# UX and Content Guidance

LifeIQ should feel intelligent, calm, and useful. The app can be information-rich, but it should not over-explain itself.

## Core UX Principle

Show the least text that helps the user make the next useful decision.

Text should earn its place. Prefer clear labels, concise values, short status lines, and progressive disclosure over long explanations on primary surfaces.

## Voice

LifeIQ copy should be:

- concise
- practical
- evidence-aware
- calm
- non-medical
- specific when the app has evidence

Avoid:

- motivational filler
- generic wellness advice
- clinical or diagnostic language
- long paragraphs on dashboard cards
- explaining obvious UI controls
- making weak patterns sound certain

## Dashboard Content

The dashboard is a scanning surface.

- Use short titles and compact subtitles.
- Keep explanatory text brief.
- Prefer metric values, trend labels, confidence tags, and short insight summaries.
- Move deeper explanation into sheets/detail screens.
- Avoid placing instructions in the UI when the control itself is understandable.
- Make the primary value or takeaway visually dominant over the card title.
- Treat repeated labels, timestamps, units, and action chrome as secondary or tertiary text unless they are the main thing the user needs to act on.
- Use color and weight to highlight meaningful change, not to decorate every card.

## Insight Content

Insights should be understandable without sounding overconfident.

Good insight copy should usually include:

- the signal or relationship
- the direction of the pattern
- the evidence window when useful
- the confidence level when useful

Avoid:

- claiming causation unless the engine actually supports it
- implying medical certainty
- moralizing habits or vices
- surfacing sensitive habit names in screenshots or default public-facing examples when avoidable

## Empty and Loading States

Empty states should explain what is missing and how the user can unlock value, but stay brief.

Major screens and major dashboard sections should have an intentional empty state for no data, missing permissions, locked access, or first-run setup when those states are possible.

Good empty states:

- name the missing data or permission
- offer one clear action when available
- avoid walls of setup instructions
- distinguish empty data from an error or failed load

Loading states should be calm and short. Avoid fake precision.

When a visible surface is repopulating after an async change such as a time range or filter update, use a redacted loading state rather than leaving stale values fully active. This keeps the UI from feeling broken or laggy while preserving the user's mental model of the layout.

## Detail Screens

Detail screens may explain more, but should still use structure:

- short title
- one-sentence summary
- scannable sections
- clear rows or bullets where helpful
- no dense paragraphs unless the user explicitly opened an explanation surface

## Premium and Locked UI

Premium prompts should show value without hostility.

- Free users should understand what is locked and why it matters.
- Do not clutter core free surfaces with repeated upgrade copy.
- Locked previews should be useful enough to communicate value.
- Use the shared subscription route instead of duplicating paywall copy.

## Accessibility and Mobile Constraints

- Text must fit on small devices, especially `iPhone SE (2nd generation)`.
- Avoid hero-scale text in compact cards.
- Dynamic content should not overlap controls.
- Important status should not rely only on color.
- Keep repeated workflows ergonomic and predictable.
