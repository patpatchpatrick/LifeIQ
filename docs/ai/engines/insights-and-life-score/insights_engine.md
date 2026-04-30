# Insights Engine Plan

This document describes the target architecture and product behavior for the LifeIQ insights engine.

## Product Goal

The insights engine should help users understand:
- what is changing
- what is helping or hurting them
- what is relevant now
- what they might try next

The engine should feel:
- personal
- trustworthy
- explainable
- actionable

It should not feel like:
- random AI output
- generic health advice
- the same repeated card forever

## V1 Launch Philosophy

V1 does not need a huge insight catalog.

For launch, the better tradeoff is:
- build the right shared engine foundation
- keep the active relationship set small and curated
- make the surfaced insights feel trustworthy and relevant

So the launch goal is:
- strong system shape
- modest insight breadth
- high confidence in the relationships that are active

## Current Reality

The app now has a rebuilt first-pass insights engine with the new architecture direction in place.

Current code entry points:
- active relationship definitions now live in [SQInsightRelationshipRegistry.swift](/Users/patrickdoyle/Developer/mapps/BeastFitness/BeastFitness/Managers/Insights/SQInsightRelationshipRegistry.swift)
- relationship and surface metadata now live in [SQInsightRelationshipDefinition.swift](/Users/patrickdoyle/Developer/mapps/BeastFitness/BeastFitness/Models/Insights/SQInsightRelationshipDefinition.swift)
- shared driver models now live in [SQInsightDriver.swift](/Users/patrickdoyle/Developer/mapps/BeastFitness/BeastFitness/Models/Insights/SQInsightDriver.swift)
- shared change models now live in [SQInsightChange.swift](/Users/patrickdoyle/Developer/mapps/BeastFitness/BeastFitness/Models/Insights/SQInsightChange.swift)
- shared action models now live in [SQInsightAction.swift](/Users/patrickdoyle/Developer/mapps/BeastFitness/BeastFitness/Models/Insights/SQInsightAction.swift)
- shared feature snapshots now live in [SQInsightFeatureSnapshot.swift](/Users/patrickdoyle/Developer/mapps/BeastFitness/BeastFitness/Models/Insights/SQInsightFeatureSnapshot.swift)
- feature construction now lives in [SQInsightFeatureBuilder.swift](/Users/patrickdoyle/Developer/mapps/BeastFitness/BeastFitness/Managers/Insights/SQInsightFeatureBuilder.swift)
- shared driver construction now lives in [SQInsightDriverBuilder.swift](/Users/patrickdoyle/Developer/mapps/BeastFitness/BeastFitness/Managers/Insights/SQInsightDriverBuilder.swift)
- shared change construction now lives in [SQInsightChangeBuilder.swift](/Users/patrickdoyle/Developer/mapps/BeastFitness/BeastFitness/Managers/Insights/SQInsightChangeBuilder.swift)
- shared action construction now lives in [SQInsightActionBuilder.swift](/Users/patrickdoyle/Developer/mapps/BeastFitness/BeastFitness/Managers/Insights/SQInsightActionBuilder.swift)
- relationship analysis now lives in [SQInsightRelationshipAnalyzer.swift](/Users/patrickdoyle/Developer/mapps/BeastFitness/BeastFitness/Managers/Insights/SQInsightRelationshipAnalyzer.swift)
- recent trend analysis now lives in [SQInsightTrendAnalyzer.swift](/Users/patrickdoyle/Developer/mapps/BeastFitness/BeastFitness/Managers/Insights/SQInsightTrendAnalyzer.swift)
- baseline deviation analysis now lives in [SQInsightBaselineAnalyzer.swift](/Users/patrickdoyle/Developer/mapps/BeastFitness/BeastFitness/Managers/Insights/SQInsightBaselineAnalyzer.swift)
- follow-up analysis now lives in [SQInsightFollowUpAnalyzer.swift](/Users/patrickdoyle/Developer/mapps/BeastFitness/BeastFitness/Managers/Insights/SQInsightFollowUpAnalyzer.swift)
- current-state risk/opportunity analysis now lives in [SQInsightCurrentStateAnalyzer.swift](/Users/patrickdoyle/Developer/mapps/BeastFitness/BeastFitness/Managers/Insights/SQInsightCurrentStateAnalyzer.swift)
- engine orchestration now lives in [SQInsightAnalysisEngine.swift](/Users/patrickdoyle/Developer/mapps/BeastFitness/BeastFitness/Managers/Insights/SQInsightAnalysisEngine.swift)
- range-aware ranking policy now lives in [SQInsightSurfacingPolicy.swift](/Users/patrickdoyle/Developer/mapps/BeastFitness/BeastFitness/Managers/Insights/SQInsightSurfacingPolicy.swift)

