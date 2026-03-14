# Metric Tracking System Redesign Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the daily check-in metric system to introduce `SQMetricEntry` as the canonical analytics storage unit, expand the metric catalog with new groups/metrics, and split check-ins into morning/evening periods.

**Architecture:** `SQMetricEntry` replaces `SQDailyCheckInStats` as the Firestore write target — each metric value becomes one entry with a period, UTC timestamp, and local-timezone `anchorDayKey`. `SQDailyCheckInStats` is retained as a read-time UI aggregate built from entries. `SQDailyNote` stores per-day free-form notes shared across both check-in periods. A one-time migration converts existing `SQDailyCheckInStats` records to `SQMetricEntry` records.

**Tech Stack:** Swift, SwiftUI, SwiftData, Firestore (via existing `SQNetworkService`/`SQFirestoreRoute` patterns), `BeastFitnessCore` (SQLogger, EventHub), `UnfrozenEnum` for all enums.

**Spec:** `docs/superpowers/specs/2026-03-11-metric-tracking-redesign-design.md`

**Note on build verification:** Per project conventions, do NOT build the Xcode project during implementation. Write code, commit, and let the user build at the end.

---

## File Map

### New Files
| File | Purpose |
|------|---------|
| `BeastFitness/Models/DailyCheckIn/SQMetricEntry.swift` | `SQMetricEntry` model + `SQMetricPeriod` enum |
| `BeastFitness/Models/DailyCheckIn/SQDailyNote.swift` | `SQDailyNote` model |
| `BeastFitness/Models/DailyCheckIn/SQMetricEntryEntity.swift` | SwiftData entity for `SQMetricEntry` |
| `BeastFitness/Models/DailyCheckIn/SQDailyNoteEntity.swift` | SwiftData entity for `SQDailyNote` |
| `BeastFitness/Networking/Routers/SQMetricEntryRoute.swift` | Firestore routes for metric entries |
| `BeastFitness/Networking/Routers/SQDailyNoteRoute.swift` | Firestore routes for daily notes |
| `BeastFitness/Networking/Services/SQMetricEntryService.swift` | Firestore service for metric entries |
| `BeastFitness/Networking/Services/SQDailyNoteService.swift` | Firestore service for daily notes |
| `BeastFitness/Managers/SQMetricEntryManager.swift` | Business logic: save/sync/query metric entries and notes |
| `BeastFitness/Managers/SQMetricMigrationManager.swift` | One-time migration from `SQDailyCheckInStats` → `SQMetricEntry` |

### Modified Files
| File | Changes |
|------|---------|
| `BeastFitness/Models/DailyCheckIn/SQMetric.swift` | Add `SQMetricPeriod`; update `SQDefaultGroup` (new groups, `UnfrozenEnum`); add `period`/`isDefault` to `SQMetricDefinition`; add new metric IDs; add `unknown` to `SQMetricKind`/`SQMetricUnit` |
| `BeastFitness/Models/DailyCheckIn/SQMetricDefinitionEntity.swift` | Add `periodRaw`, `isDefault` fields; update `toDefinition()` and `apply()` |
| `BeastFitness/Managers/SQMetricsManager.swift` | Overhaul `presetMetrics()` with new catalog, groups, periods, isDefault |
| `BeastFitness/Managers/SQDailyCheckInManager.swift` | Update save to write `SQMetricEntry` + `SQDailyNote`; update read to build stats from entries |
| `BeastFitness/ViewModels/Dashboard/DailyCheckIn/SQDailyCheckInViewModel.swift` | Accept `period` param; filter metrics by period in `buildRows()` |
| `BeastFitness/StateManagement/DashboardState.swift` | Add period routing (before noon → morning, noon+ → evening) in `displayDailyCheckInSheet` |
| `BeastFitness/BeastFitnessApp.swift` | Register new SwiftData entities in `.modelContainer` |
| `BeastFitness/AppState/SQAppState.swift` | Add `metricEntryManager` property |

---

## Chunk 1: Data Model

### Task 1: Update SQMetric.swift

**Files:**
- Modify: `BeastFitness/Models/DailyCheckIn/SQMetric.swift`

- [ ] **Step 1: Update SQMetric.swift with all model changes**

Replace the full file contents:

```swift
//
//  SQMetric.swift
//  BeastFitness
//

import Foundation

// MARK: - SQMetricKind

enum SQMetricKind: String, Codable, CaseIterable, UnfrozenEnum {
    case binary      // Legacy 0/1 — no longer used for new metrics; kept for backward-compatibility decoding
    case scale       // Segmented control (min–max by step)
    case number      // Free-form numeric input (hours, lbs, etc.)
    case unknown     // Fallback for unrecognized values from Firestore
}

// MARK: - SQMetricUnit

enum SQMetricUnit: String, Codable, CaseIterable, UnfrozenEnum {
    case none
    case hours
    case count
    case pounds
    case kilograms
    case percent
    case unknown     // Fallback for unrecognized values from Firestore
}

// MARK: - SQMetricPeriod

/// Determines which check-in screen a metric appears on.
enum SQMetricPeriod: String, Codable, CaseIterable, Hashable, UnfrozenEnum {
    case morning   // Appears on the morning check-in screen (logged before noon)
    case evening   // Appears on the evening check-in screen (logged at noon or later)
    case unknown   // Fallback for unrecognized values from Firestore
}

// MARK: - SQDefaultGroup

/// Well-known default group names. Users may also create arbitrary group strings;
/// these are just the ones that ship with presets and appear in the picker by default.
enum SQDefaultGroup: String, CaseIterable, UnfrozenEnum {
    case stats          = "Stats"            // One-time or infrequent physical measurements (e.g. weight)
    case self_          = "Self"             // Daily mental/physical state metrics
    case sleep          = "Sleep"            // Sleep tracking metrics
    case positiveHabits = "Positive Habits"  // Behaviors to build (nutrition, meditation)
    case vices          = "Vices"            // Behaviors to monitor (alcohol, caffeine, etc.)
    case general        = "General"          // Fallback for user-created metrics
    case unknown        = "unknown"          // Fallback for unrecognized values from Firestore
    case habit          = "Habit"            // Legacy — retained for migration read path only
    case personal       = "Self_legacy"      // Legacy alias for .self_ — used only during migration
}

// MARK: - SQMetricDefinition

struct SQMetricDefinition: Identifiable, Codable, Hashable {
    let id: String               // Stable preset IDs or UUIDs for custom metrics
    var title: String            // Display name e.g. "Mood", "Sleep Hours", "Alcohol"
    var kind: SQMetricKind       // How the value is entered (scale, number, etc.)
    var unit: SQMetricUnit       // Unit for display purposes (e.g. pounds, hours)
    var group: String            // User-facing group name (e.g. "Self", "Vices") — any string is valid
    var min: Float?              // Minimum value for scale/number entry
    var max: Float?              // Maximum value for scale/number entry
    var step: Float?             // Step granularity for scale segmented control
    var isPreset: Bool           // True if this metric ships with the app
    var isEnabled: Bool          // True if the user is actively tracking this metric
    var isDefault: Bool          // True if this metric is enabled by default for new users on first launch
    var sortOrder: Int           // Display order within the check-in form
    var isArchived: Bool         // Soft-deleted; hidden from all lists but preserved in history
    var emoji: String?           // Optional single-grapheme emoji chosen by the user
    var period: SQMetricPeriod   // Which check-in screen this metric appears on (morning or evening)
    var updatedAt: Date          // UTC timestamp of last modification; used for incremental Firestore sync

    // MARK: - Manual Init (non-decoder)
    init(
        id: String,
        title: String,
        kind: SQMetricKind,
        unit: SQMetricUnit,
        group: String,
        min: Float? = nil,
        max: Float? = nil,
        step: Float? = nil,
        isPreset: Bool,
        isEnabled: Bool = true,
        isDefault: Bool = false,
        sortOrder: Int,
        isArchived: Bool = false,
        emoji: String? = nil,
        period: SQMetricPeriod = .morning,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.unit = unit
        self.group = group
        self.min = min
        self.max = max
        self.step = step
        self.isPreset = isPreset
        self.isEnabled = isEnabled
        self.isDefault = isDefault
        self.sortOrder = sortOrder
        self.isArchived = isArchived
        self.emoji = emoji
        self.period = period
        self.updatedAt = updatedAt
    }

    // MARK: - Custom Decoder (handles missing fields from older Firestore documents)
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try  c.decode(String.self,             forKey: .id)
        title       = try  c.decode(String.self,             forKey: .title)
        kind        = try  c.decode(SQMetricKind.self,       forKey: .kind)
        unit        = try  c.decode(SQMetricUnit.self,       forKey: .unit)
        group       = try  c.decode(String.self,             forKey: .group)
        min         = try  c.decodeIfPresent(Float.self,     forKey: .min)
        max         = try  c.decodeIfPresent(Float.self,     forKey: .max)
        step        = try  c.decodeIfPresent(Float.self,     forKey: .step)
        isPreset    = try  c.decode(Bool.self,               forKey: .isPreset)
        isEnabled   = try  c.decode(Bool.self,               forKey: .isEnabled)
        isDefault   = (try c.decodeIfPresent(Bool.self,      forKey: .isDefault)) ?? false
        sortOrder   = try  c.decode(Int.self,                forKey: .sortOrder)
        isArchived  = try  c.decode(Bool.self,               forKey: .isArchived)
        emoji       = try  c.decodeIfPresent(String.self,    forKey: .emoji)
        period      = (try c.decodeIfPresent(SQMetricPeriod.self, forKey: .period)) ?? .morning
        updatedAt   = (try c.decodeIfPresent(Date.self,      forKey: .updatedAt)) ?? .now
    }
}

// MARK: - SQMetricId

/// Stable string identifiers for all preset metrics.
enum SQMetricId {

    // MARK: Stats
    static let weight        = "metric.weight"          // number (pounds); morning

    // MARK: Self — enabled by default
    static let mood          = "metric.mood"            // scale 0–10; morning
    static let mentalClarity = "metric.mentalClarity"   // scale 0–10; morning
    static let energy        = "metric.energy"          // scale 0–10; morning
    static let soreness      = "metric.soreness"        // scale 0–10; morning

    // MARK: Sleep
    static let sleepQuality  = "metric.sleepQuality"   // scale 0–10; morning (reflects prior night)
    static let sleepHours    = "metric.sleepHours"     // number 0–24 hrs; morning (reflects prior night)

    // MARK: Positive Habits
    static let meditation    = "metric.meditation"     // scale 0–10; evening
    static let nutrition     = "metric.nutrition"      // scale 0–10; evening — NEW

    // MARK: Vices — alcohol and caffeine enabled by default
    static let alcohol       = "metric.alcohol"        // scale 0–10; evening
    static let caffeine      = "metric.caffeine"       // scale 0–10; evening
    static let weed          = "metric.weed"           // scale 0–10; evening
    static let porn          = "metric.porn"           // scale 0–10; evening
    static let nicotine      = "metric.nicotine"       // scale 0–10; evening — NEW

    // MARK: - Custom metric ID generator
    static func custom(_ uuid: UUID = UUID()) -> String {
        "metric.custom.\(uuid.uuidString.lowercased())"
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add BeastFitness/Models/DailyCheckIn/SQMetric.swift
git commit -m "feat: update SQMetric with period, isDefault, new groups, UnfrozenEnum conformance"
```

