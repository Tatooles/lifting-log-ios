# Lifting Log Foundation Milestone Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first production-grade foundation milestone for the native iOS 17+ SwiftUI workout tracker by replacing mock state with SwiftData persistence, seed data, a start-workout flow, active workout engine, real history, exercise CRUD, settings, and tests.

**Architecture:** Keep the existing SwiftUI UI skeleton as the visual baseline, but replace the prototype `AppStore` and mock models with SwiftData models, focused feature services, and a root-owned active workout engine. The core app works fully offline; HealthKit, Watch, Live Activities, App Intents, widgets, and CloudKit remain future integrations through explicit extension points.

**Tech Stack:** Swift 6, SwiftUI, Observation, SwiftData, XCTest, XcodeGen, Xcode 26+

---

## Non-Negotiable Constraints

- Do not revert existing dirty UI changes unless the user explicitly asks.
- Preserve the current dark compact visual language where reasonable.
- Do not add HealthKit, Watch, Live Activities, Dynamic Island, App Intents, widgets, or CloudKit code in this milestone.
- Do not ship a first-class named template UI. Users start from a blank workout or from a past workout.
- Keep iOS deployment target at 17.0 or higher.
- Use SwiftData for production persistence.
- Use in-memory SwiftData containers for unit tests.

## Verified Commands

Generate project:

```bash
xcodegen generate
```

Build:

```bash
xcodebuild build -project LiftingLog.xcodeproj -scheme LiftingLog -destination generic/platform=iOS\ Simulator -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

All tests:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Unit tests:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -only-testing:LiftingLogTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

UI tests:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -only-testing:LiftingLogUITests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

## Target File Map

Create:

- `LiftingLog/App/AppNavigationState.swift`
- `LiftingLog/Core/Persistence/LiftingLogSchema.swift`
- `LiftingLog/Core/Persistence/ModelContainerFactory.swift`
- `LiftingLog/Core/Persistence/SeedDataService.swift`
- `LiftingLog/Core/Persistence/PreviewDataFactory.swift`
- `LiftingLog/Core/Models/Exercise.swift`
- `LiftingLog/Core/Models/WorkoutTemplate.swift`
- `LiftingLog/Core/Models/WorkoutSession.swift`
- `LiftingLog/Core/Models/LoggedExercise.swift`
- `LiftingLog/Core/Models/LoggedSet.swift`
- `LiftingLog/Core/Models/UserSettings.swift`
- `LiftingLog/Core/Models/HealthDataLink.swift`
- `LiftingLog/Core/Models/SeedMetadata.swift`
- `LiftingLog/Core/Domain/ExerciseCategory.swift`
- `LiftingLog/Core/Domain/ExerciseEquipment.swift`
- `LiftingLog/Core/Domain/MeasurementUnit.swift`
- `LiftingLog/Core/Domain/WorkoutSessionStatus.swift`
- `LiftingLog/Core/Domain/WorkoutSource.swift`
- `LiftingLog/Core/Domain/SetKind.swift`
- `LiftingLog/Core/Domain/WorkoutBlueprint.swift`
- `LiftingLog/Core/Domain/WorkoutMetrics.swift`
- `LiftingLog/Core/Formatting/WorkoutFormatters.swift`
- `LiftingLog/Features/StartWorkout/StartWorkoutView.swift`
- `LiftingLog/Features/StartWorkout/PastWorkoutPickerView.swift`
- `LiftingLog/Features/Workout/ActiveWorkoutEngine.swift`
- `LiftingLog/Features/Workout/AddExerciseSheet.swift`
- `LiftingLog/Features/Exercises/ExerciseLibraryView.swift`
- `LiftingLog/Features/Exercises/ExerciseEditorView.swift`
- `LiftingLog/Features/Exercises/ExercisePickerView.swift`
- `LiftingLog/Features/Profile/SettingsView.swift`
- `LiftingLogTests/SwiftDataTestSupport.swift`
- `LiftingLogTests/ModelPersistenceTests.swift`
- `LiftingLogTests/SeedDataServiceTests.swift`
- `LiftingLogTests/ActiveWorkoutEngineTests.swift`
- `LiftingLogTests/HistoryPersistenceTests.swift`
- `LiftingLogTests/SettingsTests.swift`

Modify:

- `LiftingLog/App/LiftingLogApp.swift`
- `LiftingLog/App/AppShellView.swift`
- `LiftingLog/Shared/Components/FloatingTabBar.swift`
- `LiftingLog/Shared/DesignSystem/AppTheme.swift`
- `LiftingLog/Features/Workout/WorkoutSessionView.swift`
- `LiftingLog/Features/Workout/WorkoutHeaderView.swift`
- `LiftingLog/Features/Workout/ExerciseCardView.swift`
- `LiftingLog/Features/Workout/SetRowView.swift`
- `LiftingLog/Features/Workout/FinishWorkoutSheet.swift`
- `LiftingLog/Features/History/HistoryView.swift`
- `LiftingLog/Features/History/WorkoutHistoryRow.swift`
- `LiftingLog/Features/History/ExerciseHistoryRow.swift`
- `LiftingLog/Features/History/WorkoutHistoryDetailView.swift`
- `LiftingLog/Features/History/ExerciseHistoryDetailView.swift`
- `LiftingLog/Features/Profile/ProfileView.swift`
- `LiftingLogTests/FormattingTests.swift`
- `LiftingLogUITests/LiftingLogUITests.swift`

Remove after replacement:

- `LiftingLog/Shared/Models/WorkoutModels.swift`
- `LiftingLog/Shared/Stores/AppStore.swift`
- `LiftingLog/Shared/Mocks/MockRepository.swift`
- `LiftingLogTests/AppStoreTests.swift`

Keep:

- `LiftingLog/Shared/Components/SurfaceCard.swift`
- `LiftingLog/Shared/Components/StateViews.swift`
- `project.yml`, unless new source folders require no change because XcodeGen already includes `LiftingLog`.

## Task 1: Add SwiftData Domain Models

**Files:**

- Create all files under `LiftingLog/Core/Models/`
- Create all enum/value files under `LiftingLog/Core/Domain/`
- Create `LiftingLogTests/ModelPersistenceTests.swift`
- Create `LiftingLogTests/SwiftDataTestSupport.swift`

- [ ] Add in-memory SwiftData test support.

`LiftingLogTests/SwiftDataTestSupport.swift` should expose:

```swift
import SwiftData
@testable import LiftingLog

