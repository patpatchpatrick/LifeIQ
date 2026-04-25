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
