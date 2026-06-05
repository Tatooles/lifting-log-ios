# Local Sync Outbox Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add durable local sync metadata and an outbox for v1 syncable SwiftData entities, with retry-safe state transitions and testable integration points in existing app flows.

**Architecture:** Add a SwiftData `SyncOutboxEntry` work-queue model plus string-backed sync enums. A `SyncOutboxRecorder` owns all outbox mutation, while small mutation services connect existing exercise, settings, workout finish, and workout delete flows to the recorder without adding user-visible behavior.

**Tech Stack:** Swift 6, SwiftData, XCTest, XcodeGen project structure, existing `xcodebuild` test workflow.

---

## File Structure

- Create `LiftingLog/Core/Sync/SyncOperation.swift`
  - Defines `create`, `update`, and `delete` operation values.
- Create `LiftingLog/Core/Sync/SyncOutboxStatus.swift`
  - Defines `pending`, `inFlight`, `failed`, and `completed` queue states.
- Create `LiftingLog/Core/Sync/SyncOutboxEntry.swift`
  - SwiftData model for one durable pending sync operation.
- Modify `LiftingLog/Core/Sync/SyncEntityKind.swift`
  - Add raw string values used by outbox persistence while preserving current v1 scope tests.
- Modify `LiftingLog/Core/Persistence/LiftingLogSchema.swift`
  - Register `SyncOutboxEntry`.
- Create `LiftingLog/Core/Sync/SyncOutboxRecorder.swift`
  - Central API for create/update/delete coalescing, retry state, completion, pending fetches, and bootstrap.
- Create `LiftingLog/Core/Domain/ExerciseMutationService.swift`
  - Testable service for exercise create/update/remove flows with outbox recording.
- Create `LiftingLog/Core/Domain/SettingsMutationService.swift`
  - Testable service for settings updates with outbox recording.
- Create `LiftingLog/Core/Domain/WorkoutHistoryMutationService.swift`
  - Testable service for workout-history delete flow with outbox recording.
- Modify `LiftingLog/Core/Models/Exercise.swift`
  - Return whether removal archived or tombstoned.
- Modify `LiftingLog/Core/Models/UserSettings.swift`
  - Keep the existing model API compatible by delegating weight-unit updates through the settings mutation service.
- Modify `LiftingLog/Features/Exercises/ExerciseEditorView.swift`
  - Use `ExerciseMutationService`.
- Modify `LiftingLog/Features/Exercises/ExerciseLibraryView.swift`
  - Use `ExerciseMutationService` for removal.
- Modify `LiftingLog/Features/Profile/SettingsView.swift`
  - Use `SettingsMutationService`.
- Modify `LiftingLog/Features/Workout/ActiveWorkoutEngine.swift`
  - Record completed workout graph sync intent when a workout is finished.
- Modify `LiftingLog/Features/History/WorkoutHistoryDetailView.swift`
  - Use `WorkoutHistoryMutationService`.
- Create `LiftingLogTests/SyncOutboxEntryTests.swift`
  - Persistence tests for model and enum defaults.
- Create `LiftingLogTests/SyncOutboxRecorderTests.swift`
  - State-machine and bootstrap tests.
- Create `LiftingLogTests/SyncOutboxIntegrationTests.swift`
  - Tests for exercise, settings, workout finish, and workout delete integration points.
- Modify existing tests that call changed exercise/settings APIs.

---

### Task 1: Add Outbox Model and Persisted Sync Types

**Files:**
- Create: `LiftingLog/Core/Sync/SyncOperation.swift`
- Create: `LiftingLog/Core/Sync/SyncOutboxStatus.swift`
- Create: `LiftingLog/Core/Sync/SyncOutboxEntry.swift`
- Modify: `LiftingLog/Core/Sync/SyncEntityKind.swift`
- Modify: `LiftingLog/Core/Persistence/LiftingLogSchema.swift`
- Test: `LiftingLogTests/SyncOutboxEntryTests.swift`

- [ ] **Step 1: Write the failing persistence tests**

Create `LiftingLogTests/SyncOutboxEntryTests.swift`:

```swift
import SwiftData
import XCTest
@testable import LiftingLog

@MainActor
final class SyncOutboxEntryTests: XCTestCase {
    func testSyncEntityKindRawValuesMatchConvexTablesForV1Scope() {
        XCTAssertEqual(SyncEntityKind.userSettings.rawValue, "userSettings")
        XCTAssertEqual(SyncEntityKind.exercise.rawValue, "exercises")
        XCTAssertEqual(SyncEntityKind.workoutSession.rawValue, "workoutSessions")
        XCTAssertEqual(SyncEntityKind.loggedExercise.rawValue, "loggedExercises")
        XCTAssertEqual(SyncEntityKind.loggedSet.rawValue, "loggedSets")
    }

    func testOutboxEntryPersistsRequiredMetadata() throws {
        let container = try SwiftDataTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let entityID = UUID(uuidString: "00000000-0000-0000-0000-000000000901")!
        let createdAt = Date(timeIntervalSince1970: 100)
        let updatedAt = Date(timeIntervalSince1970: 200)
        let attemptedAt = Date(timeIntervalSince1970: 300)
        let entry = SyncOutboxEntry(
            entityKind: .exercise,
            entityID: entityID,
            operation: .update,
            status: .failed,
            ownerTokenIdentifier: "issuer|user_123",
            createdAt: createdAt,
            updatedAt: updatedAt,
            lastAttemptAt: attemptedAt,
            attemptCount: 2,
            lastErrorMessage: "offline"
        )

        context.insert(entry)
        try context.save()

        let fetched = try XCTUnwrap(context.fetch(FetchDescriptor<SyncOutboxEntry>()).first)
        XCTAssertEqual(fetched.entityKind, .exercise)
        XCTAssertEqual(fetched.entityID, entityID)
        XCTAssertEqual(fetched.operation, .update)
        XCTAssertEqual(fetched.status, .failed)
        XCTAssertEqual(fetched.ownerTokenIdentifier, "issuer|user_123")
        XCTAssertEqual(fetched.createdAt, createdAt)
        XCTAssertEqual(fetched.updatedAt, updatedAt)
        XCTAssertEqual(fetched.lastAttemptAt, attemptedAt)
        XCTAssertEqual(fetched.attemptCount, 2)
        XCTAssertEqual(fetched.lastErrorMessage, "offline")
    }

    func testOutboxEntryDefaultsToPendingCreateWithoutOwner() {
        let entityID = UUID(uuidString: "00000000-0000-0000-0000-000000000902")!
        let now = Date(timeIntervalSince1970: 400)
        let entry = SyncOutboxEntry(entityKind: .userSettings, entityID: entityID, operation: .create, now: now)

        XCTAssertEqual(entry.entityKind, .userSettings)
        XCTAssertEqual(entry.operation, .create)
        XCTAssertEqual(entry.status, .pending)
        XCTAssertNil(entry.ownerTokenIdentifier)
        XCTAssertEqual(entry.createdAt, now)
        XCTAssertEqual(entry.updatedAt, now)
        XCTAssertNil(entry.lastAttemptAt)
        XCTAssertEqual(entry.attemptCount, 0)
        XCTAssertNil(entry.lastErrorMessage)
    }
}
```