---

### Task 2: Create SQMetricEntry.swift and SQDailyNote.swift

**Files:**
- Create: `BeastFitness/Models/DailyCheckIn/SQMetricEntry.swift`
- Create: `BeastFitness/Models/DailyCheckIn/SQDailyNote.swift`

- [ ] **Step 1: Create SQMetricEntry.swift**

```swift
//
//  SQMetricEntry.swift
//  BeastFitness
//

import Foundation

/// A single metric value logged by the user during a check-in.
/// This is the canonical analytics storage unit — one entry per metric per check-in submission.
struct SQMetricEntry: Identifiable, Codable, Hashable {

    // MARK: - Identity

    var id: String
    /// References `SQMetricDefinition.id` — identifies which metric was logged.
    var metricId: String

    // MARK: - Timing

    /// UTC timestamp of when the user submitted this entry.
    var recordedAt: Date
    /// "YYYY-MM-DD" in the user's local timezone at time of entry.
    /// Used to group entries into calendar days for display and insights, handles travel correctly.
    var anchorDayKey: String
    /// IANA timezone identifier (e.g. "America/New_York") at time of entry.
    /// Stored for auditability and to allow recomputing `anchorDayKey` if needed.
    var timeZoneIdentifier: String

    // MARK: - Period

    /// The check-in period this entry was logged in (morning or evening).
    var period: SQMetricPeriod

    // MARK: - Value

    /// The value as entered by the user, in their configured scale (e.g. 0–5 if they set a 5-point scale).
    var rawValue: Float
    /// `rawValue` converted to a 0–10 score for the insight engine.
    /// Allows comparing all metrics regardless of their individual scales.
    /// Formula: `(rawValue - min) / (max - min) * 10` for scale metrics; `rawValue` for number metrics.
    var normalizedScore: Float

    // MARK: - Init

    init(
        id: String = UUID().uuidString,
        metricId: String,
        recordedAt: Date = .now,
        anchorDayKey: String,
        timeZoneIdentifier: String,
        period: SQMetricPeriod,
        rawValue: Float,
        normalizedScore: Float
    ) {
        self.id = id
        self.metricId = metricId
        self.recordedAt = recordedAt
        self.anchorDayKey = anchorDayKey
        self.timeZoneIdentifier = timeZoneIdentifier
        self.period = period
        self.rawValue = rawValue
        self.normalizedScore = normalizedScore
    }
}

// MARK: - Normalization Helper

extension SQMetricEntry {

    /// Computes `normalizedScore` from a raw value and metric definition bounds.
    /// - Scale metrics: `(rawValue - min) / (max - min) * 10`, clamped to 0–10.
    /// - Number metrics: returns `rawValue` unchanged (unbounded, insight engine uses raw).
    static func normalizedScore(for rawValue: Float, definition: SQMetricDefinition) -> Float {
        switch definition.kind {
        case .scale, .binary:
            let min = definition.min ?? 0
            let max = definition.max ?? 10
            guard max > min else { return rawValue }
            let normalized = (rawValue - min) / (max - min) * 10
            return Swift.min(10, Swift.max(0, normalized))
        case .number, .unknown:
            return rawValue
        }
    }

    /// Builds a `SQMetricEntry` from a raw value, metric definition, and current device context.
    static func make(
        metricId: String,
        rawValue: Float,
        definition: SQMetricDefinition,
        recordedAt: Date = .now
    ) -> SQMetricEntry {
        let tz = TimeZone.current
        let anchorDayKey = recordedAt.anchorDayKey(in: tz)
        return SQMetricEntry(
            metricId: metricId,
            recordedAt: recordedAt,
            anchorDayKey: anchorDayKey,
            timeZoneIdentifier: tz.identifier,
            period: definition.period,
            rawValue: rawValue,
            normalizedScore: normalizedScore(for: rawValue, definition: definition)
        )
    }
}

// MARK: - Date Extension

extension Date {
    /// Returns "YYYY-MM-DD" formatted in the given timezone — used as the stable day grouping key.
    func anchorDayKey(in timeZone: TimeZone = .current) -> String {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: self)
        let year  = components.year  ?? 0
        let month = components.month ?? 0
        let day   = components.day   ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}
```

- [ ] **Step 2: Create SQDailyNote.swift**

