# LifeIQ AI Rules

This file tracks durable implementation and product rules for AI assistants working in this repository. Add rules here when a decision should consistently shape future code, UI, docs, or product reasoning.

## UI Controls

- Prefer the shared `SQDropDownMenu` / `SQDropDownMenuViewModel` style for dropdowns and multi-value single-selection fields. Avoid introducing native SwiftUI picker/menu styling for app surfaces unless there is a specific product reason.

## Definitions

- Keep score and feature definitions in `docs/ai/Definitions.md`. Life Score, Recovery Score, Insights, Performance Score, Difficulty Score, and future feature explainers should use that file as the source of truth before in-app copy or AI guidance is changed.