- [ ] **Step 2: Run the new tests to verify they fail**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -only-testing:LiftingLogTests/SyncOutboxEntryTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: FAIL because `SyncOutboxEntry`, `SyncOperation`, `SyncOutboxStatus`, and `SyncEntityKind.rawValue` do not exist yet.

- [ ] **Step 3: Add `SyncOperation`**

Create `LiftingLog/Core/Sync/SyncOperation.swift`:

```swift
import Foundation

enum SyncOperation: String, CaseIterable, Codable, Equatable, Hashable {
    case create
    case update
    case delete
}
```

- [ ] **Step 4: Add `SyncOutboxStatus`**

Create `LiftingLog/Core/Sync/SyncOutboxStatus.swift`:

```swift
import Foundation

enum SyncOutboxStatus: String, CaseIterable, Codable, Equatable, Hashable {
    case pending
    case inFlight
    case failed
    case completed
}
```

- [ ] **Step 5: Update `SyncEntityKind` with raw values**

Replace `LiftingLog/Core/Sync/SyncEntityKind.swift` with:

```swift
enum SyncEntityKind: String, CaseIterable, Equatable, Codable, Hashable {
    case userSettings = "userSettings"
    case exercise = "exercises"
    case workoutSession = "workoutSessions"
    case loggedExercise = "loggedExercises"
    case loggedSet = "loggedSets"
    case workoutTemplate = "workoutTemplates"
    case healthDataLink = "healthDataLinks"
    case seedMetadata = "seedMetadata"

    static let v1Synced: [SyncEntityKind] = [
        .userSettings,
        .exercise,
        .workoutSession,
        .loggedExercise,
        .loggedSet,
    ]

    static let v1Excluded: [SyncEntityKind] = [
        .workoutTemplate,
        .healthDataLink,
        .seedMetadata,
    ]

    var isV1Synced: Bool {
        Self.v1Synced.contains(self)
    }
}
```

- [ ] **Step 6: Add the SwiftData outbox model**

Create `LiftingLog/Core/Sync/SyncOutboxEntry.swift`:

```swift
import Foundation
import SwiftData

@Model
final class SyncOutboxEntry: Identifiable {
    @Attribute(.unique) var id: UUID
    var entityKindRaw: String
    var entityID: UUID
    var operationRaw: String
    var statusRaw: String
    var ownerTokenIdentifier: String?
    var createdAt: Date
    var updatedAt: Date
    var lastAttemptAt: Date?
    var attemptCount: Int
    var lastErrorMessage: String?

    init(
        id: UUID = UUID(),
        entityKind: SyncEntityKind,
        entityID: UUID,
        operation: SyncOperation,
        status: SyncOutboxStatus = .pending,
        ownerTokenIdentifier: String? = nil,
        createdAt: Date,
        updatedAt: Date,
        lastAttemptAt: Date? = nil,
        attemptCount: Int = 0,
        lastErrorMessage: String? = nil
    ) {
        self.id = id
        self.entityKindRaw = entityKind.rawValue
        self.entityID = entityID
        self.operationRaw = operation.rawValue
        self.statusRaw = status.rawValue
        self.ownerTokenIdentifier = ownerTokenIdentifier
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastAttemptAt = lastAttemptAt
        self.attemptCount = attemptCount
        self.lastErrorMessage = lastErrorMessage
    }

    convenience init(
        id: UUID = UUID(),
        entityKind: SyncEntityKind,
        entityID: UUID,
        operation: SyncOperation,
        ownerTokenIdentifier: String? = nil,
        now: Date = .now
    ) {
        self.init(
            id: id,
            entityKind: entityKind,
            entityID: entityID,
            operation: operation,
            status: .pending,
            ownerTokenIdentifier: ownerTokenIdentifier,
            createdAt: now,
            updatedAt: now
        )
    }

    var entityKind: SyncEntityKind {
        get { SyncEntityKind(rawValue: entityKindRaw) ?? .exercise }
        set { entityKindRaw = newValue.rawValue }
    }

    var operation: SyncOperation {
        get { SyncOperation(rawValue: operationRaw) ?? .update }
        set { operationRaw = newValue.rawValue }
    }

    var status: SyncOutboxStatus {
        get { SyncOutboxStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    var isActive: Bool {
        status != .completed
    }

    var hasBeenAttempted: Bool {
        attemptCount > 0 || lastAttemptAt != nil || status == .inFlight || status == .failed
    }

    func refreshPending(now: Date) {
        status = .pending
        updatedAt = now
        lastErrorMessage = nil
    }
}
```

- [ ] **Step 7: Register the model in the SwiftData schema**

Modify `LiftingLog/Core/Persistence/LiftingLogSchema.swift`:

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
        SeedMetadata.self,
        SyncOutboxEntry.self
    ]
}
```

- [ ] **Step 8: Run tests for the model and existing sync scope**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -only-testing:LiftingLogTests/SyncOutboxEntryTests -only-testing:LiftingLogTests/SyncConflictResolverTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: PASS.

- [ ] **Step 9: Commit Task 1**

```bash
git add LiftingLog/Core/Sync/SyncOperation.swift LiftingLog/Core/Sync/SyncOutboxStatus.swift LiftingLog/Core/Sync/SyncOutboxEntry.swift LiftingLog/Core/Sync/SyncEntityKind.swift LiftingLog/Core/Persistence/LiftingLogSchema.swift LiftingLogTests/SyncOutboxEntryTests.swift
git commit -m "Add local sync outbox model"
```

---

### Task 2: Implement Recorder Coalescing and Retry State

**Files:**
- Create: `LiftingLog/Core/Sync/SyncOutboxRecorder.swift`
- Test: `LiftingLogTests/SyncOutboxRecorderTests.swift`

- [ ] **Step 1: Write failing recorder tests**

Create `LiftingLogTests/SyncOutboxRecorderTests.swift` with the state-machine tests:

```swift
import SwiftData
import XCTest
@testable import LiftingLog

