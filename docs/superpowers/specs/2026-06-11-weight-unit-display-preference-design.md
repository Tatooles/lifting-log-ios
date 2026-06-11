# Weight Unit Display Preference Design

## Context

GitHub issue 49 covers a data-model problem in the current weight unit setting. Changing the lb/kg setting currently fetches historical `LoggedSet` rows, converts `weight` and `placeholderWeight`, touches those rows, and can enqueue many sync mutations for completed workout history. With sync status now visible, users can see large pending queues from what should be a settings-only change.

The fix is to keep the pound/kilogram toggle, but make it a display and input preference rather than a historical data rewrite.

## Goals

- Keep the lb/kg setting in the app.
- Treat workout weights as stable canonical data below the UI boundary.
- Make changing the setting update only `UserSettings` and its sync outbox entry.
- Preserve a clean experience for users who choose kilograms from the beginning.
- Ensure CSV export respects the selected unit.
- Prevent floating-point precision artifacts from appearing in user-facing strings.

## Non-Goals

- Do not repair already-corrupted local or Convex weight data in this issue.
- Do not add per-set unit metadata in this issue.
- Do not run a local or Convex migration that rewrites historical workout rows.
- Do not change Convex sync payload semantics beyond documenting that synced weights are canonical pounds.

## Decision

Use pounds as the canonical persisted and synced weight unit for v1.

`LoggedSet.weight` and `LoggedSet.placeholderWeight` are interpreted as pounds everywhere below the UI boundary. Existing rows are treated as pounds because the current schema has no reliable way to reconstruct prior toggle history.

`UserSettings.weightUnit` remains a user preference only. Changing it updates `UserSettings`, records only a settings sync mutation, saves, and requests sync. It must not fetch, touch, convert, or enqueue mutations for `LoggedSet`, `LoggedExercise`, or `WorkoutSession` records.

## Conversion Rules

Use the precise conversion factor already represented by `MeasurementUnit` (`1 kg = 2.20462262185 lb`). The conversion factor is not rounded to `2.2`; using the precise factor keeps data correct and does not make the implementation meaningfully harder.

Keep full precision internally. Round only at presentation and export boundaries through shared formatting code.

Required conversion boundaries:

- Workout entry displays selected-unit values. Parsed input is converted from selected unit to canonical pounds before saving `LoggedSet.weight`.
- Placeholder weights are stored as canonical pounds and converted only for display in set rows.
- Starting from a past workout can copy past set weights into new placeholder weights without conversion, because both values are canonical pounds.
- Workout history and quick history convert stored pounds to the selected unit before formatting.
- Internal metrics may remain canonical pounds unless shown with a unit. Any visible volume must be converted or labeled clearly.
- CSV export converts weights from canonical pounds into the selected unit and writes the selected unit in the `unit` column.
- Sync payload mapping sends canonical pounds. Convex does not do display-unit conversion.

## Implementation Shape

Add a small unit-aware weight helper around `MeasurementUnit` so call sites do not manually decide conversion direction. It should support at least:

- Display weight from stored canonical pounds.
- Stored canonical pounds from user-entered display weight.
- Optional formatting helpers if that avoids duplicated formatter calls.

Update these areas:

- `SettingsMutationService.updateWeightUnit` stops fetching `LoggedSet` records and only updates settings.
- `UserSettings.updateWeightUnit` stops rewriting sets, or is removed/redirected if tests no longer need a model-level mutation method.
- `SetRowView` displays `weight` and `placeholderWeight` in the selected unit and converts parsed weight input back to pounds before calling the engine.
- History detail, exercise history, quick history, and any other read-only history surfaces convert before formatting.
- `WorkoutDataExportService` converts exported weights into the selected unit and keeps the `unit` column aligned with that selected unit.
- `SyncPayloadMapper.loggedSetPayload` continues sending stored canonical pounds without display conversion.

## Error Handling

Conversion helpers should preserve `nil` weights as `nil` so empty fields and missing placeholders keep their current behavior.

Invalid numeric input should continue using the existing parse behavior: an empty or unparseable weight clears the stored weight instead of crashing. The implementation should not add new alerts for normal in-field editing.

Settings save failures should keep the existing rollback and alert behavior in `SettingsView`. The important behavioral change is that the save attempt no longer includes historical set rewrites, which reduces the chance and blast radius of a failure.

## Testing

Cover behavior at the boundaries most likely to regress:

- Updating the weight unit changes only `UserSettings`; it does not mutate logged set weights, placeholder weights, logged set timestamps, or workout graph parent records.
- Updating the weight unit enqueues only the user settings outbox entry.
- Entering weights in pounds stores pounds unchanged.
- Entering weights in kilograms stores canonical pounds but displays the original kilogram value cleanly.
- Placeholder weights display in the selected unit without changing stored placeholders.
- Starting from a past workout carries canonical placeholder weights forward and displays them correctly.
- Workout history and quick history render selected-unit weights.
- CSV export converts the `weight` column to the selected unit and labels the `unit` column correctly.
- Sync payload mapping sends canonical stored pounds.
- Formatter coverage guards against floating-point artifacts such as `99.999999` or `100.0000001` reaching user-facing strings.

Add or update one to two UI tests for the user-visible risk:

- A kilogram-first workout entry flow: set units to kilograms, enter a normal kilogram value such as `100`, complete or revisit the set, and assert the UI shows a clean `100` rather than a floating-point artifact.
- A settings toggle display flow: create or use a completed workout, switch units, and assert workout or exercise history displays converted values cleanly without requiring any history-editing action from the user.

Existing tests that currently expect bulk conversion on settings change should be updated or removed because that behavior becomes the bug being eliminated.

## Risks

- Users who toggled units before this fix may already have rewritten local or synced weights. This issue intentionally does not infer or repair that history.
- Some UI surfaces currently assume stored weights are already in the selected unit. Implementation must search all workout entry, history, export, sync, and test call sites.
- Display rounding must be centralized enough that kg-first users do not see noisy decimals after entering normal kilogram values.

## Follow-Up

Create a separate follow-up to investigate the already-corrupted Convex/local weight data:

- Determine how the wrong weights were produced from available app, sync, and outbox behavior.
- Compare local and Convex records where possible.
- Decide whether a manual or automated repair path is possible.
- Keep any repair work separate from issue 49 so the prevention fix can land cleanly.
