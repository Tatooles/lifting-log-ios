# Sync-Ready Data Model Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the SwiftData models in issue #4 safe for later Convex sync by adding tombstone metadata, documenting sync scope in code, and covering the behavior with persistence tests.

**Architecture:** Keep SwiftData as the local source of truth and add lightweight model-level sync metadata to the v1 synced entities only. Add small helper types for sync scope and conflict decisions so later Convex work has one local policy to reuse, while leaving transport, outbox, and backend schema to later phases.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, XCTest, XcodeBuildMCP.

---

### Task 1: Sync Scope and Conflict Helpers

**Files:**
- Create: `LiftingLog/Core/Sync/SyncEntityKind.swift`
- Create: `LiftingLog/Core/Sync/SyncConflictResolver.swift`
- Test: `LiftingLogTests/SyncConflictResolverTests.swift`

- [ ] **Step 1: Write failing tests for sync scope and conflict decisions**

Add `LiftingLogTests/SyncConflictResolverTests.swift` with tests that assert:

```swift
import XCTest
@testable import LiftingLog

final class SyncConflictResolverTests: XCTestCase {
    func testV1SyncScopeIncludesWorkoutGraphAndSettingsOnly() {
        XCTAssertEqual(
            SyncEntityKind.v1Synced,
            [.userSettings, .exercise, .workoutSession, .loggedExercise, .loggedSet]
        )
        XCTAssertEqual(
            SyncEntityKind.v1Excluded,
            [.workoutTemplate, .healthDataLink, .seedMetadata]
        )
    }

    func testLatestIncomingUpdateAppliesWhenNewerThanLocal() {
        let decision = SyncConflictResolver.decision(
            localUpdatedAt: Date(timeIntervalSince1970: 100),
            localDeletedAt: nil,
            incomingUpdatedAt: Date(timeIntervalSince1970: 200),
            incomingDeletedAt: nil
        )

        XCTAssertEqual(decision, .applyIncoming)
    }

    func testOlderIncomingUpdateDoesNotReplaceLocalTombstone() {
        let decision = SyncConflictResolver.decision(
            localUpdatedAt: Date(timeIntervalSince1970: 300),
            localDeletedAt: Date(timeIntervalSince1970: 300),
            incomingUpdatedAt: Date(timeIntervalSince1970: 200),
            incomingDeletedAt: nil
        )

        XCTAssertEqual(decision, .keepLocal)
    }

    func testNewerIncomingDeleteAppliesOverLocalActiveRecord() {
        let decision = SyncConflictResolver.decision(
            localUpdatedAt: Date(timeIntervalSince1970: 100),
            localDeletedAt: nil,
            incomingUpdatedAt: Date(timeIntervalSince1970: 200),
            incomingDeletedAt: Date(timeIntervalSince1970: 200)
        )

        XCTAssertEqual(decision, .applyIncoming)
    }

    func testNewerIncomingActiveRecordDoesNotRestoreLocalTombstoneUnlessAllowed() {
        let localUpdatedAt = Date(timeIntervalSince1970: 100)
        let localDeletedAt = Date(timeIntervalSince1970: 100)
        let incomingUpdatedAt = Date(timeIntervalSince1970: 200)

        XCTAssertEqual(
            SyncConflictResolver.decision(
                localUpdatedAt: localUpdatedAt,
                localDeletedAt: localDeletedAt,
                incomingUpdatedAt: incomingUpdatedAt,
                incomingDeletedAt: nil,
                allowsIncomingRestore: false
            ),
            .keepLocal
        )
        XCTAssertEqual(
            SyncConflictResolver.decision(
                localUpdatedAt: localUpdatedAt,
                localDeletedAt: localDeletedAt,
                incomingUpdatedAt: incomingUpdatedAt,
                incomingDeletedAt: nil,
                allowsIncomingRestore: true
            ),
            .applyIncoming
        )
    }
}
```

- [ ] **Step 2: Run the tests and verify they fail**

Run: `xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -only-testing:LiftingLogTests/SyncConflictResolverTests -derivedDataPath /private/tmp/codex-ios-app-derived-data`

Expected: build fails because `SyncEntityKind` and `SyncConflictResolver` do not exist.

- [ ] **Step 3: Implement minimal sync helpers**

Create `SyncEntityKind` with explicit v1 included and excluded arrays. Create `SyncConflictResolver` with `SyncMergeDecision` and latest-update/tombstone policy. Keep all types internal to the app target.

- [ ] **Step 4: Run the focused tests and verify they pass**

Run the same focused test command. Expected: `SyncConflictResolverTests` passes.

- [ ] **Step 5: Commit**

Commit message: `feat: define v1 sync scope helpers`

### Task 2: Tombstone Metadata on Synced Models

**Files:**
- Modify: `LiftingLog/Core/Models/UserSettings.swift`
- Modify: `LiftingLog/Core/Models/Exercise.swift`
- Modify: `LiftingLog/Core/Models/WorkoutSession.swift`
- Modify: `LiftingLog/Core/Models/LoggedExercise.swift`
- Modify: `LiftingLog/Core/Models/LoggedSet.swift`
- Test: `LiftingLogTests/ModelPersistenceTests.swift`

