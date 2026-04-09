# SwiftData Migration Plan

LifeIQ now boots SwiftData through [`SQPersistenceController`](/Users/patrickdoyle/Code/mapps/BeastFitness/BeastFitness/BeastFitness/Models/Sync/SQPersistenceController.swift), with an explicit `VersionedSchema` and `SchemaMigrationPlan`.

## Current shape

- `SQCurrentLocalSchema` points at `SQLocalPersistenceSchemaV1`.
- Persisted app models are declared inside `SQLocalPersistenceSchemaV1`.
- App code continues using the existing names (`SQWorkoutSessionEntity`, `SQMetricEntryEntity`, etc.) through top-level type aliases.
- `BeastFitnessApp` creates the container explicitly with `Schema(versionedSchema:)` and `SQPersistenceMigrationPlan`.

## Rules going forward

- Never edit an already-shipped schema version in place once it has reached production.
- Add a new schema version (`SQLocalPersistenceSchemaV2`, `V3`, etc.) for every persisted model change.
- Keep older schema types intact so staged migration can read prior stores.
- After adding the new schema, move `SQCurrentLocalSchema` to the latest version so the rest of the app targets the newest models.

## When to use each migration type

- Use `MigrationStage.lightweight` for additive or metadata-only changes SwiftData can infer safely.
- Use `MigrationStage.custom` for renames, required backfills, data reshaping, row consolidation, or any transform where correctness depends on our own code.

## Suggested workflow for a schema change

1. Copy the affected model definitions into a new `SQLocalPersistenceSchemaV*` version.
2. Make the schema edits only in the new version.
3. Update `SQPersistenceMigrationPlan.schemas`.
4. Add the migration stage from the prior version to the new version.
5. Point `SQCurrentLocalSchema` at the newest schema.
6. Test opening a store created by the previous production build before shipping.

## Notes for this repo

- `SQDailyCheckInEntity` was removed before production, so it is not part of the supported migration chain.
- When renaming a property or model, preserve store compatibility with SwiftData migration metadata (`originalName`) in the new schema version when appropriate.
- If a migration needs data backfill from workouts or daily check-ins, prefer a custom stage rather than relying on default values that can hide data loss.