```swift
//
//  SQDailyNote.swift
//  BeastFitness
//

import Foundation

/// A free-form note logged by the user for a specific calendar day.
/// Notes are shared across morning and evening check-ins — one note per day.
/// Editable from either check-in screen.
struct SQDailyNote: Identifiable, Codable, Hashable {

    /// "YYYY-MM-DD" in the user's local timezone — uniquely identifies the day.
    /// Also serves as the Firestore document ID for this note.
    var anchorDayKey: String

    /// The user's free-form note text.
    var content: String

    /// UTC timestamp of the last edit — used for incremental Firestore sync.
    var updatedAt: Date

    var id: String { anchorDayKey }

    init(anchorDayKey: String, content: String, updatedAt: Date = .now) {
        self.anchorDayKey = anchorDayKey
        self.content = content
        self.updatedAt = updatedAt
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add BeastFitness/Models/DailyCheckIn/SQMetricEntry.swift BeastFitness/Models/DailyCheckIn/SQDailyNote.swift
git commit -m "feat: add SQMetricEntry and SQDailyNote models"
```

---

## Chunk 2: Persistence Layer

### Task 3: Update SQMetricDefinitionEntity.swift

**Files:**
- Modify: `BeastFitness/Models/DailyCheckIn/SQMetricDefinitionEntity.swift`

- [ ] **Step 1: Add `periodRaw` and `isDefault` fields**

Add the two new stored properties after `emoji`:

```swift
var emoji: String?
var periodRaw: String      // Stores SQMetricPeriod.rawValue — raw string for SwiftData compatibility
var isDefault: Bool        // True if this metric is enabled by default for new users
```

Update `init` to include the new parameters (add after `emoji`):

```swift
init(
    id: String,
    title: String,
    kind: SQMetricKind,
    unit: SQMetricUnit,
    group: String,
    min: Float? = nil,
    max: Float? = nil,
    step: Float? = nil,
    isPreset: Bool,
    isEnabled: Bool,
    isDefault: Bool = false,
    sortOrder: Int,
    isArchived: Bool,
    emoji: String? = nil,
    period: SQMetricPeriod = .morning
) {
    self.id = id
    self.title = title
    self.kindRaw = kind.rawValue
    self.unitRaw = unit.rawValue
    self.groupRaw = group
    self.minValue = min
    self.maxValue = max
    self.stepValue = step
    self.isPreset = isPreset
    self.isEnabled = isEnabled
    self.isDefault = isDefault
    self.sortOrder = sortOrder
    self.isArchived = isArchived
    self.emoji = emoji
    self.periodRaw = period.rawValue
    self.updatedAt = .now
}
```

Add computed property in the extension:

```swift
var period: SQMetricPeriod { SQMetricPeriod(unfrozenRawValue: periodRaw) }
```

Update `toDefinition()` to include new fields:

```swift
func toDefinition() -> SQMetricDefinition {
    .init(
        id: id,
        title: title,
        kind: kind,
        unit: unit,
        group: group,
        min: minValue,
        max: maxValue,
        step: stepValue,
        isPreset: isPreset,
        isEnabled: isEnabled,
        isDefault: isDefault,
        sortOrder: sortOrder,
        isArchived: isArchived,
        emoji: emoji,
        period: period,
        updatedAt: updatedAt
    )
}
```

Update `apply(_ def:)` to include new fields:

```swift
func apply(_ def: SQMetricDefinition) {
    title = def.title
    kindRaw = def.kind.rawValue
    unitRaw = def.unit.rawValue
    groupRaw = def.group
    minValue = def.min
    maxValue = def.max
    stepValue = def.step
    isPreset = def.isPreset
    isEnabled = def.isEnabled
    isDefault = def.isDefault
    sortOrder = def.sortOrder
    isArchived = def.isArchived
    emoji = def.emoji
    periodRaw = def.period.rawValue
    updatedAt = def.updatedAt
}
```

- [ ] **Step 2: Commit**

```bash
git add BeastFitness/Models/DailyCheckIn/SQMetricDefinitionEntity.swift
git commit -m "feat: add period and isDefault fields to SQMetricDefinitionEntity"
```

---

### Task 4: Create SQMetricEntryEntity.swift

**Files:**
- Create: `BeastFitness/Models/DailyCheckIn/SQMetricEntryEntity.swift`

- [ ] **Step 1: Create the file**

```swift
//
//  SQMetricEntryEntity.swift
//  BeastFitness
//

import Foundation
import SwiftData

/// SwiftData entity for persisting a single metric entry locally.
/// Mirrors `SQMetricEntry` — one row per metric value logged during a check-in.
@Model
final class SQMetricEntryEntity {

    @Attribute(.unique) var id: String
    /// References `SQMetricDefinition.id` — identifies which metric this value belongs to.
    var metricId: String
    /// UTC timestamp of when the user submitted this entry.
    var recordedAt: Date
    /// "YYYY-MM-DD" in the user's local timezone — groups entries into days.
    var anchorDayKey: String
    /// IANA timezone identifier at time of entry (e.g. "America/New_York").
    var timeZoneIdentifier: String
    /// Raw string for `SQMetricPeriod` — stored as String for SwiftData compatibility.
    var periodRaw: String
    /// The value as entered by the user in their configured scale.
    var rawValue: Float
    /// `rawValue` normalized to 0–10 for the insight engine.
    var normalizedScore: Float

    init(entry: SQMetricEntry) {
        self.id = entry.id
        self.metricId = entry.metricId
        self.recordedAt = entry.recordedAt
        self.anchorDayKey = entry.anchorDayKey
        self.timeZoneIdentifier = entry.timeZoneIdentifier
        self.periodRaw = entry.period.rawValue
        self.rawValue = entry.rawValue
        self.normalizedScore = entry.normalizedScore
    }
}

// MARK: - Conversion

extension SQMetricEntryEntity {

    var period: SQMetricPeriod { SQMetricPeriod(unfrozenRawValue: periodRaw) }

    func toEntry() -> SQMetricEntry {
        SQMetricEntry(
            id: id,
            metricId: metricId,
            recordedAt: recordedAt,
            anchorDayKey: anchorDayKey,
            timeZoneIdentifier: timeZoneIdentifier,
            period: period,
            rawValue: rawValue,
            normalizedScore: normalizedScore
        )
    }

    /// Upserts a list of entries into the local store.
    static func upsert(_ entries: [SQMetricEntry], in context: ModelContext) throws {
        for entry in entries {
            let id = entry.id
            let descriptor = FetchDescriptor<SQMetricEntryEntity>(
                predicate: #Predicate { $0.id == id }
            )
            if let existing = try context.fetch(descriptor).first {
                existing.rawValue = entry.rawValue
                existing.normalizedScore = entry.normalizedScore
                existing.periodRaw = entry.period.rawValue
                existing.recordedAt = entry.recordedAt
            } else {
                context.insert(SQMetricEntryEntity(entry: entry))
            }
        }
        try context.save()
    }

    /// Returns all entries for a given `anchorDayKey`, optionally filtered by period.
    static func getAll(
        for anchorDayKey: String,
        period: SQMetricPeriod? = nil,
        context: ModelContext
    ) throws -> [SQMetricEntry] {
        let descriptor = FetchDescriptor<SQMetricEntryEntity>(
            predicate: #Predicate { $0.anchorDayKey == anchorDayKey }
        )
        let entities = try context.fetch(descriptor)
        let filtered = period.map { p in entities.filter { $0.period == p } } ?? entities
        return filtered.map { $0.toEntry() }
    }

    /// Returns all entries with `recordedAt` after a given date (for incremental sync).
    static func getAll(after date: Date, context: ModelContext) throws -> [SQMetricEntry] {
        let descriptor = FetchDescriptor<SQMetricEntryEntity>(
            predicate: #Predicate { $0.recordedAt > date },
            sortBy: [SortDescriptor(\.recordedAt)]
        )
        return try context.fetch(descriptor).map { $0.toEntry() }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add BeastFitness/Models/DailyCheckIn/SQMetricEntryEntity.swift
git commit -m "feat: add SQMetricEntryEntity SwiftData model"
```

