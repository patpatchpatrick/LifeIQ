# Agent Notes (BeastFitness)

## Apps in this repo

This project contains **two apps** that work together:

1. **BeastFitness**
   - iOS app.
   - Primary focus for current UI/product work.

2. **Beast Fitness Watch Watch App**
   - watchOS app.
   - Communicates with the iOS app for workout experiences.

## How they work together

- When starting workouts in the **iOS app**, it communicates with the **Watch app**, and vice versa.
- Any changes involving workout flows should consider both sides of the connection and keep payloads/state in sync.

## Current focus

We are currently focused on building a **strong, beautiful dashboard** in the iOS app that displays:

- **HealthKit** statistics (e.g., performance metrics and trends)
- **Workouts** history and summaries
- **Daily stats/habits** that we track ourselves (e.g., mood, alcohol use, energy levels, etc.)

## Shared module

- We use a shared module called **BeastFitnessCore**.
- Shared code such as extensions, utilities (e.g., logging), and reusable business logic should generally live in **BeastFitnessCore** so it can be reused across app targets/modules.
- We use a local package called **CoolCharts** for all chart/graph components. Any chart visualizations should be added to or used from CoolCharts.

## UI conventions

- **Always use `SQColor` for colors** — Never use SwiftUI's `Color` directly. Use `.sqForegroundColor()` and `.sqBackgroundColor()` modifiers.
- **Always use `SQFont` for fonts** — Never use SwiftUI's `Font` directly. Use `.sqFont()` modifier.  Example: (SQFont(type: .bodySmall).font)
- **Always use `SQImageSymbol` for SF Symbols** — Never use hardcoded string literals in `Image(systemName:)`. All SF Symbols must be defined in the `SQImageSymbol` enum (found in `BeastFitness/UI/SQImage.swift`) to ensure we track all icons centrally. If a symbol you need doesn't exist in the enum, add it there first before using it.
  - Use `SQImageView` with `SQImage(symbol: .symbolName)` for rendering symbols with proper styling
  - Example: `SQImageView(image: .init(symbol: .chevronUp, symbolStyle: .colorWithFont(.textPrimary, font: .bodySmall)))`
- **Use shared components for common UI patterns** — For collapsible section headers, use `SQCollapsibleSectionHeader` to ensure consistent styling across dashboard sections.
- These wrappers ensure consistent theming and styling across the app.
## Coding style

- **Prefer stored properties over computed properties** — When a value can be calculated once and stored, use a stored property with `didSet` observers to update it when dependencies change, rather than recalculating via computed properties on every access.
## Product goal

Use all available data (HealthKit + workouts + self-tracked habits) to build a dashboard that provides:

- Clear, actionable **insights** into a user’s life
- Valuable, easy-to-understand **trends over time**
- A modern, polished UI with strong information hierarchy
