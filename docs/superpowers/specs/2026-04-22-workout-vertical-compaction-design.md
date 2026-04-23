# Workout Vertical Compaction Design

**Date:** 2026-04-22

**Goal:** Tighten the workout/form screen vertically so more of the active workout is visible at once, without changing the existing information architecture or making controls feel cramped.

## Scope

- Limit the work to the workout flow only.
- Keep behavior, navigation, and data flow unchanged.
- Reduce vertical bulk in the sticky workout header, workout title/date block, exercise cards, set rows, and workout notes controls.
- Leave history, profile, and the floating tab bar unchanged.

## Components Affected

- `LiftingLog/Features/Workout/WorkoutSessionView.swift`
- `LiftingLog/Features/Workout/WorkoutHeaderView.swift`
- `LiftingLog/Features/Workout/ExerciseCardView.swift`
- `LiftingLog/Features/Workout/SetRowView.swift`

## Design Decisions

- Compress vertical rhythm first by removing excess padding and stack spacing before shrinking typography.
- Keep tap targets comfortable by preserving usable control height in interactive elements while trimming surrounding dead space.
- Preserve the current visual language: dark surfaces, rounded cards, red accent, and the same screen structure.
- Treat this as refinement, not redesign. Notes stay inline, the sticky header stays present, and exercise cards keep the same expand/collapse pattern.

## Layout Changes

### Workout Header

- Reduce the top and bottom inset of the sticky header container.
- Tighten the timer capsule padding and the finish button vertical padding.
- Reduce spacing inside the progress block so the header consumes less height while still reading clearly.

### Screen Intro

- Reduce the vertical spacing between the workout name field and the date label.
- Slightly reduce the workout name font size if needed, but prioritize tighter spacing over aggressive typography changes.
- Pull the main content closer to the sticky header by reducing the top content inset.

### Exercise Cards

- Reduce header padding around the exercise title row.
- Tighten the space between the column headers, set rows, add-set button, and notes field.
- Reduce the bottom padding of expanded cards so stacked exercises feel denser.

### Set Rows And Notes

- Shorten numeric input fields by reducing vertical padding and corner radius proportionally.
- Keep the completion toggle visually balanced with the denser input row.
- Reduce the minimum height and inner padding of the exercise notes and workout notes fields.
- Reduce vertical padding on the add-exercise and add-set controls while keeping them easy to hit.

## Risks And Guardrails

- Avoid clipping or crowding text in larger Dynamic Type settings.
- Avoid making repeated controls feel too similar in density to plain text.
- Avoid changes to shared styling that would implicitly compact other screens.

## Success Criteria

- The workout screen shows meaningfully more content before scrolling.
- Expanded exercise cards feel denser, especially across repeated set rows.
- The sticky header remains readable and usable without dominating the top of the screen.
- The screen still feels intentional and touch-friendly rather than compressed for its own sake.

## Verification

- Build the app successfully after the layout changes.
- Verify the workout screen with expanded and collapsed exercise cards.
- Verify the finish button and sheet presentation still work.
