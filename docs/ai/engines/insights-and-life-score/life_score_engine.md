# Life Score and Orb Plan

This document defines the intended role of the Life Score and the orb (`Que`) relative to the insights engine.

## Product Role

The orb should be the summary state object for the product.

At a high level:
- `Life Score` / `Que` answers: "How am I doing?"
- `Insights` answer: "Why is it like that?" and "What should I do?"

That relationship should make the app feel cohesive.

## What The Orb Should Not Be

The orb should not be:
- just another stat card
- a random black box
- a direct display of whichever insight card happened to rank highest

The orb needs to feel:
- stable
- legible
- trustworthy

## Shared Inputs With Insights

The orb and the insights engine should share the same underlying dependencies.

Examples:
- sleep
- recovery
- workouts
- recent behaviors and habits
- recent trends
- future nutrition / cycle / other tracked signals

The orb should not use a disconnected scoring world from the insight engine.

## Intended Relationship With Insights

The product relationship should be:
- shared normalized inputs
- shared derived features
- separate outputs

That means:
- the orb is not computed from insight cards
- insights are not directly mutating the orb
- insights can explain why the orb is high, low, rising, or falling
- orb state can influence which insights are surfaced

## Score Drivers

The score system should eventually expose a concept like score drivers or contributions.

Examples:
- sleep is lifting the score
- resting HR is helping recovery
- shorter sleep is dragging the score down
- recovery is helping
- recent strain is pulling the score down
- recent habits are supporting or hurting the score

These drivers are important because they create a clean bridge between:
- score computation
- insight explanation
- user-facing action suggestions

The app now has a first shared driver layer in the insights engine:
- `SQInsightDriver`
- `SQInsightDriverBuilder`

That layer should remain reusable by Life Score rather than reimplemented separately inside dashboard-only score code.

The current app now also consumes that shared driver layer in the Life Score detail flow, without changing the existing score formula yet. That is the intended migration shape:
- keep score math stable
- move explanation onto shared drivers
- later let the score formula reuse the same driver inputs more directly

The shared Life Score input path now also carries resting-heart-rate summaries, so the score can start reflecting a broader recovery picture than sleep and habits alone.

The Life Score detail flow now also consumes shared recent `changes`, so the explanation layer can answer both:
- what is helping / dragging
- what has shifted recently

The Life Score detail flow now also consumes shared `actions`, so the explanation layer can recommend one concrete next move without inventing separate score-only advice logic.

Phase 1 metric semantics are now part of `SQMetricDefinition`: `signalRole`, `lifeScoreImpact`, `insightMode`, and `sensitivity`. Current Life Score behavior should not directly depend on these fields yet; future contributor-based scoring should route through a resolver so stored `.automatic` values resolve consistently and custom metrics stay capped.

View Lab simulation reports are the calibration harness for score tuning. Before changing score behavior, capture baseline distributions for score deltas, component scores, top drivers/changes, action families, HealthKit fallback usage, and component availability.

Preset semantic defaults should be non-clobbering after their one-time backfill. Future user edits to preset metric semantics must not be reset by normal preset migration.

Contributor-based metric scoring should be developed in shadow mode first. The shadow model can read rich insight signal features and report custom/sensitive/behavior contribution totals, but the visible Life Score should not switch to contributor scoring until simulator reports are reviewed.

Life Score hero copy should be state-first, not signal-first. The default headline comes from the current state (`Strong`, `Primed`, `Balanced`, `Slightly Off`, `Dipping`, `Under Pressure`, etc.) using a small deterministic copy library so repeated app reloads stay stable while consecutive days can vary.

`Under Pressure` should be reserved for stacked or severe negatives. A single mild drag should usually become `Slightly Off` or `Dipping`, especially for balanced personas with otherwise good sleep, training, and habit patterns. Scores at or above 88 should not become `Under Pressure` unless there is an unusually severe stacked condition.

Positive momentum should be allowed to produce `Rebounding` before `Under Pressure` is considered. For example, a score in the mid-70s that is up meaningfully from yesterday should not be red unless there are multiple severe negatives.

When an individual Life Score component changes the weighted score by about 10+ points versus yesterday, that component should be allowed to override the generic insight headline. Significant drops take priority over lifts because they usually explain the user's immediate concern best. The point impact should drive prioritization, but the surfaced headline should stay human-readable instead of saying the exact point drag.

Life Score hero actions should also be state-first. Use the state to choose the decision style (`push`, `maintain`, `adjust`, `recover`) and only use component-specific actions when a low component is clearly the context.

Sleep detail should stay source-transparent. If Life Score sleep comes from Daily Check-In, show the check-in calculation. If it comes from HealthKit, identify the HealthKit sleep score/breakdown. If Life Score applies a stricter adjustment than the dashboard Sleep Score, show the raw sleep score and the adjusted Life Score sleep component separately.

Sleep freshness should be day-anchored. User-entered sleep quality/duration wins for the same wake day, but newer HealthKit sleep should replace older or HealthKit-prefilled sleep check-in values for Today-facing drivers and score context. Stale sleep values should not be treated as the latest Today signal.

## Dashboard Use

On the dashboard, the orb should eventually support:
- current score / state
- high-level direction or momentum
- top positive contributors
- top negative contributors

Insights should then use that context to surface explanation and action.

Examples:
- if the score is low, prioritize insights explaining the drag
- if the score is strong, prioritize insights explaining strength and opportunity

Current UI/product direction:
- on the main dashboard, the orb should stay simple, emotional, and fast
- the orb answers "How am I doing?"
- the primary insight and drivers answer "Why?" and "What should I do?"

The top of the `Today` dashboard should eventually combine:
- orb / score / state
- one primary insight
- lightweight supportive and drag drivers
- one suggested action

## Alignment Rule

The system should follow this rule:

`Life Score and Insights must remain aligned through shared underlying signals.`

And this rule:

`Insights explain and contextualize the score; they do not directly mutate it.`

And this rule:

`The score can affect which insights are prioritized, but not the underlying truth of those insights.`

## Future Architecture Implication

The planning implication is:
- build one shared feature layer for score + insights
- allow two output systems:
  - score generation
  - insight generation

That is the safest way to keep the app feeling like one system instead of multiple unrelated analytics features.

## Near-Term Constraint

We do not need to implement the orb logic yet.

But the insights planning work should avoid choices that would make future orb alignment awkward.

Examples:
- avoid insight-only data shaping that the score could not reuse
- avoid building recommendation logic that ignores current score state entirely
- avoid treating dashboard insights as detached cards with no score context

## Life Score Detail Direction

The Life Score tap-in view should remain, but its job should change.

It should no longer lead with:
- dense formula explanation
- raw weighted math
- too much prose before meaning

It should instead lead with:
- current score and state
- one-sentence interpretation
- "what's driving it" using shared drivers
- one or two suggested actions

Formula transparency should still exist, but as a secondary or collapsed section rather than the primary story.

The intended hierarchy is:
- orb on dashboard = state
- Life Score detail = explanation
- insights = ranked context and follow-through

Shared insight drivers should not call a signal supportive only because it improved versus baseline. Readiness signals also need a reasonable absolute value before they can produce "helping today" language. Life Score can still apply a final action guard so low sleep/recovery, negative momentum, `Dipping`, or `Under Pressure` states do not become "push harder" training advice.
