# Agent Notes (BeastFitness)

## Referenced projects

**SportsPulse** (`/Users/patrickdoyle/Code/mapps/SportsPulse`) is available as a read-only reference. Do not edit any files in SportsPulse unless explicitly instructed to do so. It may be used for looking up patterns, shared conventions, or code examples when directed.

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

### Daily Check-In Metrics Organization

Metrics have a `group: String` property on `SQMetricDefinition`. Groups are user-facing strings and fully dynamic — users can create their own. Well-known defaults are defined in `SQDefaultGroup` (`BeastFitness/Models/DailyCheckIn/SQMetric.swift`):

- **Self** (`.personal`) — Physical and mental state metrics: mood, energy, mental clarity, soreness/recovery, sleep hours, sleep quality
- **Habit** (`.habit`) — Behavioral tracking metrics: alcohol, weed, porn, caffeine, meditation
- **General** (`.general`) — Fallback group for uncategorized or user-created metrics

The dashboard renders a collapsible section per group, ordered by the first metric's `sortOrder` within that group. The metric form lets users pick from existing groups or type a new one.

## Shared module

- We use a shared module called **BeastFitnessCore**.
- Shared code such as extensions, utilities (e.g., logging), and reusable business logic should generally live in **BeastFitnessCore** so it can be reused across app targets/modules.
- We use a local package called **CoolCharts** for all chart/graph components. Any chart visualizations should be added to or used from CoolCharts.

### Time Range Utilities

**SQTimeRange** provides standardized date ranges for querying data:

```swift
// Available time ranges
SQTimeRange.today      // Today (midnight to now)
SQTimeRange.pastWeek   // Past 7 days
SQTimeRange.pastYear   // Past year
// ... etc

// Each time range has start and end dates
let startDate = SQTimeRange.pastWeek.startDate
let endDate = SQTimeRange.pastWeek.endDate

// Example: Fetching data for a specific time range
let checkIns = try SQDailyCheckInEntity.getAll(
    from: SQTimeRange.pastWeek.startDate,
    to: SQTimeRange.pastWeek.endDate,
    context: context
)
```

**Important:** Always use `SQTimeRange` date properties instead of manually calculating dates. This ensures consistency across the app.

## State Management Architecture

All application state is centralized in **SQAppState** (singleton: `SQAppState.shared`):

```swift
@MainActor
@Observable final class SQAppState {
    let hub: EventHub               // Event bus for cross-component communication

    let userState: SQUserState      // User authentication state
    let navigationState: NavigationState
    let dashboardState: DashboardState
    let workoutSessionState: WorkoutSessionState
    // ... etc
}
```

### Creating New State Objects

Follow this pattern (see `SQUserState` or `SettingsState` for examples):

1. **Create protocol** defining the state interface:
```swift
@MainActor
protocol MyFeatureStating: AnyObject {
    var hub: EventHub { get }
    // Add your state properties/methods here
}
```

2. **Create state class** implementing the protocol:
```swift
@MainActor
@Observable final class MyFeatureState: MyFeatureStating {
    let hub: EventHub

    // Your state properties
    var someValue: String = ""

    init(hub: EventHub) {
        self.hub = hub
    }
}
```

3. **Add to SQAppState**:
```swift
// In SQAppState.swift
let myFeatureState: MyFeatureState

// In init():
self.myFeatureState = .init(hub: hub)
```

4. **Access from anywhere**:
```swift
let currentUser = SQAppState.shared.userState.loggedInUser
```

### State Benefits
- **Centralized**: All state in one place
- **Observable**: SwiftUI views auto-update when state changes
- **Event-driven**: Use `hub` for cross-component communication
- **Type-safe**: Protocol-based design

## Date Formatting Conventions

**Always use `SQDateFormatters`** for formatting dates — Never create `DateFormatter` instances directly. Use the shared `SQDateFormatters.shared` singleton with predefined styles:

### Available Styles