- [ ] **Step 1: Write failing persistence tests for tombstone defaults, delete, and restore**

Extend `ModelPersistenceTests` with tests that create each v1 synced model and assert `deletedAt == nil` and `isDeleted == false`. Add tests that `markDeleted(now:)` sets `deletedAt` and `updatedAt`, and `restoreFromDeletion(now:)` clears `deletedAt` and advances `updatedAt`.

- [ ] **Step 2: Run the focused tests and verify they fail**

Run: `xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -only-testing:LiftingLogTests/ModelPersistenceTests -derivedDataPath /private/tmp/codex-ios-app-derived-data`

Expected: build fails because the tombstone API does not exist.

- [ ] **Step 3: Add tombstone properties and methods**

For each synced model, add `deletedAt: Date?` to stored properties and initializer parameters. Add `isDeleted`, `markDeleted(now:)`, and `restoreFromDeletion(now:)`. `markDeleted(now:)` should set `deletedAt` and `updatedAt` to `now`. `restoreFromDeletion(now:)` should clear `deletedAt` and set `updatedAt` to `now`.

- [ ] **Step 4: Run the focused tests and verify they pass**

Run the same focused test command. Expected: `ModelPersistenceTests` passes.

- [ ] **Step 5: Commit**

Commit message: `feat: add tombstone metadata to sync models`

### Task 3: Tombstone-Aware Workout Delete Paths

**Files:**
- Modify: `LiftingLog/Features/Workout/ActiveWorkoutEngine.swift`
- Modify: `LiftingLog/Features/History/WorkoutHistoryDetailView.swift`
- Modify: `LiftingLogTests/ActiveWorkoutEngineTests.swift`
- Modify: `LiftingLogTests/HistoryPersistenceTests.swift`

- [ ] **Step 1: Write failing tests for tombstone deletes and reindexing**

Add tests proving:

- `removeLoggedExercise` tombstones the logged exercise and its sets instead of hard deleting them.
- `removeLoggedExercise` reindexes remaining non-deleted sibling logged exercises.
- `removeSet` tombstones the set instead of hard deleting it and reindexes remaining non-deleted sibling sets.
- Deleting a completed workout from history tombstones the session, logged exercises, and sets.

- [ ] **Step 2: Run the focused tests and verify they fail**

Run: `xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -only-testing:LiftingLogTests/ActiveWorkoutEngineTests -only-testing:LiftingLogTests/HistoryPersistenceTests -derivedDataPath /private/tmp/codex-ios-app-derived-data`

Expected: tests fail because current delete paths use `context.delete`.

- [ ] **Step 3: Update delete paths**

Change workout delete behavior to mark records deleted with the same `now` value and filter/reindex using non-deleted siblings. Replace direct history `modelContext.delete(session)` with a tombstone cascade helper on `WorkoutSession`.

- [ ] **Step 4: Run the focused tests and verify they pass**

Run the same focused test command. Expected: focused tests pass.

- [ ] **Step 5: Commit**

Commit message: `feat: tombstone workout graph deletes`

### Task 4: Query Filters, Template Exclusion, and Full Verification

**Files:**
- Modify: user-facing queries or computed arrays that list exercises, workouts, history sessions, active sessions, and export sessions.
- Modify: `LiftingLogTests/ModelPersistenceTests.swift`
- Modify: affected feature tests only if tombstone filtering changes expected counts.

- [ ] **Step 1: Write failing tests for tombstone filtering and template exclusion**

Add tests proving active library and history fetch helpers exclude tombstoned records. Add a test proving `WorkoutTemplate` remains excluded from `SyncEntityKind.v1Synced`.

- [ ] **Step 2: Run focused unit tests and verify they fail**

Run relevant focused test commands for changed test files.

- [ ] **Step 3: Update user-visible filtering**

Update local computed arrays and fetch filtering so tombstoned records do not appear in active workouts, workout history, exercise history, exercise picker/library/profile counts, past-workout picker, quick history, or export output.

- [ ] **Step 4: Run focused unit tests**

Run focused unit tests for model, engine, history, export, and settings behavior.

- [ ] **Step 5: Run full unit test suite**

Run: `xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -only-testing:LiftingLogTests -derivedDataPath /private/tmp/codex-ios-app-derived-data`

Expected: unit tests pass.

- [ ] **Step 6: Commit**

Commit message: `test: cover sync-ready tombstone filtering`

### Task 5: Final Review and Push

**Files:**
- All changed files.

- [ ] **Step 1: Review full diff against issue #4 and the design spec**

Confirm stable IDs and timestamps remain, tombstones are present on v1 synced entities, templates are excluded, conflict policy is represented, and tests cover persistence.

- [ ] **Step 2: Run final verification**

Run full unit tests. If time allows and unit tests are clean, run the UI suite or targeted UI tests for history deletion and exercise library deletion.

- [ ] **Step 3: Push branch**

Run: `git push`

Expected: remote branch updates cleanly.
