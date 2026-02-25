# Workout & HealthKit Cache Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Cache HealthKit workout and VO2 Max fetch results with a 5-minute TTL, and share a single `SQWorkoutManager` instance across all controllers via a `shared` singleton.

**Architecture:** Two-layer approach — (1) `SQHealthKitManager.shared` (already a singleton) gains in-memory TTL caches for `fetchWorkouts()` and `fetchVO2MaxSamples()`, eliminating redundant HK queries when the same time range is requested within 5 minutes. (2) `SQWorkoutManager` gets a `static let shared` singleton so all controllers share one instance and the SwiftData merge step also runs only once per call chain. Cache is invalidated on workout save/delete, and when `shouldForceRefresh: true` is passed to the dashboard.

**Tech Stack:** Swift, HealthKit, SwiftData, `@MainActor` controllers, `SQTimeRange` (String-backed Hashable enum).

**Files changed in this plan:**
| File | Change |
|------|--------|
| `BeastFitness/Managers/SQWorkoutManager.swift` | Add `static let shared`; call `invalidateCache()` on save/delete |
| `BeastFitness/Utility/ThirdParty/SQHealthKitManager.swift` | Add cache structs + dicts; modify `fetchWorkouts()`; add `invalidateCache()` to class and protocol |
| `BeastFitness/Utility/ThirdParty/SQHealthKitManager+VO2Max.swift` | Modify `fetchVO2MaxSamples(_ timeRange:)` to use VO2 Max cache |
| `BeastFitness/ViewModels/Dashboard/SQDashboardController.swift` | Use `.shared` default; call `invalidateCache()` on force-refresh |
| `BeastFitness/ViewModels/Leaderboard/SQLeaderboardController.swift` | Use `.shared` default |
| `BeastFitness/ViewModels/Workouts/WorkoutSummary/SQWorkoutSummaryController.swift` | Use `.shared` default |
| `BeastFitness/ViewModels/Workouts/WorkoutSession/SQWorkoutSessionController.swift` | Use `.shared` default |
| `BeastFitness/Managers/SQNewWorkoutReviewState.swift` | Use `.shared` default |

---

### Task 1: Add `SQWorkoutManager.shared` singleton

**Files:**
- Modify: `BeastFitness/Managers/SQWorkoutManager.swift`

**Step 1: Add the shared singleton**

In `SQWorkoutManager.swift`, add the following line directly inside the class body, right after the opening of `final class SQWorkoutManager: SQWorkoutManaging {` (after the two private property declarations, before `init`):

```swift
static let shared = SQWorkoutManager()
```

**Step 2: Update the 5 callsite default parameters**

Each of these files has `workoutManager: SQWorkoutManaging = SQWorkoutManager()` in an `init`. Change `SQWorkoutManager()` to `SQWorkoutManager.shared` in each:

**`BeastFitness/ViewModels/Dashboard/SQDashboardController.swift` line ~40:**
```swift
// Before:
init(state: DashboardStating, dailyCheckInManager: SQDailyCheckInManaging = SQDailyCheckInManager(), workoutManager: SQWorkoutManaging = SQWorkoutManager(), healthKitManager: SQHealthKitManaging = SQHealthKitManager()) {

// After:
init(state: DashboardStating, dailyCheckInManager: SQDailyCheckInManaging = SQDailyCheckInManager(), workoutManager: SQWorkoutManaging = SQWorkoutManager.shared, healthKitManager: SQHealthKitManaging = SQHealthKitManager.shared) {
```
Note: also update `healthKitManager` default to `.shared` while here.

**`BeastFitness/ViewModels/Leaderboard/SQLeaderboardController.swift` line ~57:**
```swift
// Before:
workoutManager: SQWorkoutManaging = SQWorkoutManager()

// After:
workoutManager: SQWorkoutManaging = SQWorkoutManager.shared
```

**`BeastFitness/ViewModels/Workouts/WorkoutSummary/SQWorkoutSummaryController.swift` line ~41:**
```swift
// Before:
init(state: WorkoutSummaryStating, workoutManager: SQWorkoutManaging = SQWorkoutManager(), healthKitManager: SQHealthKitManaging = SQHealthKitManager(), ...

// After:
init(state: WorkoutSummaryStating, workoutManager: SQWorkoutManaging = SQWorkoutManager.shared, healthKitManager: SQHealthKitManaging = SQHealthKitManager.shared, ...
```
Note: also update `healthKitManager` default to `.shared`.

**`BeastFitness/ViewModels/Workouts/WorkoutSession/SQWorkoutSessionController.swift` line ~57:**
```swift
// Before:
workoutManager: SQWorkoutManaging = SQWorkoutManager()

// After:
workoutManager: SQWorkoutManaging = SQWorkoutManager.shared
```

**`BeastFitness/Managers/SQNewWorkoutReviewState.swift` line ~24:**
```swift
// Before:
init(hub: EventHub, workoutManager: SQWorkoutManaging = SQWorkoutManager()) {

// After:
init(hub: EventHub, workoutManager: SQWorkoutManaging = SQWorkoutManager.shared) {
```

**Step 3: Commit**