- `.short` - Example: "1/28/23"
- `.medium` - Example: "Jan 28, 2023"
- `.long` - Example: "January 28, 2023"
- `.full` - Example: "Saturday, January 28, 2023 at 3:42 PM"
- `.fullWithoutDayName` - Example: "January 28, 2023 at 3:42 PM"
- `.timeOnly` - Example: "3:42 PM"
- `.firebaseDayKey` - Example: "2025-01-22" (for Firestore keys)

### Usage

```swift
// Using the Date extension (preferred)
let dateString = myDate.formattedString(with: .medium)

// Using SQDateFormatters directly
let dateString = SQDateFormatters.shared.string(from: myDate, style: .medium)

// Firestore day key
let dayKey = myDate.firebaseDailyDateKey
```

## Logging Conventions

We use **SQLogger** (from BeastFitnessCore) for all logging:

### Basic Usage

**iOS apps** - use `log()`:
```swift
SQLogger.shared.log(
    "Message here",
    .info,                    // Level: .debug, .info, .log, .error
    context: .dailyCheckIn    // Context: categorizes logs
)
```

**watchOS apps** - use `logW()`:
```swift
SQLogger.shared.logW(
    "Message here",
    .info,
    context: .workoutSession
)
```

### Available Contexts (iOS)

- `.general` - General app events
- `.dailyCheckIn` - Daily check-in operations
- `.dashboard` - Dashboard loading/updates
- `.workoutSession` - Workout tracking
- `.healthKit` - HealthKit operations
- `.metricsManager` - Metrics management
- `.dataProcessing` - Data sync/processing
- ... (see `SQiOSLogContext` for full list)

### Log Levels

- `.debug` - Detailed debugging info (verbose)
- `.info` - General informational messages
- `.log` - Standard operational logs
- `.error` - Error conditions

### Priority Logs

Use `isPriority: true` for important logs that should stand out:
```swift
SQLogger.shared.log(
    "✅ Sync completed: 42 documents fetched",
    .info,
    context: .dailyCheckIn,
    isPriority: true  // Adds visual separators
)
```

### Best Practices

1. **Log sync operations** with document counts:
   ```swift
   SQLogger.shared.log(
       "Fetched \(stats.count) documents from Firestore",
       .info,
       context: .dailyCheckIn
   )
   ```

2. **Log errors with context**:
   ```swift
   SQLogger.shared.log(
       "Failed to save: \(error.localizedDescription)",
       .error,
       context: .dailyCheckIn
   )
   ```

3. **Use appropriate contexts** - helps filter logs in Console.app
4. **Mark important events as priority** - easier to spot in logs

## Networking conventions

We use **Firestore** as our backend with a custom networking layer built around routes and services:

### Architecture Components

- **SQFirestoreRoute** (protocol) — Defines a route with a Firestore reference and optional write body
  - Routes are enums that represent specific API operations
  - Each route returns a `SQFirestoreReference` (documentRead, documentWrite, collection, or query)
  - Write routes must provide a `writeBody: Encodable?`

- **SQNetworkService** (base class) — Executes routes and handles Firestore operations
  - `performRequest<T: Codable>(_ route: SQFirestoreRoute) async throws -> T`
  - Automatically handles read/write operations based on the route's reference type
  - Write operations use `SQVoidWrite` as the return type

- **Service classes** (e.g., `SQDailyCheckInService`) — Domain-specific services that inherit from `SQNetworkService`
  - Define high-level operations (e.g., `saveDailyCheckInStats`, `fetchAllDailyCheckIns`)
  - Call `performRequest()` with the appropriate route

### Example: Adding a new network operation

1. **Define the route** in the appropriate route enum (e.g., `SQDailyCheckInRoute`):
```swift
enum SQDailyCheckInRoute {
    case fetchAllDailyCheckIns(SQUser, afterDate: Date?)
}

extension SQDailyCheckInRoute: SQFirestoreRoute {
    func reference(in db: Firestore) -> SQFirestoreReference {
        case .fetchAllDailyCheckIns(let user, let afterDate):
            let query = db.collection("users/\(user.id)/daily-check-in-summaries")
                .whereField("date", isGreaterThan: afterDate ?? .distantPast)
            return .query(query)
    }
}
```