@MainActor
final class SyncOutboxRecorderTests: XCTestCase {
    func testRecordCreateCreatesPendingEntry() throws {
        let container = try SwiftDataTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let recorder = SyncOutboxRecorder()
        let entityID = UUID(uuidString: "00000000-0000-0000-0000-000000001001")!
        let now = Date(timeIntervalSince1970: 100)

        try recorder.recordCreate(entityKind: .exercise, entityID: entityID, context: context, now: now)
        try context.save()

        let entry = try XCTUnwrap(try fetchEntries(context).first)
        XCTAssertEqual(entry.entityKind, .exercise)
        XCTAssertEqual(entry.entityID, entityID)
        XCTAssertEqual(entry.operation, .create)
        XCTAssertEqual(entry.status, .pending)
        XCTAssertEqual(entry.createdAt, now)
        XCTAssertEqual(entry.updatedAt, now)
    }

    func testUpdateCoalescesIntoPendingCreate() throws {
        let container = try SwiftDataTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let recorder = SyncOutboxRecorder()
        let entityID = UUID(uuidString: "00000000-0000-0000-0000-000000001002")!

        try recorder.recordCreate(entityKind: .exercise, entityID: entityID, context: context, now: Date(timeIntervalSince1970: 100))
        try recorder.recordUpdate(entityKind: .exercise, entityID: entityID, context: context, now: Date(timeIntervalSince1970: 200))
        try context.save()

        let entries = try fetchEntries(context)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].operation, .create)
        XCTAssertEqual(entries[0].updatedAt, Date(timeIntervalSince1970: 200))
    }

    func testUnattemptedCreateDeletedBeforeSyncRemovesEntry() throws {
        let container = try SwiftDataTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let recorder = SyncOutboxRecorder()
        let entityID = UUID(uuidString: "00000000-0000-0000-0000-000000001003")!

        try recorder.recordCreate(entityKind: .exercise, entityID: entityID, context: context, now: Date(timeIntervalSince1970: 100))
        try recorder.recordDelete(entityKind: .exercise, entityID: entityID, context: context, now: Date(timeIntervalSince1970: 200))
        try context.save()

        XCTAssertTrue(try fetchEntries(context).isEmpty)
    }

    func testAttemptedCreateDeletedBeforeAckBecomesDelete() throws {
        let container = try SwiftDataTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let recorder = SyncOutboxRecorder()
        let entityID = UUID(uuidString: "00000000-0000-0000-0000-000000001004")!

        try recorder.recordCreate(entityKind: .exercise, entityID: entityID, context: context, now: Date(timeIntervalSince1970: 100))
        let entry = try XCTUnwrap(try fetchEntries(context).first)
        recorder.markInFlight(entry, now: Date(timeIntervalSince1970: 150))
        recorder.markFailed(entry, message: "offline", now: Date(timeIntervalSince1970: 160))
        try recorder.recordDelete(entityKind: .exercise, entityID: entityID, context: context, now: Date(timeIntervalSince1970: 200))
        try context.save()

        let entries = try fetchEntries(context)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].operation, .delete)
        XCTAssertEqual(entries[0].status, .pending)
        XCTAssertEqual(entries[0].attemptCount, 1)
        XCTAssertNil(entries[0].lastErrorMessage)
    }

    func testUpdateUpgradesToDelete() throws {
        let container = try SwiftDataTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let recorder = SyncOutboxRecorder()
        let entityID = UUID(uuidString: "00000000-0000-0000-0000-000000001005")!

        try recorder.recordUpdate(entityKind: .userSettings, entityID: entityID, context: context, now: Date(timeIntervalSince1970: 100))
        try recorder.recordDelete(entityKind: .userSettings, entityID: entityID, context: context, now: Date(timeIntervalSince1970: 200))
        try context.save()

        let entry = try XCTUnwrap(try fetchEntries(context).first)
        XCTAssertEqual(entry.operation, .delete)
        XCTAssertEqual(entry.updatedAt, Date(timeIntervalSince1970: 200))
    }

    func testRetryStateTransitions() throws {
        let container = try SwiftDataTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let recorder = SyncOutboxRecorder()
        let entityID = UUID(uuidString: "00000000-0000-0000-0000-000000001006")!

        try recorder.recordUpdate(entityKind: .exercise, entityID: entityID, context: context, now: Date(timeIntervalSince1970: 100))
        let entry = try XCTUnwrap(try fetchEntries(context).first)

        recorder.markInFlight(entry, now: Date(timeIntervalSince1970: 200))
        XCTAssertEqual(entry.status, .inFlight)
        XCTAssertEqual(entry.attemptCount, 1)
        XCTAssertEqual(entry.lastAttemptAt, Date(timeIntervalSince1970: 200))

        recorder.markFailed(entry, message: "timeout", now: Date(timeIntervalSince1970: 210))
        XCTAssertEqual(entry.status, .failed)
        XCTAssertEqual(entry.lastErrorMessage, "timeout")
        XCTAssertEqual(entry.updatedAt, Date(timeIntervalSince1970: 210))

        recorder.markPendingForRetry(entry, now: Date(timeIntervalSince1970: 300))
        XCTAssertEqual(entry.status, .pending)
        XCTAssertNil(entry.lastErrorMessage)
        XCTAssertEqual(entry.attemptCount, 1)

        recorder.removeCompleted(entry, context: context)
        try context.save()
        XCTAssertTrue(try fetchEntries(context).isEmpty)
    }

    func testPendingEntriesExcludeCompletedEntries() throws {
        let container = try SwiftDataTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let recorder = SyncOutboxRecorder()
        let pendingID = UUID(uuidString: "00000000-0000-0000-0000-000000001007")!
        let completedID = UUID(uuidString: "00000000-0000-0000-0000-000000001008")!

        context.insert(SyncOutboxEntry(entityKind: .exercise, entityID: pendingID, operation: .update, now: Date(timeIntervalSince1970: 100)))
        context.insert(SyncOutboxEntry(entityKind: .exercise, entityID: completedID, operation: .update, status: .completed, createdAt: Date(timeIntervalSince1970: 100), updatedAt: Date(timeIntervalSince1970: 100)))
        try context.save()

        let pending = try recorder.pendingEntries(context: context)
        XCTAssertEqual(pending.map(\.entityID), [pendingID])
    }

    private func fetchEntries(_ context: ModelContext) throws -> [SyncOutboxEntry] {
        try context.fetch(FetchDescriptor<SyncOutboxEntry>())
            .sorted { $0.createdAt < $1.createdAt }
    }
}
```

- [ ] **Step 2: Run recorder tests to verify they fail**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -only-testing:LiftingLogTests/SyncOutboxRecorderTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: FAIL because `SyncOutboxRecorder` does not exist.

- [ ] **Step 3: Implement `SyncOutboxRecorder` core API**

Create `LiftingLog/Core/Sync/SyncOutboxRecorder.swift`:

```swift
import Foundation
import SwiftData

