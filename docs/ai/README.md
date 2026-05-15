# LifeIQ AI Docs

This folder contains durable product, architecture, and implementation guidance for AI assistants working in the LifeIQ / BeastFitness repo.

## Core Docs

- `product_context.md`: product brief, brand direction, and product intent.
- `product_vision.md`: long-term product direction and prioritization.
- `Definitions.md`: source of truth for score and feature definitions.
- `rules.md`: durable implementation and product rules.
- `architecture.md`: app-layer responsibilities and boundaries.
- `ux_content.md`: copy, content density, and UX communication rules.
- `shared_ui.md`: shared component and design-system guidance.
- `privacy_security.md`: privacy, security, sensitive data, and subscription safety guidance.
- `healthkit_data.md`: HealthKit expansion and data interpretation guidance.
- `observability.md`: logging, analytics, Firestore metrics, and debugging guidance.
- `testing.md`: testing and manual verification priorities.

## Engine Docs

- `engines/insights-and-life-score/README.md`: planning and design guidance for Insights, Life Score, and related engines.

## Maintenance Rule

When a decision should shape future code or product behavior, add it to the most specific doc here and link it from `AGENTS.md` only when agents should check it routinely.

Use `rules.md` for short durable rules. Use the topic-specific docs for deeper guidance.
