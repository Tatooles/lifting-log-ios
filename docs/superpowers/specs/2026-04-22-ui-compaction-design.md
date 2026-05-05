# UI Compaction Design

**Date:** 2026-04-22

**Goal:** Reduce the overall perceived size of the app UI so the shell and content match the tighter reference layout, with the largest change applied to the floating bottom navigation.

## Scope

- Shrink the floating tab bar height, padding, corner radius, and icon/text sizes.
- Remove the oversized center emphasis from `Add Workout` so it uses the same visual scale as the other tabs.
- Tighten shell spacing so content and bottom chrome sit closer to the device edges.
- Reduce oversized typography, padding, and control heights across workout, history, and profile screens.

## Design Decisions

- Use shared sizing tokens in `AppTheme` instead of ad hoc constants so the compact scale stays consistent.
- Keep the existing visual language: dark surfaces, red accent, rounded cards, and the current information architecture.
- Focus on compaction, not redesign. Layout hierarchy and feature behavior stay the same.

## Success Criteria

- The bottom bar no longer dominates the screen or increases in height because of the center action.
- Workout cards, rows, and headers read denser without becoming cramped.
- History and profile screens scale down consistently with the workout screen.