@MainActor
struct SyncOutboxRecorder {
    func recordCreate(
        entityKind: SyncEntityKind,
        entityID: UUID,
        ownerTokenIdentifier: String? = nil,
        context: ModelContext,
        now: Date = .now
    ) throws {
        guard entityKind.isV1Synced else { return }

        if let entry = try activeEntry(
            entityKind: entityKind,
            entityID: entityID,
            ownerTokenIdentifier: ownerTokenIdentifier,
            context: context
        ) {
            if entry.operation != .delete {
                entry.operation = .create
            }
            entry.refreshPending(now: now)
            return
        }

        context.insert(
            SyncOutboxEntry(
                entityKind: entityKind,
                entityID: entityID,
                operation: .create,
                ownerTokenIdentifier: ownerTokenIdentifier,
                now: now
            )
        )
    }

    func recordUpdate(
        entityKind: SyncEntityKind,
        entityID: UUID,
        ownerTokenIdentifier: String? = nil,
        context: ModelContext,
        now: Date = .now
    ) throws {
        guard entityKind.isV1Synced else { return }

        if let entry = try activeEntry(
            entityKind: entityKind,
            entityID: entityID,
            ownerTokenIdentifier: ownerTokenIdentifier,
            context: context
        ) {
            if entry.operation != .create && entry.operation != .delete {
                entry.operation = .update
            }
            entry.refreshPending(now: now)
            return
        }

        context.insert(
            SyncOutboxEntry(
                entityKind: entityKind,
                entityID: entityID,
                operation: .update,
                ownerTokenIdentifier: ownerTokenIdentifier,
                now: now
            )
        )
    }

    func recordDelete(
        entityKind: SyncEntityKind,
        entityID: UUID,
        ownerTokenIdentifier: String? = nil,
        context: ModelContext,
        now: Date = .now
    ) throws {
        guard entityKind.isV1Synced else { return }

        if let entry = try activeEntry(
            entityKind: entityKind,
            entityID: entityID,
            ownerTokenIdentifier: ownerTokenIdentifier,
            context: context
        ) {
            if entry.operation == .create && !entry.hasBeenAttempted {
                context.delete(entry)
                return
            }

            entry.operation = .delete
            entry.refreshPending(now: now)
            return
        }

        context.insert(
            SyncOutboxEntry(
                entityKind: entityKind,
                entityID: entityID,
                operation: .delete,
                ownerTokenIdentifier: ownerTokenIdentifier,
                now: now
            )
        )
    }

    func markInFlight(_ entry: SyncOutboxEntry, now: Date = .now) {
        entry.status = .inFlight
        entry.attemptCount += 1
        entry.lastAttemptAt = now
        entry.lastErrorMessage = nil
        entry.updatedAt = now
    }

    func markFailed(_ entry: SyncOutboxEntry, message: String, now: Date = .now) {
        entry.status = .failed
        entry.lastErrorMessage = message
        entry.updatedAt = now
    }

    func markPendingForRetry(_ entry: SyncOutboxEntry, now: Date = .now) {
        entry.status = .pending
        entry.lastErrorMessage = nil
        entry.updatedAt = now
    }

    func removeCompleted(_ entry: SyncOutboxEntry, context: ModelContext) {
        context.delete(entry)
    }

    func pendingEntries(context: ModelContext) throws -> [SyncOutboxEntry] {
        try context.fetch(FetchDescriptor<SyncOutboxEntry>())
            .filter { $0.status != .completed }
            .sorted {
                if $0.updatedAt == $1.updatedAt {
                    return $0.createdAt < $1.createdAt
                }
                return $0.updatedAt < $1.updatedAt
            }
    }

    private func activeEntry(
        entityKind: SyncEntityKind,
        entityID: UUID,
        ownerTokenIdentifier: String?,
        context: ModelContext
    ) throws -> SyncOutboxEntry? {
        let rawKind = entityKind.rawValue
        let descriptor = FetchDescriptor<SyncOutboxEntry>(
            predicate: #Predicate { entry in
                entry.entityKindRaw == rawKind && entry.entityID == entityID
            }
        )

        return try context.fetch(descriptor).first {
            $0.ownerTokenIdentifier == ownerTokenIdentifier && $0.isActive
        }
    }
}
```

- [ ] **Step 4: Run recorder tests**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -only-testing:LiftingLogTests/SyncOutboxRecorderTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: PASS.

- [ ] **Step 5: Run sync outbox model and recorder tests together**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -only-testing:LiftingLogTests/SyncOutboxEntryTests -only-testing:LiftingLogTests/SyncOutboxRecorderTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: PASS.

- [ ] **Step 6: Commit Task 2**

```bash
git add LiftingLog/Core/Sync/SyncOutboxRecorder.swift LiftingLogTests/SyncOutboxRecorderTests.swift
git commit -m "Add sync outbox recorder state machine"
```

---

### Task 3: Add Bootstrap Support

**Files:**
- Modify: `LiftingLog/Core/Sync/SyncOutboxRecorder.swift`
- Modify: `LiftingLogTests/SyncOutboxRecorderTests.swift`

- [ ] **Step 1: Add failing bootstrap tests**

Append these tests to `SyncOutboxRecorderTests`:

```swift
func testBootstrapCreatesEntriesForExistingV1Records() throws {
    let container = try SwiftDataTestSupport.makeInMemoryContainer()
    let context = container.mainContext
    let recorder = SyncOutboxRecorder()
    let now = Date(timeIntervalSince1970: 500)
    let settings = UserSettings(id: UUID(uuidString: "00000000-0000-0000-0000-000000001101")!)
    let exercise = Exercise(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000001102")!,
        name: "Bench Press",
        category: .strength,
        equipment: .barbell,
        primaryMuscle: "Chest"
    )
    let session = WorkoutSession(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000001103")!,
        title: "Push",
        startedAt: Date(timeIntervalSince1970: 100),
        status: .completed,
        source: .blank
    )
    let loggedExercise = LoggedExercise(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000001104")!,
        orderIndex: 0,
        exercise: exercise
    )
    let set = LoggedSet(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000001105")!,
        orderIndex: 0,
        weight: 185,
        reps: 5,
        isCompleted: true
    )
    loggedExercise.sets.append(set)
    set.loggedExercise = loggedExercise
    session.loggedExercises.append(loggedExercise)
    loggedExercise.session = session

    context.insert(settings)
    context.insert(exercise)
    context.insert(session)
    try context.save()

    try recorder.bootstrapV1SyncableRecords(context: context, now: now)
    try context.save()

    let entries = try fetchEntries(context)
    XCTAssertEqual(Set(entries.map(\.entityKind)), [.userSettings, .exercise, .workoutSession, .loggedExercise, .loggedSet])
    XCTAssertTrue(entries.allSatisfy { $0.operation == .create })
    XCTAssertTrue(entries.allSatisfy { $0.status == .pending })
    XCTAssertTrue(entries.allSatisfy { $0.updatedAt == now })
}