That is the new base, and it should continue becoming more general than simple metric-to-metric comparisons.

## Rebuild Status

The old evaluator/config stack has been replaced as the live runtime path.

The current runtime system now follows this mapping:
- `SQInsightFeatureSnapshot` -> shared day feature layer
- `SQInsightFeatureBuilder` -> normalized feature construction
- `SQInsightDriver` / `SQInsightDriverBuilder` -> shared “what is helping / what is dragging” layer for insights + future Life Score alignment
- `SQInsightChange` / `SQInsightChangeBuilder` -> shared “what changed recently” layer for `Today` and future dashboard storytelling
- `SQInsightAction` / `SQInsightActionBuilder` -> shared “what should I do next” layer for `Today`, Life Score detail, and future dashboard hero surfaces
- `SQInsightRelationshipRegistry` -> active relationship source of truth
- `SQInsightRelationshipAnalyzer` -> reusable analyzer for relationship / bucket-comparison insights
- `SQInsightTrendAnalyzer` -> reusable analyzer for recent trend insights
- `SQInsightBaselineAnalyzer` -> reusable analyzer for baseline-change insights
- `SQInsightFollowUpAnalyzer` -> reusable analyzer for recent follow-up / experiment-outcome insights
- `SQInsightCurrentStateAnalyzer` -> reusable analyzer for `Today` risk/opportunity insights
- `SQInsightAnalysisEngine` -> candidate generation and result orchestration
- `SQInsightSurfacingPolicy` -> range-aware surfacing policy

The current-state analyzer is allowed to evaluate either:
- a single signal against baseline
- or a stacked pair of aligned signals against baseline for stronger `Today` cards

`SQInsightsService` now applies a separate surfacing pass after candidate generation:
- `Today` is curated like a briefing
- `Past 7 Days` is curated like a recent story
- `Past Year` is curated like a longer-term playbook

`SQInsightsResult` also now carries a curated driver list alongside surfaced cards. That driver list is not a UI surface yet, but it is the intended shared bridge into future orb / Life Score explanation.

`SQInsightsResult` also now carries curated `changes`, which are intended to back the lightweight `What Changed` surface in the eventual `Today` dashboard.

`SQInsightsResult` also now carries curated `actions`, which are intended to back the lightweight `What To Do` surface in the eventual `Today` dashboard and any orb/detail explanation surfaces that need one recommended next move.

`Today` insight titles should describe the day-state implication instead of simply restating the signal. Prefer "You're in a good position to train today" over "Soreness looks manageable today", and prefer "The day may feel heavier than usual" over "Stress is under pressure today".

`Today` actions should be concrete decisions, not generic advice. Positive training-readiness actions can rotate across a small stable library, while caution actions should say whether to moderate effort, recover, or adjust a specific habit.

`Today` surfacing should not show habit/vice relationship, trend, baseline, or follow-up insights just because the historical pattern is true. For stale-sensitive signals such as alcohol, caffeine, weed, nicotine, and porn, the latest value needs to be fresh and non-zero to be treated as currently relevant.

`Today` surfacing now also has a first-pass novelty layer in the surfacing step:
- novelty is applied in surfacing, not in the core analyzers
- the current implementation only tracks the primary visible `Today` insight family
- repeated families get a soft ranking penalty on following days
- same-day dashboard reloads should not keep decaying novelty again

Weekly/yearly insight freshness now has a separate first-pass memory layer:
- `Past 7 Days` and `Past Year` still use the same core insights engine
- they do not use `Today` novelty suppression
- instead, they can mark one surfaced insight as `New` when it is newly relevant since the last time that surface was viewed
- `New` stays attached until the user actually opens that surface and the insight is still present there
- `Past 7 Days` and `Past Year` use different cooldowns, so yearly `New` insights appear much less often than weekly ones
- the time-range selector can surface that freshness state via a subtle hidden-range indicator

The current relationship registry is also broader than the original vice-only seed set. It now includes:
- vice and carryover relationships
- sleep -> recovery / mood / clarity relationships
- resting-heart-rate -> recovery / energy / workout-readiness relationships
- training-readiness and workout-performance relationships
- mind-and-body signals such as:
  - mental clarity
  - motivation
  - stress
  - anxiety
  - soreness

The internal engine-backed `View Lab` is expected to exercise both:
- normal / desirable states
- messy / contradictory states

That matters because the engine needs to stay coherent when user data is uneven or behavior patterns are not “ideal.”

That is now the implementation baseline going forward.

## Rebuild Principle

The new insights system can be designed as a clean engine rather than a careful incremental migration.

The product goal is to build the right long-term foundation now while the app is still early.

