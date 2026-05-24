# Cloned Workout Placeholder Values Design

## Context

LiftingLog currently lets a user start a new active workout from a completed past workout. The clone keeps the old workout's structure and copies set values into the new workout as real values. The requested change is to make cloned workouts behave more like a last-session reference: the user can see what they did last time, but today's workout starts blank until the user enters or confirms values.

## Goals

- Preserve the past workout's title, exercise order, set count, and set kinds when cloning.
- Show previous weight and reps directly in the cloned set fields as placeholder text.
- Keep the new workout's actual weight, reps, and RPE values blank until the user enters or confirms them.
- Commit placeholder weight and reps into actual values when the user completes a set with the checkmark.
- Leave RPE blank by default because RPE is a subjective outcome of the current set, not a target to repeat.
- Start cloned workout notes and exercise notes blank.

## Non-Goals

- Do not add separate previous-value columns.
- Do not change blank workout behavior.
- Do not change add-set behavior outside cloned placeholder state.
- Do not auto-fill or placeholder RPE from past workouts.
- Do not migrate historical completed workouts to use placeholder values.

## User-Facing Behavior

When a user starts a workout from a past workout, the new workout opens with the same title and exercise layout. Each cloned set shows the past weight and reps as placeholders inside the existing weight and reps fields. The RPE field shows the normal `RPE` placeholder.

If the user types a weight or reps value, that typed value is saved immediately and takes precedence over the placeholder. If the user leaves weight or reps blank and taps the set checkmark, the placeholder value becomes the real saved value before the set is marked complete. If the user leaves RPE blank and taps the checkmark, RPE remains blank.

Workout notes and exercise notes are not copied into the new workout. They start blank so notes describe the current session.

## Data Model

Add optional placeholder fields to `LoggedSet`:

- `placeholderWeight: Double?`
- `placeholderReps: Int?`

These fields represent previous-session reference values for the active cloned workout. They are separate from actual logged values:

- Metrics and history continue to use `weight`, `reps`, and `rpe`.
- `completedVolume` remains based only on actual `weight` and `reps`.
- Existing non-cloned sets have nil placeholder fields.

The placeholder fields remain stored after completion. They are reference metadata and do not affect calculations. Keeping them avoids extra cleanup behavior and preserves a clear record of what the user saw as the prior reference while logging.

## Clone Flow

Update `ActiveWorkoutEngine.startWorkout(fromPast:context:now:)` so cloned sessions are initialized as follows:

- `WorkoutSession.title` copies the past title.
- `WorkoutSession.notes` is blank.
- `source` remains `.pastWorkout`.
- `sourceSessionID` remains the source session ID.
- Each `LoggedExercise` keeps order, exercise reference, and snapshot name.
- Each `LoggedExercise.notes` is blank.
- Each `LoggedSet` keeps order and kind.
- Each `LoggedSet.weight`, `reps`, and `rpe` start nil.
- Each `LoggedSet.placeholderWeight` receives the past set's weight.
- Each `LoggedSet.placeholderReps` receives the past set's reps.
- Each cloned set starts incomplete.

## Set Editing And Completion

Update `SetRowView` so the weight and reps text fields choose placeholders from the set's placeholder fields when actual values are blank:

- Weight placeholder uses formatted `placeholderWeight` if present, otherwise the unit placeholder such as `lb` or `kg`.
- Reps placeholder uses `placeholderReps` if present, otherwise `reps`.
- RPE remains `RPE`.

Update `ActiveWorkoutEngine.toggleSetCompletion` so completion commits blank actual values from placeholders:

- When changing from incomplete to complete, if `weight` is nil and `placeholderWeight` is present, assign `weight = placeholderWeight`.
- When changing from incomplete to complete, if `reps` is nil and `placeholderReps` is present, assign `reps = placeholderReps`.
- Do not overwrite non-nil actual values.
- Do not apply placeholder values when changing from complete back to incomplete.
- Do not apply any RPE placeholder.

This keeps manual edits authoritative while allowing one-tap confirmation for sets that match last time.

## Error Handling

No new user-facing error states are needed. The existing engine methods already throw on SwiftData save failures, and the existing callers surface `lastErrorMessage` where applicable.

The completion path updates placeholder-derived values and completion state in the same save operation. If saving fails, SwiftData state follows the existing completion behavior.

## Testing

Update and add unit coverage in `ActiveWorkoutEngineTests`:

- Starting from a past workout creates blank actual `weight`, `reps`, and `rpe` values while storing placeholder `weight` and `reps`.
- Starting from a past workout copies the title but blanks workout notes and exercise notes.
- Completing a cloned set commits placeholder weight and reps into actual values.
- Completing a cloned set does not overwrite manually entered weight or reps.
- Completing a cloned set leaves RPE nil unless the user entered RPE.

Existing metrics tests should continue to prove that incomplete placeholder-only sets do not count toward completed volume before confirmation.

## RPE Decision

RPE will not be placeholdered or auto-committed. This follows the product intent that RPE records today's perceived effort rather than last session's target.
