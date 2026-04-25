# Relationship Registry Plan

This document defines how active relationships and supported insights should be curated.

## Goal

There should be one clear place where the app defines:
- which relationship types are active
- which inputs and outcomes are allowed to be compared
- what timing models are valid
- what recommendation family is attached
- what copy / category / suppression guidance applies

This is the planning source of truth for that concept.

## V1 Scope Rule

For V1, the registry should prioritize quality over breadth.

That means:
- support a small number of active relationships at launch
- make it easy to add more later without redesigning the system
- avoid turning the launch dashboard into a noisy list of weak cards

## Where Active Relationships Live Today

The active relationship source of truth now lives in:
- [SQInsightRelationshipRegistry.swift](/Users/patrickdoyle/Developer/mapps/BeastFitness/BeastFitness/Managers/Insights/SQInsightRelationshipRegistry.swift)

And the underlying relationship model now lives in:
- [SQInsightRelationshipDefinition.swift](/Users/patrickdoyle/Developer/mapps/BeastFitness/BeastFitness/Models/Insights/SQInsightRelationshipDefinition.swift)

That is now the place to look for:
- which relationship families are active
- which variants are active
- what categories, recommendation families, timing models, analyzer families, and eligible dashboard ranges are attached

## Current Structure

The current structure is:
- `BeastFitness/Managers/Insights/SQInsightRelationshipRegistry.swift`
- `BeastFitness/Models/Insights/SQInsightRelationshipDefinition.swift`

That is now the maintainable place for product-approved relationships.

## Working Rule

New active relationships should be added to the dedicated registry.

Do not add new active relationship definitions back into `SQInsightsService` or scattered evaluator config blocks.

## What A Relationship Definition Should Capture

Each relationship should eventually describe:
- relationship id
- input signal
- output signal
- timing model
- analyzer family
- eligible surface intents / dashboard ranges
- insight class
- category
- expected direction if known
- minimum data requirements
- effect thresholds
- recommendation family
- presentation hints
- suppression / dedupe family
- whether it is active, experimental, or disabled

## Example Kinds Of Relationships

Examples the registry should eventually support:
- alcohol -> next-day energy
- alcohol -> next 2-day mood carryover
- sleep duration -> same-day workout performance
- workout temperature -> next-day mood
- workout performance -> next-day motivation
- caffeine timing -> same-night sleep quality
- weed usage -> REM sleep
- future nutrition input -> digestion, sleep, or energy outcomes
- future menstrual phase -> mood, recovery, or workout outcome relationships

The key idea is:
- the engine should be general enough to support many domains
- the registry should remain curated enough to avoid nonsense

## Active Relationship Policy

The app should not automatically activate every pair of signals.

A relationship should become active only when it is:
- believable
- explainable
- product-relevant
- worth surfacing to users

That keeps the system from turning into a pile of weak or embarrassing cards.

## Recommendation Policy

Recommendations should not be handwritten separately in many evaluators forever.

Each relationship should eventually map to a recommendation family such as:
- reduce
- increase
- shift earlier
- shift later
- keep consistent
- protect recovery
- moderate strain
- observe and compare

The presentation layer can then generate user-facing copy from structured relationship metadata.

## Current Working Rule

The registry is already extracted into dedicated code.

The current code-level source of truth for active relationship definitions is:
- `SQInsightRelationshipRegistry.activeRelationships`

The runtime now uses that registry for more than one analyzer family:
- relationship / bucket comparison
- recent trend
- baseline deviation