That means it is acceptable to:
- replace the current registry structure
- replace the current evaluator layout
- replace the current snapshot model
- rebuild surfacing logic by range

As long as the new system keeps the useful product intent:
- trustworthy relationships
- understandable insight cards
- curated active relationships
- strong dashboard relevance

## Rebuild Strategy

### Step 1: Define The New Engine Shape First

Before implementation, lock down:
- normalized input model
- day/window feature model
- relationship registry structure
- analyzer families
- insight classes
- ranking rules by range

### Step 2: Extend The Registry As The Source Of Truth

The dedicated registry is now in place.

Going forward:
- add new relationship families there
- keep one source of truth for active relationships
- avoid rebuilding scattered config homes

### Step 3: Build A Shared Feature Layer For Insights And Life Score

The new system should build a shared feature layer that both engines can read from.

That is a better long-term foundation than extending the current insights snapshot model indefinitely.

### Step 4: Rebuild Analyzers Against The New Feature Layer

Implement reusable analyzers against the new structure rather than wrapping legacy evaluators forever.

### Step 5: Rebuild Surfacing Around Time-Range Intent

Implement range-specific surfacing from the new engine:
- `Today` = briefing
- `Past 7 Days` = recent story
- `Past Year` = personal playbook

### Step 6: Add Orb / Life Score Alignment On Top Of Shared Features

Once shared features exist, score/orb logic should be added as a sibling output system.

## Target Architecture

The target system should be built in layers:

1. Source adapters
2. Normalized analysis inputs
3. Day/window feature layer
4. Relationship registry
5. Reusable analyzers
6. Scoring and ranking
7. Presentation / recommendation layer
8. Dashboard surfacing policy by time range

## Modularity Rule

The engine should be built so it can eventually move into its own package or module.

That means:
- keep core relationship models and analysis types as app-light as practical
- allow dependence on core shared models where needed
- keep app-specific adapters and legacy bridges outside the core registry/analysis layer
- avoid letting UI, dashboard view models, or feature-specific services leak deep into the engine core

### 1. Source Adapters

Raw app models should not all conform to one giant shared protocol.

Instead, each source domain should have an adapter that converts data into a shared analysis language.

Examples:
- metric entry insight source
- workout insight source
- sleep insight source
- heart / recovery insight source
- future nutrition insight source
- future menstrual-cycle insight source

### 2. Normalized Analysis Inputs

The system should normalize tracked data into shared analysis primitives.

At a high level, the engine should support two kinds of inputs:
- discrete events
- time-anchored values / signals

Examples:
- event: completed workout
- event: alcohol logged
- event: caffeine logged late
- value: mood = 7
- value: sleep duration = 6.8 hours
- value: workout performance = 8
- value: resting heart rate = 54

This is the long-term foundation that lets many domains participate in the same engine.

### 3. Day / Window Feature Layer

For V1 and near-term work, most analysis should still happen on day-based and rolling-window features.

That means the engine should derive things like:
- same-day values
- previous-day values
- next-day values
- trailing 3-day and 7-day averages
- change vs personal baseline
- short multi-day carryover windows

This is the main analysis substrate for near-term work.

### 4. Relationship Registry

The engine needs one clear place where active relationship definitions are curated.

A relationship definition should describe:
- input signal
- output signal
- time model
- allowed analyzer type
- category
- expected direction if known
- thresholds / guardrails
- recommendation family
- suppression / duplication rules

This should become the single source of truth for:
- what insight relationships are active
- which ones are experimental
- which ones are suppressed

See [relationship_registry.md](/Users/patrickdoyle/Developer/mapps/BeastFitness/docs/ai/engines/insights-and-life-score/relationship_registry.md).

### 5. Reusable Analyzers

The system should prefer a small set of reusable analyzers over many hardcoded one-off evaluators.

Initial analyzer families:
- bucket comparison
- lagged effect analysis
- rolling trend analysis
- baseline deviation analysis
- persistence / decay analysis
- follow-up / experiment outcome analysis

The goal is not fancy ML first.
The goal is reusable and explainable analysis.

### 6. Scoring and Ranking

Every candidate insight should be scored on more than just sample size.

Useful dimensions:
- confidence
- effect size
- consistency
- recency
- actionability
- novelty
- relevance to current state

### 7. Presentation and Recommendations

Analysis and presentation should be separated.

The analyzer should determine:
- what appears to be true
- how strong the effect is
- how reliable it is

The presentation layer should determine:
- title
- summary
- confidence label
- user-facing explanation
- suggested next action

Recommendations should be template-driven first, not freeform AI-generated first.

### 8. Range-Specific Surfacing

The engine should use one shared candidate pool, but different surfacing policies by range.

`Today` is not just a smaller version of `Past Year`.

