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

### Daily Check-In Metrics Organization

Daily check-in metrics are organized into groups using the `SQMetricGroup` enum (defined in `BeastFitness/Models/DailyCheckIn/SQMetric.swift`):

- **State** (.state) — Physical and mental state metrics: mood, energy, mental clarity, soreness/recovery, sleep hours, sleep quality
- **Habits** (.habits) — Behavioral tracking metrics: alcohol, weed, porn, caffeine, meditation
- **Custom** (.custom) — User-created metrics

All metrics must have a `group` property assigned in their `SQMetricDefinition`. The dashboard displays these groups as separate collapsible sections for better organization.

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
- **Always use `SQImageSymbol` for SF Symbols** — Never use hardcoded string literals in `Image(systemName:)`. All SF Symbols must be defined in the `SQImageSymbol` enum (found in `BeastFitness/UI/SQImage.swift`) to ensure we track all icons centrally. If a symbol you need doesn't exist in the enum, add it there first before using it.
  - Use `SQImageView` with `SQImage(symbol: .symbolName)` for rendering symbols with proper styling
  - Example: `SQImageView(image: .init(symbol: .chevronUp, symbolStyle: .colorWithFont(.textPrimary, font: .bodySmall)))`
- **Use shared components for common UI patterns** — For collapsible section headers, use `SQCollapsibleSectionHeader` to ensure consistent styling across dashboard sections.
- These wrappers ensure consistent theming and styling across the app.
## Coding style

- **Prefer stored properties over computed properties** — When a value can be calculated once and stored, use a stored property with `didSet` observers to update it when dependencies change, rather than recalculating via computed properties on every access.
- **Never use force unwrap (!)** — Force unwrapping can cause crashes. Always use optional binding (`if let`, `guard let`), optional chaining (`?.`), or nil coalescing (`??`) with appropriate fallback values. If data is truly expected to exist, handle the nil case gracefully with a fallback or error state (e.g., "N/A", default value, or early return).
## Product goal

Use all available data (HealthKit + workouts + self-tracked habits) to build a dashboard that provides:

- Clear, actionable **insights** into a user’s life
- Valuable, easy-to-understand **trends over time**
- A modern, polished UI with strong information hierarchy