---

### Task 5: Create SQDailyNoteEntity.swift

**Files:**
- Create: `BeastFitness/Models/DailyCheckIn/SQDailyNoteEntity.swift`

- [ ] **Step 1: Create the file**

```swift
//
//  SQDailyNoteEntity.swift
//  BeastFitness
//

import Foundation
import SwiftData

/// SwiftData entity for persisting a user's daily note locally.
/// One note per calendar day, keyed by `anchorDayKey`.
@Model
final class SQDailyNoteEntity {

    /// "YYYY-MM-DD" in the user's local timezone — unique per day; also used as Firestore document ID.
    @Attribute(.unique) var anchorDayKey: String
    /// The user's free-form note text.
    var content: String
    /// UTC timestamp of last edit — used for incremental Firestore sync.
    var updatedAt: Date

    init(note: SQDailyNote) {
        self.anchorDayKey = note.anchorDayKey
        self.content = note.content
        self.updatedAt = note.updatedAt
    }
}

// MARK: - Conversion

extension SQDailyNoteEntity {

    func toNote() -> SQDailyNote {
        SQDailyNote(anchorDayKey: anchorDayKey, content: content, updatedAt: updatedAt)
    }

    /// Upserts a note for the given day. Creates if absent, updates content if present.
    static func upsert(_ note: SQDailyNote, in context: ModelContext) throws {
        let key = note.anchorDayKey
        let descriptor = FetchDescriptor<SQDailyNoteEntity>(
            predicate: #Predicate { $0.anchorDayKey == key }
        )
        if let existing = try context.fetch(descriptor).first {
            existing.content = note.content
            existing.updatedAt = note.updatedAt
        } else {
            context.insert(SQDailyNoteEntity(note: note))
        }
        try context.save()
    }

    /// Returns the note for a given `anchorDayKey`, or nil if none exists.
    static func get(for anchorDayKey: String, context: ModelContext) throws -> SQDailyNote? {
        let descriptor = FetchDescriptor<SQDailyNoteEntity>(
            predicate: #Predicate { $0.anchorDayKey == anchorDayKey }
        )
        return try context.fetch(descriptor).first?.toNote()
    }

    /// Returns all notes updated after a given date (for incremental sync).
    static func getAll(after date: Date, context: ModelContext) throws -> [SQDailyNote] {
        let descriptor = FetchDescriptor<SQDailyNoteEntity>(
            predicate: #Predicate { $0.updatedAt > date }
        )
        return try context.fetch(descriptor).map { $0.toNote() }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add BeastFitness/Models/DailyCheckIn/SQDailyNoteEntity.swift
git commit -m "feat: add SQDailyNoteEntity SwiftData model"
```

---

### Task 6: Register new entities in BeastFitnessApp.swift

**Files:**
- Modify: `BeastFitness/BeastFitnessApp.swift`

- [ ] **Step 1: Add new entities to the `.modelContainer` call**

Find the `.modelContainer(for:)` modifier (currently lists 5 entity types). Add `SQMetricEntryEntity.self` and `SQDailyNoteEntity.self` to the array:

```swift
.modelContainer(for: [
    SQDailyCheckInEntity.self,
    SQWorkoutSessionEntity.self,
    SQMetricDefinitionEntity.self,
    SQSyncMetadataEntity.self,
    SQWorkoutProcessedEntity.self,
    SQMetricEntryEntity.self,   // New: canonical metric entry storage
    SQDailyNoteEntity.self,     // New: per-day notes
])
```

- [ ] **Step 2: Commit**

```bash
git add BeastFitness/BeastFitnessApp.swift
git commit -m "feat: register SQMetricEntryEntity and SQDailyNoteEntity in SwiftData container"
```

---

### Task 7: Create Firestore routes and services

**Files:**
- Create: `BeastFitness/Networking/Routers/SQMetricEntryRoute.swift`
- Create: `BeastFitness/Networking/Services/SQMetricEntryService.swift`
- Create: `BeastFitness/Networking/Routers/SQDailyNoteRoute.swift`
- Create: `BeastFitness/Networking/Services/SQDailyNoteService.swift`

Check the existing `SQDailyCheckInRoute.swift` and `SQDailyCheckInService.swift` for the exact import patterns, `SQFirestoreRoute` protocol, `SQNetworkService` base class, and `SQVoidWrite` usage before writing these files.

- [ ] **Step 1: Create SQMetricEntryRoute.swift**

```swift
//
//  SQMetricEntryRoute.swift
//  BeastFitness
//

import Foundation
import FirebaseFirestore

enum SQMetricEntryRoute {
    /// Saves (writes) a single metric entry document for a user.
    case saveMetricEntry(SQMetricEntry, user: SQUser)
    /// Fetches all metric entries for a user, optionally after a date for incremental sync.
    case fetchMetricEntries(user: SQUser, afterDate: Date?)
}

extension SQMetricEntryRoute: SQFirestoreRoute {

    var writeBody: Encodable? {
        switch self {
        case .saveMetricEntry(let entry, _): return entry
        case .fetchMetricEntries: return nil
        }
    }

    func reference(in db: Firestore) -> SQFirestoreReference {
        switch self {
        case .saveMetricEntry(let entry, let user):
            let ref = db.collection("users/\(user.id)/metric-entries").document(entry.id)
            return .documentWrite(ref)

        case .fetchMetricEntries(let user, let afterDate):
            let collection = db.collection("users/\(user.id)/metric-entries")
            if let afterDate {
                let query = collection.whereField("recordedAt", isGreaterThan: afterDate)
                return .query(query)
            }
            return .collection(collection)
        }
    }
}
```

- [ ] **Step 2: Create SQMetricEntryService.swift**

```swift
//
//  SQMetricEntryService.swift
//  BeastFitness
//

import Foundation
import BeastFitnessCore

protocol SQMetricEntryServicing {
    static func saveMetricEntry(_ entry: SQMetricEntry, for user: SQUser) async throws
    static func fetchMetricEntries(for user: SQUser, afterDate: Date?) async throws -> [SQMetricEntry]
}

final class SQMetricEntryService: SQNetworkService, SQMetricEntryServicing {

    static func saveMetricEntry(_ entry: SQMetricEntry, for user: SQUser) async throws {
        let _: SQVoidWrite = try await performRequest(
            SQMetricEntryRoute.saveMetricEntry(entry, user: user)
        )
    }

    static func fetchMetricEntries(for user: SQUser, afterDate: Date? = nil) async throws -> [SQMetricEntry] {
        try await performRequest(SQMetricEntryRoute.fetchMetricEntries(user: user, afterDate: afterDate))
    }
}
```

- [ ] **Step 3: Create SQDailyNoteRoute.swift**

```swift
//
//  SQDailyNoteRoute.swift
//  BeastFitness
//

import Foundation
import FirebaseFirestore

enum SQDailyNoteRoute {
    /// Saves (writes) a daily note document for a user.
    case saveDailyNote(SQDailyNote, user: SQUser)
    /// Fetches all daily notes for a user, optionally after a date for incremental sync.
    case fetchDailyNotes(user: SQUser, afterDate: Date?)
}

extension SQDailyNoteRoute: SQFirestoreRoute {

    var writeBody: Encodable? {
        switch self {
        case .saveDailyNote(let note, _): return note
        case .fetchDailyNotes: return nil
        }
    }

    func reference(in db: Firestore) -> SQFirestoreReference {
        switch self {
        case .saveDailyNote(let note, let user):
            let ref = db.collection("users/\(user.id)/daily-notes").document(note.anchorDayKey)
            return .documentWrite(ref)

        case .fetchDailyNotes(let user, let afterDate):
            let collection = db.collection("users/\(user.id)/daily-notes")
            if let afterDate {
                let query = collection.whereField("updatedAt", isGreaterThan: afterDate)
                return .query(query)
            }
            return .collection(collection)
        }
    }
}
```