@MainActor
enum SwiftDataTestSupport {
    static func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(LiftingLogSchema.models)
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
```

- [ ] Add raw-value domain enums.

Required enum cases:

- `ExerciseCategory`: `strength`, `cardio`, `mobility`, `other`
- `ExerciseEquipment`: `barbell`, `dumbbell`, `machine`, `cable`, `bodyweight`, `kettlebell`, `other`
- `MeasurementUnit`: `pounds`, `kilograms`
- `WorkoutSessionStatus`: `active`, `completed`, `discarded`
- `WorkoutSource`: `blank`, `pastWorkout`, `template`
- `SetKind`: `working`, `warmup`, `drop`, `failure`

Each enum should be `String`, `CaseIterable`, `Codable`, and `Identifiable` where useful for pickers.

- [ ] Add SwiftData models.

Use `@Model` classes with `UUID` IDs and relationship arrays initialized in constructors. Include `createdAt` and `updatedAt` defaults. Use delete rules so deleting a `WorkoutSession` cascades to `LoggedExercise`, and deleting a `LoggedExercise` cascades to `LoggedSet`.

Required model class names:

- `Exercise`
- `WorkoutTemplate`
- `WorkoutSession`
- `LoggedExercise`
- `LoggedSet`
- `UserSettings`
- `HealthDataLink`
- `SeedMetadata`

- [ ] Add `LiftingLogSchema`.

`LiftingLog/Core/Persistence/LiftingLogSchema.swift` should define:

```swift
import SwiftData

enum LiftingLogSchema {
    static let models: [any PersistentModel.Type] = [
        Exercise.self,
        WorkoutTemplate.self,
        WorkoutSession.self,
        LoggedExercise.self,
        LoggedSet.self,
        UserSettings.self,
        HealthDataLink.self,
        SeedMetadata.self
    ]
}
```

- [ ] Add model persistence tests.

Tests should verify:

- Creating an `Exercise` saves and fetches by `id`.
- Creating a `WorkoutSession` with one `LoggedExercise` and one `LoggedSet` persists relationships.
- Completed set volume is computed only when set has weight, reps, and `isCompleted == true`.
- `HealthDataLink` can store a future HealthKit link without importing HealthKit.
- `WorkoutTemplate` can be created, but no UI depends on it.

- [ ] Run unit tests and expect compile failures until all new models build.

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -only-testing:LiftingLogTests/ModelPersistenceTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

- [ ] Implement missing model code until `ModelPersistenceTests` pass.

- [ ] Commit when green.

```bash
git add LiftingLog/Core LiftingLogTests/SwiftDataTestSupport.swift LiftingLogTests/ModelPersistenceTests.swift
git commit -m "feat: add SwiftData foundation models"
```

## Task 2: Add Persistence Container And Seed Data

**Files:**

- Create `LiftingLog/Core/Persistence/ModelContainerFactory.swift`
- Create `LiftingLog/Core/Persistence/SeedDataService.swift`
- Create `LiftingLog/Core/Persistence/PreviewDataFactory.swift`
- Create `LiftingLogTests/SeedDataServiceTests.swift`
- Create `LiftingLogTests/SettingsTests.swift`

- [ ] Add `ModelContainerFactory`.

It should create the production container from `LiftingLogSchema.models` and provide a preview/in-memory helper for previews.

- [ ] Add `SeedDataService`.

It should:

- Create one `UserSettings` record if missing.
- Insert the curated seed exercise list.
- Track seed version with `SeedMetadata(key: "exerciseSeed", version: 1)`.
- Be idempotent when run repeatedly.

Seed these exercises with stable seed identifiers:

- `back-squat`
- `front-squat`
- `romanian-deadlift`
- `conventional-deadlift`
- `leg-press`
- `leg-extension`
- `leg-curl`
- `bench-press`
- `incline-dumbbell-press`
- `overhead-press`
- `pull-up`
- `lat-pulldown`
- `barbell-row`
- `seated-cable-row`
- `dumbbell-row`
- `face-pull`
- `biceps-curl`
- `triceps-pushdown`
- `calf-raise`
- `plank`

- [ ] Add `PreviewDataFactory`.

It should create an in-memory container, run seed data, and add one completed workout plus one active workout option for previews. Preview data should not be used by production app launch.

- [ ] Add seed data tests.

Tests should verify:

- Seed service inserts exactly 20 exercises.
- Running seed service twice still leaves exactly 20 seeded exercises.
- Back Squat exists with category strength and equipment barbell.
- Settings singleton is created exactly once.

- [ ] Run seed/settings tests.

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -only-testing:LiftingLogTests/SeedDataServiceTests -only-testing:LiftingLogTests/SettingsTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

- [ ] Commit when green.

```bash
git add LiftingLog/Core/Persistence LiftingLogTests/SeedDataServiceTests.swift LiftingLogTests/SettingsTests.swift
git commit -m "feat: seed exercises and settings"
```

## Task 3: Wire SwiftData Into App Launch

**Files:**

- Modify `LiftingLog/App/LiftingLogApp.swift`
- Create `LiftingLog/App/AppNavigationState.swift`
- Modify `LiftingLog/App/AppShellView.swift`
- Modify `LiftingLog/Shared/Components/FloatingTabBar.swift`

- [ ] Update app launch.

`LiftingLogApp` should:

- Create a `ModelContainer` through `ModelContainerFactory`.
- Run seed data once during startup using the main context.
- Own `@State private var navigationState = AppNavigationState()`.
- Own `@State private var activeWorkoutEngine = ActiveWorkoutEngine()`.
- Inject `.modelContainer(modelContainer)`.
- Inject navigation and active workout engine into the root view through initializers or environment.

- [ ] Add `AppNavigationState`.

It should be an `@Observable` class with:

- `selectedTab: AppTab`
- `historyMode: HistoryMode`
- route/sheet state only when it belongs at app shell level

- [ ] Replace static tab metadata with dynamic workout tab metadata.

When no active workout exists:

- Workout tab title: `Start`
- Workout tab symbol: `plus.circle`

When an active workout exists:

- Workout tab title: `Current`
- Workout tab symbol: `timer`

- [ ] Refactor `AppShellView`.

It should show:

- History tab: `HistoryView`
- Workout tab with no active session: `StartWorkoutView`
- Workout tab with active session: `WorkoutSessionView`
- Profile tab: `ProfileView`

- [ ] Keep the existing floating tab visual style.

Only adjust `FloatingTabBar` enough to accept dynamic tab title/icon metadata.

- [ ] Build.

```bash
xcodebuild build -project LiftingLog.xcodeproj -scheme LiftingLog -destination generic/platform=iOS\ Simulator -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

- [ ] Commit when green.

```bash
git add LiftingLog/App LiftingLog/Shared/Components/FloatingTabBar.swift
git commit -m "feat: wire SwiftData app shell"
```

## Task 4: Implement Active Workout Engine

**Files:**

- Create `LiftingLog/Features/Workout/ActiveWorkoutEngine.swift`
- Create `LiftingLog/Core/Domain/WorkoutBlueprint.swift`
- Create `LiftingLog/Core/Domain/WorkoutMetrics.swift`
- Create `LiftingLogTests/ActiveWorkoutEngineTests.swift`

- [ ] Add `WorkoutBlueprint`.

It should represent a transient workout starting point:

- `title: String`
- `notes: String`
- `exercises: [WorkoutBlueprintExercise]`
- each blueprint exercise has `exerciseID`, `exerciseName`, `notes`, and `sets`
- each blueprint set has `weight`, `reps`, `rpe`, and `kind`

Factory methods:

- blank blueprint
- blueprint from completed `WorkoutSession`

- [ ] Add `WorkoutMetrics`.

It should compute:

- total set count
- completed set count
- completed volume
- elapsed or final duration label inputs

- [ ] Add `ActiveWorkoutEngine`.

Required methods:

- `loadActiveSession(context:)`
- `startBlankWorkout(context:now:)`
- `startWorkout(fromPast:context:now:)`
- `addExercise(_:to:context:)`
- `removeLoggedExercise(_:context:)`
- `addSet(to:context:)`
- `removeSet(_:context:)`
- `updateSet(_:weight:reps:rpe:context:)`
- `toggleSetCompletion(_:context:now:)`
- `updateWorkoutTitle(_:session:context:)`
- `updateWorkoutNotes(_:session:context:)`
- `updateExerciseNotes(_:loggedExercise:context:)`
- `finishWorkout(_:context:now:)`
- `discardWorkout(_:context:)`

Rules:

- Starting a workout returns the existing active workout if one exists.
- Starting from a past workout copies exercise order, set count, previous weight, reps, and RPE, but all sets start incomplete.
- Finish sets status to completed, sets `endedAt`, persists `durationSeconds`, and clears `activeSessionID`.
- Discard sets status to discarded and clears `activeSessionID`.

- [ ] Add engine tests.

Tests should verify:

- Starting blank creates one active session with source blank.
- Starting blank twice does not create two active sessions.
- Starting from past copies exercises and sets as incomplete.
- Adding an exercise appends order index.
- Adding a set copies the previous set values and starts incomplete.
- Completing a set updates metrics.
- Finishing moves the session out of active state and into completed history.
- Discarded sessions do not appear in completed-history fetches.

- [ ] Run engine tests.

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -only-testing:LiftingLogTests/ActiveWorkoutEngineTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

- [ ] Commit when green.

```bash
git add LiftingLog/Features/Workout/ActiveWorkoutEngine.swift LiftingLog/Core/Domain/WorkoutBlueprint.swift LiftingLog/Core/Domain/WorkoutMetrics.swift LiftingLogTests/ActiveWorkoutEngineTests.swift
git commit -m "feat: add active workout engine"
```

## Task 5: Add Start Workout Flow

**Files:**

- Create `LiftingLog/Features/StartWorkout/StartWorkoutView.swift`
- Create `LiftingLog/Features/StartWorkout/PastWorkoutPickerView.swift`
- Modify `LiftingLog/App/AppShellView.swift`
- Modify `LiftingLogUITests/LiftingLogUITests.swift`

- [ ] Build `StartWorkoutView` with the existing visual system.

Content:

- Screen title `Start Workout`
- Primary card/button for `Blank Workout`
- Section for `Use Past Workout`
- Recent completed workouts sorted newest first
- Empty state when no completed sessions exist

Behavior:

- Tapping blank starts active workout and routes workout tab to `WorkoutSessionView`.
- Tapping a past workout starts active workout from that session and routes workout tab to `WorkoutSessionView`.

- [ ] Add UI identifiers.

Use:

- `StartWorkoutTitle`
- `StartBlankWorkoutButton`
- `PastWorkoutButton-<session id uuid string>` for row buttons where practical
- `WorkoutTitle`
- `WorkoutTab`

- [ ] Update UI tests.

Replace the current launch test expectation with:

- Launch starts on workout tab.
- If no active workout, `StartWorkoutTitle` exists.
- Tap `StartBlankWorkoutButton`.
- `WorkoutTitle` exists.
- Workout tab title/icon reflects active state through `WorkoutTab`.

- [ ] Run UI tests.

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -only-testing:LiftingLogUITests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

- [ ] Commit when green.

```bash
git add LiftingLog/Features/StartWorkout LiftingLog/App/AppShellView.swift LiftingLogUITests/LiftingLogUITests.swift
git commit -m "feat: add start workout flow"
```

## Task 6: Refactor Workout UI To Persisted Data

**Files:**

- Modify `LiftingLog/Features/Workout/WorkoutSessionView.swift`
- Modify `LiftingLog/Features/Workout/WorkoutHeaderView.swift`
- Modify `LiftingLog/Features/Workout/ExerciseCardView.swift`
- Modify `LiftingLog/Features/Workout/SetRowView.swift`
- Modify `LiftingLog/Features/Workout/FinishWorkoutSheet.swift`
- Create `LiftingLog/Features/Workout/AddExerciseSheet.swift`

- [ ] Refactor `WorkoutSessionView`.

It should:

- Query or receive the active `WorkoutSession`.
- Use `TimelineView` or a lightweight timer for elapsed display.
- Bind title and notes through engine methods.
- Render logged exercises ordered by `orderIndex`.
- Show `Add Exercise`.
- Present `FinishWorkoutSheet`.
- Preserve compact spacing and dark visual baseline.

- [ ] Refactor `ExerciseCardView`.

It should:

- Accept `LoggedExercise` plus focused engine dependency.
- Use view-local collapsed state keyed by `LoggedExercise.id`.
- Render `exerciseSnapshotName`.
- Render ordered logged sets.
- Add set through the engine.
- Edit exercise notes through the engine.

- [ ] Refactor `SetRowView`.

It should:

- Accept `LoggedSet`.
- Convert text field strings to `Double?`, `Int?`, and `Double?`.
- Route mutations through engine methods.
- Keep current visual row style.

- [ ] Refactor `FinishWorkoutSheet`.

It should:

- Show duration, sets done, and volume from `WorkoutMetrics`.
- `Save Workout` calls `finishWorkout`.
- `Keep Going` dismisses.
- Add a `Discard Workout` secondary/destructive action in the sheet footer, visually below `Keep Going`, with a confirmation alert before changing the session status to discarded.

- [ ] Add `AddExerciseSheet`.

It should:

- Search seeded and custom exercises.
- Add selected exercise to active workout.
- Offer `Create Exercise` to open `ExerciseEditorView`.

- [ ] Remove dependency on `AppStore` from all workout views.

No workout view should import or reference `AppStore` after this task.

- [ ] Build and run active workout engine tests.

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -only-testing:LiftingLogTests/ActiveWorkoutEngineTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

- [ ] Commit when green.

```bash
git add LiftingLog/Features/Workout
git commit -m "feat: persist active workout UI"
```

## Task 7: Add Exercise Library CRUD

**Files:**

- Create `LiftingLog/Features/Exercises/ExerciseLibraryView.swift`
- Create `LiftingLog/Features/Exercises/ExerciseEditorView.swift`
- Create `LiftingLog/Features/Exercises/ExercisePickerView.swift`
- Modify `LiftingLog/Features/Workout/AddExerciseSheet.swift`
- Add or extend `LiftingLogTests/ModelPersistenceTests.swift`

- [ ] Add `ExercisePickerView`.

It should:

- Query non-archived exercises sorted by name.
- Search by name.
- Return selected exercise to the active workout flow.
- Include a create button.

- [ ] Add `ExerciseEditorView`.

Fields:

- Name
- Category
- Equipment
- Primary muscle
- Notes

Validation:

- Name must not be empty after trimming whitespace.
- Duplicate active exercise names should be blocked or clearly handled.

- [ ] Add archive behavior.

For exercises with logged history, archive instead of hard delete. For custom exercises without logged history, hard delete is acceptable.

- [ ] Add exercise CRUD tests.

Tests should verify:

- Custom exercise can be created and fetched.
- Custom exercise can be edited.
- Archived exercise is excluded from active picker fetches.
- Seeded exercise with history is not hard-deleted by normal archive action.

- [ ] Run unit tests.

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -only-testing:LiftingLogTests/ModelPersistenceTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

- [ ] Commit when green.

```bash
git add LiftingLog/Features/Exercises LiftingLog/Features/Workout/AddExerciseSheet.swift LiftingLogTests/ModelPersistenceTests.swift
git commit -m "feat: add exercise library crud"
```

## Task 8: Refactor History To Real Persisted Data

**Files:**

- Modify `LiftingLog/Features/History/HistoryView.swift`
- Modify `LiftingLog/Features/History/WorkoutHistoryRow.swift`
- Modify `LiftingLog/Features/History/ExerciseHistoryRow.swift`
- Modify `LiftingLog/Features/History/WorkoutHistoryDetailView.swift`
- Modify `LiftingLog/Features/History/ExerciseHistoryDetailView.swift`
- Create `LiftingLogTests/HistoryPersistenceTests.swift`

- [ ] Refactor workouts history.

It should query `WorkoutSession` where status is completed, sorted by `startedAt` descending.

Rows should show:

- Title
- Date
- Duration
- Exercise count
- Set count

- [ ] Refactor workout detail.

It should show:

- Session title and date
- Duration, exercise count, completed sets, volume
- Notes if present
- Logged exercises with logged sets
- Delete completed workout action

- [ ] Refactor exercise history.

It should derive exercise history from persisted logged exercises and sets. A simple first implementation can query completed sessions and compute grouped rows in memory because the dataset is local and small in milestone 1.

Rows should show:

- Exercise snapshot/library name
- Last performed date
- Completed set count

- [ ] Refactor exercise history detail.

It should show recent logged sets for the selected exercise name or exercise ID.

- [ ] Add history tests.

Tests should verify:

- Finished workout appears in completed-history fetch.
- Deleted completed workout no longer appears.
- Exercise history count includes completed sets only.
- Starting from past workout does not mutate the original past workout.

- [ ] Run history tests.

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -only-testing:LiftingLogTests/HistoryPersistenceTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

- [ ] Commit when green.

```bash
git add LiftingLog/Features/History LiftingLogTests/HistoryPersistenceTests.swift
git commit -m "feat: persist workout history"
```

## Task 9: Refactor Profile And Settings

**Files:**

- Modify `LiftingLog/Features/Profile/ProfileView.swift`
- Create `LiftingLog/Features/Profile/SettingsView.swift`
- Modify `LiftingLogTests/SettingsTests.swift`

- [ ] Refactor `ProfileView`.

It should:

- Preserve existing dark card style.
- Query settings.
- Show workout count and exercise count from persisted data.
- Link to `SettingsView`.

- [ ] Add `SettingsView`.

It should:

- Let user choose pounds or kilograms.
- Let user edit default rest timer seconds if simple.
- Persist settings changes.

- [ ] Add settings tests.

Tests should verify:

- Settings singleton exists after seed.
- Updating weight unit persists.
- Running seed again does not overwrite user-edited settings.

- [ ] Run settings tests.

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -only-testing:LiftingLogTests/SettingsTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

- [ ] Commit when green.

```bash
git add LiftingLog/Features/Profile LiftingLogTests/SettingsTests.swift
git commit -m "feat: persist profile settings"
```

## Task 10: Remove Prototype Store And Mock Models

**Files:**

- Delete `LiftingLog/Shared/Models/WorkoutModels.swift`
- Delete `LiftingLog/Shared/Stores/AppStore.swift`
- Delete `LiftingLog/Shared/Mocks/MockRepository.swift`
- Delete `LiftingLogTests/AppStoreTests.swift`
- Modify any remaining references found by search

- [ ] Search for prototype references.

```bash
rg -n "AppStore|MockRepository|WorkoutModels|WorkoutSession\\(|WorkoutExercise|ExerciseSet|WorkoutHistoryItem|ExerciseHistoryItem" LiftingLog LiftingLogTests LiftingLogUITests
```

- [ ] Remove or replace all prototype references.

Expected after cleanup:

- No `AppStore`
- No `MockRepository`
- No old value-type workout model names
- `WorkoutSession` references point to the SwiftData model

- [ ] Run full build.

```bash
xcodebuild build -project LiftingLog.xcodeproj -scheme LiftingLog -destination generic/platform=iOS\ Simulator -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

- [ ] Commit when green.

```bash
git add -A LiftingLog LiftingLogTests
git commit -m "refactor: remove mock workout store"
```

## Task 11: Final UI Test Refresh

**Files:**

- Modify `LiftingLogUITests/LiftingLogUITests.swift`
- Add accessibility identifiers in touched views as needed

- [ ] Add UI smoke coverage.

Tests should cover:

- Launch shows start workout state when no active workout exists.
- Start blank workout routes to active workout screen.
- Workout tab metadata changes to current-workout state.
- Finish sheet opens from workout screen.
- Keep Going dismisses finish sheet.
- History tab opens.
- Profile tab opens.

- [ ] Keep UI tests resilient.

Avoid depending on exact seeded row order beyond stable text like `Back Squat` only after seed data is known to exist.

- [ ] Run UI tests.

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -only-testing:LiftingLogUITests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

- [ ] Commit when green.

```bash
git add LiftingLog LiftingLogUITests/LiftingLogUITests.swift
git commit -m "test: refresh foundation ui smoke tests"
```

## Task 12: Full Verification And Documentation Update

**Files:**

- Modify `README.md`
- Optionally modify this plan with implementation notes if execution discovers a necessary path change

- [ ] Run full tests.

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

- [ ] Run build.

```bash
xcodebuild build -project LiftingLog.xcodeproj -scheme LiftingLog -destination generic/platform=iOS\ Simulator -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

- [ ] Update README commands if the verified commands differ from the current README.

- [ ] Final search for deferred integrations.

```bash
rg -n "HealthKit|HKHealth|CloudKit|CKContainer|ActivityKit|WidgetKit|AppIntent|WatchConnectivity|Live Activit|Dynamic Island" LiftingLog LiftingLogTests LiftingLogUITests
```

Expected: no production integration code. `HealthDataLink` names are acceptable; framework imports are not.

- [ ] Final search for mock store leftovers.

```bash
rg -n "AppStore|MockRepository|WorkoutHistoryItem|ExerciseHistoryItem|ExerciseSet|WorkoutExercise" LiftingLog LiftingLogTests LiftingLogUITests
```

Expected: no matches unless a type name was intentionally retained for a new SwiftData model, which this plan does not recommend.

- [ ] Commit final docs if changed.

```bash
git add README.md docs/superpowers/specs/2026-05-04-foundation-milestone-design.md docs/superpowers/plans/2026-05-04-foundation-milestone-implementation.md
git commit -m "docs: document foundation milestone plan"
```

## Implementation Order Summary

1. SwiftData models.
2. Persistence container and seed data.
3. App launch and dynamic app shell.
4. Active workout engine.
5. Start-workout flow.
6. Persisted active workout UI.
7. Exercise CRUD.
8. Persisted history.
9. Profile/settings.
10. Remove prototype store.
11. Refresh UI tests.
12. Full verification and README.

## Completion Criteria

- `xcodebuild build` succeeds.
- `xcodebuild test` succeeds.
- Production app uses SwiftData, not mock repository state.
- Seed exercises are idempotent.
- Blank workout start works.
- Past workout reuse works.
- Active workout tab dynamically changes to current-workout metadata.
- Active workout persists and can be finished into history.
- Exercise CRUD exists at least through add-exercise flows.
- Completed history and exercise history are persisted.
- Settings persist.
- No deferred native integrations are introduced.
