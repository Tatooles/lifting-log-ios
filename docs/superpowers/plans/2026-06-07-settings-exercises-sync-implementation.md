# Settings And Exercises Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build automatic authenticated Convex sync for local `UserSettings` and `Exercise` records while preserving offline-first behavior.

**Architecture:** Add a focused SwiftData-backed sync layer with payload mappers, per-owner cursors, a fakeable sync client protocol, and a `@MainActor` coordinator that pushes outbox entries and pulls remote changes. Wire app-level triggers through an environment sync scheduler while keeping polished UI for issue #12.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, XCTest, ConvexMobile, ClerkConvex, existing Convex TypeScript backend.

---

## Source Map

- Create `LiftingLog/Core/Sync/SyncPayloads.swift`: request/response DTOs for settings/exercise sync, cursor structs, timestamp helpers, and SwiftData-to-Convex payload mappers.
- Create `LiftingLog/Core/Sync/SyncCursorState.swift`: SwiftData model storing owner-specific `userSettings` and `exercises` cursors.
- Modify `LiftingLog/Core/Persistence/LiftingLogSchema.swift`: include `SyncCursorState.self`.
- Create `LiftingLog/Core/Sync/SettingsExerciseSyncClient.swift`: protocol for fakeable settings/exercise sync API.
- Create `LiftingLog/Core/Sync/ConvexSettingsExerciseSyncClient.swift`: real adapter around `ConvexClientWithAuth<String>`.
- Create `LiftingLog/Core/Sync/SettingsExerciseSyncCoordinator.swift`: `@MainActor` sync runner that claims ownership, retries abandoned work, pushes outbox entries, pulls remote changes, and advances cursors.
- Create `LiftingLog/Core/Sync/SyncScheduler.swift`: environment-facing scheduler object that stores the current owner and requests sync runs after app/auth/mutation events.
- Modify `LiftingLog/Core/Domain/SettingsMutationService.swift`: pass current owner and request sync after settings mutations.
- Modify `LiftingLog/Core/Domain/ExerciseMutationService.swift`: pass current owner and request sync after exercise mutations.
- Modify `LiftingLog/App/LiftingLogApp.swift`: instantiate the authenticated Convex client, real sync client, coordinator, and scheduler; inject scheduler into the environment.
- Create `LiftingLogTests/SyncPayloadMappingTests.swift`: unit tests for payload mapping.
- Create `LiftingLogTests/SyncCursorStateTests.swift`: unit tests for cursor persistence.
- Create `LiftingLogTests/SettingsExerciseSyncCoordinatorTests.swift`: unit tests for ownership, push, pull, retry, and cursor behavior with a fake client.
- Modify `LiftingLogUITests/LiftingLogUITests.swift`: add narrow workflow-to-sync trigger tests using launch-argument test mode.

## Task 1: Payload DTOs And Mapping

**Files:**
- Create: `LiftingLog/Core/Sync/SyncPayloads.swift`
- Test: `LiftingLogTests/SyncPayloadMappingTests.swift`

- [ ] **Step 1: Write failing payload mapping tests**

Add `LiftingLogTests/SyncPayloadMappingTests.swift`:

```swift
import XCTest
@testable import LiftingLog

final class SyncPayloadMappingTests: XCTestCase {
    func testUserSettingsPayloadUsesClientIdAndUnixSeconds() throws {
        let settings = UserSettings(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000001001")!,
            weightUnit: .kilograms,
            defaultRestTimerSeconds: 120,
            hasCompletedOnboarding: true,
            createdAt: Date(timeIntervalSince1970: 10),
            updatedAt: Date(timeIntervalSince1970: 20),
            deletedAt: nil
        )

        let payload = SyncPayloadMapper.userSettingsPayload(from: settings)

        XCTAssertEqual(payload.clientId, "00000000-0000-0000-0000-000000001001")
        XCTAssertEqual(payload.weightUnitRaw, "kilograms")
        XCTAssertEqual(payload.defaultRestTimerSeconds, 120)
        XCTAssertTrue(payload.hasCompletedOnboarding)
        XCTAssertEqual(payload.createdAt, 10)
        XCTAssertEqual(payload.updatedAt, 20)
        XCTAssertNil(payload.deletedAt)
    }

    func testExercisePayloadPreservesRawTaxonomyStrings() throws {
        let exercise = Exercise(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000001002")!,
            seedIdentifier: "seed-bench",
            name: "Bench Press",
            category: .strength,
            equipment: .barbell,
            primaryMuscleGroup: .chest,
            notes: "Pause reps",
            isArchived: true,
            isSeeded: true,
            createdAt: Date(timeIntervalSince1970: 30),
            updatedAt: Date(timeIntervalSince1970: 40),
            deletedAt: Date(timeIntervalSince1970: 50)
        )
        exercise.categoryRaw = "future-strength"
        exercise.equipmentRaw = "future-bar"
        exercise.primaryMuscleRaw = "Future Chest"
        exercise.primaryMuscleGroupRaw = "future-chest"

        let payload = SyncPayloadMapper.exercisePayload(from: exercise)

        XCTAssertEqual(payload.clientId, "00000000-0000-0000-0000-000000001002")
        XCTAssertEqual(payload.seedIdentifier, "seed-bench")
        XCTAssertEqual(payload.name, "Bench Press")
        XCTAssertEqual(payload.categoryRaw, "future-strength")
        XCTAssertEqual(payload.equipmentRaw, "future-bar")
        XCTAssertEqual(payload.primaryMuscleRaw, "Future Chest")
        XCTAssertEqual(payload.primaryMuscleGroupRaw, "future-chest")
        XCTAssertEqual(payload.notes, "Pause reps")
        XCTAssertTrue(payload.isArchived)
        XCTAssertTrue(payload.isSeeded)
        XCTAssertEqual(payload.createdAt, 30)
        XCTAssertEqual(payload.updatedAt, 40)
        XCTAssertEqual(payload.deletedAt, 50)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```sh
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -only-testing:LiftingLogTests/SyncPayloadMappingTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: FAIL because `SyncPayloadMapper`, `UserSettingsSyncPayload`, and `ExerciseSyncPayload` do not exist.

- [ ] **Step 3: Add payload DTOs and mapper**

Create `LiftingLog/Core/Sync/SyncPayloads.swift`:

```swift
import Foundation

struct UserSettingsSyncPayload: Codable, Equatable {
    let clientId: String
    let createdAt: Double
    let updatedAt: Double
    let deletedAt: Double?
    let weightUnitRaw: String
    let defaultRestTimerSeconds: Int
    let hasCompletedOnboarding: Bool
}

struct ExerciseSyncPayload: Codable, Equatable {
    let clientId: String
    let createdAt: Double
    let updatedAt: Double
    let deletedAt: Double?
    let seedIdentifier: String?
    let name: String
    let categoryRaw: String
    let equipmentRaw: String
    let primaryMuscleRaw: String
    let primaryMuscleGroupRaw: String
    let notes: String
    let isArchived: Bool
    let isSeeded: Bool
}

enum SyncPayloadMapper {
    static func userSettingsPayload(from settings: UserSettings) -> UserSettingsSyncPayload {
        UserSettingsSyncPayload(
            clientId: settings.id.uuidString.lowercased(),
            createdAt: settings.createdAt.timeIntervalSince1970,
            updatedAt: settings.updatedAt.timeIntervalSince1970,
            deletedAt: settings.deletedAt?.timeIntervalSince1970,
            weightUnitRaw: settings.weightUnitRaw,
            defaultRestTimerSeconds: settings.defaultRestTimerSeconds,
            hasCompletedOnboarding: settings.hasCompletedOnboarding
        )
    }

    static func exercisePayload(from exercise: Exercise) -> ExerciseSyncPayload {
        ExerciseSyncPayload(
            clientId: exercise.id.uuidString.lowercased(),
            createdAt: exercise.createdAt.timeIntervalSince1970,
            updatedAt: exercise.updatedAt.timeIntervalSince1970,
            deletedAt: exercise.deletedAt?.timeIntervalSince1970,
            seedIdentifier: exercise.seedIdentifier,
            name: exercise.name,
            categoryRaw: exercise.categoryRaw,
            equipmentRaw: exercise.equipmentRaw,
            primaryMuscleRaw: exercise.primaryMuscleRaw,
            primaryMuscleGroupRaw: exercise.primaryMuscleGroupRaw,
            notes: exercise.notes,
            isArchived: exercise.isArchived,
            isSeeded: exercise.isSeeded
        )
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run the same `xcodebuild test ... -only-testing:LiftingLogTests/SyncPayloadMappingTests` command.

Expected: PASS.

- [ ] **Step 5: Commit**

```sh
git add LiftingLog/Core/Sync/SyncPayloads.swift LiftingLogTests/SyncPayloadMappingTests.swift
git commit -m "Add sync payload mapping"
```

## Task 2: Cursor State Persistence

**Files:**
- Create: `LiftingLog/Core/Sync/SyncCursorState.swift`
- Modify: `LiftingLog/Core/Persistence/LiftingLogSchema.swift`
- Test: `LiftingLogTests/SyncCursorStateTests.swift`

- [ ] **Step 1: Write failing cursor state tests**

Create `LiftingLogTests/SyncCursorStateTests.swift`:

```swift
import SwiftData
import XCTest
@testable import LiftingLog

@MainActor
final class SyncCursorStateTests: XCTestCase {
    func testCursorStatePersistsOwnerAndCursors() throws {
        let container = try SwiftDataTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let state = SyncCursorState(
            ownerTokenIdentifier: "issuer|owner_a",
            userSettingsCursor: 12,
            exercisesCursor: 34
        )

        context.insert(state)
        try context.save()

        let fetched = try XCTUnwrap(context.fetch(FetchDescriptor<SyncCursorState>()).first)
        XCTAssertEqual(fetched.ownerTokenIdentifier, "issuer|owner_a")
        XCTAssertEqual(fetched.userSettingsCursor, 12)
        XCTAssertEqual(fetched.exercisesCursor, 34)
    }

    func testCursorStateLookupCreatesMissingOwnerState() throws {
        let container = try SwiftDataTestSupport.makeInMemoryContainer()
        let context = container.mainContext

        let state = try SyncCursorState.state(for: "issuer|owner_a", context: context)
        try context.save()

        XCTAssertEqual(state.ownerTokenIdentifier, "issuer|owner_a")
        XCTAssertEqual(state.userSettingsCursor, 0)
        XCTAssertEqual(state.exercisesCursor, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<SyncCursorState>()).count, 1)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```sh
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -only-testing:LiftingLogTests/SyncCursorStateTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: FAIL because `SyncCursorState` does not exist and is not part of the schema.

- [ ] **Step 3: Add `SyncCursorState` and schema entry**

Create `LiftingLog/Core/Sync/SyncCursorState.swift`:

```swift
import Foundation
import SwiftData

@Model
final class SyncCursorState: Identifiable {
    @Attribute(.unique) var id: UUID
    var ownerTokenIdentifier: String
    var userSettingsCursor: Double
    var exercisesCursor: Double

    init(
        id: UUID = UUID(),
        ownerTokenIdentifier: String,
        userSettingsCursor: Double = 0,
        exercisesCursor: Double = 0
    ) {
        self.id = id
        self.ownerTokenIdentifier = ownerTokenIdentifier
        self.userSettingsCursor = userSettingsCursor
        self.exercisesCursor = exercisesCursor
    }