func testBootstrapUsesDeleteForTombstonedRecords() throws {
    let container = try SwiftDataTestSupport.makeInMemoryContainer()
    let context = container.mainContext
    let recorder = SyncOutboxRecorder()
    let exercise = Exercise(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000001106")!,
        name: "Deleted Lift",
        category: .strength,
        equipment: .barbell,
        primaryMuscle: "Back",
        deletedAt: Date(timeIntervalSince1970: 100)
    )

    context.insert(exercise)
    try recorder.bootstrapV1SyncableRecords(context: context, now: Date(timeIntervalSince1970: 200))
    try context.save()

    let entry = try XCTUnwrap(try fetchEntries(context).first)
    XCTAssertEqual(entry.entityKind, .exercise)
    XCTAssertEqual(entry.operation, .delete)
}

func testBootstrapSkipsActiveWorkoutGraph() throws {
    let container = try SwiftDataTestSupport.makeInMemoryContainer()
    let context = container.mainContext
    let recorder = SyncOutboxRecorder()
    let activeSession = WorkoutSession(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000001107")!,
        title: "Active",
        startedAt: Date(timeIntervalSince1970: 100),
        status: .active,
        source: .blank
    )
    let activeExercise = LoggedExercise(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000001108")!,
        orderIndex: 0
    )
    let activeSet = LoggedSet(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000001109")!,
        orderIndex: 0
    )
    activeExercise.sets.append(activeSet)
    activeSet.loggedExercise = activeExercise
    activeSession.loggedExercises.append(activeExercise)
    activeExercise.session = activeSession

    context.insert(activeSession)
    try recorder.bootstrapV1SyncableRecords(context: context, now: Date(timeIntervalSince1970: 200))
    try context.save()

    XCTAssertTrue(try fetchEntries(context).isEmpty)
}

func testBootstrapDoesNotDuplicateExistingEntries() throws {
    let container = try SwiftDataTestSupport.makeInMemoryContainer()
    let context = container.mainContext
    let recorder = SyncOutboxRecorder()
    let exerciseID = UUID(uuidString: "00000000-0000-0000-0000-000000001110")!
    let exercise = Exercise(
        id: exerciseID,
        name: "Squat",
        category: .strength,
        equipment: .barbell,
        primaryMuscle: "Quads"
    )

    context.insert(exercise)
    try recorder.recordUpdate(entityKind: .exercise, entityID: exerciseID, context: context, now: Date(timeIntervalSince1970: 100))
    try recorder.bootstrapV1SyncableRecords(context: context, now: Date(timeIntervalSince1970: 200))
    try context.save()

    let entries = try fetchEntries(context)
    XCTAssertEqual(entries.count, 1)
    XCTAssertEqual(entries[0].operation, .update)
    XCTAssertEqual(entries[0].updatedAt, Date(timeIntervalSince1970: 100))
}
```

- [ ] **Step 2: Run bootstrap tests to verify they fail**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -only-testing:LiftingLogTests/SyncOutboxRecorderTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: FAIL because `bootstrapV1SyncableRecords` does not exist.

- [ ] **Step 3: Implement bootstrap in `SyncOutboxRecorder`**

Add these methods to `SyncOutboxRecorder`:

```swift
func bootstrapV1SyncableRecords(
    ownerTokenIdentifier: String? = nil,
    context: ModelContext,
    now: Date = .now
) throws {
    for settings in try context.fetch(FetchDescriptor<UserSettings>()) {
        try recordBootstrapEntry(
            entityKind: .userSettings,
            entityID: settings.id,
            isDeleted: settings.isDeleted,
            ownerTokenIdentifier: ownerTokenIdentifier,
            context: context,
            now: now
        )
    }

    for exercise in try context.fetch(FetchDescriptor<Exercise>()) {
        try recordBootstrapEntry(
            entityKind: .exercise,
            entityID: exercise.id,
            isDeleted: exercise.isDeleted,
            ownerTokenIdentifier: ownerTokenIdentifier,
            context: context,
            now: now
        )
    }

    for session in try context.fetch(FetchDescriptor<WorkoutSession>()) where session.status != .active {
        try recordBootstrapEntry(
            entityKind: .workoutSession,
            entityID: session.id,
            isDeleted: session.isDeleted,
            ownerTokenIdentifier: ownerTokenIdentifier,
            context: context,
            now: now
        )

        for loggedExercise in session.loggedExercises {
            try recordBootstrapEntry(
                entityKind: .loggedExercise,
                entityID: loggedExercise.id,
                isDeleted: loggedExercise.isDeleted,
                ownerTokenIdentifier: ownerTokenIdentifier,
                context: context,
                now: now
            )

            for set in loggedExercise.sets {
                try recordBootstrapEntry(
                    entityKind: .loggedSet,
                    entityID: set.id,
                    isDeleted: set.isDeleted,
                    ownerTokenIdentifier: ownerTokenIdentifier,
                    context: context,
                    now: now
                )
            }
        }
    }
}

private func recordBootstrapEntry(
    entityKind: SyncEntityKind,
    entityID: UUID,
    isDeleted: Bool,
    ownerTokenIdentifier: String?,
    context: ModelContext,
    now: Date
) throws {
    if try activeEntry(
        entityKind: entityKind,
        entityID: entityID,
        ownerTokenIdentifier: ownerTokenIdentifier,
        context: context
    ) != nil {
        return
    }

    if isDeleted {
        try recordDelete(
            entityKind: entityKind,
            entityID: entityID,
            ownerTokenIdentifier: ownerTokenIdentifier,
            context: context,
            now: now
        )
    } else {
        try recordCreate(
            entityKind: entityKind,
            entityID: entityID,
            ownerTokenIdentifier: ownerTokenIdentifier,
            context: context,
            now: now
        )
    }
}
```

- [ ] **Step 4: Run recorder tests**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -only-testing:LiftingLogTests/SyncOutboxRecorderTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: PASS.

- [ ] **Step 5: Commit Task 3**

```bash
git add LiftingLog/Core/Sync/SyncOutboxRecorder.swift LiftingLogTests/SyncOutboxRecorderTests.swift
git commit -m "Add sync outbox bootstrap support"
```

---

### Task 4: Add Testable Mutation Services and Flow Integration

**Files:**
- Create: `LiftingLog/Core/Domain/ExerciseMutationService.swift`
- Create: `LiftingLog/Core/Domain/SettingsMutationService.swift`
- Create: `LiftingLog/Core/Domain/WorkoutHistoryMutationService.swift`
- Modify: `LiftingLog/Core/Models/Exercise.swift`
- Modify: `LiftingLog/Core/Models/UserSettings.swift`
- Modify: `LiftingLog/Features/Exercises/ExerciseEditorView.swift`
- Modify: `LiftingLog/Features/Exercises/ExerciseLibraryView.swift`
- Modify: `LiftingLog/Features/Profile/SettingsView.swift`
- Modify: `LiftingLog/Features/Workout/ActiveWorkoutEngine.swift`
- Modify: `LiftingLog/Features/History/WorkoutHistoryDetailView.swift`
- Test: `LiftingLogTests/SyncOutboxIntegrationTests.swift`
- Modify existing tests that call changed settings or exercise APIs.

- [ ] **Step 1: Write failing integration tests**

Create `LiftingLogTests/SyncOutboxIntegrationTests.swift`:

```swift
import SwiftData
import XCTest
@testable import LiftingLog