```bash
git add BeastFitness/Managers/SQWorkoutManager.swift \
        BeastFitness/ViewModels/Dashboard/SQDashboardController.swift \
        BeastFitness/ViewModels/Leaderboard/SQLeaderboardController.swift \
        BeastFitness/ViewModels/Workouts/WorkoutSummary/SQWorkoutSummaryController.swift \
        BeastFitness/ViewModels/Workouts/WorkoutSession/SQWorkoutSessionController.swift \
        BeastFitness/Managers/SQNewWorkoutReviewState.swift
git commit -m "refactor: make SQWorkoutManager a shared singleton, use shared HKManager defaults"
```

---

### Task 2: Add cache infrastructure + workout cache to `SQHealthKitManager`

**Files:**
- Modify: `BeastFitness/Utility/ThirdParty/SQHealthKitManager.swift`

**Step 1: Add cache structs and stored properties**

In `SQHealthKitManager.swift`, add these two private structs and two stored properties directly inside the `final class SQHealthKitManager` body, just after the existing `private let anchorKeyPrefix = "Anchor_"` line:

```swift
// MARK: - Cache

private struct WorkoutCacheEntry {
    let workouts: [HKWorkout]
    let fetchedAt: Date
    var isStale: Bool { Date().timeIntervalSince(fetchedAt) > 300 } // 5 min TTL
}

private struct VO2MaxCacheEntry {
    let samples: [SQVO2MaxSample]
    let fetchedAt: Date
    var isStale: Bool { Date().timeIntervalSince(fetchedAt) > 300 } // 5 min TTL
}

private var workoutCache: [SQTimeRange: WorkoutCacheEntry] = [:]
private var vo2MaxCache: [SQTimeRange: VO2MaxCacheEntry] = [:]
```

**Step 2: Add `invalidateCache()` method to the class**

Add this method to the class body in `SQHealthKitManager.swift` (a good spot is right before the `// MARK: - Anchors` section):

```swift
func invalidateCache() {
    workoutCache.removeAll()
    vo2MaxCache.removeAll()
    SQLogger.shared.log("HealthKit cache invalidated", .debug, context: .healthKit)
}
```

**Step 3: Add `invalidateCache()` to the `SQHealthKitManaging` protocol**

In `SQHealthKitManager.swift`, add to the `protocol SQHealthKitManaging` body:

```swift
func invalidateCache()
```

**Step 4: Modify `fetchWorkouts()` to check and populate the cache**

The current `fetchWorkouts()` body in `SQHealthKitManager.swift` (around line 161) needs a cache check at the top and a cache write before returning. Only cache when `filterDuplicates == true` (the only call pattern used in production).

Replace the existing `fetchWorkouts()` implementation with:

```swift
func fetchWorkouts(_ timeRange: SQTimeRange, filterDuplicates: Bool = true) async throws -> [HKWorkout] {
    // Return cached result if fresh (only cache the standard filterDuplicates=true path)
    if filterDuplicates, let cached = workoutCache[timeRange], !cached.isStale {
        SQLogger.shared.log(
            "↩️ Workout cache hit for \(timeRange.rawValue) (\(cached.workouts.count) workouts)",
            .debug,
            context: .healthKit
        )
        return cached.workouts
    }

    guard HKHealthStore.isHealthDataAvailable() else {
        throw SQError.standard
    }

    try await Self.healthStore.requestAuthorization(
        toShare: allTypesToReadWrite,
        read: allTypesToReadWrite
    )

    let predicate = HKQuery.predicateForSamples(
        withStart: timeRange.startDate,
        end: timeRange.endDate
    )

    let limit = HKObjectQueryNoLimit
    let workoutType: HKSampleType = .workoutType()

    var workouts = try await executeQuery(
        sampleType: workoutType,
        predicate: predicate,
        anchor: nil,
        limit: limit
    )

    if filterDuplicates {
        workouts = Self.filterDuplicateWorkouts(workouts)
        workouts = workouts.filter { $0.workoutActivityType != .other }
    }

    // Populate cache for standard (filtered) fetches
    if filterDuplicates {
        workoutCache[timeRange] = WorkoutCacheEntry(workouts: workouts, fetchedAt: .now)
        SQLogger.shared.log(
            "💾 Workout cache populated for \(timeRange.rawValue) (\(workouts.count) workouts)",
            .debug,
            context: .healthKit
        )
    }

    return workouts
}
```

**Step 5: Commit**

```bash
git add BeastFitness/Utility/ThirdParty/SQHealthKitManager.swift
git commit -m "feat: add TTL workout cache and invalidateCache() to SQHealthKitManager"
```

---

### Task 3: Add VO2 Max cache to `SQHealthKitManager+VO2Max`

**Files:**
- Modify: `BeastFitness/Utility/ThirdParty/SQHealthKitManager+VO2Max.swift`

**Note:** Only cache `fetchVO2MaxSamples(_ timeRange:)` — the `fetchVO2MaxSamples(upTo date: limit:)` variant uses a dynamic date cutoff unique to each workout, so it's not worth caching.

