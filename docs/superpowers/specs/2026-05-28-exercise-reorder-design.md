# Exercise Reorder Design

## Context

GitHub issue 31 adds a focused reorder flow for exercises in an active workout. Users need to recover from entering exercises in the wrong order without deleting and recreating exercises that may already have sets, notes, placeholders, completion state, or edited values.

The current active workout screen shows a sticky header with elapsed time, set progress, and a prominent `Finish` button. Exercise cards already support expansion, history, set editing, notes, and deletion. This feature should not add drag behavior to the full exercise cards and should leave exercise card actions unchanged.

## User Flow

The sticky active workout header changes from `timer + set progress + Finish` to `timer + set progress + workout options menu`.

The workout options control is an icon-only native SwiftUI `Menu` using an ellipsis-style system icon. It has an accessibility label of `Workout options`.

The menu contains:

- `Finish Workout`
- `Reorder Exercises`

`Finish Workout` preserves the existing behavior and opens the current finish sheet. `Reorder Exercises` is disabled when the workout has fewer than two visible exercises.

Choosing `Reorder Exercises` opens a sheet titled `Reorder Exercises`. The sheet opens at a medium detent and can expand to large. It shows the current visible workout exercises in order. Each row contains the exercise name and compact set progress, such as `2/3 sets`. Drag handles are visible immediately because the user has already selected a reorder action.

The sheet has `Cancel` and `Done` actions. `Cancel` dismisses without changing the workout order. `Done` applies the draft order and dismisses after a successful save.

## Liquid Glass And Compatibility

The menu should use native SwiftUI menu controls so iOS 26 can render the system Liquid Glass menu presentation automatically. The app can keep its iOS 17 deployment target because the base menu does not require directly referencing iOS 26-only APIs.

If the workout options button itself uses iOS 26-specific glass styling later, that styling should be availability-gated with an iOS 17-compatible fallback. The v1 design should prioritize native controls over custom blur or hand-rolled glass effects.

## Architecture

The feature stays within the existing workout feature boundary.

- `WorkoutHeaderView` renders the workout options menu instead of a dedicated finish button.
- `WorkoutSessionView` owns presentation state for the reorder sheet, alongside the existing finish, add exercise, and history sheets.
- A new `ReorderExercisesSheet` view owns the draft exercise order and drag UI.
- `ActiveWorkoutEngine` exposes a focused reorder method, such as `reorderLoggedExercises(in:orderedIDs:context:)`.
- Exercise cards remain unchanged for this issue.

The engine method owns persistence because reordering is a domain mutation, not only view state. This keeps the sheet simple and gives unit tests a direct API for order updates, validation, and data preservation.

## Data Flow And Persistence

When the reorder sheet opens, it snapshots `session.sortedLoggedExercises` into a local draft array of exercise IDs. Dragging rows mutates only that draft array. No SwiftData writes happen while dragging.

On `Done`, the sheet passes the ordered IDs to `ActiveWorkoutEngine`. The engine resolves the IDs against the current `session.sortedLoggedExercises`, validates that the draft contains exactly the currently visible exercise IDs, then assigns contiguous `orderIndex` values starting at `0`.

Only moved visible exercises need updated `orderIndex` values and `updatedAt` timestamps. The session is touched once and the model context is saved once. Sets, notes, completion state, placeholders, reference notes, and exercise IDs are preserved because the existing `LoggedExercise` objects stay intact.

After save, `WorkoutSessionView` re-renders from `session.sortedLoggedExercises`. Existing collapsed state should follow exercises after reorder because `collapsedExerciseIDs` is keyed by `LoggedExercise.id`.

## Error Handling And Edge Cases

`Reorder Exercises` is disabled when there are fewer than two visible exercises.

If the sheet opens and the workout changes before `Done`, the engine validates before mutating. If the draft order no longer matches the current visible exercise IDs, the engine does not partially reorder. It reports an error through `engine.lastErrorMessage`, and the sheet remains open so the user does not think the reorder succeeded.

The sheet lists only non-deleted exercises. Tombstoned exercises are excluded from reorder validation and update. They keep their existing historical `orderIndex` values.

## Testing

Unit coverage goes in `ActiveWorkoutEngineTests`:

- Reordering exercises updates visible `orderIndex` values and changes `session.sortedLoggedExercises`.
- Reordering preserves each exercise's sets, notes, completion state, placeholders, and IDs.
- Invalid ordered IDs do not partially mutate the workout.
- Tombstoned exercises are excluded from reorder validation and left untouched.

UI coverage goes in `LiftingLogUITests`:

- Start a workout and add four exercises.
- Open the workout options menu and choose `Reorder Exercises`.
- Move an exercise in the sheet, tap `Done`, and verify the active workout card order changes.
- Confirm the menu disables reorder with fewer than two exercises if XCTest can assert that cleanly; otherwise keep that behavior covered through unit or accessibility-level validation.