@MainActor
final class SyncOutboxIntegrationTests: XCTestCase {
    func testExerciseServiceRecordsCreateUpdateAndDeleteIntent() throws {
        let container = try SwiftDataTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let service = ExerciseMutationService()
        let createdAt = Date(timeIntervalSince1970: 100)
        let updatedAt = Date(timeIntervalSince1970: 200)
        let deletedAt = Date(timeIntervalSince1970: 300)

        let exercise = try service.createExercise(
            name: "Incline DB Row",
            category: .strength,
            equipment: .dumbbell,
            primaryMuscle: "Back",
            notes: "",
            context: context,
            now: createdAt
        )
        try service.updateExercise(
            exercise,
            name: "Incline Dumbbell Row",
            category: .strength,
            equipment: .dumbbell,
            primaryMuscle: "Back",
            notes: "Chest supported",
            context: context,
            now: updatedAt
        )
        try service.removeExercise(exercise, context: context, now: deletedAt)

        XCTAssertTrue(try fetchEntries(context).isEmpty, "Unattempted create deleted before sync should leave no outbox entry.")

        let existing = Exercise(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000001201")!,
            name: "Existing Press",
            category: .strength,
            equipment: .barbell,
            primaryMuscle: "Chest"
        )
        context.insert(existing)
        try context.save()

        try service.updateExercise(
            existing,
            name: "Existing Bench Press",
            category: .strength,
            equipment: .barbell,
            primaryMuscle: "Chest",
            notes: "",
            context: context,
            now: updatedAt
        )
        try service.removeExercise(existing, context: context, now: deletedAt)

        let entry = try XCTUnwrap(try fetchEntries(context).first)
        XCTAssertEqual(entry.entityKind, .exercise)
        XCTAssertEqual(entry.entityID, existing.id)
        XCTAssertEqual(entry.operation, .delete)
    }

    func testSettingsServiceRecordsSettingsAndConvertedSetUpdates() throws {
        let container = try SwiftDataTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let service = SettingsMutationService()
        let settings = UserSettings(id: UUID(uuidString: "00000000-0000-0000-0000-000000001202")!, weightUnit: .pounds)
        let set = LoggedSet(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000001203")!,
            orderIndex: 0,
            weight: 225,
            reps: 5,
            placeholderWeight: 185,
            placeholderReps: 5,
            isCompleted: true
        )
        context.insert(settings)
        context.insert(set)
        try context.save()

        try service.updateWeightUnit(.kilograms, settings: settings, context: context, now: Date(timeIntervalSince1970: 200))

        let entries = try fetchEntries(context)
        XCTAssertEqual(Set(entries.map(\.entityKind)), [.userSettings, .loggedSet])
        XCTAssertTrue(entries.allSatisfy { $0.operation == .update })
    }

    func testRestTimerServiceRecordsSettingsUpdate() throws {
        let container = try SwiftDataTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let service = SettingsMutationService()
        let settings = UserSettings(id: UUID(uuidString: "00000000-0000-0000-0000-000000001204")!)
        context.insert(settings)
        try context.save()

        try service.updateRestTimerSeconds(120, settings: settings, context: context, now: Date(timeIntervalSince1970: 200))

        let entry = try XCTUnwrap(try fetchEntries(context).first)
        XCTAssertEqual(settings.defaultRestTimerSeconds, 120)
        XCTAssertEqual(entry.entityKind, .userSettings)
        XCTAssertEqual(entry.operation, .update)
    }

    func testFinishingWorkoutRecordsCompletedGraphCreateIntent() throws {
        let container = try SwiftDataTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let engine = ActiveWorkoutEngine()
        let exercise = Exercise(name: "Bench Press", category: .strength, equipment: .barbell, primaryMuscle: "Chest")
        context.insert(exercise)
        let session = try engine.startBlankWorkout(context: context, now: Date(timeIntervalSince1970: 100))
        let loggedExercise = try engine.addExercise(exercise, to: session, context: context)
        let set = try XCTUnwrap(loggedExercise.sets.first)
        try engine.updateSet(set, weight: 185, reps: 5, rpe: 8, context: context)

        try engine.finishWorkout(session, context: context, now: Date(timeIntervalSince1970: 500))

        let entries = try fetchEntries(context)
        XCTAssertEqual(Set(entries.map(\.entityKind)), [.workoutSession, .loggedExercise, .loggedSet])
        XCTAssertTrue(entries.allSatisfy { $0.operation == .create })
        XCTAssertTrue(entries.contains { $0.entityID == session.id })
        XCTAssertTrue(entries.contains { $0.entityID == loggedExercise.id })
        XCTAssertTrue(entries.contains { $0.entityID == set.id })
    }

    func testDeletingWorkoutHistoryRecordsDeleteIntentForGraph() throws {
        let container = try SwiftDataTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let service = WorkoutHistoryMutationService()
        let session = completedWorkoutGraph()
        context.insert(session)
        try context.save()

        try service.deleteWorkoutHistory(session, context: context, now: Date(timeIntervalSince1970: 600))

        let entries = try fetchEntries(context)
        XCTAssertEqual(Set(entries.map(\.entityKind)), [.workoutSession, .loggedExercise, .loggedSet])
        XCTAssertTrue(entries.allSatisfy { $0.operation == .delete })
        XCTAssertTrue(session.isDeleted)
        XCTAssertTrue(session.loggedExercises.allSatisfy(\.isDeleted))
        XCTAssertTrue(session.loggedExercises.flatMap(\.sets).allSatisfy(\.isDeleted))
    }