- [ ] **Step 4: Create SQDailyNoteService.swift**

```swift
//
//  SQDailyNoteService.swift
//  BeastFitness
//

import Foundation
import BeastFitnessCore

protocol SQDailyNoteServicing {
    static func saveDailyNote(_ note: SQDailyNote, for user: SQUser) async throws
    static func fetchDailyNotes(for user: SQUser, afterDate: Date?) async throws -> [SQDailyNote]
}

final class SQDailyNoteService: SQNetworkService, SQDailyNoteServicing {

    static func saveDailyNote(_ note: SQDailyNote, for user: SQUser) async throws {
        let _: SQVoidWrite = try await performRequest(
            SQDailyNoteRoute.saveDailyNote(note, user: user)
        )
    }

    static func fetchDailyNotes(for user: SQUser, afterDate: Date? = nil) async throws -> [SQDailyNote] {
        try await performRequest(SQDailyNoteRoute.fetchDailyNotes(user: user, afterDate: afterDate))
    }
}
```

- [ ] **Step 5: Commit**

```bash
git add BeastFitness/Networking/Routers/SQMetricEntryRoute.swift \
        BeastFitness/Networking/Services/SQMetricEntryService.swift \
        BeastFitness/Networking/Routers/SQDailyNoteRoute.swift \
        BeastFitness/Networking/Services/SQDailyNoteService.swift
git commit -m "feat: add Firestore routes and services for metric entries and daily notes"
```

---

## Chunk 3: Business Logic

### Task 8: Update SQMetricsManager preset catalog

**Files:**
- Modify: `BeastFitness/Managers/SQMetricsManager.swift`

Read `SQMetricsManager.swift` fully before editing. The key method to replace is `presetMetrics()`. You also need to update the `SQMetricsManaging` protocol to add `dailyCheckInMetrics(for:)`.

- [ ] **Step 1: Add `dailyCheckInMetrics(for period:)` to the `SQMetricsManaging` protocol**

Find the protocol definition and add:
```swift
/// Returns enabled metrics for a specific check-in period, sorted by sortOrder.
func dailyCheckInMetrics(for period: SQMetricPeriod) -> [SQMetricDefinition]
```

- [ ] **Step 2: Implement `dailyCheckInMetrics(for period:)` in `SQMetricsManager`**

Add the implementation after the existing `dailyCheckInMetrics()` method:
```swift
func dailyCheckInMetrics(for period: SQMetricPeriod) -> [SQMetricDefinition] {
    metrics
        .filter { $0.isEnabled && !$0.isArchived && $0.period == period }
        .sorted { $0.sortOrder < $1.sortOrder }
}
```

- [ ] **Step 3: Replace `presetMetrics()` with the new catalog**

Find the `presetMetrics()` function and replace its body completely:

```swift
private static func presetMetrics() -> [SQMetricDefinition] {
    [
        // MARK: Stats (morning)
        .init(id: SQMetricId.weight, title: "Weight", kind: .number, unit: .pounds,
              group: SQDefaultGroup.stats.rawValue,
              min: 0, max: 1000, step: 0.1,
              isPreset: true, isEnabled: false, isDefault: false,
              sortOrder: 0, emoji: "⚖️", period: .morning),

        // MARK: Self (morning) — all enabled by default
        .init(id: SQMetricId.mood, title: "Mood", kind: .scale, unit: .none,
              group: SQDefaultGroup.self_.rawValue,
              min: 0, max: 10, step: 1,
              isPreset: true, isEnabled: true, isDefault: true,
              sortOrder: 10, emoji: "😊", period: .morning),

        .init(id: SQMetricId.mentalClarity, title: "Mental Clarity", kind: .scale, unit: .none,
              group: SQDefaultGroup.self_.rawValue,
              min: 0, max: 10, step: 1,
              isPreset: true, isEnabled: true, isDefault: true,
              sortOrder: 11, emoji: "🧠", period: .morning),

        .init(id: SQMetricId.energy, title: "Energy Level", kind: .scale, unit: .none,
              group: SQDefaultGroup.self_.rawValue,
              min: 0, max: 10, step: 1,
              isPreset: true, isEnabled: true, isDefault: true,
              sortOrder: 12, emoji: "⚡", period: .morning),

        .init(id: SQMetricId.soreness, title: "Soreness / Recovery", kind: .scale, unit: .none,
              group: SQDefaultGroup.self_.rawValue,
              min: 0, max: 10, step: 1,
              isPreset: true, isEnabled: true, isDefault: true,
              sortOrder: 13, emoji: "💪", period: .morning),

        // MARK: Sleep (morning — reflects prior night)
        .init(id: SQMetricId.sleepQuality, title: "Sleep Quality", kind: .scale, unit: .none,
              group: SQDefaultGroup.sleep.rawValue,
              min: 0, max: 10, step: 1,
              isPreset: true, isEnabled: false, isDefault: false,
              sortOrder: 20, emoji: "😴", period: .morning),

        .init(id: SQMetricId.sleepHours, title: "Sleep Hours", kind: .number, unit: .hours,
              group: SQDefaultGroup.sleep.rawValue,
              min: 0, max: 24, step: 0.5,
              isPreset: true, isEnabled: false, isDefault: false,
              sortOrder: 21, emoji: "🌙", period: .morning),

        // MARK: Positive Habits (evening)
        .init(id: SQMetricId.meditation, title: "Meditation", kind: .scale, unit: .none,
              group: SQDefaultGroup.positiveHabits.rawValue,
              min: 0, max: 10, step: 1,
              isPreset: true, isEnabled: false, isDefault: false,
              sortOrder: 30, emoji: "🧘", period: .evening),

        .init(id: SQMetricId.nutrition, title: "Nutrition", kind: .scale, unit: .none,
              group: SQDefaultGroup.positiveHabits.rawValue,
              min: 0, max: 10, step: 1,
              isPreset: true, isEnabled: true, isDefault: true,
              sortOrder: 31, emoji: "🥗", period: .evening),

        // MARK: Vices (evening) — alcohol and caffeine enabled by default
        .init(id: SQMetricId.alcohol, title: "Alcohol", kind: .scale, unit: .none,
              group: SQDefaultGroup.vices.rawValue,
              min: 0, max: 10, step: 1,
              isPreset: true, isEnabled: true, isDefault: true,
              sortOrder: 40, emoji: "🍺", period: .evening),

        .init(id: SQMetricId.caffeine, title: "Caffeine", kind: .scale, unit: .none,
              group: SQDefaultGroup.vices.rawValue,
              min: 0, max: 10, step: 1,
              isPreset: true, isEnabled: true, isDefault: true,
              sortOrder: 41, emoji: "☕", period: .evening),

        .init(id: SQMetricId.weed, title: "Weed", kind: .scale, unit: .none,
              group: SQDefaultGroup.vices.rawValue,
              min: 0, max: 10, step: 1,
              isPreset: true, isEnabled: false, isDefault: false,
              sortOrder: 42, emoji: "🌿", period: .evening),

        .init(id: SQMetricId.porn, title: "Porn", kind: .scale, unit: .none,
              group: SQDefaultGroup.vices.rawValue,
              min: 0, max: 10, step: 1,
              isPreset: true, isEnabled: false, isDefault: false,
              sortOrder: 43, emoji: nil, period: .evening),

        .init(id: SQMetricId.nicotine, title: "Nicotine", kind: .scale, unit: .none,
              group: SQDefaultGroup.vices.rawValue,
              min: 0, max: 10, step: 1,
              isPreset: true, isEnabled: false, isDefault: false,
              sortOrder: 44, emoji: "🚬", period: .evening),
    ]
}
```

- [ ] **Step 4: Update the `migrateNewPresets()` method**