2. **Add the service method**:
```swift
static func fetchAllDailyCheckIns(for user: SQUser, afterDate: Date? = nil) async throws -> [SQDailyCheckInStats] {
    try await performRequest(SQDailyCheckInRoute.fetchAllDailyCheckIns(user, afterDate: afterDate))
}
```

### Optimization: Incremental Sync

Always use `afterDate` parameters for syncing to minimize Firestore reads:
- First sync: `fetchAllDailyCheckIns(for: user, afterDate: nil)` fetches all
- Subsequent syncs: `fetchAllDailyCheckIns(for: user, afterDate: lastSyncDate)` fetches only new data

### Firestore Metrics Tracking

**IMPORTANT**: All Firestore reads and writes must be tracked using `SQFirestoreMetricsManager` for cost monitoring.

#### Usage

Call `recordReads()` after fetching documents from Firestore:
```swift
let documents = try await fetchFromFirestore()

// Track the reads
Task { @MainActor in
    SQFirestoreMetricsManager.shared.recordReads(
        documents.count,
        operation: "Fetch daily check-ins"
    )
}
```

This logs:
- Number of reads for this operation
- Cumulative session total
- Session duration

Example log output:
```
📊 Firestore: 7 reads for 'Fetch daily check-ins' | Session total: 15 reads (3m)
```

#### Where to Add Tracking

- **Network Service Layer**: Already integrated in `SQNetworkService.decodeTypedArray()` for collection/query fetches
- **New Firestore Operations**: Add tracking immediately after any new Firestore read/write operations
- **Custom Queries**: Track reads when using Firestore directly outside the standard network layer

#### Why This Matters

Firestore charges per document read/write. Tracking metrics helps:
- Monitor costs during development
- Identify expensive operations
- Optimize sync strategies
- Catch accidental over-fetching

## UI conventions

- **Always use `SQColor` for colors** — Never use SwiftUI's `Color` directly. Use `.sqForegroundColor()` and `.sqBackgroundColor()` modifiers.
- **Always use `SQFont` for fonts** — Never use SwiftUI's `Font` directly. Use `.sqFont()` modifier.  Example: (SQFont(type: .bodySmall).font)
- **Always use `SQUITextField` or `SQTextField` for text inputs** — Never use SwiftUI's `TextField` directly. Prefer `SQUITextField` (UIKit-backed, single-line) as the default. Use `SQTextField` as a fallback when multiline is needed (`axis: .vertical`).
- **Always use `SQImageSymbol` for SF Symbols** — Never use hardcoded string literals in `Image(systemName:)`. All SF Symbols must be defined in the `SQImageSymbol` enum (found in `BeastFitness/UI/SQImage.swift`) to ensure we track all icons centrally. If a symbol you need doesn't exist in the enum, add it there first before using it.
  - Use `SQImageView` with `SQImage(symbol: .symbolName)` for rendering symbols with proper styling
  - Example: `SQImageView(image: .init(symbol: .chevronUp, symbolStyle: .colorWithFont(.textPrimary, font: .bodySmall)))`
- **Use shared components for common UI patterns** — For collapsible section headers, use `SQCollapsibleSectionHeader` to ensure consistent styling across dashboard sections.
- These wrappers ensure consistent theming and styling across the app.

### Dashboard Groups and Subsections

Dashboard content is organized in two layers:

1. **Section Groups** (`SQDashboardSectionGroupViewModel`) — top-level buckets in `SQDashboardView`
2. **Subsections** (`SQDashboardSubsectionViewModel`) — collapsible cards inside a group

Current group/subsection structure:

- **Daily Stats** group
  - **Metrics** subsection
  - **Performance** subsection
