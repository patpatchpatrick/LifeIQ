# Metric Tracking System Redesign
**Date:** 2026-03-11
**Status:** Approved

---

## Goal

Redesign the daily check-in metric system to support period-aware, insight-ready data. The new model introduces `SQMetricEntry` as the canonical analytics storage unit, expands the metric catalog with new groups and metrics, and splits the single check-in screen into morning and evening periods based on device time.

---

## 1. Data Model

### `SQMetricPeriod`

```swift
enum SQMetricPeriod: String, Codable, CaseIterable, Hashable, UnfrozenEnum {
    case morning   // Appears on the morning check-in screen (logged before noon)
    case evening   // Appears on the evening check-in screen (logged at noon or later)
    case unknown   // Fallback for unrecognized values from Firestore
}
```

### `SQMetricEntry` — new source of truth for analytics storage

Replaces `SQDailyCheckInStats` as the canonical write target. Each logged metric value becomes one entry.

```swift
struct SQMetricEntry: Identifiable, Codable, Hashable {
    var id: String                 // UUID — unique identifier for this entry
    var metricId: String           // References SQMetricDefinition.id — which metric was logged
    var recordedAt: Date           // UTC timestamp of when the user submitted this entry
    var anchorDayKey: String       // "YYYY-MM-DD" in the user's local timezone — groups entries into "days" for display and insights
    var period: SQMetricPeriod     // The check-in period this was logged in (morning or evening)
    var rawValue: Float            // The value as entered by the user, in their configured scale (e.g. 0–5 if they use a 5-point scale)
    var normalizedScore: Float     // rawValue converted to a 0–10 score — used by the insight engine so all metrics are comparable regardless of scale
    var timeZoneIdentifier: String // IANA timezone identifier (e.g. "America/New_York") at time of entry — used to verify/recompute anchorDayKey, handles travel correctly
}
```

### `SQDailyNote` — per-day free-form notes

Notes are per calendar day, shared across morning and evening check-ins. Editable from either screen.

```swift
struct SQDailyNote: Identifiable, Codable {
    var anchorDayKey: String  // "YYYY-MM-DD" in the user's local timezone — doubles as the Firestore document ID
    var content: String       // The user's free-form note text
    var updatedAt: Date       // UTC timestamp of last edit — used for incremental sync
}
```

### `SQDailyCheckInStats` — demoted to display aggregate

Kept as a UI convenience model built at read time from `SQMetricEntry` records grouped by `anchorDayKey`. No longer written to Firestore as the canonical source.

### Updated `SQMetricDefinition` fields

```swift
var period: SQMetricPeriod   // Which check-in screen (morning/evening) this metric appears on
var isDefault: Bool           // If true, metric is enabled by default for new users on first launch
```

### Updated `SQDefaultGroup`

```swift
enum SQDefaultGroup: String, CaseIterable, UnfrozenEnum {
    case stats          = "Stats"            // One-time or infrequent physical measurements (e.g. weight)
    case self_          = "Self"             // Daily mental/physical state metrics
    case sleep          = "Sleep"            // Sleep tracking metrics
    case positiveHabits = "Positive Habits"  // Behaviors to build (nutrition, meditation)
    case vices          = "Vices"            // Behaviors to monitor (alcohol, caffeine, etc.)
    case general        = "General"          // Fallback for user-created metrics
    case unknown        = "unknown"          // Fallback for unrecognized values from Firestore
    case habit          = "Habit"            // Legacy — retained for migration read path only
}
```

Custom groups remain fully supported. `SQMetricDefinition.group` is still a plain `String`; `SQDefaultGroup` provides well-known constants only. Users can type any group name when creating a metric.

---

## 2. Metric Catalog

`SQMetricKind.binary` is retired — all former binary metrics become `scale` 0–10.

| # | Title | Group | Kind | Scale | Period | Default | Emoji |
|---|-------|-------|------|-------|--------|---------|-------|
| 0 | Weight | Stats | number (lbs) | 0–1000 | morning | no | ⚖️ |
| 1 | Mood | Self | scale | 0–10 | morning | **yes** | 😊 |
| 2 | Mental Clarity | Self | scale | 0–10 | morning | **yes** | 🧠 |
| 3 | Energy Level | Self | scale | 0–10 | morning | **yes** | ⚡ |
| 4 | Soreness / Recovery | Self | scale | 0–10 | morning | **yes** | 💪 |
| 5 | Sleep Quality | Sleep | scale | 0–10 | morning | no | 😴 |
| 6 | Sleep Hours | Sleep | number (hrs) | 0–24 | morning | no | 🌙 |
| 7 | Meditation | Positive Habits | scale | 0–10 | evening | no | 🧘 |
| 8 | Nutrition | Positive Habits | scale | 0–10 | evening | **yes** | 🥗 |
| 9 | Alcohol | Vices | scale | 0–10 | evening | **yes** | 🍺 |
| 10 | Caffeine | Vices | scale | 0–10 | evening | **yes** | ☕ |
| 11 | Weed | Vices | scale | 0–10 | evening | no | 🌿 |
| 12 | Porn | Vices | scale | 0–10 | evening | no | — |
| 13 | Nicotine | Vices | scale | 0–10 | evening | no | 🚬 |

