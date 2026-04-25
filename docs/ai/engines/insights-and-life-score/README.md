# Insights and Life Score Engine

This directory is the high-level planning area for the shared analytics layer behind:
- `Insights`
- `Life Score` / `Que` / the orb

The long-term product goal is:
- `Life Score` answers: "How am I doing?"
- `Insights` answer: "Why?" and "What should I do?"

## Core Product Relationship

Life Score and Insights should be built from the same underlying inputs:
- daily check-in metrics
- workouts
- sleep
- heart / recovery data
- future nutrition, menstrual, and other tracked data

They should not be built as separate disconnected systems.

They also should not be tightly coupled in a brittle way.

The intended relationship is:
- shared normalized inputs
- shared derived features
- separate outputs

That means:
- the orb does not directly depend on individual insight cards
- insight cards do not directly mutate the orb
- both systems stay aligned because they interpret the same underlying truth
- orb state and orb contributors can influence which insights are surfaced

## Doc Map

- [insights_engine.md](/Users/patrickdoyle/Developer/mapps/BeastFitness/docs/ai/engines/insights-and-life-score/insights_engine.md)
  The target insights architecture, insight classes, range behavior, and rollout plan.
- [life_score_engine.md](/Users/patrickdoyle/Developer/mapps/BeastFitness/docs/ai/engines/insights-and-life-score/life_score_engine.md)
  The target Life Score / orb role, score-driver model, and how it should align with insights.
- [relationship_registry.md](/Users/patrickdoyle/Developer/mapps/BeastFitness/docs/ai/engines/insights-and-life-score/relationship_registry.md)
  The source-of-truth planning doc for active relationship definitions and future registry structure.

## Non-Goals For V1

- Do not build a black-box AI system.
- Do not start with backend-only analytics.
- Do not try to support every possible signal pair immediately.
- Do not mix personal truths with population truths in the same concept.

## Design Constraints

- `Today`, `Past 7 Days`, and `Past Year` should not feel like the same dashboard with a different filter.
- Daily insights should feel dynamic through relevance, recency, actionability, and novelty.
- The engine must stay extensible enough to support future domains like nutrition and menstrual tracking.
- The engine must eventually support population and cohort insights, but that is a later layer, not the starting point.
- The system should have one clear place where active relationship definitions are curated and maintained.
- The current deterministic insights engine is a useful reference, but the new system can be rebuilt cleanly if that is the faster path.
- V1 does not need a large number of insight types. It does need the right engine shape, registry, and shared feature layer so the system can grow cleanly after launch.
- Build the engine in a modular way so it can eventually move into its own package or module. Keep app-specific dependencies and adapter logic at the edges wherever practical.

## Current Product Direction

The current agreed product direction is:
- `Today` is the primary experience and should feel like a briefing, not a feed
- `Past 7 Days` is the main exploration surface for insights
- `Past Year` is a distilled personal playbook, not an endless list
- the orb / Life Score should stay fast and simple on the main dashboard
- tapping the orb should answer "Why this score?" rather than leading with formula math
- `Today` should use novelty suppression so the same primary briefing does not repeat too often
- `Past 7 Days` / `Past Year` should use a separate `New` insight freshness model so users have a clear reason to revisit those ranges
- hidden weekly/yearly freshness should be discoverable from the time-range selector, not only after opening the section

This means the system should optimize for:
- one strong primary insight on `Today`
- lightweight drivers and one suggested action on `Today`
- clearer explanation of score state through shared drivers
- progressive disclosure instead of dense dashboard feeds

Monetization should stay in mind, but it is not the current design driver.

For now:
- get the core surfaces right first
- keep premium ideas secondary
- avoid letting free/premium gating distort the base dashboard architecture too early

## Current Implementation Stop Point

The current backend/engine stopping point that is good enough for UI exploration is:
- shared feature layer exists
- multiple analyzer families exist
- range-specific surfacing exists
- shared drivers exist
- the Life Score detail path already consumes shared drivers
- a shared raw-input shape exists for both Insights and Life Score
- an internal scenario/gallery `View Lab` exists for testing real dashboard surfaces against engine-backed mock inputs
- the View Lab scenario library now intentionally includes both:
  - expected states
  - noisy / contradictory / odd states that still need coherent outputs
- the current signal catalog now covers more than just sleep + alcohol + caffeine, including:
  - mood
  - energy
  - mental clarity
  - motivation
  - stress
  - anxiety
  - soreness
  - resting heart rate
  - workout performance / workout difficulty

That is enough to start serious UI brainstorming without waiting for every future analyzer or score formula rewrite.