## Insight Classes

The engine should explicitly support multiple kinds of insight.

Core classes:
- `RelationshipInsight`
- `TrendInsight`
- `BaselineChangeInsight`
- `FollowUpInsight`
- `RiskInsight`
- `OpportunityInsight`
- future `PopulationBenchmarkInsight`
- future `CohortInsight`

If every card is only "X affects Y", the product will get repetitive quickly.

## Time Range Strategy

### Today

Question answered:
- what matters right now?

Primary insight types:
- current-state insight
- recent-change insight
- action / lever insight
- follow-up insight

Today should be dynamic, but not random.

Current UI/product direction for `Today`:
- orb / Life Score hero
- 1 primary insight
- 2-3 lightweight drivers
- 1 suggested action
- optionally 1 lightweight "what changed" surface

`Today` should feel like a briefing, not an insight feed.
It should not show long lists of similar cards or lead with long statistical explanations.

Daily surfacing should favor:
- relevance now
- recency
- actionability
- novelty
- confidence

The product goal is:
- users should not see the exact same daily lead insight forever
- a slightly weaker but much more relevant insight can win today

### Past 7 Days

Question answered:
- what has been happening lately?

Primary insight types:
- trend insights
- baseline-change insights
- recent relationship insights
- weekly opportunity or risk insights

This is likely the richest near-term range for the product.

Current UI/product direction for `Past 7 Days`:
- this is the main insight exploration surface
- the current scrollable insight feed belongs here, refined over time
- trend and baseline-change cards should carry most of the weight here

### Past Year

Question answered:
- what have I learned about myself?

Primary insight types:
- strongest stable relationships
- long-term recurring patterns
- top levers
- future seasonal patterns

This should behave like a personal playbook, not a noisy feed.

Current UI/product direction for `Past Year`:
- show only the strongest 3-5 durable patterns
- emphasize top levers and stable truths
- do not treat this like the same insight feed with a broader filter

## Daily Insight Dynamism

Daily insights should be ranked, not randomized.

Useful inputs for a `Today` surfacing score:
- relevance to latest sleep / recovery / workouts
- relevance to last 1-3 days
- actionability today
- novelty vs recently shown insights
- confidence

The system should eventually track suppression context such as:
- recently shown relationship family
- recently shown insight type
- show count over trailing days

That is how daily insights stay fresh without feeling arbitrary.

## Current UI Strategy Constraint

The UI should not be treated as a separate concern from the engine outputs.

The engine and dashboard should continue moving toward:
- one shared candidate pool
- explicit range-specific surfacing
- one shared driver layer
- primary insight + drivers + action on `Today`

That is the shape another AI should use when brainstorming UI direction for this system.

## Recommended Build Sequence

The recommended sequence from the current implementation point is:
1. Keep finishing the shared engine outputs first:
   - drivers
   - current-state cards
   - stronger range-specific surfacing
2. Use that stable output shape to redesign the dashboard surfaces:
   - `Today`
   - `Past 7 Days`
   - `Past Year`
3. Then tighten the Life Score/orb detail flow around the same outputs.
4. Only after the surfaces feel right should premium gating and deeper monetization mechanics be finalized.

## Future Population Insights

Population and cohort insights are a future layer, not a current requirement.

They should be modeled separately from personal truths.

Examples of future distinction:
- `PersonalInsight`: "For you, alcohol tends to hurt next-day energy."
- `PopulationBenchmark`: "Your alcohol usage is lower than 70% of similar users."
- `CohortInsight`: "Among similar users, higher alcohol is associated with lower energy."

The engine should stay compatible with that future, but V1 should remain personal-first.

## Rollout Plan

### Phase 1

Design and build the new engine foundation.

Goals:
- define the new normalized input and feature layers
- define the dedicated registry
- re-express the curated relationships we still want
- separate analysis from presentation from the start
- design `Today`, `Past 7 Days`, and `Past Year` surfacing explicitly
- keep orb alignment in scope through shared features
- launch with a deliberately small set of product-approved relationships rather than trying to fill the dashboard with volume

### Phase 2

Expand the rebuilt engine across more domains and insight classes.

Goals:
- richer normalized signal layer
- more domains beyond check-in metrics
- multi-day lag support
- change-vs-baseline and follow-up insight classes

### Phase 3

Add future benchmark and cohort layers.

Goals:
- backend analytics support
- population benchmarks
- cohort comparisons
- privacy-conscious user-facing benchmark insights

## Immediate Planning Rule

When designing or implementing new insights work:
- prefer a system that can eventually compare almost any tracked input with almost any outcome
- but only activate curated, believable, product-approved relationships
- and keep one obvious registry as the place where those active relationships are defined