**Step 1: Modify `fetchVO2MaxSamples(_ timeRange:)` to check and populate the cache**

The `vo2MaxCache` stored property was added to the main class body in Task 2. This extension can access it directly.

Replace the existing `fetchVO2MaxSamples(_ timeRange:)` implementation in `SQHealthKitManager+VO2Max.swift` with:

```swift
@MainActor
func fetchVO2MaxSamples(_ timeRange: SQTimeRange) async throws -> [SQVO2MaxSample] {
    // Return cached result if fresh
    if let cached = vo2MaxCache[timeRange], !cached.isStale {
        SQLogger.shared.log(
            "↩️ VO2 Max cache hit for \(timeRange.rawValue) (\(cached.samples.count) samples)",
            .debug,
            context: .healthKit
        )
        return cached.samples
    }

    guard HKHealthStore.isHealthDataAvailable() else {
        throw SQHealthKitError.healthDataUnavailable
    }

    try await Self.healthStore.requestAuthorization(
        toShare: allTypesToReadWrite,
        read: allTypesToReadWrite
    )

    let vo2Type = HKQuantityType.quantityType(forIdentifier: .vo2Max)!
    let predicate = HKQuery.predicateForSamples(
        withStart: timeRange.startDate,
        end: timeRange.endDate,
        options: []
    )

    let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

    let samples: [HKQuantitySample] = try await withCheckedThrowingContinuation { continuation in
        let query = HKSampleQuery(
            sampleType: vo2Type,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sort]
        ) { _, samples, error in
            if let error {
                continuation.resume(throwing: error)
                return
            }
            continuation.resume(returning: samples as? [HKQuantitySample] ?? [])
        }

        Self.healthStore.execute(query)
    }

    let result = samples.map(Self.mapVO2MaxSample)

    // Populate cache
    vo2MaxCache[timeRange] = VO2MaxCacheEntry(samples: result, fetchedAt: .now)
    SQLogger.shared.log(
        "💾 VO2 Max cache populated for \(timeRange.rawValue) (\(result.count) samples)",
        .debug,
        context: .healthKit
    )

    return result
}
```

**Step 2: Commit**

```bash
git add BeastFitness/Utility/ThirdParty/SQHealthKitManager+VO2Max.swift
git commit -m "feat: add TTL VO2 Max cache to SQHealthKitManager"
```

---

### Task 4: Wire up cache invalidation

**Files:**
- Modify: `BeastFitness/Managers/SQWorkoutManager.swift`
- Modify: `BeastFitness/ViewModels/Dashboard/SQDashboardController.swift`

**Step 1: Invalidate cache on workout save**

In `SQWorkoutManager.saveWorkout()`, add a call to `healthKitManager.invalidateCache()` after the HealthKit save succeeds (right after `workout.updateHkWorkoutId(...)`) so the next fetch sees the newly saved workout:

```swift
// After: workout.updateHkWorkoutId(hkWorkout?.uuid.uuidString)
// Add:
healthKitManager.invalidateCache()
SQLogger.shared.log("Invalidated HK cache after saving workout", .debug, context: .workoutManager)
```

**Step 2: Invalidate cache on workout delete**

In `SQWorkoutManager.deleteWorkout()`, add a call right after the `attemptToDeleteWorkoutFromHealthKit` call completes (before the SwiftData delete):

```swift
// After: await attemptToDeleteWorkoutFromHealthKit(workout)
// Add:
healthKitManager.invalidateCache()
SQLogger.shared.log("Invalidated HK cache after deleting workout", .debug, context: .workoutManager)
```

**Step 3: Invalidate cache when dashboard force-refreshes**

In `SQDashboardController.loadUI(for:shouldForceRefresh:)`, add a cache invalidation right at the top when `shouldForceRefresh` is true, before any HealthKit fetches begin. The `guard !hasLoadedUI || shouldForceRefresh` check already handles gating. Add right after `hasLoadedUI = true`:

```swift
// Invalidate caches so a force-refresh always hits HealthKit fresh
if shouldForceRefresh {
    healthKitManager.invalidateCache()
    SQLogger.shared.log("Force-refresh: invalidated HealthKit cache", .debug, context: .dashboard)
}
```

**Step 4: Commit**

```bash
git add BeastFitness/Managers/SQWorkoutManager.swift \
        BeastFitness/ViewModels/Dashboard/SQDashboardController.swift
git commit -m "feat: invalidate HK cache on workout save/delete and dashboard force-refresh"
```

---

## Summary

After these 4 tasks:

- **9 HealthKit workout queries** on every dashboard load → **9 cache hits** after the first load (within 5 min window)
- **3 VO2 Max HealthKit queries** on dashboard load → **3 cache hits** on subsequent navigations
- The leaderboard and workout summary views share the same `SQHealthKitManager.shared` cache, so navigating to them after the dashboard is instant
- `SQWorkoutManager.shared` is now a singleton — the SwiftData merge step is also shared
- Pull-to-refresh (when implemented) just needs to call `loadUI(shouldForceRefresh: true)` — cache invalidation is already wired in
- Cache auto-invalidates after 5 minutes passively, and immediately on any workout mutation