Find `migrateNewPresets()`. It inserts any new preset IDs that don't yet exist in local storage. The new preset IDs to add are `nutrition` and `nicotine`. The method should already handle this automatically by comparing `existingIds` against `presetMetrics()` — verify this is the case and confirm the new IDs will be picked up automatically. If the method iterates `presetMetrics()` and inserts any with IDs not in `existingIds`, no changes are needed beyond the updated `presetMetrics()`.

Also find where existing preset metrics are updated on migration (to pick up `period` and `isDefault` for metrics that already exist). Add a step that updates all existing preset entities to apply the latest `period` and `isDefault` values from `presetMetrics()`. This handles existing users getting the new field values:

Find the migration function (likely called `loadIfNeeded` or `migrateNewPresets`) and after inserting new presets, add:

```swift
// Update period and isDefault for all existing presets (new fields added in this migration)
let latestPresets = Self.presetMetrics()
for entity in entities where entity.isPreset {
    if let latest = latestPresets.first(where: { $0.id == entity.id }) {
        entity.periodRaw = latest.period.rawValue
        entity.isDefault = latest.isDefault
        // Convert legacy binary metrics to scale
        if entity.kindRaw == SQMetricKind.binary.rawValue {
            entity.kindRaw = SQMetricKind.scale.rawValue
            entity.minValue = 0
            entity.maxValue = 10
            entity.stepValue = 1
        }
    }
}
```

- [ ] **Step 5: Commit**

```bash
git add BeastFitness/Managers/SQMetricsManager.swift
git commit -m "feat: overhaul preset metrics catalog with new groups, periods, isDefault; add dailyCheckInMetrics(for:)"
```

---

### Task 9: Create SQMetricEntryManager.swift

**Files:**
- Create: `BeastFitness/Managers/SQMetricEntryManager.swift`

Read `SQDailyCheckInManager.swift` for sync pattern reference before writing this file. Also read the `SQSyncMetadataEntity` usage in `SQDailyCheckInManager.swift`.

- [ ] **Step 1: Create the file**

```swift
//
//  SQMetricEntryManager.swift
//  BeastFitness
//

import SwiftData
import Foundation
import BeastFitnessCore

// MARK: - Protocol

@MainActor
protocol SQMetricEntryManaging: AnyObject {
    var hub: EventHub { get }

    /// Saves a set of metric entries and an optional note for the day to local storage and Firestore.
    func save(entries: [SQMetricEntry], note: SQDailyNote?, to context: ModelContext) async throws

    /// Returns all entries for a given calendar day (all periods), built as a stats aggregate for display.
    /// Also returns the note for that day if one exists.
    func getEntries(for anchorDayKey: String, context: ModelContext) throws -> [SQMetricEntry]

    /// Returns the note for a given calendar day, or nil if none exists.
    func getNote(for anchorDayKey: String, context: ModelContext) throws -> SQDailyNote?

    /// Syncs metric entries and notes from Firestore if needed.
    func syncIfNeeded(for timeRange: SQTimeRange, context: ModelContext) async throws -> SyncResult
}

// MARK: - Implementation

@MainActor
@Observable
final class SQMetricEntryManager: SQMetricEntryManaging {

    let hub: EventHub
    private let entryService: SQMetricEntryServicing.Type
    private let noteService: SQDailyNoteServicing.Type

    init(
        hub: EventHub,
        entryService: SQMetricEntryServicing.Type = SQMetricEntryService.self,
        noteService: SQDailyNoteServicing.Type = SQDailyNoteService.self
    ) {
        self.hub = hub
        self.entryService = entryService
        self.noteService = noteService
    }

    // MARK: - Save

    func save(entries: [SQMetricEntry], note: SQDailyNote?, to context: ModelContext) async throws {
        // Save entries locally
        do {
            try SQMetricEntryEntity.upsert(entries, in: context)
        } catch {
            SQLogger.shared.log("Failed to save entries to SwiftData: \(error)", .error, context: .dailyCheckIn)
            throw error
        }

        // Save note locally if present
        if let note {
            do {
                try SQDailyNoteEntity.upsert(note, in: context)
            } catch {
                SQLogger.shared.log("Failed to save note to SwiftData: \(error)", .error, context: .dailyCheckIn)
                throw error
            }
        }

        // Push to Firestore (non-throwing — failures are logged but don't block the user)
        let user = SQAppState.shared.userState.loggedInUser
        for entry in entries {
            do {
                try await entryService.saveMetricEntry(entry, for: user)
            } catch {
                SQLogger.shared.log("Firestore push failed for entry \(entry.id): \(error)", .error, context: .dailyCheckIn)
            }
        }
        if let note {
            do {
                try await noteService.saveDailyNote(note, for: user)
            } catch {
                SQLogger.shared.log("Firestore push failed for note \(note.anchorDayKey): \(error)", .error, context: .dailyCheckIn)
            }
        }

        SQLogger.shared.log("Saved \(entries.count) entries", .info, context: .dailyCheckIn)
    }

    // MARK: - Read

    func getEntries(for anchorDayKey: String, context: ModelContext) throws -> [SQMetricEntry] {
        try SQMetricEntryEntity.getAll(for: anchorDayKey, context: context)
    }

    func getNote(for anchorDayKey: String, context: ModelContext) throws -> SQDailyNote? {
        try SQDailyNoteEntity.get(for: anchorDayKey, context: context)
    }

    // MARK: - Sync

    func syncIfNeeded(for timeRange: SQTimeRange, context: ModelContext) async throws -> SyncResult {
        SQLogger.shared.log("Checking entry sync for \(timeRange)", .debug, context: .dailyCheckIn)

        let localEntries = try SQMetricEntryEntity.getAll(
            after: timeRange.startDate,
            context: context
        )
        let lastSync = getLastSyncDate(context: context)

        if localEntries.isEmpty || lastSync == nil {
            let count = try await performFullSync(context: context)
            SyncResult.fullSyncCompleted.logSync(documentCount: count, service: "MetricEntries", context: .dailyCheckIn)
            return .fullSyncCompleted
        } else if shouldRefresh(lastSync: lastSync) {
            let count = try await performIncrementalSync(lastSync: lastSync, context: context)
            SyncResult.refreshCompleted.logSync(documentCount: count, service: "MetricEntries", context: .dailyCheckIn)
            return .refreshCompleted
        } else {
            SyncResult.noSyncNeeded.logSync(service: "MetricEntries", context: .dailyCheckIn)
            return .noSyncNeeded
        }
    }

    // MARK: - Private Sync Helpers

    private func performFullSync(context: ModelContext) async throws -> Int {
        let user = SQAppState.shared.userState.loggedInUser
        let entries = try await entryService.fetchMetricEntries(for: user, afterDate: nil)
        let notes   = try await noteService.fetchDailyNotes(for: user, afterDate: nil)

        try SQMetricEntryEntity.upsert(entries, in: context)
        for note in notes { try SQDailyNoteEntity.upsert(note, in: context) }

        updateLastSyncDate(to: .now, context: context)
        Task { @MainActor in
            SQFirestoreMetricsManager.shared.recordReads(
                entries.count + notes.count,
                operation: "Full sync metric entries + notes"
            )
        }
        return entries.count + notes.count
    }

    private func performIncrementalSync(lastSync: Date?, context: ModelContext) async throws -> Int {
        let user = SQAppState.shared.userState.loggedInUser
        let entries = try await entryService.fetchMetricEntries(for: user, afterDate: lastSync)
        let notes   = try await noteService.fetchDailyNotes(for: user, afterDate: lastSync)

        try SQMetricEntryEntity.upsert(entries, in: context)
        for note in notes { try SQDailyNoteEntity.upsert(note, in: context) }

        updateLastSyncDate(to: .now, context: context)
        Task { @MainActor in
            SQFirestoreMetricsManager.shared.recordReads(
                entries.count + notes.count,
                operation: "Incremental sync metric entries + notes"
            )
        }
        return entries.count + notes.count
    }

    private func shouldRefresh(lastSync: Date?) -> Bool {
        guard let lastSync else { return true }
        return Date().timeIntervalSince(lastSync) / 3600 > 6
    }

    // MARK: - Sync Metadata

    private let syncMetadataId = "metric-entries-sync"

    private func getLastSyncDate(context: ModelContext) -> Date? {
        let id = syncMetadataId
        let descriptor = FetchDescriptor<SQSyncMetadataEntity>(
            predicate: #Predicate { $0.id == id }
        )
        return (try? context.fetch(descriptor).first?.lastSyncDate) ?? nil
    }

    private func updateLastSyncDate(to date: Date, context: ModelContext) {
        let id = syncMetadataId
        let descriptor = FetchDescriptor<SQSyncMetadataEntity>(
            predicate: #Predicate { $0.id == id }
        )
        do {
            if let existing = try context.fetch(descriptor).first {
                existing.lastSyncDate = date
            } else {
                let meta = SQSyncMetadataEntity(id: id)
                meta.lastSyncDate = date
                context.insert(meta)
            }
            try context.save()
        } catch {
            SQLogger.shared.log("Failed to save entry sync metadata: \(error)", .error, context: .dailyCheckIn)
        }
    }
}
```