    static func state(for ownerTokenIdentifier: String, context: ModelContext) throws -> SyncCursorState {
        let existing = try context.fetch(FetchDescriptor<SyncCursorState>())
            .first { $0.ownerTokenIdentifier == ownerTokenIdentifier }
        if let existing {
            return existing
        }

        let state = SyncCursorState(ownerTokenIdentifier: ownerTokenIdentifier)
        context.insert(state)
        return state
    }
}
```

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
        SyncOutboxEntry.self,
        SyncCursorState.self
    ]
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run the same `xcodebuild test ... -only-testing:LiftingLogTests/SyncCursorStateTests` command.

Expected: PASS.

- [ ] **Step 5: Commit**

```sh
git add LiftingLog/Core/Sync/SyncCursorState.swift LiftingLog/Core/Persistence/LiftingLogSchema.swift LiftingLogTests/SyncCursorStateTests.swift
git commit -m "Persist sync cursors per owner"
```

## Task 3: Sync Client Protocol And Real Convex Adapter

**Files:**
- Modify: `LiftingLog/Core/Sync/SyncPayloads.swift`
- Create: `LiftingLog/Core/Sync/SettingsExerciseSyncClient.swift`
- Create: `LiftingLog/Core/Sync/ConvexSettingsExerciseSyncClient.swift`
- Test: `LiftingLogTests/SyncPayloadMappingTests.swift`

- [ ] **Step 1: Extend tests for client response decoding arguments**

Append to `SyncPayloadMappingTests`:

```swift
func testFetchChangesRequestIncludesZeroWorkoutGraphCursors() throws {
    let cursors = SyncChangeCursors(userSettings: 10, exercises: 20)

    XCTAssertEqual(cursors.userSettings, 10)
    XCTAssertEqual(cursors.exercises, 20)
    XCTAssertEqual(cursors.workoutSessions, 0)
    XCTAssertEqual(cursors.loggedExercises, 0)
    XCTAssertEqual(cursors.loggedSets, 0)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```sh
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -only-testing:LiftingLogTests/SyncPayloadMappingTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: FAIL because `SyncChangeCursors` does not exist.

- [ ] **Step 3: Add response DTOs, protocol, and adapter**

Append to `LiftingLog/Core/Sync/SyncPayloads.swift`:

```swift
struct SyncChangeCursors: Codable, Equatable {
    var userSettings: Double
    var exercises: Double
    var workoutSessions: Double = 0
    var loggedExercises: Double = 0
    var loggedSets: Double = 0
}

struct SyncHasMore: Codable, Equatable {
    var userSettings: Bool
    var exercises: Bool
    var workoutSessions: Bool = false
    var loggedExercises: Bool = false
    var loggedSets: Bool = false
}

struct UserSettingsSyncRecord: Codable, Equatable {
    let clientId: String
    let createdAt: Double
    let updatedAt: Double
    let deletedAt: Double?
    let serverUpdatedAt: Double
    let weightUnitRaw: String
    let defaultRestTimerSeconds: Int
    let hasCompletedOnboarding: Bool
}

struct ExerciseSyncRecord: Codable, Equatable {
    let clientId: String
    let createdAt: Double
    let updatedAt: Double
    let deletedAt: Double?
    let serverUpdatedAt: Double
    let seedIdentifier: String?
    let name: String
    let categoryRaw: String
    let equipmentRaw: String
    let primaryMuscleRaw: String
    let primaryMuscleGroupRaw: String
    let notes: String
    let isArchived: Bool
    let isSeeded: Bool
}

struct SyncFetchChangesResponse: Codable, Equatable {
    let userSettings: [UserSettingsSyncRecord]
    let exercises: [ExerciseSyncRecord]
    let cursors: SyncChangeCursors
    let hasMore: SyncHasMore
}

struct SyncMutationResult: Codable, Equatable {
    let status: String
    let serverUpdatedAt: Double?
}
```

Create `LiftingLog/Core/Sync/SettingsExerciseSyncClient.swift`:

```swift
import Foundation

protocol SettingsExerciseSyncClient {
    func upsertUserSettings(_ record: UserSettingsSyncPayload) async throws -> SyncMutationResult
    func upsertExercise(_ record: ExerciseSyncPayload) async throws -> SyncMutationResult
    func tombstone(entityKind: SyncEntityKind, clientId: UUID, deletedAt: Date) async throws -> SyncMutationResult
    func fetchChanges(cursors: SyncChangeCursors, limit: Int) async throws -> SyncFetchChangesResponse
}
```

Create `LiftingLog/Core/Sync/ConvexSettingsExerciseSyncClient.swift`:

```swift
import Combine
import ConvexMobile
import Foundation

struct ConvexSettingsExerciseSyncClient: SettingsExerciseSyncClient {
    private let client: ConvexClientWithAuth<String>

    init(client: ConvexClientWithAuth<String>) {
        self.client = client
    }

    func upsertUserSettings(_ record: UserSettingsSyncPayload) async throws -> SyncMutationResult {
        let args: [String: ConvexEncodable?] = ["record": record.convexDictionary()]
        return try await client.mutation(
            "sync:upsertUserSettings",
            with: args
        )
    }

    func upsertExercise(_ record: ExerciseSyncPayload) async throws -> SyncMutationResult {
        let args: [String: ConvexEncodable?] = ["record": record.convexDictionary()]
        return try await client.mutation(
            "sync:upsertExercise",
            with: args
        )
    }

    func tombstone(entityKind: SyncEntityKind, clientId: UUID, deletedAt: Date) async throws -> SyncMutationResult {
        return try await client.mutation(
            "sync:tombstone",
            with: [
                "entityKind": entityKind.rawValue,
                "clientId": clientId.uuidString.lowercased(),
                "deletedAt": deletedAt.timeIntervalSince1970,
            ]
        )
    }

    func fetchChanges(cursors: SyncChangeCursors, limit: Int) async throws -> SyncFetchChangesResponse {
        let publisher = client.subscribe(
            to: "sync:fetchChanges",
            with: ["cursors": cursors.convexDictionary(), "limit": limit],
            yielding: SyncFetchChangesResponse.self
        )

        for try await response in publisher.values {
            return response
        }

        throw ConvexSettingsExerciseSyncClientError.noFetchChangesValue
    }
}

enum ConvexSettingsExerciseSyncClientError: LocalizedError {
    case noFetchChangesValue

    var errorDescription: String? {
        switch self {
        case .noFetchChangesValue:
            "Convex fetchChanges subscription completed without a value."
        }
    }
}

private extension UserSettingsSyncPayload {
    func convexDictionary() -> [String: ConvexEncodable?] {
        [
            "clientId": clientId,
            "createdAt": createdAt,
            "updatedAt": updatedAt,
            "deletedAt": deletedAt,
            "weightUnitRaw": weightUnitRaw,
            "defaultRestTimerSeconds": defaultRestTimerSeconds,
            "hasCompletedOnboarding": hasCompletedOnboarding,
        ]
    }
}

private extension ExerciseSyncPayload {
    func convexDictionary() -> [String: ConvexEncodable?] {
        [
            "clientId": clientId,
            "createdAt": createdAt,
            "updatedAt": updatedAt,
            "deletedAt": deletedAt,
            "seedIdentifier": seedIdentifier,
            "name": name,
            "categoryRaw": categoryRaw,
            "equipmentRaw": equipmentRaw,
            "primaryMuscleRaw": primaryMuscleRaw,
            "primaryMuscleGroupRaw": primaryMuscleGroupRaw,
            "notes": notes,
            "isArchived": isArchived,
            "isSeeded": isSeeded,
        ]
    }
}

private extension SyncChangeCursors {
    func convexDictionary() -> [String: ConvexEncodable?] {
        [
            "userSettings": userSettings,
            "exercises": exercises,
            "workoutSessions": workoutSessions,
            "loggedExercises": loggedExercises,
            "loggedSets": loggedSets,
        ]
    }
}
```

- [ ] **Step 4: Run tests and build to verify compile**

Run:

```sh
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -only-testing:LiftingLogTests/SyncPayloadMappingTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: PASS.

- [ ] **Step 5: Commit**

```sh
git add LiftingLog/Core/Sync/SyncPayloads.swift LiftingLog/Core/Sync/SettingsExerciseSyncClient.swift LiftingLog/Core/Sync/ConvexSettingsExerciseSyncClient.swift LiftingLogTests/SyncPayloadMappingTests.swift
git commit -m "Add settings exercise sync client"
```

## Task 4: Coordinator Ownership And Retry Preparation

**Files:**
- Create: `LiftingLog/Core/Sync/SettingsExerciseSyncCoordinator.swift`
- Test: `LiftingLogTests/SettingsExerciseSyncCoordinatorTests.swift`

- [ ] **Step 1: Write failing ownership and retry tests**

Create `LiftingLogTests/SettingsExerciseSyncCoordinatorTests.swift`:

```swift
import SwiftData
import XCTest
@testable import LiftingLog

@MainActor
final class SettingsExerciseSyncCoordinatorTests: XCTestCase {
    func testFirstRunClaimsUnownedSettingsExercisesAndOutboxEntries() async throws {
        let container = try SwiftDataTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let settings = UserSettings(id: UUID(uuidString: "00000000-0000-0000-0000-000000002001")!)
        let exercise = Exercise(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000002002")!,
            name: "Bench Press",
            category: .strength,
            equipment: .barbell,
            primaryMuscle: "Chest"
        )
        context.insert(settings)
        context.insert(exercise)
        try SyncOutboxRecorder().recordUpdate(
            entityKind: .userSettings,
            entityID: settings.id,
            ownerTokenIdentifier: nil,
            context: context,
            now: Date(timeIntervalSince1970: 100)
        )
        try context.save()

        let coordinator = SettingsExerciseSyncCoordinator(client: FakeSettingsExerciseSyncClient())
        try coordinator.prepareForSync(ownerTokenIdentifier: "issuer|owner_a", context: context)

        let entries = try context.fetch(FetchDescriptor<SyncOutboxEntry>())
        XCTAssertEqual(settings.syncOwnerTokenIdentifier, "issuer|owner_a")
        XCTAssertEqual(exercise.syncOwnerTokenIdentifier, "issuer|owner_a")
        XCTAssertEqual(entries.first?.ownerTokenIdentifier, "issuer|owner_a")
    }

    func testPrepareSkipsRowsOwnedByDifferentOwner() async throws {
        let container = try SwiftDataTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let exercise = Exercise(
            name: "Squat",
            category: .strength,
            equipment: .barbell,
            primaryMuscle: "Quads"
        )
        exercise.syncOwnerTokenIdentifier = "issuer|owner_a"
        context.insert(exercise)
        try context.save()

        let coordinator = SettingsExerciseSyncCoordinator(client: FakeSettingsExerciseSyncClient())
        try coordinator.prepareForSync(ownerTokenIdentifier: "issuer|owner_b", context: context)

        XCTAssertEqual(exercise.syncOwnerTokenIdentifier, "issuer|owner_a")
    }

    func testPrepareReturnsRelevantInFlightEntriesToPending() async throws {
        let container = try SwiftDataTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let entry = SyncOutboxEntry(
            entityKind: .exercise,
            entityID: UUID(uuidString: "00000000-0000-0000-0000-000000002003")!,
            operation: .update,
            status: .inFlight,
            ownerTokenIdentifier: "issuer|owner_a",
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 200)
        )
        context.insert(entry)
        try context.save()

        let coordinator = SettingsExerciseSyncCoordinator(client: FakeSettingsExerciseSyncClient())
        try coordinator.prepareForSync(ownerTokenIdentifier: "issuer|owner_a", context: context)

        XCTAssertEqual(entry.status, .pending)
    }
}

final class FakeSettingsExerciseSyncClient: SettingsExerciseSyncClient {
    var upsertedSettings: [UserSettingsSyncPayload] = []
    var upsertedExercises: [ExerciseSyncPayload] = []
    var tombstones: [(SyncEntityKind, UUID, Date)] = []
    var fetchResponse = SyncFetchChangesResponse(
        userSettings: [],
        exercises: [],
        cursors: SyncChangeCursors(userSettings: 0, exercises: 0),
        hasMore: SyncHasMore(userSettings: false, exercises: false)
    )
    var error: Error?

    func upsertUserSettings(_ record: UserSettingsSyncPayload) async throws -> SyncMutationResult {
        if let error { throw error }
        upsertedSettings.append(record)
        return SyncMutationResult(status: "updated", serverUpdatedAt: 1)
    }

    func upsertExercise(_ record: ExerciseSyncPayload) async throws -> SyncMutationResult {
        if let error { throw error }
        upsertedExercises.append(record)
        return SyncMutationResult(status: "updated", serverUpdatedAt: 1)
    }

    func tombstone(entityKind: SyncEntityKind, clientId: UUID, deletedAt: Date) async throws -> SyncMutationResult {
        if let error { throw error }
        tombstones.append((entityKind, clientId, deletedAt))
        return SyncMutationResult(status: "tombstoned", serverUpdatedAt: 1)
    }

    func fetchChanges(cursors: SyncChangeCursors, limit: Int) async throws -> SyncFetchChangesResponse {
        if let error { throw error }
        return fetchResponse
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```sh
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -only-testing:LiftingLogTests/SettingsExerciseSyncCoordinatorTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: FAIL because `syncOwnerTokenIdentifier` and `SettingsExerciseSyncCoordinator` do not exist.

- [ ] **Step 3: Add owner fields and coordinator preparation**

Modify `UserSettings` and `Exercise` initializers to include:

```swift
var syncOwnerTokenIdentifier: String?
```

Set it in each initializer:

```swift
self.syncOwnerTokenIdentifier = syncOwnerTokenIdentifier
```

Add initializer parameter before timestamps:

```swift
syncOwnerTokenIdentifier: String? = nil,
```

Create `LiftingLog/Core/Sync/SettingsExerciseSyncCoordinator.swift`:

```swift
import Foundation
import SwiftData

@MainActor
final class SettingsExerciseSyncCoordinator {
    private let client: SettingsExerciseSyncClient
    private let recorder = SyncOutboxRecorder()
    private var isRunning = false

    init(client: SettingsExerciseSyncClient) {
        self.client = client
    }

    func prepareForSync(ownerTokenIdentifier: String, context: ModelContext) throws {
        for settings in try context.fetch(FetchDescriptor<UserSettings>()) {
            if settings.syncOwnerTokenIdentifier == nil {
                settings.syncOwnerTokenIdentifier = ownerTokenIdentifier
            }
        }

        for exercise in try context.fetch(FetchDescriptor<Exercise>()) {
            if exercise.syncOwnerTokenIdentifier == nil {
                exercise.syncOwnerTokenIdentifier = ownerTokenIdentifier
            }
        }

        for entry in try context.fetch(FetchDescriptor<SyncOutboxEntry>()) {
            guard entry.entityKind == .userSettings || entry.entityKind == .exercise else {
                continue
            }
            if entry.ownerTokenIdentifier == nil {
                entry.ownerTokenIdentifier = ownerTokenIdentifier
            }
            if entry.ownerTokenIdentifier == ownerTokenIdentifier, entry.status == .inFlight {
                recorder.markPendingForRetry(entry, now: .now)
            }
        }

        try context.save()
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run the same coordinator test command.

Expected: PASS.

- [ ] **Step 5: Commit**

```sh
git add LiftingLog/Core/Models/UserSettings.swift LiftingLog/Core/Models/Exercise.swift LiftingLog/Core/Sync/SettingsExerciseSyncCoordinator.swift LiftingLogTests/SettingsExerciseSyncCoordinatorTests.swift
git commit -m "Add sync coordinator ownership preparation"
```

## Task 5: Coordinator Push Flow

**Files:**
- Modify: `LiftingLog/Core/Sync/SettingsExerciseSyncCoordinator.swift`
- Test: `LiftingLogTests/SettingsExerciseSyncCoordinatorTests.swift`

- [ ] **Step 1: Add failing push tests**

Append to `SettingsExerciseSyncCoordinatorTests`:

```swift
func testRunPushesSettingsAndExerciseEntriesThenRemovesOutbox() async throws {
    let container = try SwiftDataTestSupport.makeInMemoryContainer()
    let context = container.mainContext
    let settings = UserSettings(id: UUID(uuidString: "00000000-0000-0000-0000-000000003001")!)
    let exercise = Exercise(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000003002")!,
        name: "Bench Press",
        category: .strength,
        equipment: .barbell,
        primaryMuscle: "Chest"
    )
    context.insert(settings)
    context.insert(exercise)
    let recorder = SyncOutboxRecorder()
    try recorder.recordUpdate(entityKind: .userSettings, entityID: settings.id, ownerTokenIdentifier: "issuer|owner_a", context: context, now: Date(timeIntervalSince1970: 100))
    try recorder.recordCreate(entityKind: .exercise, entityID: exercise.id, ownerTokenIdentifier: "issuer|owner_a", context: context, now: Date(timeIntervalSince1970: 100))
    try context.save()

    let client = FakeSettingsExerciseSyncClient()
    let coordinator = SettingsExerciseSyncCoordinator(client: client)
    try await coordinator.run(ownerTokenIdentifier: "issuer|owner_a", context: context)

    XCTAssertEqual(client.upsertedSettings.count, 1)
    XCTAssertEqual(client.upsertedExercises.count, 1)
    XCTAssertTrue(try context.fetch(FetchDescriptor<SyncOutboxEntry>()).isEmpty)
}

func testRunMarksFailedEntryAndStopsOnPushError() async throws {
    struct PushError: LocalizedError { var errorDescription: String? { "offline" } }
    let container = try SwiftDataTestSupport.makeInMemoryContainer()
    let context = container.mainContext
    let exercise = Exercise(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000003003")!,
        name: "Squat",
        category: .strength,
        equipment: .barbell,
        primaryMuscle: "Quads"
    )
    context.insert(exercise)
    try SyncOutboxRecorder().recordUpdate(entityKind: .exercise, entityID: exercise.id, ownerTokenIdentifier: "issuer|owner_a", context: context, now: Date(timeIntervalSince1970: 100))
    try context.save()

    let client = FakeSettingsExerciseSyncClient()
    client.error = PushError()
    let coordinator = SettingsExerciseSyncCoordinator(client: client)
    try await coordinator.run(ownerTokenIdentifier: "issuer|owner_a", context: context)

    let entry = try XCTUnwrap(context.fetch(FetchDescriptor<SyncOutboxEntry>()).first)
    XCTAssertEqual(entry.status, .failed)
    XCTAssertEqual(entry.lastErrorMessage, "offline")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run the coordinator test command.

Expected: FAIL because `run(ownerTokenIdentifier:context:)` does not exist.

- [ ] **Step 3: Implement push flow**

Replace `SettingsExerciseSyncCoordinator` with:

```swift
import Foundation
import SwiftData

@MainActor
final class SettingsExerciseSyncCoordinator {
    private let client: SettingsExerciseSyncClient
    private let recorder = SyncOutboxRecorder()
    private var isRunning = false

    init(client: SettingsExerciseSyncClient) {
        self.client = client
    }

    func run(ownerTokenIdentifier: String?, context: ModelContext) async throws {
        guard let ownerTokenIdentifier else { return }
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        try prepareForSync(ownerTokenIdentifier: ownerTokenIdentifier, context: context)
        try await pushPendingEntries(ownerTokenIdentifier: ownerTokenIdentifier, context: context)
    }

    func prepareForSync(ownerTokenIdentifier: String, context: ModelContext) throws {
        for settings in try context.fetch(FetchDescriptor<UserSettings>()) where settings.syncOwnerTokenIdentifier == nil {
            settings.syncOwnerTokenIdentifier = ownerTokenIdentifier
        }

        for exercise in try context.fetch(FetchDescriptor<Exercise>()) where exercise.syncOwnerTokenIdentifier == nil {
            exercise.syncOwnerTokenIdentifier = ownerTokenIdentifier
        }

        for entry in try context.fetch(FetchDescriptor<SyncOutboxEntry>()) {
            guard entry.entityKind == .userSettings || entry.entityKind == .exercise else { continue }
            if entry.ownerTokenIdentifier == nil {
                entry.ownerTokenIdentifier = ownerTokenIdentifier
            }
            if entry.ownerTokenIdentifier == ownerTokenIdentifier, entry.status == .inFlight {
                recorder.markPendingForRetry(entry, now: .now)
            }
        }

        try context.save()
    }

    private func pushPendingEntries(ownerTokenIdentifier: String, context: ModelContext) async throws {
        let entries = try recorder.pendingEntries(context: context)
            .filter { entry in
                entry.ownerTokenIdentifier == ownerTokenIdentifier
                    && (entry.entityKind == .userSettings || entry.entityKind == .exercise)
            }

        for entry in entries {
            recorder.markInFlight(entry, now: .now)
            try context.save()

            do {
                try await push(entry: entry, context: context)
                recorder.removeCompleted(entry, context: context)
                try context.save()
            } catch {
                recorder.markFailed(entry, message: error.localizedDescription, now: .now)
                try context.save()
                break
            }
        }
    }

    private func push(entry: SyncOutboxEntry, context: ModelContext) async throws {
        guard let entityKind = entry.entityKind, let operation = entry.operation else { return }

        switch (entityKind, operation) {
        case (.userSettings, .create), (.userSettings, .update):
            guard let settings = try findUserSettings(id: entry.entityID, context: context) else {
                _ = try await client.tombstone(entityKind: .userSettings, clientId: entry.entityID, deletedAt: entry.updatedAt)
                return
            }
            _ = try await client.upsertUserSettings(SyncPayloadMapper.userSettingsPayload(from: settings))
        case (.exercise, .create), (.exercise, .update):
            guard let exercise = try findExercise(id: entry.entityID, context: context) else {
                _ = try await client.tombstone(entityKind: .exercise, clientId: entry.entityID, deletedAt: entry.updatedAt)
                return
            }
            _ = try await client.upsertExercise(SyncPayloadMapper.exercisePayload(from: exercise))
        case (.userSettings, .delete):
            let deletedAt = try findUserSettings(id: entry.entityID, context: context)?.deletedAt ?? entry.updatedAt
            _ = try await client.tombstone(entityKind: .userSettings, clientId: entry.entityID, deletedAt: deletedAt)
        case (.exercise, .delete):
            let deletedAt = try findExercise(id: entry.entityID, context: context)?.deletedAt ?? entry.updatedAt
            _ = try await client.tombstone(entityKind: .exercise, clientId: entry.entityID, deletedAt: deletedAt)
        default:
            return
        }
    }

    private func findUserSettings(id: UUID, context: ModelContext) throws -> UserSettings? {
        try context.fetch(FetchDescriptor<UserSettings>()).first { $0.id == id }
    }

    private func findExercise(id: UUID, context: ModelContext) throws -> Exercise? {
        try context.fetch(FetchDescriptor<Exercise>()).first { $0.id == id }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run the coordinator test command.

Expected: PASS.

- [ ] **Step 5: Commit**

```sh
git add LiftingLog/Core/Sync/SettingsExerciseSyncCoordinator.swift LiftingLogTests/SettingsExerciseSyncCoordinatorTests.swift
git commit -m "Push settings and exercise outbox entries"
```

## Task 6: Coordinator Pull Flow And Cursor Advancement

**Files:**
- Modify: `LiftingLog/Core/Sync/SettingsExerciseSyncCoordinator.swift`
- Test: `LiftingLogTests/SettingsExerciseSyncCoordinatorTests.swift`

- [ ] **Step 1: Add failing pull tests**

Append to `SettingsExerciseSyncCoordinatorTests`:

```swift
func testRunPullsRemoteExerciseAndAdvancesCursor() async throws {
    let container = try SwiftDataTestSupport.makeInMemoryContainer()
    let context = container.mainContext
    let client = FakeSettingsExerciseSyncClient()
    client.fetchResponse = SyncFetchChangesResponse(
        userSettings: [],
        exercises: [
            ExerciseSyncRecord(
                clientId: "00000000-0000-0000-0000-000000004001",
                createdAt: 10,
                updatedAt: 20,
                deletedAt: nil,
                serverUpdatedAt: 30,
                seedIdentifier: nil,
                name: "Remote Bench",
                categoryRaw: "strength",
                equipmentRaw: "barbell",
                primaryMuscleRaw: "Chest",
                primaryMuscleGroupRaw: "chest",
                notes: "",
                isArchived: false,
                isSeeded: false
            )
        ],
        cursors: SyncChangeCursors(userSettings: 0, exercises: 30),
        hasMore: SyncHasMore(userSettings: false, exercises: false)
    )

    let coordinator = SettingsExerciseSyncCoordinator(client: client)
    try await coordinator.run(ownerTokenIdentifier: "issuer|owner_a", context: context)

    let exercises = try context.fetch(FetchDescriptor<Exercise>())
    let cursor = try XCTUnwrap(context.fetch(FetchDescriptor<SyncCursorState>()).first)
    XCTAssertEqual(exercises.count, 1)
    XCTAssertEqual(exercises.first?.name, "Remote Bench")
    XCTAssertEqual(exercises.first?.syncOwnerTokenIdentifier, "issuer|owner_a")
    XCTAssertEqual(cursor.exercisesCursor, 30)
}

func testRunKeepsLocalNewerExerciseWhenRemoteIsOlder() async throws {
    let container = try SwiftDataTestSupport.makeInMemoryContainer()
    let context = container.mainContext
    let exercise = Exercise(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000004002")!,
        name: "Local Name",
        category: .strength,
        equipment: .barbell,
        primaryMuscle: "Chest",
        updatedAt: Date(timeIntervalSince1970: 50)
    )
    exercise.syncOwnerTokenIdentifier = "issuer|owner_a"
    context.insert(exercise)
    try context.save()

    let client = FakeSettingsExerciseSyncClient()
    client.fetchResponse = SyncFetchChangesResponse(
        userSettings: [],
        exercises: [
            ExerciseSyncRecord(
                clientId: exercise.id.uuidString.lowercased(),
                createdAt: 10,
                updatedAt: 20,
                deletedAt: nil,
                serverUpdatedAt: 30,
                seedIdentifier: nil,
                name: "Remote Older Name",
                categoryRaw: "strength",
                equipmentRaw: "barbell",
                primaryMuscleRaw: "Chest",
                primaryMuscleGroupRaw: "chest",
                notes: "",
                isArchived: false,
                isSeeded: false
            )
        ],
        cursors: SyncChangeCursors(userSettings: 0, exercises: 30),
        hasMore: SyncHasMore(userSettings: false, exercises: false)
    )

    try await SettingsExerciseSyncCoordinator(client: client).run(ownerTokenIdentifier: "issuer|owner_a", context: context)

    XCTAssertEqual(exercise.name, "Local Name")
}

func testRunAppliesRemoteSettingsWithoutLoggedSetOutboxCascade() async throws {
    let container = try SwiftDataTestSupport.makeInMemoryContainer()
    let context = container.mainContext
    let settings = UserSettings(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000004003")!,
        weightUnit: .pounds,
        updatedAt: Date(timeIntervalSince1970: 10)
    )
    settings.syncOwnerTokenIdentifier = "issuer|owner_a"
    context.insert(settings)
    try context.save()

    let client = FakeSettingsExerciseSyncClient()
    client.fetchResponse = SyncFetchChangesResponse(
        userSettings: [
            UserSettingsSyncRecord(
                clientId: settings.id.uuidString.lowercased(),
                createdAt: 10,
                updatedAt: 20,
                deletedAt: nil,
                serverUpdatedAt: 25,
                weightUnitRaw: "kilograms",
                defaultRestTimerSeconds: 150,
                hasCompletedOnboarding: true
            )
        ],
        exercises: [],
        cursors: SyncChangeCursors(userSettings: 25, exercises: 0),
        hasMore: SyncHasMore(userSettings: false, exercises: false)
    )

    try await SettingsExerciseSyncCoordinator(client: client).run(ownerTokenIdentifier: "issuer|owner_a", context: context)

    XCTAssertEqual(settings.weightUnit, .kilograms)
    XCTAssertEqual(settings.defaultRestTimerSeconds, 150)
    XCTAssertTrue(try context.fetch(FetchDescriptor<SyncOutboxEntry>()).isEmpty)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run the coordinator test command.

Expected: FAIL because `run` does not pull remote changes or advance cursors.

- [ ] **Step 3: Implement pull flow**

Add these methods to `SettingsExerciseSyncCoordinator`, and call `try await pullChanges(ownerTokenIdentifier:context:)` after `pushPendingEntries` in `run`:

```swift
private func pullChanges(ownerTokenIdentifier: String, context: ModelContext) async throws {
    let state = try SyncCursorState.state(for: ownerTokenIdentifier, context: context)
    var hasMore = true

    while hasMore {
        let response = try await client.fetchChanges(
            cursors: SyncChangeCursors(
                userSettings: state.userSettingsCursor,
                exercises: state.exercisesCursor
            ),
            limit: 100
        )

        try apply(userSettingsRecords: response.userSettings, ownerTokenIdentifier: ownerTokenIdentifier, context: context)
        try apply(exerciseRecords: response.exercises, ownerTokenIdentifier: ownerTokenIdentifier, context: context)

        state.userSettingsCursor = response.cursors.userSettings
        state.exercisesCursor = response.cursors.exercises
        try context.save()

        hasMore = response.hasMore.userSettings || response.hasMore.exercises
    }
}

private func apply(
    userSettingsRecords records: [UserSettingsSyncRecord],
    ownerTokenIdentifier: String,
    context: ModelContext
) throws {
    for record in records {
        guard let id = UUID(uuidString: record.clientId) else { continue }
        let existing = try context.fetch(FetchDescriptor<UserSettings>()).first { $0.id == id }
        if let existing {
            let decision = SyncConflictResolver.decision(
                localUpdatedAt: existing.updatedAt,
                localDeletedAt: existing.deletedAt,
                incomingUpdatedAt: Date(timeIntervalSince1970: record.updatedAt),
                incomingDeletedAt: record.deletedAt.map(Date.init(timeIntervalSince1970:))
            )
            guard decision == .applyIncoming else { continue }
            apply(record, to: existing, ownerTokenIdentifier: ownerTokenIdentifier)
        } else if record.deletedAt == nil {
            let settings = UserSettings(
                id: id,
                weightUnit: MeasurementUnit(rawValue: record.weightUnitRaw) ?? .pounds,
                defaultRestTimerSeconds: record.defaultRestTimerSeconds,
                hasCompletedOnboarding: record.hasCompletedOnboarding,
                syncOwnerTokenIdentifier: ownerTokenIdentifier,
                createdAt: Date(timeIntervalSince1970: record.createdAt),
                updatedAt: Date(timeIntervalSince1970: record.updatedAt),
                deletedAt: nil
            )
            settings.weightUnitRaw = record.weightUnitRaw
            context.insert(settings)
        }
    }
}

private func apply(_ record: UserSettingsSyncRecord, to settings: UserSettings, ownerTokenIdentifier: String) {
    settings.syncOwnerTokenIdentifier = ownerTokenIdentifier
    settings.weightUnitRaw = record.weightUnitRaw
    settings.defaultRestTimerSeconds = record.defaultRestTimerSeconds
    settings.hasCompletedOnboarding = record.hasCompletedOnboarding
    settings.createdAt = Date(timeIntervalSince1970: record.createdAt)
    settings.updatedAt = Date(timeIntervalSince1970: record.updatedAt)
    settings.deletedAt = record.deletedAt.map(Date.init(timeIntervalSince1970:))
}

private func apply(
    exerciseRecords records: [ExerciseSyncRecord],
    ownerTokenIdentifier: String,
    context: ModelContext
) throws {
    for record in records {
        guard let id = UUID(uuidString: record.clientId) else { continue }
        let existing = try context.fetch(FetchDescriptor<Exercise>()).first { $0.id == id }
        if let existing {
            let decision = SyncConflictResolver.decision(
                localUpdatedAt: existing.updatedAt,
                localDeletedAt: existing.deletedAt,
                incomingUpdatedAt: Date(timeIntervalSince1970: record.updatedAt),
                incomingDeletedAt: record.deletedAt.map(Date.init(timeIntervalSince1970:))
            )
            guard decision == .applyIncoming else { continue }
            apply(record, to: existing, ownerTokenIdentifier: ownerTokenIdentifier)
        } else if record.deletedAt == nil {
            let exercise = Exercise(
                id: id,
                seedIdentifier: record.seedIdentifier,
                name: record.name,
                category: ExerciseCategory(rawValue: record.categoryRaw) ?? .other,
                equipment: ExerciseEquipment(rawValue: record.equipmentRaw) ?? .other,
                primaryMuscleGroup: ExerciseMuscleGroup(rawValue: record.primaryMuscleGroupRaw) ?? .other,
                notes: record.notes,
                isArchived: record.isArchived,
                isSeeded: record.isSeeded,
                syncOwnerTokenIdentifier: ownerTokenIdentifier,
                createdAt: Date(timeIntervalSince1970: record.createdAt),
                updatedAt: Date(timeIntervalSince1970: record.updatedAt),
                deletedAt: record.deletedAt.map(Date.init(timeIntervalSince1970:))
            )
            exercise.categoryRaw = record.categoryRaw
            exercise.equipmentRaw = record.equipmentRaw
            exercise.primaryMuscleRaw = record.primaryMuscleRaw
            exercise.primaryMuscleGroupRaw = record.primaryMuscleGroupRaw
            context.insert(exercise)
        }
    }
}

private func apply(_ record: ExerciseSyncRecord, to exercise: Exercise, ownerTokenIdentifier: String) {
    exercise.syncOwnerTokenIdentifier = ownerTokenIdentifier
    exercise.seedIdentifier = record.seedIdentifier
    exercise.name = record.name
    exercise.categoryRaw = record.categoryRaw
    exercise.equipmentRaw = record.equipmentRaw
    exercise.primaryMuscleRaw = record.primaryMuscleRaw
    exercise.primaryMuscleGroupRaw = record.primaryMuscleGroupRaw
    exercise.notes = record.notes
    exercise.isArchived = record.isArchived
    exercise.isSeeded = record.isSeeded
    exercise.createdAt = Date(timeIntervalSince1970: record.createdAt)
    exercise.updatedAt = Date(timeIntervalSince1970: record.updatedAt)
    exercise.deletedAt = record.deletedAt.map(Date.init(timeIntervalSince1970:))
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run the coordinator test command.

Expected: PASS.

- [ ] **Step 5: Commit**

```sh
git add LiftingLog/Core/Sync/SettingsExerciseSyncCoordinator.swift LiftingLogTests/SettingsExerciseSyncCoordinatorTests.swift
git commit -m "Pull settings and exercise changes"
```

## Task 7: Sync Scheduler And Mutation Trigger Wiring

**Files:**
- Create: `LiftingLog/Core/Sync/SyncScheduler.swift`
- Modify: `LiftingLog/Core/Domain/SettingsMutationService.swift`
- Modify: `LiftingLog/Core/Domain/ExerciseMutationService.swift`
- Test: `LiftingLogTests/SyncOutboxIntegrationTests.swift`

- [ ] **Step 1: Add failing owner propagation tests**

Add to `SyncOutboxIntegrationTests`:

```swift
func testSettingsMutationUsesCurrentSyncOwnerAndRequestsSync() throws {
    let container = try SwiftDataTestSupport.makeInMemoryContainer()
    let context = container.mainContext
    let settings = UserSettings(defaultRestTimerSeconds: 90)
    context.insert(settings)
    try context.save()

    let scheduler = SyncScheduler()
    scheduler.currentOwnerTokenIdentifier = "issuer|owner_a"

    try SettingsMutationService(syncScheduler: scheduler).updateDefaultRestTimerSeconds(
        120,
        settings: settings,
        context: context,
        now: Date(timeIntervalSince1970: 100)
    )

    let entry = try XCTUnwrap(fetchEntries(context).first)
    XCTAssertEqual(settings.syncOwnerTokenIdentifier, "issuer|owner_a")
    XCTAssertEqual(entry.ownerTokenIdentifier, "issuer|owner_a")
    XCTAssertEqual(scheduler.requestCount, 1)
}

func testExerciseMutationUsesCurrentSyncOwnerAndRequestsSync() throws {
    let container = try SwiftDataTestSupport.makeInMemoryContainer()
    let context = container.mainContext
    let scheduler = SyncScheduler()
    scheduler.currentOwnerTokenIdentifier = "issuer|owner_a"

    let exercise = try ExerciseMutationService(syncScheduler: scheduler).createExercise(
        name: "Owner Bench",
        category: .strength,
        equipment: .barbell,
        primaryMuscle: "Chest",
        notes: "",
        context: context,
        now: Date(timeIntervalSince1970: 100)
    )

    let entry = try XCTUnwrap(fetchEntries(context).first)
    XCTAssertEqual(exercise.syncOwnerTokenIdentifier, "issuer|owner_a")
    XCTAssertEqual(entry.ownerTokenIdentifier, "issuer|owner_a")
    XCTAssertEqual(scheduler.requestCount, 1)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```sh
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -only-testing:LiftingLogTests/SyncOutboxIntegrationTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: FAIL because `SyncScheduler` and service initializers do not exist.

- [ ] **Step 3: Add scheduler and service injection**

Create `LiftingLog/Core/Sync/SyncScheduler.swift`:

```swift
import Foundation
import SwiftData

@MainActor
@Observable
final class SyncScheduler {
    var currentOwnerTokenIdentifier: String?
    private(set) var requestCount = 0
    private var coordinator: SettingsExerciseSyncCoordinator?
    private weak var modelContext: ModelContext?

    init(coordinator: SettingsExerciseSyncCoordinator? = nil, modelContext: ModelContext? = nil) {
        self.coordinator = coordinator
        self.modelContext = modelContext
    }

    func configure(coordinator: SettingsExerciseSyncCoordinator, modelContext: ModelContext) {
        self.coordinator = coordinator
        self.modelContext = modelContext
    }

    func requestSync() {
        requestCount += 1
        guard let coordinator, let modelContext else { return }
        let owner = currentOwnerTokenIdentifier
        Task { @MainActor in
            try? await coordinator.run(ownerTokenIdentifier: owner, context: modelContext)
        }
    }
}
```

Modify `SettingsMutationService`:

```swift
@MainActor
struct SettingsMutationService {
    private let recorder = SyncOutboxRecorder()
    private let syncScheduler: SyncScheduler?

    init(syncScheduler: SyncScheduler? = nil) {
        self.syncScheduler = syncScheduler
    }
```

In both mutation methods, compute owner:

```swift
let effectiveOwner = ownerTokenIdentifier ?? syncScheduler?.currentOwnerTokenIdentifier
settings.syncOwnerTokenIdentifier = effectiveOwner ?? settings.syncOwnerTokenIdentifier
```

Pass `effectiveOwner` to `recordUpdate`, save, then call:

```swift
syncScheduler?.requestSync()
```

Modify `ExerciseMutationService` similarly:

```swift
@MainActor
struct ExerciseMutationService {
    private let recorder = SyncOutboxRecorder()
    private let syncScheduler: SyncScheduler?

    init(syncScheduler: SyncScheduler? = nil) {
        self.syncScheduler = syncScheduler
    }
```

Set `exercise.syncOwnerTokenIdentifier = effectiveOwner` on create/update/remove, pass `effectiveOwner` to recorder calls, save, and call `syncScheduler?.requestSync()`.

- [ ] **Step 4: Run tests to verify they pass**

Run the `SyncOutboxIntegrationTests` command.

Expected: PASS.

- [ ] **Step 5: Commit**

```sh
git add LiftingLog/Core/Sync/SyncScheduler.swift LiftingLog/Core/Domain/SettingsMutationService.swift LiftingLog/Core/Domain/ExerciseMutationService.swift LiftingLogTests/SyncOutboxIntegrationTests.swift
git commit -m "Trigger sync after settings and exercise mutations"
```

## Task 8: App-Level Sync Runtime

**Files:**
- Modify: `LiftingLog/App/LiftingLogApp.swift`
- Modify: `LiftingLog/Features/Profile/SettingsView.swift`
- Modify: `LiftingLog/Features/Exercises/ExerciseEditorView.swift`
- Modify: `LiftingLog/Features/Exercises/ExerciseLibraryView.swift`

- [ ] **Step 1: Add environment access to mutation views**

Modify `SettingsView`, `ExerciseEditorView`, and `ExerciseLibraryView` to add:

```swift
@Environment(SyncScheduler.self) private var syncScheduler
```

Change service construction:

```swift
SettingsMutationService(syncScheduler: syncScheduler)
ExerciseMutationService(syncScheduler: syncScheduler)
```

- [ ] **Step 2: Wire scheduler into app root**

Modify `LiftingLogApp` to hold sync runtime state:

```swift
@State private var syncScheduler = SyncScheduler()
@State private var convexClient = ConvexClientFactory.makeAuthenticatedClient()
@State private var syncAuthTask: Task<Void, Never>?
```

In `body`, inject:

```swift
.environment(syncScheduler)
.task {
    configureSyncIfNeeded()
}
```

Add helper:

```swift
private func configureSyncIfNeeded() {
    guard syncAuthTask == nil else { return }
    let syncClient = ConvexSettingsExerciseSyncClient(client: convexClient)
    let coordinator = SettingsExerciseSyncCoordinator(client: syncClient)
    syncScheduler.configure(coordinator: coordinator, modelContext: modelContainer.mainContext)

    syncAuthTask = Task { @MainActor in
        for await state in convexClient.authState.values {
            switch state {
            case .authenticated:
                syncScheduler.currentOwnerTokenIdentifier = await resolveOwnerTokenIdentifier()
                syncScheduler.requestSync()
            case .unauthenticated:
                syncScheduler.currentOwnerTokenIdentifier = nil
            case .loading:
                break
            }
        }
    }
}

private func resolveOwnerTokenIdentifier() async -> String? {
    let publisher = convexClient.subscribe(
        to: "authSmoke:me",
        yielding: ConvexAuthSmokeIdentity.self
    )

    do {
        for try await identity in publisher.values {
            return identity.tokenIdentifier
        }
    } catch {
        return nil
    }

    return nil
}

private struct ConvexAuthSmokeIdentity: Decodable {
    let tokenIdentifier: String
}
```
- [ ] **Step 3: Build to catch wiring errors**

Run:

```sh
xcodebuild build -project LiftingLog.xcodeproj -scheme LiftingLog -destination generic/platform=iOS\ Simulator -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: PASS.

- [ ] **Step 4: Commit**

```sh
git add LiftingLog/App/LiftingLogApp.swift LiftingLog/Features/Profile/SettingsView.swift LiftingLog/Features/Exercises/ExerciseEditorView.swift LiftingLog/Features/Exercises/ExerciseLibraryView.swift
git commit -m "Wire sync scheduler into app"
```

## Task 9: Narrow UI Trigger Tests

**Files:**
- Modify: `LiftingLog/App/LiftingLogApp.swift`
- Modify: `LiftingLog/Core/Sync/SyncScheduler.swift`
- Modify: `LiftingLogUITests/LiftingLogUITests.swift`

- [ ] **Step 1: Add failing UI trigger tests**

Append to `LiftingLogUITests`:

```swift
@MainActor
func testSettingsEditRequestsSyncInUITestMode() {
    let app = makeApp(extraArguments: ["--uitest-sync-owner", "issuer|ui_owner"])
    app.launch()

    app.buttons["ProfileTab"].tap()
    app.buttons["ProfileSettingsLink"].tap()
    XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
    app.segmentedControls["WeightUnitPicker"].buttons["Kilograms"].tap()

    XCTAssertTrue(app.staticTexts["UITestSyncRequestCount-1"].waitForExistence(timeout: 3))
}

@MainActor
func testExerciseCreateRequestsSyncInUITestMode() {
    let app = makeApp(extraArguments: ["--uitest-sync-owner", "issuer|ui_owner"])
    app.launch()

    app.buttons["ProfileTab"].tap()
    app.buttons["ProfileExerciseLibraryLink"].tap()
    XCTAssertTrue(app.navigationBars["Exercises"].waitForExistence(timeout: 3))
    createExercise(name: "UI Sync Bench", equipment: "Barbell", muscle: "Chest", in: app)

    XCTAssertTrue(app.staticTexts["UITestSyncRequestCount-1"].waitForExistence(timeout: 3))
}
```

Update the existing `makeApp` helper:

```swift
private func makeApp(extraArguments: [String] = []) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = [
        "--uitest-reset-persistent-store",
        "--uitest-in-memory-store",
    ] + extraArguments
    return app
}
```

- [ ] **Step 2: Run UI tests to verify they fail**

Run:

```sh
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -only-testing:LiftingLogUITests/LiftingLogUITests/testSettingsEditRequestsSyncInUITestMode -only-testing:LiftingLogUITests/LiftingLogUITests/testExerciseCreateRequestsSyncInUITestMode -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: FAIL because there is no UI test sync owner mode or visible request count probe.

- [ ] **Step 3: Add UI test sync owner mode**

In `LiftingLogApp.init`, parse:

```swift
let arguments = ProcessInfo.processInfo.arguments
let uiTestSyncOwnerIndex = arguments.firstIndex(of: "--uitest-sync-owner")
let uiTestSyncOwner = uiTestSyncOwnerIndex.flatMap { index -> String? in
    let nextIndex = arguments.index(after: index)
    return nextIndex < arguments.endIndex ? arguments[nextIndex] : nil
}
```

Store `uiTestSyncOwner` in a property:

```swift
private let uiTestSyncOwner: String?
```

Assign in `init`:

```swift
self.uiTestSyncOwner = uiTestSyncOwner
```

In app startup after `.environment(syncScheduler)`, add:

```swift
.overlay(alignment: .bottom) {
    if ProcessInfo.processInfo.arguments.contains("--uitest-sync-owner") {
        Text("UITestSyncRequestCount-\(syncScheduler.requestCount)")
            .font(.caption2)
            .accessibilityIdentifier("UITestSyncRequestCount")
    }
}
.task {
    if let uiTestSyncOwner {
        syncScheduler.currentOwnerTokenIdentifier = uiTestSyncOwner
    }
    configureSyncIfNeeded()
}
```

In `SyncScheduler.requestSync`, keep incrementing `requestCount` even when no coordinator is configured, so UI tests can assert trigger handoff without network.

- [ ] **Step 4: Run UI tests to verify they pass**

Run the same two UI tests.

Expected: PASS.

- [ ] **Step 5: Commit**

```sh
git add LiftingLog/App/LiftingLogApp.swift LiftingLog/Core/Sync/SyncScheduler.swift LiftingLogUITests/LiftingLogUITests.swift
git commit -m "Add UI sync trigger coverage"
```

## Task 10: Final Verification

**Files:**
- All files modified above

- [ ] **Step 1: Run targeted unit tests**

Run:

```sh
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -only-testing:LiftingLogTests/SyncPayloadMappingTests -only-testing:LiftingLogTests/SyncCursorStateTests -only-testing:LiftingLogTests/SettingsExerciseSyncCoordinatorTests -only-testing:LiftingLogTests/SyncOutboxIntegrationTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: PASS.

- [ ] **Step 2: Run full unit test target**

Run:

```sh
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -only-testing:LiftingLogTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: PASS.

- [ ] **Step 3: Run narrow UI tests**

Run:

```sh
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -only-testing:LiftingLogUITests/LiftingLogUITests/testSettingsEditRequestsSyncInUITestMode -only-testing:LiftingLogUITests/LiftingLogUITests/testExerciseCreateRequestsSyncInUITestMode -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: PASS.

- [ ] **Step 4: Run Convex tests only if Convex files changed**

If any `convex/**/*.ts` file changed, run:

```sh
pnpm test
```

Expected: PASS. If no Convex files changed, skip this step and note that it was not needed.

- [ ] **Step 5: Review diff for scope**

Run:

```sh
git status --short
git diff --stat
```

Expected: only sync engine, settings/exercise mutation wiring, tests, and the implementation plan are changed. No workout graph sync implementation, account-switching UX, or polished sync status UI should be present.

- [ ] **Step 6: Commit final verification fixes**

If final verification required small fixes, commit them:

```sh
git add LiftingLog LiftingLogTests LiftingLogUITests docs/superpowers/plans/2026-06-07-settings-exercises-sync-implementation.md
git commit -m "Verify settings and exercises sync"
```

If no fixes were needed after Task 9, do not create an empty commit.