- **Sleep** group
  - **Sleep Score** subsection
  - **Sleep Phases** subsection
- **Workouts** group
  - **Totals** subsection
  - **Activities** subsection

Guidelines:

- Add new dashboard domains as a **new subsection** first; only create a new group when it materially improves hierarchy.
- Reuse existing row/view model infrastructure where possible (e.g. `SQDashboardMetricStatsRowViewModel`) before adding custom row types.
- Keep `SQDashboardController.buildSectionGroups(...)` as the source of truth for group ordering/composition.

### Sleep Dashboard Time Range Rules

Sleep uses **completed nights** anchored to the most recent completed wake day (not partial current-night data):

- **Today**: last completed night only
- **Past 7 Days**: last 7 completed nights ending with last night
- **Past 30 Days**: last 30 completed nights
- **Past Year**: last 365 completed nights
- **All Time**: full available completed-night history

For Sleep Phases rows:
- Metric rows represent average phase duration for the selected range
- Change-% compares to the prior equivalent window (Today compares to prior 7 nights)
- Timeline row shows the latest completed night's stage timeline
## Workout Source Architecture

Workouts can come from three different sources, each with its own data structure and capabilities. The **SQWorkoutSourceable** protocol provides a unified interface for accessing workout data regardless of source.

### Workout Source Types

We support three types of workouts, wrapped in the `SQWorkoutSource` enum:

1. **SQHKWorkout** (HealthKit workouts)
   - Wraps `HKWorkout` from Apple HealthKit
   - Most feature-complete source
   - Has access to detailed metrics, route data, heart rate samples, etc.
   - Located at: `BeastFitness/Models/Workouts/Workout Session/SQHKWorkout.swift`

2. **SQManualWorkout** (Manual workouts created in-app)
   - Workouts created manually by users through the app
   - Contains basic metadata: duration, calories, activity type
   - Supports strength training details (sets, reps, volume)
   - Limited metric support compared to HealthKit
   - Located at: `BeastFitness/Models/Workouts/Workout Session/SQManualWorkout.swift`

3. **SQStravaWorkout** (Strava integration - not fully implemented)
   - Workouts imported from Strava API
   - Contains Strava-specific data (map polylines, elevation, speed)
   - Integration is in progress, many features not yet implemented
   - Located at: `BeastFitness/Models/Workouts/Workout Session/SQStravaWorkout.swift`

### SQWorkoutSourceable Protocol

The `SQWorkoutSourceable` protocol defines the interface all workout sources must implement:

```swift
protocol SQWorkoutSourceable {
    var sourceId: String { get }
    var activityType: HKWorkoutActivityType { get }

    // Metric calculation methods
    func sumOutputFor(_ quantityType: SQQuantityType) -> Double?
    func avgOutputFor(_ quantityType: SQQuantityType) -> Double?

    // Core workout properties
    var activeDuration: Double? { get }  // Seconds
    var totalCalories: Double? { get }
    var startDate: Date? { get }
    var endDate: Date? { get }
    var device: SQWorkoutDevice? { get }
    var details: SQWorkoutActivityDetails? { get }
}
```

### SQWorkoutSource Enum

The `SQWorkoutSource` enum wraps the three workout types and provides convenient access:

```swift
enum SQWorkoutSource {
    case hkWorkout(SQHKWorkout)
    case stravaWorkout(SQStravaWorkout)
    case manual(SQManualWorkout)

    var sourcableData: SQWorkoutSourceable { ... }
    var rawSource: SQWorkoutSourceRaw { ... }
    var isHealthKit: Bool { ... }
}
```

### Accessing Workout Data

`SQWorkoutSession` has a `workoutSource` property that you use to access the underlying data:

