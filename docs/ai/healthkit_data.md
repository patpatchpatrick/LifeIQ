# HealthKit and Data Guidance

HealthKit is one of LifeIQ's core inputs. The app should support HealthKit data thoughtfully, permission-safely, and with room to adopt new Apple health capabilities over time.

## Product Role

HealthKit data should help LifeIQ understand:

- sleep
- heart and recovery context
- workouts and activity
- trends over time
- future health domains where Apple provides useful data and the app can explain it responsibly

HealthKit data should rarely be shown as raw data alone. Prefer connecting it to status, trends, scores, or insights.

## Adding HealthKit Support

When adding or expanding HealthKit support:

- check the latest official Apple HealthKit documentation
- confirm availability by iOS/watchOS version
- request only the permissions needed for the feature
- handle missing, denied, delayed, or partial data
- support source-aware behavior where different devices/apps may write different sample types
- use existing `SQHealthKitManager` patterns before introducing new HealthKit access points
- add mock data paths when the UI must be developed or tested without real HealthKit data

## Data Interpretation

- Do not imply medical diagnosis.
- Do not overstate precision.
- Explain uncertainty through confidence, evidence windows, or quieter copy.
- Prefer trends and patterns over isolated samples.
- Use HealthKit plus check-ins when that combination creates a better explanation.

## Time Ranges and Boundaries

- Use `SQTimeRange` date boundaries where applicable.
- Follow existing sleep semantics: completed nights only, anchored to latest completed wake day.
- Be careful with timezone and day-boundary assumptions.
- Use `SQDateFormatters` for display.

## Watch and iOS Sync

Workout-related behavior is cross-app.

- Keep iOS and watch payloads aligned when changing workout behavior.
- Avoid adding iOS-only workout fields without considering watch implications.
- Preserve source-specific handling through `SQWorkoutSourceable`.

## Future Health Domains

LifeIQ should remain open to future HealthKit categories and Apple platform additions, including areas such as cycle tracking, symptoms, medication, respiratory metrics, mobility, nutrition, mindfulness, and new workout or recovery signals.

Do not add a HealthKit domain just because it exists. Add it when:

- it supports the product vision
- the data is reliable enough for the intended use
- the app can explain it clearly
- permissions and privacy are handled carefully
- missing data does not break the experience

## Mock and Simulator Support

HealthKit-backed screens should be testable without perfect real-world data.

- Keep `SQAdminConfig.useMockDashboardHealthData` in mind for dashboard work.
- Extend mock paths for new health surfaces where practical.
- Use realistic missing-data and denied-permission states.
