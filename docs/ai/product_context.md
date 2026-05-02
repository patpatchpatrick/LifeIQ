# LifeIQ Product Context

This document is the stable AI-facing product brief for the LifeIQ app. It should be treated as the default product context for AI assistants working in this repository.

Product-facing score and feature definitions live in [Definitions.md](/Users/patrickdoyle/Developer/mapps/BeastFitness/docs/ai/Definitions.md). Treat that file as the source of truth for Life Score, Recovery Score, Insights, Performance Score, Difficulty Score, and future score definitions.

## Product Summary

LifeIQ helps people track and improve their life and health with data.

The product combines:
- Health data from Apple Health / HealthKit
- Workout history and workout summaries
- Daily self-tracked check-ins such as mood, energy, stress, recovery, sleep, nutrition, alcohol, caffeine, and custom metrics

The goal is to help users understand what is helping or hurting their health, recovery, energy, mood, and performance.

Life Score is a daily snapshot of the user's recent momentum. It looks at signals like sleep, recovery, workouts, habits, and check-ins to estimate whether the user's life is trending in a healthy direction. It is not a medical score - it is a guide to help the user notice what's supporting them and what may need attention.

Life Score should read as a practical "am I on track?" signal: a measure of whether the user's health, habits, recovery, training, and self-reported state are generally headed in a positive direction. Healthy behaviors such as working out more, performing well, or completing meaningful activity should generally support the score. Training should only become a drag when paired with evidence of overreaching, poor recovery, or repeated high-intensity strain. Too many days of inactivity can become a mild drag, but normal rest days should not be treated as failure.

## Mission

Track and improve your life and health with data.

A slightly longer product framing:
- LifeIQ turns health data, workouts, and daily check-ins into patterns and guidance a person can actually use.
- The app should help users answer questions like:
  - How did I sleep?
  - How am I recovering?
  - How are my habits affecting my mood, energy, and training?
  - What trends are improving, and what is getting worse?

## Core Product Loop

The core loop of the app is:
1. Connect Health data and log daily check-ins.
2. Review the dashboard for current status, trends, and patterns.
3. Learn from workouts, sleep, heart data, and habits over time.
4. Adjust behavior and training.
5. Come back daily and repeat.

The app should feel like a personal health intelligence layer, not just a passive data viewer.

## Who The Product Is For

LifeIQ is for people who care about their health, training, recovery, habits, and daily performance, and who want to understand those things more clearly.

Typical users may include:
- fitness-minded people who train regularly
- people trying to improve sleep, energy, or mood
- people tracking habits like alcohol, caffeine, nicotine, weed, or custom behaviors
- users who want a more reflective and actionable layer on top of Apple Health data

## Product Principles

- Actionable over decorative: the app should help users make better decisions, not just admire charts.
- Clear over clinical: the app should feel intelligent and polished without reading like a medical dashboard.
- Daily use matters: the product should reward frequent use with quick wins and growing long-term insight quality.
- Trend-aware: the app should highlight changes, comparisons, and patterns rather than isolated point values.
- Health + self-report together: HealthKit alone is not enough, and self-tracking alone is not enough. The combination is a core differentiator.

## Brand Context

- Product-facing name: `LifeIQ`
- Internal legacy naming may still use `BeastFitness`
- Mascot: `Que`
- Que is the glowing orb used throughout the product brand
- The orb also represents the LifeIQ score / recovery-intelligence object in parts of the product language and UI

Brand intent for Que:
- Que should feel like a focused intelligent companion, not a gimmick
- The orb should be used as a meaningful product object, especially around score/status/recovery concepts
- Avoid using the orb as random decorative filler

## What The App Does Today

The app currently centers around a few major surfaces:

### Dashboard

The dashboard is the primary product surface.

It is intended to surface:
- recovery / readiness
- sleep summaries and sleep phases
- heart-related trends
- workout totals and workout history
- daily check-in metrics
- insights derived from relationships between habits, sleep, workouts, and check-ins

The dashboard should feel like the user’s health home screen.

### Daily Check-Ins

Daily check-ins let the user record:
- subjective state, such as mood, energy, or clarity
- behaviors and habits, such as alcohol or caffeine
- custom user-defined metrics

Check-ins are a core input into the insight engine and should be easy to complete consistently.

### Workouts

Workout functionality includes:
- workout history
- workout summaries
- workout details such as splits, heart-rate information, and derived performance context

Workouts are not just archival. They are one of the main lenses through which the app helps users understand performance and recovery.

### Sleep and Heart Data

HealthKit-backed sleep and heart data are important parts of the product.

Sleep is especially important because it feeds:
- readiness / recovery concepts
- sleep score and sleep trends
- next-day pattern analysis

Heart data supports:
- current-state dashboard health context
- workout summaries
- longer-term cardio / recovery interpretation

### Insights

Insights are a core differentiator of the app.

They connect:
- check-ins
- workouts
- sleep
- health data

The purpose of insights is to help users understand patterns such as:
- higher alcohol tends to reduce next-day energy
- more sleep tends to improve energy or workout quality
- certain habits may hurt or help mood, motivation, or recovery

Insights should feel:
- understandable
- evidence-based
- concise
- personally relevant

## Current Product Direction

The current product emphasis is strongest on iOS, especially the dashboard experience.

Current priorities include:
- making the dashboard feel polished, clear, and useful
- improving the quality and trustworthiness of health/workout/check-in integration
- surfacing meaningful patterns and trends
- making major flows work well on both large phones and constrained devices like `iPhone SE (2nd generation)`

## UX Expectations

- The app should feel premium, intentional, and focused.
- The dashboard should feel digestible even when it is information-rich.
- Users should be able to move between quick status checks and deeper detail.
- Important empty states should feel helpful, not broken.
- Historical browsing should be possible without making common daily flows slower or noisier.

## Technical/Product Reality

- HealthKit data may be missing, delayed, denied, or partial. The app must handle that gracefully.
- Many parts of the app rely on local SwiftData plus cloud sync rather than live server fetches for every screen.
- Mock data support is important for simulator and UI development, especially for Health-backed screens.
- The app has both iOS and watchOS components, and workout-related behavior often needs to stay aligned across both.

## How To Use This Doc

Use this file as:
- the stable product brief for AI assistants
- the first context document to mirror into ChatGPT Projects
- the base layer for future docs such as:
  - `docs/ai/current_focus.md`
  - `docs/ai/architecture.md`
  - `docs/ai/decisions.md`

This file should stay relatively stable. Put fast-changing workstream details in separate AI docs rather than continuously expanding this one.