```swift
protocol SQWorkoutSessionable {
    var workoutSource: SQWorkoutSource { get }

    func getMetric(for quantityType: SQQuantityType) -> SQWorkoutMetric?
}

// Usage:
let workout: SQWorkoutSessionable = ...
let distance = workout.getMetric(for: .distanceWalkingRunning)
let pace = workout.getMetric(for: .sqPaceRunning)

// Accessing the underlying source:
switch workout.workoutSource {
case .hkWorkout(let hkWorkout):
    // Access HealthKit-specific features
    let hkWorkout = hkWorkout.hkWorkout  // The wrapped HKWorkout
case .manual(let manualWorkout):
    // Access manual workout data
case .stravaWorkout(let stravaWorkout):
    // Access Strava data
}
```

### Implementation Guidelines

When adding new metric types or capabilities:

1. **Add to protocol** if the feature should be available across all workout types
2. **Implement for SQHKWorkout first** - this is the most feature-complete source
3. **Return `nil` for unsupported sources** - SQManualWorkout and SQStravaWorkout can return `nil` for features not yet implemented
4. **Use the wrapped data** - For SQHKWorkout, query the `hkWorkout: HKWorkout` property to access HealthKit APIs

Example:
```swift
// In SQWorkoutSourceable protocol:
func fastestPaceFor(_ distance: SQDistance) -> Double?

// In SQHKWorkout:
func fastestPaceFor(_ distance: SQDistance) -> Double? {
    // Query hkWorkout for route data and calculate
    // Implementation here...
}

// In SQManualWorkout and SQStravaWorkout:
func fastestPaceFor(_ distance: SQDistance) -> Double? {
    return nil  // Not yet supported
}
```

### Why This Architecture

This design allows us to:
- Support multiple workout sources with a unified interface
- Gradually implement features for each source type
- Keep source-specific logic isolated
- Easily add new workout sources in the future (e.g., Garmin, Wahoo, etc.)

## Unit Handling

**Always use `SQUnit` for any unit-based values** — Never write ad-hoc conversion math or unit strings inline. `SQUnit` provides:

- **Conversion**: `SQUnit.convert(_:from:to:)` or the instance method `.convert(_:to:)` — type-safe, logs errors for incompatible unit types
- **Unit strings**: `.unitString` — e.g. `"°F"`, `"/mi"`, `"bpm"` — use this for display labels
- **HealthKit interop**: `.hkUnit` — maps to the corresponding `HKUnit`

When adding a new measurable quantity (distance, weight, temperature, speed, etc.), add the relevant cases to `SQUnit` and `SQUnitType` first, then use them everywhere. This keeps all unit logic in one place and makes future unit-preference support (e.g. metric vs imperial) a single-layer change.

**Storage convention**: Store values in a stable canonical unit (e.g. Celsius for temperature, meters for distance) and convert to the display unit at the presentation layer. This avoids needing to store the unit alongside every value.

## Coding style

- **Prefer stored properties over computed properties** — When a value can be calculated once and stored, use a stored property with `didSet` observers to update it when dependencies change, rather than recalculating via computed properties on every access.
- **Never use force unwrap (!)** — Force unwrapping can cause crashes. Always use optional binding (`if let`, `guard let`), optional chaining (`?.`), or nil coalescing (`??`) with appropriate fallback values. If data is truly expected to exist, handle the nil case gracefully with a fallback or error state (e.g., "N/A", default value, or early return).

## Development workflow preferences

**Performance optimization:**
- **Do NOT build the Xcode project during implementation** — Building takes too long. Skip all "Build to verify no errors" steps in implementation plans. The user will build and verify once at the end.
- **Do NOT use code reviewer tools/skills** — Code reviews are too slow during rapid development. Skip code review subagents. The user will review the final implementation themselves.

**Workflow approach:**
- Write code directly using file editing tools (Read, Edit, Write)
- Commit changes with clear commit messages
- Let the user build and review the complete implementation at the end
- Focus on speed and iteration over intermediate verification

## Product goal

Use all available data (HealthKit + workouts + self-tracked habits) to build a dashboard that provides:

- Clear, actionable **insights** into a user’s life
- Valuable, easy-to-understand **trends over time**
- A modern, polished UI with strong information hierarchy