    func testActiveWorkoutDraftEditsDoNotRecordOutboxBeforeFinish() throws {
        let container = try SwiftDataTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let engine = ActiveWorkoutEngine()
        let exercise = Exercise(name: "Squat", category: .strength, equipment: .barbell, primaryMuscle: "Quads")
        context.insert(exercise)
        let session = try engine.startBlankWorkout(context: context, now: Date(timeIntervalSince1970: 100))
        let loggedExercise = try engine.addExercise(exercise, to: session, context: context)
        let set = try XCTUnwrap(loggedExercise.sets.first)
        try engine.updateSet(set, weight: 315, reps: 3, rpe: 8, context: context)

        XCTAssertTrue(try fetchEntries(context).isEmpty)
    }

    private func completedWorkoutGraph() -> WorkoutSession {
        let exercise = Exercise(name: "Deadlift", category: .strength, equipment: .barbell, primaryMuscle: "Back")
        let session = WorkoutSession(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000001205")!,
            title: "Pull",
            startedAt: Date(timeIntervalSince1970: 100),
            status: .completed,
            source: .blank
        )
        let loggedExercise = LoggedExercise(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000001206")!,
            orderIndex: 0,
            exercise: exercise
        )
        let set = LoggedSet(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000001207")!,
            orderIndex: 0,
            weight: 315,
            reps: 5,
            isCompleted: true
        )
        loggedExercise.sets.append(set)
        set.loggedExercise = loggedExercise
        session.loggedExercises.append(loggedExercise)
        loggedExercise.session = session
        return session
    }

    private func fetchEntries(_ context: ModelContext) throws -> [SyncOutboxEntry] {
        try context.fetch(FetchDescriptor<SyncOutboxEntry>())
            .sorted { $0.entityKind.rawValue < $1.entityKind.rawValue }
    }
}
```

- [ ] **Step 2: Run integration tests to verify they fail**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -only-testing:LiftingLogTests/SyncOutboxIntegrationTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: FAIL because the mutation services do not exist and `ActiveWorkoutEngine.finishWorkout` does not record outbox entries.

- [ ] **Step 3: Update exercise removal outcome**

Modify `LiftingLog/Core/Models/Exercise.swift` by adding this enum above `@Model`:

```swift
enum ExerciseRemovalOutcome: Equatable {
    case archived
    case deleted
}
```

Replace `archive`, `archiveOrDelete`, and `markDeleted` signatures with this compatible implementation:

```swift
func archive(now: Date = .now) {
    isArchived = true
    touch(now: now)
}

@discardableResult
func archiveOrDelete(context: ModelContext, now: Date = .now) throws -> ExerciseRemovalOutcome {
    let exerciseID = id
    let hasLoggedHistory = try context.fetch(FetchDescriptor<LoggedExercise>())
        .contains { $0.exercise?.id == exerciseID }

    if isSeeded || hasLoggedHistory {
        archive(now: now)
        return .archived
    } else {
        markDeleted(now: now)
        return .deleted
    }
}
```

The existing `markDeleted(now:)` method remains available.

- [ ] **Step 4: Add `ExerciseMutationService`**

Create `LiftingLog/Core/Domain/ExerciseMutationService.swift`:

```swift
import Foundation
import SwiftData

@MainActor
struct ExerciseMutationService {
    private let recorder = SyncOutboxRecorder()

    @discardableResult
    func createExercise(
        name: String,
        category: ExerciseCategory,
        equipment: ExerciseEquipment,
        primaryMuscle: String,
        notes: String,
        context: ModelContext,
        now: Date = .now
    ) throws -> Exercise {
        let exercise = Exercise(
            name: name,
            category: category,
            equipment: equipment,
            primaryMuscle: primaryMuscle,
            notes: notes,
            createdAt: now,
            updatedAt: now
        )
        context.insert(exercise)
        try recorder.recordCreate(entityKind: .exercise, entityID: exercise.id, context: context, now: now)
        try context.save()
        return exercise
    }

    func updateExercise(
        _ exercise: Exercise,
        name: String,
        category: ExerciseCategory,
        equipment: ExerciseEquipment,
        primaryMuscle: String,
        notes: String,
        context: ModelContext,
        now: Date = .now
    ) throws {
        exercise.name = name
        exercise.categoryRaw = category.rawValue
        exercise.equipmentRaw = equipment.rawValue
        exercise.primaryMuscleRaw = primaryMuscle
        exercise.notes = notes
        exercise.touch(now: now)
        try recorder.recordUpdate(entityKind: .exercise, entityID: exercise.id, context: context, now: now)
        try context.save()
    }

    func removeExercise(_ exercise: Exercise, context: ModelContext, now: Date = .now) throws {
        let outcome = try exercise.archiveOrDelete(context: context, now: now)
        switch outcome {
        case .archived:
            try recorder.recordUpdate(entityKind: .exercise, entityID: exercise.id, context: context, now: now)
        case .deleted:
            try recorder.recordDelete(entityKind: .exercise, entityID: exercise.id, context: context, now: now)
        }
        try context.save()
    }
}
```

- [ ] **Step 5: Add `SettingsMutationService`**

Create `LiftingLog/Core/Domain/SettingsMutationService.swift`:

```swift
import Foundation
import SwiftData

@MainActor
struct SettingsMutationService {
    private let recorder = SyncOutboxRecorder()

    func updateWeightUnit(
        _ newUnit: MeasurementUnit,
        settings: UserSettings,
        context: ModelContext,
        now: Date = .now
    ) throws {
        let previousUnit = settings.weightUnit
        guard previousUnit != newUnit else { return }

        let sets = try context.fetch(FetchDescriptor<LoggedSet>())
        for set in sets where !set.isDeleted {
            var didConvertSet = false
            if let weight = set.weight {
                set.weight = previousUnit.convert(weight, to: newUnit)
                didConvertSet = true
            }
            if let placeholderWeight = set.placeholderWeight {
                set.placeholderWeight = previousUnit.convert(placeholderWeight, to: newUnit)
                didConvertSet = true
            }
            if didConvertSet {
                set.touch(now: now)
                try recorder.recordUpdate(entityKind: .loggedSet, entityID: set.id, context: context, now: now)
            }
        }

        settings.weightUnitRaw = newUnit.rawValue
        settings.touch(now: now)
        try recorder.recordUpdate(entityKind: .userSettings, entityID: settings.id, context: context, now: now)
        try context.save()
    }

    func updateRestTimerSeconds(
        _ seconds: Int,
        settings: UserSettings,
        context: ModelContext,
        now: Date = .now
    ) throws {
        settings.defaultRestTimerSeconds = seconds
        settings.touch(now: now)
        try recorder.recordUpdate(entityKind: .userSettings, entityID: settings.id, context: context, now: now)
        try context.save()
    }
}
```

- [ ] **Step 6: Keep `UserSettings.updateWeightUnit` compatible**

Modify `LiftingLog/Core/Models/UserSettings.swift` so `updateWeightUnit` delegates:

```swift
func updateWeightUnit(_ newUnit: MeasurementUnit, context: ModelContext) throws {
    try SettingsMutationService().updateWeightUnit(newUnit, settings: self, context: context)
}
```

- [ ] **Step 7: Add `WorkoutHistoryMutationService`**

Create `LiftingLog/Core/Domain/WorkoutHistoryMutationService.swift`:

```swift
import Foundation
import SwiftData

