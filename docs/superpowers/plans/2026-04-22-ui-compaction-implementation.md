# UI Compaction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tighten the app chrome and primary screens so the overall UI reads smaller and denser, especially the bottom navigation.

**Architecture:** Add shared compact sizing tokens in `AppTheme` and apply them across the app shell, floating tab bar, workout session views, history rows, and profile cards. Keep behavior unchanged while reducing typography, padding, control heights, and oversized decorative treatments.

**Tech Stack:** SwiftUI, Xcode project build, XCTest / XCUITest

---

### Task 1: Capture Compact Sizing Tokens

**Files:**
- Modify: `LiftingLog/Shared/DesignSystem/AppTheme.swift`

- [ ] Add shared constants for shell padding, compact bottom bar sizing, and tighter card radii.
- [ ] Replace existing hard-coded shell padding and radius values with the new compact tokens.

### Task 2: Compact The App Shell And Floating Tab Bar

**Files:**
- Modify: `LiftingLog/App/AppShellView.swift`
- Modify: `LiftingLog/Shared/Components/FloatingTabBar.swift`

- [ ] Reduce the bottom safe-area inset and outer padding around the floating tab bar.
- [ ] Shrink the tab bar background, icon/text sizing, and center tab treatment so `Add Workout` matches the scale of `History` and `Profile`.

### Task 3: Compact The Workout Flow

**Files:**
- Modify: `LiftingLog/Features/Workout/WorkoutSessionView.swift`
- Modify: `LiftingLog/Features/Workout/WorkoutHeaderView.swift`
- Modify: `LiftingLog/Features/Workout/ExerciseCardView.swift`
- Modify: `LiftingLog/Features/Workout/SetRowView.swift`
- Modify: `LiftingLog/Shared/Components/SurfaceCard.swift`

- [ ] Reduce workout title/date sizing and vertical spacing.
- [ ] Tighten the top workout header chips, progress section, and finish button.
- [ ] Reduce exercise card padding, row spacing, note field height, and input control heights.

### Task 4: Compact History And Profile

**Files:**
- Modify: `LiftingLog/Features/History/HistoryView.swift`
- Modify: `LiftingLog/Features/History/WorkoutHistoryRow.swift`
- Modify: `LiftingLog/Features/History/ExerciseHistoryRow.swift`
- Modify: `LiftingLog/Features/Profile/ProfileView.swift`

- [ ] Reduce screen title sizes and list/card spacing.
- [ ] Shrink row accents, capsules, and icon blocks so list density matches the compact workout screen.
- [ ] Tighten the profile hero card, stat cards, and settings rows.

### Task 5: Verify

**Files:**
- Test: `LiftingLogTests/AppStoreTests.swift`
- Test: `LiftingLogUITests/LiftingLogUITests.swift`

- [ ] Run a full project build to confirm the SwiftUI changes compile cleanly.
- [ ] Run the existing test targets to catch regressions from the shared layout refactor.