**Notes:**
- Sleep metrics appear on the morning check-in — logged in the morning reflecting on the previous night
- Sleep Quality rescaled from 1–5 → 0–10 to match the standard scale
- Nutrition and Nicotine are new metrics (did not exist previously)
- Height moves to user profile (one-time onboarding field on `SQUser`), not a tracked metric

---

## 3. Check-In Flow

### Period routing
- Single "Check In" entry point
- Device time < 12:00 PM local → morning check-in
- Device time ≥ 12:00 PM local → evening check-in
- If user has already checked in for the current period, open in edit mode (pre-filled) — no separate "already done" gate

### Screen behavior
- Reuses `SQDailyCheckInView` — minimal UI changes required
- View filters metrics by `definition.period` to show only the appropriate subset
- Only enabled metrics shown in the list
- "Add Metric" button (existing behavior) preserved — lets users add non-default metrics inline
- Notes field shared across both periods; pre-populated on evening screen if morning note exists

---

## 4. Timezone Handling

- `recordedAt` — stored as UTC
- `anchorDayKey` — computed from device local timezone at time of entry (e.g. if in Tokyo at 1am Feb 25, `anchorDayKey` = `"2025-02-25"`)
- `timeZoneIdentifier` — stored per entry (IANA identifier, e.g. `"America/New_York"`) for auditability and recomputation

This ensures "days" group by the user's subjective experience, not UTC, and handles travel correctly.

---

## 5. Normalization

Values are stored in two forms:
- `rawValue` — the value in the user's configured scale (e.g. 0–5 if they customized a 5-point scale)
- `normalizedScore` — converted to 0–10 for the insight engine: `(rawValue - min) / (max - min) * 10`

If the user changes their scale, historical `normalizedScore` values can be recomputed from `rawValue` + the original metric definition.

Binary → scale migration: former binary metrics (0 or 1) map to `normalizedScore` of 0 or 10.

---

## 6. Migration

One-time migration on first app launch after update. Controlled by a flag in `SQSyncMetadataEntity` (key: `"metric-entry-migration-v1"`). A debug override boolean allows forcing re-run during development.

**For each existing `SQDailyCheckInStats`:**
1. For each `metricId → value` in `stats.values`:
   - Look up `SQMetricDefinition` to get `period`, `min`, `max`
   - Create `SQMetricEntry`:
     - `anchorDayKey` = `stats.uniqueDateKey`
     - `recordedAt` = `stats.date` (start of day — best available approximation)
     - `period` = from metric definition
     - `rawValue` = stored value
     - `normalizedScore` = `(rawValue - min) / (max - min) * 10`
     - `timeZoneIdentifier` = current device timezone (best guess for historical data)
2. If `stats.notes` is non-empty → create `SQDailyNote` with `anchorDayKey` = `stats.uniqueDateKey`

After migration, `daily-check-in-summaries` Firestore collection becomes read-only (no new writes).

---

## 7. Sync & Storage Layer

### Firestore collections

| Collection | Status |
|---|---|
| `users/{id}/metric-entries/{entryId}` | **New** — canonical analytics storage |
| `users/{id}/daily-notes/{anchorDayKey}` | **New** — per-day notes |
| `users/{id}/metric-definitions/{metricId}` | **Updated** — adds `period` and `isDefault` fields |
| `users/{id}/daily-check-in-summaries/` | **Retired** as write target; read during migration only |

### SwiftData entities (new)
- **`SQMetricEntryEntity`** — mirrors `SQMetricEntry`; follows existing `upsert()` / `getAll()` / `get(by:)` pattern
- **`SQDailyNoteEntity`** — mirrors `SQDailyNote`; keyed by `anchorDayKey`

### New services
- **`SQMetricEntryService`**: `saveMetricEntry(_:for:)`, `fetchMetricEntries(for:afterDate:)`
- **`SQDailyNoteService`**: `saveDailyNote(_:for:)`, `fetchDailyNotes(for:afterDate:)`

### Sync strategy
- Full sync on first launch per collection
- Incremental sync (`recordedAt > lastSyncDate` for entries, `updatedAt > lastSyncDate` for notes), gated to once per 6 hours
- Sync metadata via `SQSyncMetadataEntity` keys: `"metric-entries-sync"`, `"daily-notes-sync"`
- All Firestore reads tracked via `SQFirestoreMetricsManager`

---

## Future: Insight Engine (out of scope for V1)

The data model is designed to support:
- **Same-day correlations**: morning metrics on Day D + workout outcomes on Day D
- **Lag-1 correlations**: evening metrics on Day D-1 + workout readiness on Day D
- **Example insights**: "When your sleep quality is above 7, your workout pace improves by 8%" or "Alcohol correlates with a 15% drop in next-day energy"