@MainActor
struct WorkoutHistoryMutationService {
    private let recorder = SyncOutboxRecorder()

    func deleteWorkoutHistory(_ session: WorkoutSession, context: ModelContext, now: Date = .now) throws {
        session.markDeletedCascade(now: now)
        for loggedExercise in session.loggedExercises {
            try recorder.recordDelete(entityKind: .loggedExercise, entityID: loggedExercise.id, context: context, now: now)
            for set in loggedExercise.sets {
                try recorder.recordDelete(entityKind: .loggedSet, entityID: set.id, context: context, now: now)
            }
        }
        try recorder.recordDelete(entityKind: .workoutSession, entityID: session.id, context: context, now: now)
        try context.save()
    }
}
```

- [ ] **Step 8: Update `ActiveWorkoutEngine.finishWorkout`**

In `LiftingLog/Features/Workout/ActiveWorkoutEngine.swift`, replace the body of `finishWorkout` with:

```swift
func finishWorkout(_ session: WorkoutSession, context: ModelContext, now: Date = .now) throws {
    applyFinalWorkoutTitle(to: session)
    session.status = .completed
    session.endedAt = now
    session.durationSeconds = max(0, Int(now.timeIntervalSince(session.startedAt)))
    session.touch(now: now)

    let recorder = SyncOutboxRecorder()
    do {
        for loggedExercise in session.loggedExercises {
            try recorder.recordCreate(entityKind: .loggedExercise, entityID: loggedExercise.id, context: context, now: now)
            for set in loggedExercise.sets {
                try recorder.recordCreate(entityKind: .loggedSet, entityID: set.id, context: context, now: now)
            }
        }
        try recorder.recordCreate(entityKind: .workoutSession, entityID: session.id, context: context, now: now)
        try context.save()
    } catch {
        context.rollback()
        throw error
    }
    if activeSessionID == session.id {
        activeSessionID = nil
    }
}
```

- [ ] **Step 9: Update SwiftUI call sites to use services**

In `ExerciseEditorView.save()`, replace the create/update block and save call with service calls:

```swift
do {
    let service = ExerciseMutationService()
    let savedExercise: Exercise
    if let exercise {
        try service.updateExercise(
            exercise,
            name: trimmedName,
            category: category,
            equipment: equipment,
            primaryMuscle: primaryMuscle,
            notes: notes,
            context: modelContext
        )
        savedExercise = exercise
    } else {
        savedExercise = try service.createExercise(
            name: trimmedName,
            category: category,
            equipment: equipment,
            primaryMuscle: primaryMuscle,
            notes: notes,
            context: modelContext
        )
    }
    validationMessage = nil
    onSave?(savedExercise)
    dismiss()
} catch {
    modelContext.rollback()
    validationMessage = "Couldn't save exercise. \(error.localizedDescription)"
}
```

In `ExerciseLibraryView`, replace the swipe action save block with:

```swift
do {
    try ExerciseMutationService().removeExercise(exercise, context: modelContext)
    removalErrorMessage = nil
} catch {
    modelContext.rollback()
    removalErrorMessage = error.localizedDescription
}
```

In `SettingsView.weightUnitBinding`, replace the save action with:

```swift
do {
    try SettingsMutationService().updateWeightUnit(unit, settings: settings, context: modelContext)
    alert = nil
} catch {
    modelContext.rollback()
    showSaveFailure(error)
}
```

In `SettingsView.restTimerBinding`, replace the save action with:

```swift
do {
    try SettingsMutationService().updateRestTimerSeconds(seconds, settings: settings, context: modelContext)
    alert = nil
} catch {
    modelContext.rollback()
    showSaveFailure(error)
}
```

In `WorkoutHistoryDetailView`, replace the delete button action with:

```swift
do {
    try WorkoutHistoryMutationService().deleteWorkoutHistory(session, context: modelContext)
    deleteErrorMessage = nil
    dismiss()
} catch {
    modelContext.rollback()
    deleteErrorMessage = error.localizedDescription
}
```

- [ ] **Step 10: Run integration tests**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -only-testing:LiftingLogTests/SyncOutboxIntegrationTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: PASS.

- [ ] **Step 11: Run existing impacted unit tests**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -only-testing:LiftingLogTests/SettingsTests -only-testing:LiftingLogTests/ModelPersistenceTests -only-testing:LiftingLogTests/ActiveWorkoutEngineTests -only-testing:LiftingLogTests/HistoryPersistenceTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: PASS. If a test fails because it expects no outbox records, update that test only when outbox recording is now part of the intended behavior.

- [ ] **Step 12: Commit Task 4**

```bash
git add LiftingLog/Core/Domain/ExerciseMutationService.swift LiftingLog/Core/Domain/SettingsMutationService.swift LiftingLog/Core/Domain/WorkoutHistoryMutationService.swift LiftingLog/Core/Models/Exercise.swift LiftingLog/Core/Models/UserSettings.swift LiftingLog/Features/Exercises/ExerciseEditorView.swift LiftingLog/Features/Exercises/ExerciseLibraryView.swift LiftingLog/Features/Profile/SettingsView.swift LiftingLog/Features/Workout/ActiveWorkoutEngine.swift LiftingLog/Features/History/WorkoutHistoryDetailView.swift LiftingLogTests/SyncOutboxIntegrationTests.swift LiftingLogTests/SettingsTests.swift LiftingLogTests/ModelPersistenceTests.swift LiftingLogTests/ActiveWorkoutEngineTests.swift LiftingLogTests/HistoryPersistenceTests.swift
git commit -m "Record outbox intent from local app flows"
```

---

### Task 5: Final Verification

**Files:**
- Review all files touched in Tasks 1-4.

- [ ] **Step 1: Run full unit test target**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -only-testing:LiftingLogTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: PASS.

- [ ] **Step 2: Run Convex tests to confirm backend remains untouched**

Run:

```bash
pnpm run convex:test
```

Expected: PASS.

- [ ] **Step 3: Inspect changed files**

Run:

```bash
git status --short
git diff --stat HEAD
```

Expected: Only intentional issue #9 implementation files remain modified.

- [ ] **Step 4: Commit any final test-only adjustments**

If Step 1 or Step 2 required small test expectation changes, commit them:

```bash
git add LiftingLogTests
git commit -m "Tighten sync outbox test coverage"
```

If no files are modified, skip this commit step.
