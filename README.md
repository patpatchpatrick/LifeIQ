# LifeIQ

[LifeIQ](https://apps.apple.com/us/app/life-iq-health-insights/id6768780947)

**Track and improve your life and health with data.**

LifeIQ brings Apple Health data, workouts, sleep, and daily check-ins together to help you understand your health, habits, and performance. It turns everyday signals into a clearer picture of what is supporting you, what is changing, and what deserves attention.

Built for iPhone with an Apple Watch companion, LifeIQ combines a customizable dashboard with personal scores, workout analysis, and insights into patterns in your own data.

## Features

### Your health, in one place

- View HealthKit-backed activity, sleep, and heart metrics alongside your daily check-ins.
- Customize dashboard sections and their order to focus on what matters to you.
- Explore trends across daily, weekly, monthly, and yearly time ranges.

### Daily check-ins

- Track mood, energy, stress, habits, and other personal signals.
- Create custom metrics and organize them into your own groups.
- Combine self-reported context with health and workout data to build a more useful personal history.

### Scores with context

- **Life Score:** A daily snapshot of recent momentum across health, habits, recovery, training, and check-ins.
- **Recovery Score:** An estimate of readiness based on available signals such as sleep, recent workout strain, resting heart rate, and recovery check-ins.
- **Sleep Score:** A summary of the latest completed night or selected completed-night window, with sleep summaries and phase trends.
- **Performance Score:** Workout output relative to your own history.
- **Difficulty Score:** An estimate of how taxing a workout was, driven primarily by heart-rate load.

LifeIQ's scores are guides for reflection and everyday decisions, not medical assessments.

### Workouts and Apple Watch

- Review workout history, totals, and activity summaries.
- Explore workout details such as splits, heart-rate information, and performance context where available.
- Use the Apple Watch companion for workout sessions, with shared workout models and connectivity between apps.
- Display measurements in imperial or metric units.

### Personal insights

- Discover patterns across check-ins, sleep, workouts, and health data.
- See how habits may be associated with changes in mood, energy, recovery, or performance.
- Use the premium **Insight Explorer** to compare tracked signals, inspect timing offsets, and review matched samples and confidence.

Insights describe associations in your logged data. Their usefulness depends on the amount and consistency of available data; a relationship does not establish causation.

## Technology

| Area | Technology |
| --- | --- |
| Apps | Swift, SwiftUI, and UIKit-backed shared controls |
| Health data | HealthKit |
| Local persistence | SwiftData |
| Cloud and accounts | Firebase Authentication, Cloud Firestore, Google Sign-In |
| Runtime controls | Firebase Remote Config |
| Subscriptions | StoreKit |
| Analytics and diagnostics | Amplitude, Firebase Analytics, Crashlytics |
| Shared app logic | Local `BeastFitnessCore` Swift package |
| Charts | Local `CoolCharts` Swift package |
| Dependencies | Swift Package Manager |

## Requirements

- macOS with Xcode and a toolchain that supports Swift 6.2, as required by `BeastFitnessCore`.
- iOS 18.0 or later.
- watchOS 11.5 or later for the Apple Watch app.
- Appropriate Apple signing and service configuration for device testing.

## Getting started

1. Clone the repository and open `BeastFitness.xcodeproj` in Xcode.
2. Allow Xcode to resolve the Swift Package Manager dependencies.
3. Select the `LifeIQ-Staging` scheme for development. The `LifeIQ-Prod` scheme uses the production configuration.
4. Configure signing for the iOS and watchOS targets as needed.
5. Verify the Firebase configuration for your environment under `BeastFitness/Resources/GooglePList/`. The app selects `GoogleService-Info-Staging.plist` or `GoogleService-Info-Prod.plist` through the `LIFEIQ_FIREBASE_ENVIRONMENT` build setting. If using your own backend, update the Firebase files, bundle identifiers, and related sign-in configuration together.
6. Configure `LIFEIQ_AMPLITUDE_API_KEY` if analytics are needed. Amplitude is disabled when the key is missing.
7. Choose a simulator or connected device and run the app.

Use a physical iPhone and Apple Watch to validate real health data and workout behavior. For dashboard development without populated HealthKit data, review `SQAdminConfig.useMockDashboardHealthData` in `BeastFitness/Utility/SQAdminConfig.swift`.

Subscription testing requires the corresponding StoreKit or App Store Connect sandbox setup.

## Repository structure

```text
BeastFitness/                       iOS app
  CoreFiles/                        App lifecycle and setup
  Models/                           Domain and persistence models
  StateManagement/                  Shared application state and events
  Managers/                         Services and app-wide infrastructure
  Networking/                       Network and Firestore routes
  ViewModels/                       Screen controllers and presentation models
  Views/                            Feature screens and shared views
  UI/                               Shared design tokens and UI helpers
  Utility/                          HealthKit integration and utilities
Beast Fitness Watch Watch App/      Apple Watch companion
Packages/
  BeastFitnessCore/                 Shared logic and models
  CoolCharts/                       Reusable chart components
BeastFitnessTests/                  iOS unit tests
BeastFitnessUITests/                iOS UI tests
docs/ai/                           Product and implementation documentation
```

The product is named **LifeIQ**. Project files, targets, modules, and some internal identifiers retain the legacy **BeastFitness** name.

## Architecture and development

Shared application state lives in `SQAppState.shared`, with cross-feature updates delivered through hub events. Views render presentation models and call controllers; controllers delegate persistent work and side effects to services or established managers.

Reusable logic belongs in `BeastFitnessCore`, and reusable charts belong in `CoolCharts`.

Before contributing, read [AGENTS.md](AGENTS.md) and the relevant project documentation:

- [Product context](docs/ai/product_context.md)
- [Product vision](docs/ai/product_vision.md)
- [Score and feature definitions](docs/ai/Definitions.md)
- [Architecture](docs/ai/architecture.md)
- [Shared UI](docs/ai/shared_ui.md)
- [Privacy and security](docs/ai/privacy_security.md)
- [HealthKit and data](docs/ai/healthkit_data.md)
- [Testing guidance](docs/ai/testing.md)

HealthKit-backed screens should handle missing, partial, delayed, or denied data. Keep sensitive health values, private check-in content, credentials, and payment payloads out of logs and analytics.
