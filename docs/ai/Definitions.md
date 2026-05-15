# LifeIQ Definitions

This document is the source of truth for product-facing score and feature definitions in LifeIQ. Keep in-app explainers, alerts, docs, onboarding copy, and AI assistant guidance aligned with these definitions.

## Life Score

Life Score is a daily snapshot of the user's recent momentum. It looks at signals like sleep, recovery, workouts, habits, and check-ins to estimate whether the user's life is trending in a healthy direction. It is not a medical score - it is a guide to help the user notice what's supporting them and what may need attention.

Life Score should read as a practical "am I on track?" signal across health, habits, recovery, training, and self-reported state. Healthy behavior and positive momentum should generally support the score. Training should become a drag only when the broader context suggests overreaching, poor recovery, repeated high-intensity strain, or too much inactivity. A normal rest day should not be treated as failure. Soreness by itself should not meaningfully lower Life Score; it is better treated as Recovery Score/readiness context and as an insight signal unless it stacks with other strain evidence.

## Insights

Insights look for patterns across check-ins, sleep, workouts, and health data so users can better understand what affects their mood, energy, recovery, and performance.

Users might see insights like "Low sleep may be linked to lower mood" or "Caffeine is trending higher recently."

The more check-ins users complete, the more personal and accurate insights become. Early insights may be simple, but they should get stronger as LifeIQ learns the user's patterns.

## Insight Explorer

Insight Explorer is a premium exploration surface that lets users compare two tracked signals and inspect the strongest detected relationships in their own logged data.

It should show associations across practical time windows and timing offsets, including top relationships, matched sample counts, confidence, and directional summaries. Copy must stay non-causal unless LifeIQ has a stronger evidence model; use wording like "may be linked to", "averages higher after", or "pattern in your logged data" rather than claiming that one metric directly causes another.

Free users may see a locked preview entry point, but the relationship detail surface is premium.

## Recovery Score

Recovery Score estimates how ready and recovered the user appears today based on the available recovery signals.

It starts from a neutral baseline and adjusts using signals such as sleep, recent workout strain, recovery-related check-ins, resting-heart-rate context, and custom metrics marked for Recovery Score. Missing signals are omitted rather than treated as bad data.

Recovery Score should feel like a readiness and physical recovery signal, not a moral judgment. Lower values should indicate likely strain, poor recovery, or a need to pay attention; higher values should indicate stronger readiness and recovery support.

## Sleep Score

Sleep Score summarizes the quality and usefulness of the user's latest completed sleep period or selected completed-night window.

It should be anchored to completed nights, use HealthKit sleep when available, and stay transparent about the source. When HealthKit sleep is missing, sleep-related check-ins may provide fallback context where appropriate.

## Performance Score

Performance Score is a personalized workout-output score. It describes how strongly a workout performed relative to the user's own workout history.

For runs, it is centered around a VDOT-style estimate where faster sustained pace over meaningful distance improves the score. For cycling, it is centered around sustained speed over meaningful distance and duration. Higher values should mean stronger personal performance, not necessarily a harder workout.

## Difficulty Score

Difficulty Score estimates how taxing a workout was for the user.

It is driven primarily by heart-rate load, where time in higher heart-rate zones contributes more than easy aerobic time. It should use a standardized zone-load scale rather than ranking the score against the user's workout history. Short high-intensity efforts should receive enough load-intensity credit that they are not underrated purely because they accumulated fewer total minutes than longer aerobic sessions. Same-sport history may be shown as context, but higher values should mean the workout was harder to absorb for that sport, not necessarily better.