- [ ] **Step 2: Add `metricEntryManager` to `SQAppState`**

Open `BeastFitness/AppState/SQAppState.swift`. Follow the existing pattern (see `dashboardState`, `workoutSessionState`).

Add property:
```swift
let metricEntryManager: SQMetricEntryManager
```

Initialize in `init()`:
```swift
self.metricEntryManager = .init(hub: hub)
```

- [ ] **Step 3: Commit**

```bash
git add BeastFitness/Managers/SQMetricEntryManager.swift BeastFitness/AppState/SQAppState.swift
git commit -m "feat: add SQMetricEntryManager and register in SQAppState"
```

---

### Task 10: Create SQMetricMigrationManager.swift

**Files:**
- Create: `BeastFitness/Managers/SQMetricMigrationManager.swift`

- [ ] **Step 1: Create the file**

```swift
//
//  SQMetricMigrationManager.swift
//  BeastFitness
//

import SwiftData
import Foundation
import BeastFitnessCore

/// One-time migration from the legacy `SQDailyCheckInEntity` / `SQDailyCheckInStats` format
/// to the new `SQMetricEntryEntity` + `SQDailyNoteEntity` format.
///
/// The migration is idempotent and controlled by a flag in `SQSyncMetadataEntity`.
/// Set `forceReMigrate = true` during development to re-run.
@MainActor
final class SQMetricMigrationManager {

    /// Set to `true` to force the migration to re-run even if it has already completed.
    /// For development/debugging only.
    static var forceReMigrate = false

    private static let migrationKey = "metric-entry-migration-v1"

    // MARK: - Run Migration

    /// Runs the migration if it has not already been completed (or if `forceReMigrate` is true).
    static func runIfNeeded(
        context: ModelContext,
        metricsManager: SQMetricsManaging
    ) {
        guard !hasMigrated(context: context) || forceReMigrate else {
            SQLogger.shared.log("Migration already completed, skipping", .debug, context: .dailyCheckIn)
            return
        }

        SQLogger.shared.log("Starting metric entry migration...", .info, context: .dailyCheckIn, isPriority: true)
        do {
            let count = try migrate(context: context, metricsManager: metricsManager)
            markMigrated(context: context)
            SQLogger.shared.log("Migration complete: \(count) entries created", .info, context: .dailyCheckIn, isPriority: true)
        } catch {
            SQLogger.shared.log("Migration failed: \(error)", .error, context: .dailyCheckIn, isPriority: true)
        }
    }

    // MARK: - Private Migration Logic

    @discardableResult
    private static func migrate(
        context: ModelContext,
        metricsManager: SQMetricsManaging
    ) throws -> Int {

        // Load all legacy check-in entities
        let legacyDescriptor = FetchDescriptor<SQDailyCheckInEntity>()
        let legacyEntities = try context.fetch(legacyDescriptor)

        SQLogger.shared.log("Migrating \(legacyEntities.count) legacy check-in records", .info, context: .dailyCheckIn)

        // Build a lookup for metric definitions (to get period, min, max)
        let allMetrics = metricsManager.allMetrics(includeArchived: true)
        let metricById = Dictionary(uniqueKeysWithValues: allMetrics.map { ($0.id, $0) })

        var totalEntries = 0
        let tz = TimeZone.current

        for entity in legacyEntities {
            let stats = entity.toStats()
            let anchorDayKey = stats.date.anchorDayKey(in: tz)

            // Convert each metric value to a SQMetricEntry
            var entries: [SQMetricEntry] = []
            for (metricId, rawValue) in stats.values {
                let definition = metricById[metricId]
                let period = definition?.period ?? .morning
                let normalizedScore = definition.map {
                    SQMetricEntry.normalizedScore(for: rawValue, definition: $0)
                } ?? rawValue

                let entry = SQMetricEntry(
                    metricId: metricId,
                    recordedAt: stats.date,   // Start-of-day approximation for legacy data
                    anchorDayKey: anchorDayKey,
                    timeZoneIdentifier: tz.identifier,
                    period: period,
                    rawValue: rawValue,
                    normalizedScore: normalizedScore
                )
                entries.append(entry)
            }

            try SQMetricEntryEntity.upsert(entries, in: context)
            totalEntries += entries.count

            // Migrate notes
            if let notesText = stats.notes, !notesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let note = SQDailyNote(
                    anchorDayKey: anchorDayKey,
                    content: notesText,
                    updatedAt: stats.date
                )
                try SQDailyNoteEntity.upsert(note, in: context)
            }
        }

        return totalEntries
    }

    // MARK: - Migration Flag

    private static func hasMigrated(context: ModelContext) -> Bool {
        let key = migrationKey
        let descriptor = FetchDescriptor<SQSyncMetadataEntity>(
            predicate: #Predicate { $0.id == key }
        )
        return (try? context.fetch(descriptor).first?.lastSyncDate) != nil
    }

    private static func markMigrated(context: ModelContext) {
        let key = migrationKey
        let descriptor = FetchDescriptor<SQSyncMetadataEntity>(
            predicate: #Predicate { $0.id == key }
        )
        do {
            if let existing = try context.fetch(descriptor).first {
                existing.lastSyncDate = .now
            } else {
                let meta = SQSyncMetadataEntity(id: key)
                meta.lastSyncDate = .now
                context.insert(meta)
            }
            try context.save()
        } catch {
            SQLogger.shared.log("Failed to mark migration as complete: \(error)", .error, context: .dailyCheckIn)
        }
    }
}
```

- [ ] **Step 2: Call migration at app launch**

Open `BeastFitness/BeastFitnessApp.swift`. Find where launch tasks are run (the `onAppear` or launch task method). Call the migration after the metrics manager loads, passing the model context:

```swift
// Run one-time migration from legacy check-in format → metric entries
Task { @MainActor in
    SQMetricMigrationManager.runIfNeeded(
        context: modelContext,
        metricsManager: SQMetricsManager.shared
    )
}
```

Look at how other launch tasks are structured in the file and follow the same pattern.

- [ ] **Step 3: Commit**

```bash
git add BeastFitness/Managers/SQMetricMigrationManager.swift BeastFitness/BeastFitnessApp.swift
git commit -m "feat: add SQMetricMigrationManager with one-time migration from legacy check-ins"
```

---

### Task 11: Update SQDailyCheckInManager to use new storage

**Files:**
- Modify: `BeastFitness/Managers/SQDailyCheckInManager.swift`

The manager needs to:
1. Write `SQMetricEntry` + `SQDailyNote` on save (in addition to or instead of `SQDailyCheckInEntity`)
2. Build `SQDailyCheckInStats` from `SQMetricEntryEntity` on read

- [ ] **Step 1: Update `saveDailyCheckInStats` to also write metric entries**

Update the `saveDailyCheckInStats` function. It now needs access to metric definitions to compute normalized scores. Inject `metricsManager` or use `SQMetricsManager.shared` directly:

```swift
func saveDailyCheckInStats(stats: SQDailyCheckInStats, to modelContext: ModelContext) async throws {

    // Keep writing to legacy entity for now (dashboard reads from it until fully migrated)
    do {
        try SQDailyCheckInEntity.upsert(stats: stats, in: modelContext)
    } catch {
        SQLogger.shared.log("Saving daily stats to SwiftData failed: \(error)", .error, context: .dailyCheckIn)
        throw error
    }

    // Also write to new SQMetricEntry format
    let metricsManager = SQMetricsManager.shared
    let allMetrics = metricsManager.allMetrics(includeArchived: true)
    let metricById = Dictionary(uniqueKeysWithValues: allMetrics.map { ($0.id, $0) })
    let tz = TimeZone.current
    let anchorDayKey = stats.date.anchorDayKey(in: tz)
    let now = Date.now

    var entries: [SQMetricEntry] = []
    for (metricId, rawValue) in stats.values {
        guard let definition = metricById[metricId] else { continue }
        let entry = SQMetricEntry.make(
            metricId: metricId,
            rawValue: rawValue,
            definition: definition,
            recordedAt: now
        )
        entries.append(entry)
    }

    try SQMetricEntryEntity.upsert(entries, in: modelContext)

    if let notesText = stats.notes, !notesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        let note = SQDailyNote(anchorDayKey: anchorDayKey, content: notesText)
        try SQDailyNoteEntity.upsert(note, in: modelContext)
    }

    // Firestore push (existing legacy push + new entry push)
    do {
        try await dailyCheckInService.saveDailyCheckInStats(stats)
    } catch {
        SQLogger.shared.log("Legacy Firestore push failed: \(error)", .debug, context: .dailyCheckIn)
    }

    let user = SQAppState.shared.userState.loggedInUser
    for entry in entries {
        do {
            try await SQMetricEntryService.saveMetricEntry(entry, for: user)
        } catch {
            SQLogger.shared.log("Entry Firestore push failed for \(entry.metricId): \(error)", .error, context: .dailyCheckIn)
        }
    }
}
```

- [ ] **Step 2: Update `getDailyCheckInStats` to read from new entry format**

```swift
func getDailyCheckInStats(for date: Date, context: ModelContext) async throws -> SQDailyCheckInStats? {
    let anchorDayKey = date.anchorDayKey()
    let entries = try SQMetricEntryEntity.getAll(for: anchorDayKey, context: context)

    if entries.isEmpty {
        // Fall back to legacy entity during transition period
        return try SQDailyCheckInEntity.get(for: date, context: context)
    }

    // Build SQDailyCheckInStats from entries
    var values: [String: Float] = [:]
    for entry in entries {
        values[entry.metricId] = entry.rawValue
    }

    let note = try SQDailyNoteEntity.get(for: anchorDayKey, context: context)
    return SQDailyCheckInStats(date: date, values: values, notes: note?.content)
}
```

- [ ] **Step 3: Commit**

```bash
git add BeastFitness/Managers/SQDailyCheckInManager.swift
git commit -m "feat: update SQDailyCheckInManager to dual-write metric entries and read from new format"
```

---

## Chunk 4: UI Wiring

### Task 12: Update SQDailyCheckInViewModel for period filtering

**Files:**
- Modify: `BeastFitness/ViewModels/Dashboard/DailyCheckIn/SQDailyCheckInViewModel.swift`

- [ ] **Step 1: Add `period` parameter to the ViewModel**

Add `period` property and update `init`:

```swift
/// The check-in period this view model represents (morning or evening).
/// Determines which subset of metrics is shown.
let period: SQMetricPeriod
```

Update `init` to accept `period`:
```swift
init(
    eventHub: EventHub,
    stats: SQDailyCheckInStats?,
    targetDate: Date = .now,
    period: SQMetricPeriod,
    dailyCheckInManager: SQDailyCheckInManaging = SQDailyCheckInManager(),
    metricsManager: SQMetricsManaging,
    onDismiss: @escaping () -> Void
) {
    self.period = period
    // ... rest of existing init
}
```

- [ ] **Step 2: Filter `buildRows` by period**

In `buildRows(for:)`, change:
```swift
let metrics = metricsManager.dailyCheckInMetrics()
```
to:
```swift
let metrics = metricsManager.dailyCheckInMetrics(for: period)
```

- [ ] **Step 3: Remove `SQBinaryYesNo` handling from `buildRows` and `submitTapped`**

In `buildRows`, the `.binary` case can now be treated as legacy only. Update the switch to handle `.binary` the same as `.scale` (fallthrough or convert to scale segments using 0–1 range):

```swift
case .binary:
    // Legacy: treat as a 0–10 scale for display purposes
    let segments = Self.scaleSegments(for: SQMetricDefinition(
        id: metric.id, title: metric.title, kind: .scale, unit: metric.unit,
        group: metric.group, min: 0, max: 1, step: 1,
        isPreset: metric.isPreset, sortOrder: metric.sortOrder
    ))
    guard !segments.isEmpty else { continue }
    let initial = Self.scaleInitialSelection(metricId: metric.id, stats: stats, segments: segments)
    let row = SQDailyCheckInRowSegmentedControlViewModel(
        field: field, title: displayTitle, segments: segments,
        initialSelection: initial, onFocused: { [weak self] in self?.handleRowFocused($0) }
    )
    built.append(row)
```

In `submitTapped`, the `.binary` case in the metric kind switch can be handled like `.scale`:

```swift
case .binary:
    if let segmented = row as? SQDailyCheckInRowSegmentedControlViewModel,
       let seg = segmented.selectedSegment,
       let v = Float(seg.id) {
        values[metricId] = v
    }
```

- [ ] **Step 4: Commit**

```bash
git add BeastFitness/ViewModels/Dashboard/DailyCheckIn/SQDailyCheckInViewModel.swift
git commit -m "feat: add period filtering to SQDailyCheckInViewModel"
```

---

### Task 13: Add period routing in DashboardState

**Files:**
- Modify: `BeastFitness/StateManagement/DashboardState.swift`

- [ ] **Step 1: Add period routing to `displayDailyCheckInSheet`**

Find `displayDailyCheckInSheet(with:for:)`. Add a helper that determines the current period from device time, then pass it to the ViewModel init:

```swift
func displayDailyCheckInSheet(with stats: SQDailyCheckInStats?, for date: Date? = nil) {
    let targetDate = date ?? .now
    let period = Self.checkInPeriod(for: .now)

    dailyCheckInViewModel = .init(
        eventHub: SQAppState.shared.hub,
        stats: stats,
        targetDate: targetDate,
        period: period,
        metricsManager: SQMetricsManager.shared,
        onDismiss: { [weak self] in
            self?.toggleDailyCheckInSheetVisibility(false)
        })
    toggleDailyCheckInSheetVisibility(true)
}

/// Determines the check-in period based on current device time.
/// Before noon → morning; noon or after → evening.
private static func checkInPeriod(for date: Date) -> SQMetricPeriod {
    let hour = Calendar.current.component(.hour, from: date)
    return hour < 12 ? .morning : .evening
}
```

- [ ] **Step 2: Commit**

```bash
git add BeastFitness/StateManagement/DashboardState.swift
git commit -m "feat: add morning/evening period routing to daily check-in sheet"
```

---

## Done

At this point:
- `SQMetricEntry` and `SQDailyNote` are the canonical storage format
- The updated metric catalog has new groups, periods, and metrics (Nutrition, Nicotine)
- All vices/habits use scale 0–10 (binary retired)
- Morning check-in shows Self + Sleep metrics; evening shows Positive Habits + Vices
- Period routing happens automatically based on device time at noon
- One-time migration converts all legacy check-in data to metric entries
- The data model supports future insight correlations (period, normalizedScore, anchorDayKey, recordedAt)

Hand off to the user for a build + smoke test.
