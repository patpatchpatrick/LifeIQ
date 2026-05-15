# LifeIQ Product Vision

## One-Line Vision

LifeIQ turns health data, workouts, sleep, and daily check-ins into clear, personal guidance for becoming healthier and more capable over time.

## Product Framing

LifeIQ should not feel like a generic health dashboard or a pile of charts. HealthKit, workouts, and self-tracking are inputs. The product value is the intelligence layer that helps the user understand what is happening and what to do next.

The app should increasingly answer:

- What is supporting my health right now?
- What is dragging me down?
- What patterns keep repeating across sleep, training, habits, mood, energy, and recovery?
- What should I pay attention to today?

The long-term direction is personal health intelligence: a concise, trusted view of the user's physical and behavioral signals, with insights that get better as the app understands more of their life.

## Core Problem

People can collect a lot of health data but still struggle to interpret it. Apple Health, wearables, workout apps, and habit trackers often show isolated metrics. Users still have to connect the dots themselves.

LifeIQ should reduce that interpretation burden by combining:

- HealthKit signals
- workout history and workout context
- sleep and recovery patterns
- daily check-ins
- habits, vices, and custom self-tracked metrics

The product should help users notice meaningful relationships without forcing them to become data analysts.

## Product Promise

LifeIQ helps users understand:

- how their sleep, habits, workouts, and check-ins relate
- which trends are improving or worsening
- what behaviors are likely supporting energy, mood, recovery, and performance
- when a signal deserves attention
- what small adjustments may help them feel and perform better

Insights should be actionable, personal, and evidence-aware. They should not overstate certainty or sound medical.

## Product Levels

### Level 1 - Unified Tracking

- HealthKit-backed metrics
- workout history
- daily check-ins
- custom metrics
- clear dashboard sections

### Level 2 - Scores and Summaries

- Life Score
- Recovery Score
- Sleep Score
- workout performance and difficulty context
- concise trend summaries

### Level 3 - Personal Insights

- relationships across sleep, habits, workouts, and check-ins
- insight confidence and evidence windows
- plain-language interpretation
- filters and exploration for premium users

### Level 4 - Guidance and Coaching

- prioritized actions
- personalized habit and recovery recommendations
- deeper pattern exploration
- proactive follow-up questions
- long-term progress feedback

## Future Health Direction

LifeIQ should continue expanding HealthKit coverage when it adds meaningful user value. Future candidates include additional sleep, heart, respiratory, reproductive health, mobility, nutrition, mindfulness, symptom, and workout-adjacent data types where Apple exposes reliable APIs and the app can explain the data responsibly.

When adding HealthKit functionality:

- check the latest official Apple HealthKit documentation
- prefer source-specific and permission-aware implementations
- handle missing, partial, delayed, or denied data gracefully
- add mock data support when the surface is important for simulator or UI development
- avoid medical diagnosis language
- connect the signal to useful product context rather than displaying raw data alone

## Prioritization Rule

Prioritize features in this order:

1. trustworthiness of health interpretation
2. actionable user value
3. clarity and low cognitive load
4. reliable data handling
5. daily usefulness and retention
6. monetization polish
7. visual polish beyond the shared UI system

## Product Non-Goals

- Do not build a medical diagnosis app.
- Do not make every metric equally prominent.
- Do not overwhelm users with every possible correlation.
- Do not add HealthKit data only because it exists.
- Do not make the app feel like a clinical record viewer.

## Relationship to Existing Docs

- Feature and score definitions live in `docs/ai/Definitions.md`.
- Insights and Life Score engine direction lives under `docs/ai/engines/`.
- This doc should guide product decisions without duplicating detailed engine specs.
