# Previous Column + RPE Entry Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the ghost-placeholder mechanic with a read-only "Previous" column sourced from each exercise's last completed session, and move RPE entry off the set row into a keyboard-toolbar chip picker with a badge on the reps field — landing both GitHub issues (#59 RPE, #61 Previous column) as one cohesive change.

**Architecture:** The set row's final layout is `# | Previous | LBS | REPS | ✓`. "Previous" is a pure, testable lookup that reuses the existing `ExerciseHistorySummary` / `ExerciseHistorySessionGroup` history machinery to find the most recent completed session matching the exercise's identity, indexed set-by-set. The three `placeholder*` fields are deleted from the SwiftData model, the Convex schema/validators, the sync payloads, and both unit-conversion paths. RPE moves to a chip row hosted in the existing keyboard accessory toolbar, surfaced as an `@9` badge overlaid on the reps field. Work is sequenced by risk: Convex schema migration first (non-destructive), then the iOS data-model removal, then the UI rewrite, then final Convex field removal.

**Tech Stack:** Swift 6 / SwiftUI / SwiftData (iOS 26 min), XCTest + XCUITest, Convex (TypeScript) with `convex-test` + Vitest, XcodeGen (`project.yml`).

**GitHub:** Closes #59 and #61. (#60 keeps the remaining grab-bag items.)

---

## Critical ordering & judgment calls (read before starting)

These are the decisions baked into the task order. Do not reorder across phase boundaries.

1. **Convex field removal is split front and back.** Convex rejects a schema push if any stored document still carries a field the schema no longer defines, AND the sync mutation rejects payloads with fields the validator no longer allows. So:
   - **Phase 1 (first):** make the three `placeholder*` fields **optional** in `schema.ts` and `validators.ts`, deploy, then run a one-shot internal mutation that unsets them on every existing `loggedSets` document. The server now accepts payloads with OR without the fields, and no document carries them.
   - **Phase 2 (iOS):** the client stops sending the fields. Safe because the validator still accepts payloads without them (optional).
   - **Phase 5 (last):** remove the fields from `schema.ts` and `validators.ts` entirely and deploy. Safe now: no document carries them and no client sends them.
   Chosen migration strategy: **non-destructive** (preserve all synced workout data). Do not wipe tables.

2. **The SwiftData model-field removal is a pivot that breaks several files at once.** Deleting `placeholderWeight/Reps/RPE` from `LoggedSet` simultaneously breaks `SyncPayloads`, `ConvexSyncClient`, `SyncCoordinator`, `ActiveWorkoutEngine`, and `SetRowView`. Task 2.3 changes all of them in one commit so the target compiles. Tasks 2.1–2.2 are purely additive and land first so the pivot is smaller.

3. **`.setRPE` focus target is being deleted.** It appears in `WorkoutField`, `WorkoutFocusNavigator`, `SetRowView`, `WorkoutSessionView`, and `WorkoutFocusNavigatorTests`. New focus order is weight → reps → next set's weight.

4. **UI tests that assert the old placeholder commit-on-complete behavior must be deleted, not adapted** — that behavior no longer exists. Tests that typed into `SetRPEField` must use the new chip flow. Specifics in Task 4.2.

5. **Adding new Swift files:** this project uses XcodeGen with path-globbed sources (`project.yml` → `sources: - path: LiftingLog` / `LiftingLogTests`). After creating any new `.swift` file, run `xcodegen generate` to regenerate `LiftingLog.xcodeproj`. (The committed pbxproj is old-style; `xcodegen generate` is the reliable registration path. If the regenerated diff is unexpectedly large/noisy, fall back to manually registering the file in PBXBuildFile, PBXFileReference, the group children list, and the Sources build phase.)

6. **CLAUDE.md rule:** before editing Convex code, read `convex/_generated/ai/guidelines.md`.

### Commands reference

- Convex unit tests: `pnpm run convex:test` (Vitest). Typecheck: `pnpm run convex:typecheck`.
- Convex deploy to dev: `npx convex dev --once` (push schema + functions without tailing). Run a function: `npx convex run sync:unsetLoggedSetPlaceholders '{}'`.
- iOS build/tests: use the **xcodebuildmcp** skill (scheme `LiftingLog`, an iOS 26 simulator). Unit-test target `LiftingLogTests`, UI-test target `LiftingLogUITests`.
- Per project memory: 5 UI tests fail on `main` on the dev simulator already (`testDeletingCompletedWorkoutRemovesItFromHistory`, both `testExerciseLibrary*`, both `testSettings*`, plus `testActiveWorkoutHistorySeparatesSameNameDifferentEquipment`). Do not treat those as regressions.

---

## File Structure

**New files**
- `LiftingLog/Features/Workout/PreviousSetPerformance.swift` — value type + pure lookup that reuses history machinery to produce per-index previous performance for a logged exercise.
- `LiftingLog/Features/Workout/RPEChipRow.swift` — the chip picker view (`6 · 7 · 8 · 8.5 · 9 · 9.5 · 10` + Clear) hosted in the keyboard toolbar.
- `LiftingLogTests/PreviousSetPerformanceTests.swift` — unit tests for the lookup.

**Modified files**
- `convex/schema.ts` — `loggedSets` table: placeholder fields optional (P1) then removed (P5).
- `convex/sync/validators.ts` — `loggedSetPayloadValidator`: placeholder optional (P1) then removed (P5).
- `convex/sync.ts` — add `unsetLoggedSetPlaceholders` internal mutation (P1).
- `convex/sync.test.ts` — `LoggedSetRecord` type + `loggedSetRecord()` fixture + two assertions: drop placeholder fields (P5).
- `LiftingLog/Core/Models/LoggedSet.swift` — remove 3 stored props + init params/assignments (P2).
- `LiftingLog/Core/Sync/SyncPayloads.swift` — `LoggedSetSyncPayload`, `LoggedSetSyncRecord`, `loggedSetPayload(from:)`: remove 3 fields (P2).
- `LiftingLog/Core/Sync/ConvexSyncClient.swift` — `loggedSetRecord(_:)`: remove 3 keys (P2).
- `LiftingLog/Core/Sync/SyncCoordinator.swift` — `LoggedSet(...)` init + `apply(_:to:loggedExercise:)`: remove 3 lines each (P2).
- `LiftingLog/Features/Workout/ActiveWorkoutEngine.swift` — drop placeholder usage; add `fillSetFromPrevious` (P2/P3).
- `LiftingLog/Features/Workout/SetRowView.swift` — remove RPE column + suppression hack + rpe draft; add Previous column + RPE badge (P3).
- `LiftingLog/Features/Workout/ExerciseCardView.swift` — header columns + pass previous data + RPE-edit callback (P3).
- `LiftingLog/Features/Workout/WorkoutSessionView.swift` — `WorkoutField` enum, RPE chip toolbar, badge wiring (P3/P4).
- `LiftingLog/Features/Workout/WorkoutFocusNavigator.swift` — drop `.setRPE` from focus order (P4).
- `LiftingLogTests/SyncPayloadMappingTests.swift`, `LiftingLogTests/ConvexSyncArgumentMapperTests.swift`, `LiftingLogTests/WorkoutFocusNavigatorTests.swift` — drop placeholder/RPE expectations (P2/P4).
- `LiftingLogUITests/LiftingLogUITests.swift` — delete placeholder-commit tests, rework RPE entry helpers (P4).

---

## Phase 1 — Convex: make placeholder fields optional + migrate existing docs (non-destructive)

### Task 1.1: Make placeholder fields optional in schema and validator

**Files:**
- Modify: `convex/schema.ts:118-120`
- Modify: `convex/sync/validators.ts:80-82`

- [ ] **Step 1: Read the Convex guidelines**

Run: open and read `convex/_generated/ai/guidelines.md` (CLAUDE.md requires this before Convex edits). Note the schema rules and that `ctx.db.patch` shallow-merges (setting a field to `undefined` removes it).

- [ ] **Step 2: Make schema fields optional**

In `convex/schema.ts`, the `loggedSets` table currently has (lines 118-120):

```ts
    placeholderWeight: nullableNumber,
    placeholderReps: nullableNumber,
    placeholderRPE: nullableNumber,
```

Replace with:

```ts
    placeholderWeight: v.optional(nullableNumber),
    placeholderReps: v.optional(nullableNumber),
    placeholderRPE: v.optional(nullableNumber),
```

- [ ] **Step 3: Make validator fields optional**

In `convex/sync/validators.ts`, `loggedSetPayloadValidator` currently has (lines 80-82):

```ts
  placeholderWeight: nullableNumber,
  placeholderReps: nullableNumber,
  placeholderRPE: nullableNumber,
```

Replace with:

```ts
  placeholderWeight: v.optional(nullableNumber),
  placeholderReps: v.optional(nullableNumber),
  placeholderRPE: v.optional(nullableNumber),
```

- [ ] **Step 4: Typecheck and run existing Convex tests (must still pass)**

Run: `pnpm run convex:typecheck && pnpm run convex:test`
Expected: PASS. The existing `loggedSetRecord()` fixture still sends `placeholderWeight: null` etc., which remains valid against an optional field.

- [ ] **Step 5: Commit**

```bash
git add convex/schema.ts convex/sync/validators.ts
git commit -m "Make loggedSets placeholder fields optional (migration step 1)"
```

### Task 1.2: Add and run the unset migration mutation

**Files:**
- Modify: `convex/sync.ts` (add new export near the other `internalMutation`s, ~line 1080)

- [ ] **Step 1: Add the internal mutation**

In `convex/sync.ts`, after the existing `clearAccountDeletion` export (ends ~line 1106), add:

```ts
// One-shot migration: strip the deprecated placeholder* fields from every
// loggedSets document so the columns can be removed from the schema entirely.
// Run with: npx convex run sync:unsetLoggedSetPlaceholders '{}'
export const unsetLoggedSetPlaceholders = internalMutation({
  args: {},
  handler: async (ctx) => {
    const sets = await ctx.db.query("loggedSets").collect();
    let cleared = 0;
    for (const set of sets) {
      const doc = set as Record<string, unknown>;
      if (
        doc.placeholderWeight !== undefined ||
        doc.placeholderReps !== undefined ||
        doc.placeholderRPE !== undefined
      ) {
        await ctx.db.patch(set._id, {
          placeholderWeight: undefined,
          placeholderReps: undefined,
          placeholderRPE: undefined,
        });
        cleared += 1;
      }
    }
    return { scanned: sets.length, cleared };
  },
});
```

- [ ] **Step 2: Add a Convex test proving the migration clears the fields**

In `convex/sync.test.ts`, add a new `describe` block at the end of the file (before the final closing of the file). Use the existing `testDb()` helper and `internal` API (mirror how other internal mutations are invoked in this file — search for `t.mutation(internal.sync.` to copy the exact call shape; if internal mutations are invoked elsewhere, follow that pattern):

```ts
describe("unsetLoggedSetPlaceholders migration", () => {
  test("removes placeholder fields from existing loggedSets", async () => {
    const t = testDb();
    const id = await t.run(async (ctx) => {
      return await ctx.db.insert("loggedSets", {
        ownerTokenIdentifier: "owner-1",
        clientId: "logged-set-mig",
        loggedExerciseClientId: "logged-exercise-1",
        orderIndex: 0,
        weight: 135,
        reps: 10,
        rpe: 8,
        placeholderWeight: 180,
        placeholderReps: 5,
        placeholderRPE: 8,
        kindRaw: "working",
        isCompleted: true,
        completedAt: 2,
        notes: "",
        healthLinkID: null,
        createdAt: 1,
        updatedAt: 2,
        deletedAt: null,
        serverUpdatedAt: 3,
      });
    });

    const result = await t.mutation(internal.sync.unsetLoggedSetPlaceholders, {});
    expect(result.cleared).toBe(1);

    const doc = await t.run(async (ctx) => ctx.db.get(id));
    expect(doc?.placeholderWeight).toBeUndefined();
    expect(doc?.placeholderReps).toBeUndefined();
    expect(doc?.placeholderRPE).toBeUndefined();
    expect(doc?.weight).toBe(135);
  });
});
```

Note: confirm `internal` is imported at the top of `sync.test.ts`; if not, add `import { api, internal } from "./_generated/api";` (match the existing import style — the file already imports `api`).

- [ ] **Step 3: Run the test to verify it passes**

Run: `pnpm run convex:test`
Expected: PASS, including the new migration test.

- [ ] **Step 4: Deploy and run the migration against the real dev deployment**

Run: `npx convex dev --once` (pushes the optional schema + the new mutation)
Then: `npx convex run sync:unsetLoggedSetPlaceholders '{}'`
Expected: prints `{ scanned: <n>, cleared: <m> }`. Run it a second time; `cleared` should be `0` (idempotent), proving all live docs are migrated.

- [ ] **Step 5: Commit**

```bash
git add convex/sync.ts convex/sync.test.ts
git commit -m "Add and run unsetLoggedSetPlaceholders migration (migration step 2)"
```

---

## Phase 2 — iOS: add the Previous lookup, then remove placeholder fields

### Task 2.1: Add the Previous-performance lookup (pure, TDD)

**Files:**
- Create: `LiftingLog/Features/Workout/PreviousSetPerformance.swift`
- Create: `LiftingLogTests/PreviousSetPerformanceTests.swift`

- [ ] **Step 1: Write the failing test**

Create `LiftingLogTests/PreviousSetPerformanceTests.swift`:

```swift
import SwiftData
import XCTest
@testable import LiftingLog

@MainActor
final class PreviousSetPerformanceTests: XCTestCase {
    func testReturnsLastCompletedSessionSetsByIndex() throws {
        let container = try SwiftDataTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Bench Press", category: .strength, equipment: .barbell, primaryMuscle: .chest)
        context.insert(exercise)

        // Older completed session: 135x10, 145x8
        insertCompletedSession(
            startedAt: Date(timeIntervalSince1970: 100),
            exercise: exercise,
            sets: [(135, 10), (145, 8)],
            in: context
        )
        // More recent completed session: 155x6, 160x5, 165x3 — this is the one we expect
        insertCompletedSession(
            startedAt: Date(timeIntervalSince1970: 200),
            exercise: exercise,
            sets: [(155, 6), (160, 5), (165, 3)],
            in: context
        )

        // Active session referencing the same exercise (must be ignored)
        let active = WorkoutSession(title: "Today", startedAt: Date(timeIntervalSince1970: 300), status: .active, source: .blank)
        let activeLogged = LoggedExercise(orderIndex: 0, exercise: exercise)
        activeLogged.session = active
        context.insert(active)
        context.insert(activeLogged)
        try context.save()

        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
        let previous = PreviousSetPerformance.lastCompletedSets(
            for: activeLogged,
            in: sessions,
            ownerTokenIdentifier: nil
        )

        XCTAssertEqual(previous.count, 3)
        XCTAssertEqual(previous[0], PreviousSetPerformance(weight: 155, reps: 6))
        XCTAssertEqual(previous[1], PreviousSetPerformance(weight: 160, reps: 5))
        XCTAssertEqual(previous[2], PreviousSetPerformance(weight: 165, reps: 3))
    }

    func testReturnsEmptyWhenNoHistory() throws {
        let container = try SwiftDataTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Squat", category: .strength, equipment: .barbell, primaryMuscle: .quads)
        context.insert(exercise)
        let active = WorkoutSession(title: "Today", startedAt: .now, status: .active, source: .blank)
        let logged = LoggedExercise(orderIndex: 0, exercise: exercise)
        logged.session = active
        context.insert(active)
        context.insert(logged)
        try context.save()

        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
        XCTAssertTrue(
            PreviousSetPerformance.lastCompletedSets(for: logged, in: sessions, ownerTokenIdentifier: nil).isEmpty
        )
    }

    /// Inserts a completed session with one logged exercise and the given (weightLbs, reps) sets, all marked completed.
    private func insertCompletedSession(
        startedAt: Date,
        exercise: Exercise,
        sets: [(Double, Int)],
        in context: ModelContext
    ) {
        let session = WorkoutSession(title: "Past", startedAt: startedAt, status: .completed, source: .blank)
        let logged = LoggedExercise(orderIndex: 0, exercise: exercise)
        logged.session = session
        context.insert(session)
        context.insert(logged)
        for (index, pair) in sets.enumerated() {
            let set = LoggedSet(orderIndex: index, weight: pair.0, reps: pair.1, kind: .working, isCompleted: true, completedAt: startedAt)
            set.loggedExercise = logged
            logged.sets.append(set)
            context.insert(set)
        }
        try? context.save()
    }
}
```

Note: verify the `Exercise(...)` and `LoggedSet(...)` initializer argument labels against the real models before running (open `LiftingLog/Core/Models/Exercise.swift` and `LoggedSet.swift`; `LoggedSet` init is `init(id:orderIndex:weight:reps:rpe:...kind:isCompleted:completedAt:...)`). Adjust the `Exercise` init call to match its actual signature.

- [ ] **Step 2: Run the test to verify it fails**

Run via xcodebuildmcp: build-and-test `LiftingLogTests` filtered to `PreviousSetPerformanceTests`.
Expected: FAIL to compile — `PreviousSetPerformance` does not exist yet.

- [ ] **Step 3: Implement the lookup**

Create `LiftingLog/Features/Workout/PreviousSetPerformance.swift`:

```swift
import Foundation

/// A single set's performance from the exercise's last completed session,
/// used to populate the read-only "Previous" column. Weight is canonical pounds.
struct PreviousSetPerformance: Equatable {
    let weight: Double?
    let reps: Int?

    /// Most recent completed session's sets for the given logged exercise's identity,
    /// ordered by set index. Index `i` corresponds to the current row's set index `i`;
    /// indices beyond this array have no previous value (render "—").
    ///
    /// Reuses the History feature's matching + recency logic. `visibleCompletedSessions`
    /// excludes the active session (it is not `.completed`), so the in-progress workout
    /// never matches itself.
    static func lastCompletedSets(
        for loggedExercise: LoggedExercise,
        in sessions: [WorkoutSession],
        ownerTokenIdentifier: String?
    ) -> [PreviousSetPerformance] {
        let route = ExerciseHistoryRoute(loggedExercise: loggedExercise)
        let summaries = ExerciseHistorySummary.makeSummaries(
            from: sessions,
            ownerTokenIdentifier: ownerTokenIdentifier
        )
        guard let summary = ExerciseHistorySummary.find(in: summaries, matching: route) else {
            return []
        }
        guard let group = ExerciseHistorySessionGroup.recentGroups(
            from: sessions,
            matching: summary,
            ownerTokenIdentifier: ownerTokenIdentifier,
            limit: 1
        ).first else {
            return []
        }
        guard let entry = group.loggedExerciseEntries.first else { return [] }
        return entry.setEntries.map { PreviousSetPerformance(weight: $0.set.weight, reps: $0.set.reps) }
    }
}
```

- [ ] **Step 4: Register the new files and run the test**

Run: `xcodegen generate`
Then build-and-test `LiftingLogTests` filtered to `PreviousSetPerformanceTests`.
Expected: PASS (both tests).

- [ ] **Step 5: Commit**

```bash
git add LiftingLog/Features/Workout/PreviousSetPerformance.swift LiftingLogTests/PreviousSetPerformanceTests.swift LiftingLog.xcodeproj
git commit -m "Add PreviousSetPerformance lookup reusing history machinery (#61)"
```

### Task 2.2: Add `fillSetFromPrevious` to the engine (TDD)

**Files:**
- Modify: `LiftingLog/Features/Workout/ActiveWorkoutEngine.swift`
- Modify: `LiftingLogTests/ActiveWorkoutEngineTests.swift`

- [ ] **Step 1: Write the failing test**

Append to `LiftingLogTests/ActiveWorkoutEngineTests.swift` (inside the class):

```swift
    func testFillSetFromPreviousOnlyFillsEmptyFields() throws {
        let container = try SwiftDataTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let engine = ActiveWorkoutEngine()
        let session = try engine.startBlankWorkout(context: context)
        let exercise = Exercise(name: "Row", category: .strength, equipment: .barbell, primaryMuscle: .back)
        context.insert(exercise)
        let logged = try engine.addExercise(exercise, to: session, context: context)
        let set = logged.sortedSets[0]

        // reps already typed; weight empty
        try engine.updateSet(set, weight: nil, reps: 8, rpe: nil, context: context)

        try engine.fillSetFromPrevious(set, previous: PreviousSetPerformance(weight: 185, reps: 5), context: context)

        XCTAssertEqual(set.weight, 185) // filled (was empty)
        XCTAssertEqual(set.reps, 8)     // preserved (was already set)
    }
```

(Adjust the `Exercise(...)` init call to the real signature.)

- [ ] **Step 2: Run the test to verify it fails**

Run: build-and-test filtered to `ActiveWorkoutEngineTests/testFillSetFromPreviousOnlyFillsEmptyFields`.
Expected: FAIL to compile — `fillSetFromPrevious` does not exist.

- [ ] **Step 3: Implement the engine method**

In `ActiveWorkoutEngine.swift`, add this method (place it next to `updateSet`, ~line 228):

```swift
    /// Fills only the currently-empty weight/reps fields of `set` from the previous
    /// session's same-index performance. Used by tapping the "Previous" cell or tapping
    /// ✓ on an otherwise-empty row.
    func fillSetFromPrevious(_ set: LoggedSet, previous: PreviousSetPerformance, context: ModelContext) throws {
        var didChange = false
        if set.weight == nil, let weight = previous.weight {
            set.weight = weight
            didChange = true
        }
        if set.reps == nil, let reps = previous.reps {
            set.reps = reps
            didChange = true
        }
        guard didChange else { return }
        set.touch()
        try context.save()
    }
```

- [ ] **Step 4: Run the test to verify it passes**

Run: build-and-test filtered to the new test.
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add LiftingLog/Features/Workout/ActiveWorkoutEngine.swift LiftingLogTests/ActiveWorkoutEngineTests.swift
git commit -m "Add ActiveWorkoutEngine.fillSetFromPrevious (#61)"
```

### Task 2.3: Remove placeholder fields from the model, sync layer, and engine (the pivot)

This is one commit because deleting the model fields breaks every referencing file. After this task the project compiles with `placeholder*` gone everywhere except the not-yet-removed UI column work (handled in Phase 3, which this task leaves in a compiling intermediate state by removing placeholder references from `SetRowView`'s helpers too — see Step 6).

**Files:**
- Modify: `LiftingLog/Core/Models/LoggedSet.swift`
- Modify: `LiftingLog/Core/Sync/SyncPayloads.swift`
- Modify: `LiftingLog/Core/Sync/ConvexSyncClient.swift`
- Modify: `LiftingLog/Core/Sync/SyncCoordinator.swift`
- Modify: `LiftingLog/Features/Workout/ActiveWorkoutEngine.swift`
- Modify: `LiftingLog/Features/Workout/SetRowView.swift`
- Modify: `LiftingLogTests/SyncPayloadMappingTests.swift`
- Modify: `LiftingLogTests/ConvexSyncArgumentMapperTests.swift`

- [ ] **Step 1: Remove fields from `LoggedSet`**

In `LiftingLog/Core/Models/LoggedSet.swift`:
- Delete the three stored properties (lines 11-13):
  ```swift
      var placeholderWeight: Double?
      var placeholderReps: Int?
      var placeholderRPE: Double?
  ```
- Delete the three init parameters (lines 30-32):
  ```swift
          placeholderWeight: Double? = nil,
          placeholderReps: Int? = nil,
          placeholderRPE: Double? = nil,
  ```
- Delete the three assignments (lines 47-49):
  ```swift
          self.placeholderWeight = placeholderWeight
          self.placeholderReps = placeholderReps
          self.placeholderRPE = placeholderRPE
  ```

(SwiftData note: removing stored properties from a model is a lightweight local migration; the on-device store drops the columns automatically. No `VersionedSchema` change is required for this project's setup.)

- [ ] **Step 2: Remove fields from `SyncPayloads.swift`**

- In `LoggedSetSyncPayload` delete lines 72-74:
  ```swift
      let placeholderWeight: Double?
      let placeholderReps: Int?
      let placeholderRPE: Double?
  ```
- In `loggedSetPayload(from:)` delete lines 161-163:
  ```swift
              placeholderWeight: set.placeholderWeight,
              placeholderReps: set.placeholderReps,
              placeholderRPE: set.placeholderRPE,
  ```
- In `LoggedSetSyncRecord` delete lines 263-265:
  ```swift
      let placeholderWeight: Double?
      let placeholderReps: Int?
      let placeholderRPE: Double?
  ```

- [ ] **Step 3: Remove keys from `ConvexSyncClient.loggedSetRecord(_:)`**

Delete lines 192-194:
```swift
            "placeholderWeight": record.placeholderWeight,
            "placeholderReps": record.placeholderReps.map(Double.init),
            "placeholderRPE": record.placeholderRPE,
```

- [ ] **Step 4: Remove placeholder handling in `SyncCoordinator.swift`**

- In the `LoggedSet(...)` construction (lines 1200-1202) delete:
  ```swift
                  placeholderWeight: record.placeholderWeight,
                  placeholderReps: record.placeholderReps,
                  placeholderRPE: record.placeholderRPE,
  ```
- In `apply(_:to:loggedExercise:)` (lines 1226-1228) delete:
  ```swift
          set.placeholderWeight = record.placeholderWeight
          set.placeholderReps = record.placeholderReps
          set.placeholderRPE = record.placeholderRPE
  ```

- [ ] **Step 5: Remove placeholder logic from `ActiveWorkoutEngine.swift`**

- In `startWorkout(fromPast:...)`, the cloned set no longer copies numbers (issue: "Cloning then copies *structure*, not numbers"). Change the `LoggedSet(...)` at lines 107-116 from:
  ```swift
                  let set = LoggedSet(
                      orderIndex: pastSet.orderIndex,
                      placeholderWeight: pastSet.weight,
                      placeholderReps: pastSet.reps,
                      placeholderRPE: pastSet.rpe,
                      kind: pastSet.kind,
                      isCompleted: false,
                      createdAt: now,
                      updatedAt: now
                  )
  ```
  to:
  ```swift
                  let set = LoggedSet(
                      orderIndex: pastSet.orderIndex,
                      kind: pastSet.kind,
                      isCompleted: false,
                      createdAt: now,
                      updatedAt: now
                  )
  ```
- In `addSet(to:context:)` (lines 196-203), change from:
  ```swift
          let set = LoggedSet(
              orderIndex: (sortedSets.map(\.orderIndex).max() ?? -1) + 1,
              placeholderWeight: previous?.weight ?? previous?.placeholderWeight,
              placeholderReps: previous?.reps ?? previous?.placeholderReps,
              placeholderRPE: previous?.rpe ?? previous?.placeholderRPE,
              kind: previous?.kind ?? .working,
              isCompleted: false
          )
  ```
  to:
  ```swift
          let set = LoggedSet(
              orderIndex: (sortedSets.map(\.orderIndex).max() ?? -1) + 1,
              kind: previous?.kind ?? .working,
              isCompleted: false
          )
  ```
  (The local `let previous = sortedSets.last` is still used for `kind`; keep it.)
- In `toggleSetCompletion(_:context:now:)` (lines 230-240), remove the placeholder fill on completion. Delete lines 232-234:
  ```swift
          let willComplete = !set.isCompleted
          if willComplete {
              applyPlaceholderValuesIfNeeded(to: set)
          }
  ```
  Replace with just (keep the toggle):
  ```swift
          set.isCompleted.toggle()
  ```
  (Delete the now-unused `willComplete`.)
- Delete the entire `applyPlaceholderValuesIfNeeded(to:)` method (lines 367-379).

- [ ] **Step 6: Make `SetRowView` compile without placeholders (interim)**

Phase 3 fully rewrites this view; this step only removes the now-broken `placeholder*` references so the project compiles after the pivot. In `SetRowView.swift`:
- `weightPlaceholder` (lines 135-138): replace body with `weightUnit.fieldPlaceholder`:
  ```swift
      private var weightPlaceholder: String {
          weightUnit.fieldPlaceholder
      }
  ```
- `repsPlaceholder` (lines 149-151): replace with:
  ```swift
      private var repsPlaceholder: String {
          "REPS"
      }
  ```
- `rpePlaceholder` (lines 168-170): replace with:
  ```swift
      private var rpePlaceholder: String {
          "RPE"
      }
  ```
- `suppressNextCompletionClearIfNeeded()` (lines 180-198): replace its body so it no longer reads `placeholder*`. Since the whole suppression mechanic is being deleted in Phase 3, simplify now to a no-op:
  ```swift
      private func suppressNextCompletionClearIfNeeded() {}
  ```
  (Leave the call site at line 59 for now; Phase 3 removes it.)

- [ ] **Step 7: Update unit-test fixtures that reference placeholders**

- `LiftingLogTests/SyncPayloadMappingTests.swift`: remove the `placeholderWeight/Reps/RPE` arguments where a `LoggedSet`/payload is constructed (lines ~175-177, ~216) and delete the three assertions at lines 197-199 (`XCTAssertEqual(payload.placeholder...)`). Read the surrounding test to keep it meaningful (it should still assert weight/reps/rpe map correctly).
- `LiftingLogTests/ConvexSyncArgumentMapperTests.swift`: remove the `placeholderWeight/Reps/RPE` arguments at lines 120-122 and any assertion that reads them.

- [ ] **Step 8: Build and run the full unit-test suite**

Run: `xcodegen generate` (no new files, but harmless) then build-and-test `LiftingLogTests` (all).
Expected: PASS. Pay attention to `SyncPayloadMappingTests`, `ConvexSyncArgumentMapperTests`, `ActiveWorkoutEngineTests`, `PreviousSetPerformanceTests`.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "Remove placeholder* fields from model, sync layer, and engine (#61)"
```

---

## Phase 3 — iOS: set-row redesign (Previous column + RPE removal + badge)

### Task 3.1: Rewrite `SetRowView` — Previous column, no RPE field, RPE badge

**Files:**
- Modify: `LiftingLog/Features/Workout/SetRowView.swift`

- [ ] **Step 1: Replace the view with the new layout**

Replace the entire contents of `LiftingLog/Features/Workout/SetRowView.swift` with:

```swift
import SwiftData
import SwiftUI

struct SetRowView: View {
    @Environment(\.modelContext) private var modelContext
    let set: LoggedSet
    let exerciseIndex: Int
    let index: Int
    @Bindable var engine: ActiveWorkoutEngine
    var focusedField: FocusState<WorkoutField?>.Binding
    let weightUnit: MeasurementUnit
    /// Previous session's performance for this set index, if any.
    let previous: PreviousSetPerformance?
    /// Called when the RPE badge (or its empty affordance) is tapped, to open the chip picker for this set.
    let onEditRPE: (LoggedSet) -> Void
    @State private var weightInputText = WorkoutNumberInputText()

    var body: some View {
        SwipeToDeleteRow(
            deleteAccessibilityLabel: "Remove set",
            deleteAccessibilityIdentifier: "DeleteSetButton-\(exerciseIndex)-\(index)"
        ) {
            try? engine.removeSet(set, context: modelContext)
        } content: {
            rowContent
        }
    }

    private var rowContent: some View {
        HStack(spacing: 10) {
            Text("\(index + 1)")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(AppTheme.textTertiary)
                .frame(width: 18)

            previousColumn

            numericField(
                placeholder: weightUnit.fieldPlaceholder,
                text: weightBinding,
                keyboard: .decimalPad,
                focusTarget: .setWeight(set.id),
                accessibilityIdentifier: "SetWeightField-\(exerciseIndex)-\(index)"
            )

            repsField

            Button {
                completeButtonTapped()
            } label: {
                Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(set.isCompleted ? AppTheme.accentBright : AppTheme.textTertiary)
                    .symbolEffect(.bounce, value: set.isCompleted)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(set.isCompleted ? "Mark set incomplete" : "Mark set complete")
            .accessibilityIdentifier("SetCompletionButton-\(exerciseIndex)-\(index)")
        }
        .onChange(of: focusedField.wrappedValue) { previousField, newField in
            if previousField == .setWeight(set.id), newField != .setWeight(set.id) {
                weightInputText.endEditing()
            }
        }
    }

    // MARK: Previous column

    private var previousColumn: some View {
        Button {
            guard let previous, !set.isCompleted else { return }
            try? engine.fillSetFromPrevious(set, previous: previous, context: modelContext)
        } label: {
            Text(previousText)
                .font(.footnote.weight(.medium).monospacedDigit())
                .foregroundStyle(AppTheme.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(previous == nil || set.isCompleted)
        .accessibilityIdentifier("SetPreviousValue-\(exerciseIndex)-\(index)")
        .accessibilityLabel(previous == nil ? "No previous set" : "Previous: \(previousText)")
    }

    private var previousText: String {
        guard let previous else { return "—" }
        let weight = weightUnit.displayWeight(fromCanonicalPounds: previous.weight).map(WorkoutFormatters.number)
        guard let weight, let reps = previous.reps else { return "—" }
        return "\(weight) × \(reps)"
    }

    // MARK: Reps field with RPE badge

    private var repsField: some View {
        numericField(
            placeholder: "REPS",
            text: repsBinding,
            keyboard: .numberPad,
            focusTarget: .setReps(set.id),
            accessibilityIdentifier: "SetRepsField-\(exerciseIndex)-\(index)"
        )
        .overlay(alignment: .topTrailing) {
            rpeBadge
        }
    }

    @ViewBuilder
    private var rpeBadge: some View {
        if let rpe = set.rpe {
            Button {
                onEditRPE(set)
            } label: {
                Text("@\(WorkoutFormatters.number(rpe))")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppTheme.accentBright)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(AppTheme.accentMuted, in: Capsule())
                    .offset(x: -4, y: 4)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("SetRPEBadge-\(exerciseIndex)-\(index)")
            .accessibilityLabel("RPE \(WorkoutFormatters.number(rpe)), tap to edit")
        }
    }

    // MARK: Shared numeric field

    private func numericField(
        placeholder: String,
        text: Binding<String>,
        keyboard: UIKeyboardType,
        focusTarget: WorkoutField,
        accessibilityIdentifier: String
    ) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(keyboard)
            .multilineTextAlignment(.center)
            .font(.body.weight(.semibold))
            .fontDesign(.rounded)
            .foregroundStyle(AppTheme.textPrimary)
            .focused(focusedField, equals: focusTarget)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                AppTheme.fieldFill,
                in: RoundedRectangle(cornerRadius: AppTheme.fieldCornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.fieldCornerRadius, style: .continuous)
                    .strokeBorder(
                        focusedField.wrappedValue == focusTarget ? AppTheme.accentBright.opacity(0.7) : .clear,
                        lineWidth: 1.5
                    )
            )
            .animation(.easeOut(duration: 0.15), value: focusedField.wrappedValue == focusTarget)
            .accessibilityIdentifier(accessibilityIdentifier)
            .id(focusTarget)
    }

    private var weightBinding: Binding<String> {
        Binding(
            get: { weightInputText.displayText(for: weightUnit.displayWeight(fromCanonicalPounds: set.weight)) },
            set: { value in
                weightInputText.updateDraft(value)
                let displayWeight = WorkoutFormatters.parseNumber(value)
                let canonicalWeight = weightUnit.canonicalWeight(fromDisplayWeight: displayWeight)
                try? engine.updateSet(set, weight: canonicalWeight, reps: set.reps, rpe: set.rpe, context: modelContext)
            }
        )
    }

    private var repsBinding: Binding<String> {
        Binding(
            get: { set.reps.map(String.init) ?? "" },
            set: { value in
                try? engine.updateSet(set, weight: set.weight, reps: Int(value), rpe: set.rpe, context: modelContext)
            }
        )
    }

    private func completeButtonTapped() {
        clearFocusedFieldForThisSet()
        // Tapping ✓ on an empty row fills it from the previous session first.
        if !set.isCompleted, set.weight == nil, set.reps == nil, let previous {
            try? engine.fillSetFromPrevious(set, previous: previous, context: modelContext)
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            try? engine.toggleSetCompletion(set, context: modelContext)
        }
    }

    private func clearFocusedFieldForThisSet() {
        if focusedField.wrappedValue == .setWeight(set.id)
            || focusedField.wrappedValue == .setReps(set.id) {
            focusedField.wrappedValue = nil
        }
    }
}

struct WorkoutNumberInputText {
    private var draft: String?

    mutating func updateDraft(_ value: String) {
        draft = value
    }

    mutating func endEditing() {
        draft = nil
    }

    func displayText(for value: Double?) -> String {
        draft ?? value.map(WorkoutFormatters.number) ?? ""
    }
}
```

(This removes the RPE `numericField`, the `rpeInputText`, the `suppressedCompletionClearField` mechanic, `shouldSuppressDecimalClear`, and `suppressNextCompletionClearIfNeeded`. `WorkoutNumberInputText` stays for the weight draft.)

- [ ] **Step 2: It won't compile yet** — `SetRowView` now requires `previous:` and `onEditRPE:`, and `WorkoutField.setRPE` is still referenced elsewhere. These are fixed in Tasks 3.2 and 4.1. Proceed to Task 3.2 before building.

### Task 3.2: Update `ExerciseCardView` — header columns + pass previous data + RPE callback

**Files:**
- Modify: `LiftingLog/Features/Workout/ExerciseCardView.swift`

- [ ] **Step 1: Add a sessions query and the previous lookup**

In `ExerciseCardView`, add alongside the existing `@Query` (after line 14):

```swift
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
```

Add a property that passes the RPE-edit intent up to the parent. Add to the struct's stored properties (near `viewHistory`, line 12):

```swift
    let onEditRPE: (LoggedSet) -> Void
```

Add a computed property for the previous performance array (after `weightUnit`, ~line 21):

```swift
    private var previousSets: [PreviousSetPerformance] {
        PreviousSetPerformance.lastCompletedSets(
            for: loggedExercise,
            in: sessions,
            ownerTokenIdentifier: syncScheduler.currentOwnerTokenIdentifier
        )
    }
```

- [ ] **Step 2: Update the column header row**

Replace the header `HStack` (lines 109-115):

```swift
                        HStack(spacing: 10) {
                            Color.clear.frame(width: 18)
                            columnHeader(weightUnit.fieldLabel)
                            columnHeader("REPS")
                            columnHeader("RPE")
                            Color.clear.frame(width: 44)
                        }
                        .padding(.horizontal, 16)
```

with the new `# | Previous | LBS | REPS | ✓` layout (RPE header removed, Previous added):

```swift
                        HStack(spacing: 10) {
                            Color.clear.frame(width: 18)
                            columnHeader("PREVIOUS")
                            columnHeader(weightUnit.fieldLabel)
                            columnHeader("REPS")
                            Color.clear.frame(width: 44)
                        }
                        .padding(.horizontal, 16)
```

- [ ] **Step 3: Pass `previous` and `onEditRPE` into each `SetRowView`**

Replace the `SetRowView(...)` call (lines 119-128):

```swift
                            ForEach(Array(loggedExercise.sortedSets.enumerated()), id: \.element.id) { index, set in
                                SetRowView(
                                    set: set,
                                    exerciseIndex: exerciseIndex,
                                    index: index,
                                    engine: engine,
                                    focusedField: focusedField,
                                    weightUnit: weightUnit,
                                    previous: index < previousSets.count ? previousSets[index] : nil,
                                    onEditRPE: onEditRPE
                                )
                                    .padding(.horizontal, 16)
                            }
```

- [ ] **Step 2 note:** still won't fully build until Task 4.1 wires `onEditRPE` from `WorkoutSessionView` and removes `.setRPE`. Continue to Phase 4.

---

## Phase 4 — iOS: RPE chip entry, focus order, and test updates

### Task 4.1: RPE chip row + toolbar wiring + drop `.setRPE`

**Files:**
- Create: `LiftingLog/Features/Workout/RPEChipRow.swift`
- Modify: `LiftingLog/Features/Workout/WorkoutSessionView.swift`
- Modify: `LiftingLog/Features/Workout/WorkoutFocusNavigator.swift`

- [ ] **Step 1: Create the chip row view**

Create `LiftingLog/Features/Workout/RPEChipRow.swift`:

```swift
import SwiftUI

struct RPEChipRow: View {
    static let values: [Double] = [6, 7, 8, 8.5, 9, 9.5, 10]
    let selected: Double?
    let onSelect: (Double) -> Void
    let onClear: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Self.values, id: \.self) { value in
                    Button {
                        onSelect(value)
                    } label: {
                        Text(WorkoutFormatters.number(value))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selected == value ? AppTheme.onAccent : AppTheme.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                selected == value ? AnyShapeStyle(AppTheme.accentBright) : AnyShapeStyle(AppTheme.surfaceMuted),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("RPEChip-\(WorkoutFormatters.number(value))")
                }

                Button(role: .destructive, action: onClear) {
                    Text("Clear")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AppTheme.surfaceMuted, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("RPEChipClear")
            }
            .padding(.horizontal, 4)
        }
    }
}
```

Note: confirm `AppTheme.onAccent` exists (per project memory there is a fixed on-accent text color from the recent redesign). If the exact token differs, use the project's on-accent/white text token; grep `AppTheme` for `onAccent`/`accentForeground` and use the real name.

- [ ] **Step 2: Update `WorkoutField` and the focus navigator (drop `.setRPE`)**

In `WorkoutSessionView.swift`:
- Delete `case setRPE(UUID)` from the `WorkoutField` enum (line 10).
- In `isSetField(_:)` (lines 296-303), update the switch so it no longer references `.setRPE`:
  ```swift
      private static func isSetField(_ field: WorkoutField?) -> Bool {
          switch field {
          case .setWeight, .setReps:
              return true
          case .workoutTitle, .workoutNotes, .exerciseNotes, nil:
              return false
          }
      }
  ```

In `WorkoutFocusNavigator.swift`, delete line 16 so the per-set loop no longer appends `.setRPE`:
```swift
                fields.append(.setRPE(set.id))
```
The loop becomes weight then reps only.

- [ ] **Step 3: Add RPE chip state + the badge callback + toolbar integration**

In `WorkoutSessionView`:
- Add state (near line 25): `@State private var rpeEditingSetID: UUID?`
- Pass `onEditRPE` into `ExerciseCardView` (the `ForEach` at lines 47-57). Add the closure:
  ```swift
                          ExerciseCardView(
                              loggedExercise: loggedExercise,
                              exerciseIndex: exerciseIndex,
                              engine: engine,
                              isCollapsed: isCollapsedBinding(for: loggedExercise),
                              focusedField: $focusedField,
                              viewHistory: { selectedHistoryExercise = loggedExercise },
                              onEditRPE: { set in
                                  focusedField = .setReps(set.id)
                                  rpeEditingSetID = set.id
                              }
                          )
                          .id(loggedExercise.id)
  ```
- Replace the keyboard `ToolbarItemGroup` (lines 180-224) so it shows the chip row when `rpeEditingSetID != nil` and a set field is focused; otherwise the normal prev/next + RPE + Done controls. Replace the whole `.toolbar { ToolbarItemGroup(placement: .keyboard) { ... } }` block with:

```swift
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    if rpeEditingSetID != nil {
                        RPEChipRow(
                            selected: editingSet?.rpe,
                            onSelect: { value in
                                if let set = editingSet {
                                    try? engine.updateSet(set, weight: set.weight, reps: set.reps, rpe: value, context: modelContext)
                                }
                                rpeEditingSetID = nil
                                focusedField = nextFocusedField
                            },
                            onClear: {
                                if let set = editingSet {
                                    try? engine.updateSet(set, weight: set.weight, reps: set.reps, rpe: nil, context: modelContext)
                                }
                                rpeEditingSetID = nil
                            }
                        )
                    } else {
                        let previousField = previousFocusedField
                        let nextField = nextFocusedField

                        Button {
                            focusedField = previousField
                        } label: {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .disabled(previousField == nil)
                        .accessibilityLabel("Previous field")
                        .accessibilityIdentifier("PreviousWorkoutFieldButton")

                        Button {
                            focusedField = nextField
                        } label: {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .disabled(nextField == nil)
                        .accessibilityLabel("Next field")
                        .accessibilityIdentifier("NextWorkoutFieldButton")

                        if let focusedSetID {
                            Button("RPE") {
                                rpeEditingSetID = focusedSetID
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .accessibilityIdentifier("RPEToolbarButton")
                        }

                        Spacer()

                        Button("Done") {
                            let scrollTarget = recentlyAddedExerciseID
                            focusedField = nil

                            if let scrollTarget {
                                Task { @MainActor in
                                    try? await Task.sleep(for: .milliseconds(500))
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
                                        scrollProxy.scrollTo(scrollTarget, anchor: .top)
                                    }
                                    self.recentlyAddedExerciseID = nil
                                }
                            }
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .accessibilityIdentifier("DismissKeyboardButton")
                    }
                }
            }
```

- Add helper computed properties (near `focusedSetID` usage; place after `nextFocusedField`, ~line 281):

```swift
    private var focusedSetID: UUID? {
        switch focusedField {
        case .setWeight(let id), .setReps(let id):
            return id
        default:
            return nil
        }
    }

    /// The set currently targeted for RPE editing (from the toolbar button or a badge tap).
    private var editingSet: LoggedSet? {
        guard let rpeEditingSetID else { return nil }
        for loggedExercise in session.sortedLoggedExercises {
            if let match = loggedExercise.sortedSets.first(where: { $0.id == rpeEditingSetID }) {
                return match
            }
        }
        return nil
    }
```

- Clear `rpeEditingSetID` when focus leaves all set fields. In the existing `.onChange(of: focusedField)` (line 158), add at the top of the handler:
  ```swift
                  if Self.isSetField(newField) == false {
                      rpeEditingSetID = nil
                  }
  ```

- [ ] **Step 4: Register the new file and build**

Run: `xcodegen generate`
Then build `LiftingLog` (app target).
Expected: compiles cleanly. If `AppTheme.onAccent` was wrong, fix per Step 1 note.

- [ ] **Step 5: Run all unit tests**

Run: build-and-test `LiftingLogTests` (all) — but first apply Task 4.2's `WorkoutFocusNavigatorTests` edits, since removing `.setRPE` breaks that test file. Do Task 4.2 Step 1, then run.

### Task 4.2: Update unit + UI tests for the new behavior

**Files:**
- Modify: `LiftingLogTests/WorkoutFocusNavigatorTests.swift`
- Modify: `LiftingLogUITests/LiftingLogUITests.swift`

- [ ] **Step 1: Fix `WorkoutFocusNavigatorTests`**

Remove every `.setRPE(...)` entry from the expected focus-order arrays (lines 24, 27, 31, 47, 90, 105) so each set contributes only `.setWeight` then `.setReps`. Update the adjacency tests at lines 54-59 and 116: previously "next after `.setRPE(firstSet)`" was the second set's weight; now "next after `.setReps(firstSet)`" should be `.setWeight(secondSet)`. Rewrite those two assertions to navigate from `.setReps(firstSetID)` instead of `.setRPE(firstSetID)`. Read the full file and adjust each array to the new two-field-per-set shape.

- [ ] **Step 2: Run the focus navigator tests**

Run: build-and-test filtered to `WorkoutFocusNavigatorTests`.
Expected: PASS. Then run the full `LiftingLogTests` suite — expected PASS.

- [ ] **Step 3: Delete obsolete placeholder UI tests**

In `LiftingLogUITests/LiftingLogUITests.swift`, delete these tests and their now-unused private helper:
- `testCompletingClonedSetWhileWeightFieldIsFocusedCommitsPlaceholders` (lines 294-297)
- `testCompletingClonedSetWhileRPEFieldIsFocusedCommitsPlaceholders` (lines 299-302)
- `testClearingCompletedRPERemovesLoggedRPE` (lines 312-318)
- `assertCompletingClonedSetCommitsPlaceholdersAfterFocusing(fieldIdentifier:)` (lines 753-779)

Rationale: commit-on-complete of placeholder values no longer exists (clone copies structure, not numbers), and there is no `SetRPEField` to focus. Keep `testClearingCompletedWeightRemovesLoggedWeight` but see Step 4 (its helper types into the RPE field).

- [ ] **Step 4: Rework RPE entry in UI helpers**

There is no `SetRPEField` text field anymore; RPE is entered via the toolbar chip. Add a helper and update the two helpers that typed RPE:

Add:
```swift
    @MainActor
    private func setRPEViaChips(_ value: String, in app: XCUIApplication) {
        // A set field must be focused (keyboard up) for the RPE toolbar button to appear.
        app.buttons["RPEToolbarButton"].tap()
        app.buttons["RPEChip-\(value)"].tap()
    }
```

- In `fillFirstBenchSet(in:)` (lines 813-821): remove the three RPE lines (819-821). After tapping reps and typing "5", the reps field is focused, so callers that want RPE call `setRPEViaChips("8", in: app)` explicitly. Update `fillFirstBenchSet` to end after reps:
  ```swift
      @MainActor
      private func fillFirstBenchSet(in app: XCUIApplication) {
          app.textFields["SetWeightField-0-0"].tap()
          app.textFields["SetWeightField-0-0"].typeText("185")
          app.textFields["SetRepsField-0-0"].tap()
          app.textFields["SetRepsField-0-0"].typeText("5")
      }
  ```
- In `createCompletedWorkout(...)` (lines 738-743): replace the three `SetRPEField` lines with the chip flow while the reps field is focused:
  ```swift
          app.textFields["SetWeightField-0-0"].tap()
          app.textFields["SetWeightField-0-0"].typeText(weight)
          app.textFields["SetRepsField-0-0"].tap()
          app.textFields["SetRepsField-0-0"].typeText(reps)
          setRPEViaChips(rpe, in: app)
  ```
  Note: `rpe` values passed by callers must be one of the chip values (`6,7,8,8.5,9,9.5,10`). Check call sites of `createCompletedWorkout` and adjust any non-chip RPE argument to a chip value.
- `createCompletedBenchWorkout` calls `fillFirstBenchSet` then completes — it now records no RPE, which is fine (RPE is optional). If a downstream assertion expects `@ 8` in history for that flow, either add `setRPEViaChips("8", in: app)` after `fillFirstBenchSet` or update the expected string. Check `testExerciseHistorySummaryUsesAvailableContentWidth` and similar.

- [ ] **Step 5: Add a UI test for the Previous column**

Add a test verifying the Previous column appears on a cloned workout and fills on tap. Mirror existing patterns (`createCompletedBenchWorkout`, `PastWorkoutButton-0`):

```swift
    @MainActor
    func testPreviousColumnShowsLastSessionAndFillsOnTap() {
        let app = makeApp()
        app.launch()

        createCompletedBenchWorkout(in: app, title: "Prev Source") // logs 185 x 5, completed

        app.buttons["WorkoutTab"].tap()
        XCTAssertTrue(app.buttons["PastWorkoutButton-0"].waitForExistence(timeout: 3))
        app.buttons["PastWorkoutButton-0"].tap()
        XCTAssertTrue(app.textFields["WorkoutTitle"].waitForExistence(timeout: 3))

        // Cloned set starts empty (structure only); Previous shows last time.
        XCTAssertEqual(app.textFields["SetWeightField-0-0"].value as? String, "")
        let previous = app.buttons["SetPreviousValue-0-0"]
        XCTAssertTrue(previous.waitForExistence(timeout: 3))
        XCTAssertEqual(previous.label, "Previous: 185 × 5")

        previous.tap()
        XCTAssertEqual(app.textFields["SetWeightField-0-0"].value as? String, "185")
        XCTAssertEqual(app.textFields["SetRepsField-0-0"].value as? String, "5")
    }
```

(If `createCompletedBenchWorkout`'s exact logged numbers differ, adjust the expected strings. Confirm the `×` glyph matches `previousText` in `SetRowView`.)

- [ ] **Step 6: Run the UI test suite**

Run: build-and-test `LiftingLogUITests`. Per project memory, ignore the 5 known-failing tests on the dev simulator; if `snapshot_ui`/element queries go stale, reboot the simulator and relaunch.
Expected: the new/edited tests pass; no new regressions beyond the known 5.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "Move RPE entry to keyboard chip picker; add Previous column UI (#59, #61)"
```

---

## Phase 5 — Convex: remove placeholder fields entirely

Safe now: every live `loggedSets` doc was migrated in Task 1.2, and the iOS client stopped sending the fields in Task 2.3.

### Task 5.1: Remove fields from schema, validator, and tests

**Files:**
- Modify: `convex/schema.ts:118-120`
- Modify: `convex/sync/validators.ts:80-82`
- Modify: `convex/sync.test.ts` (type at 211-213, fixture at 130-132, assertions at 339-341, 405-407, 1169-1171, 1214-1216)

- [ ] **Step 1: Remove from schema**

In `convex/schema.ts`, delete the three now-optional placeholder lines from the `loggedSets` table (118-120).

- [ ] **Step 2: Remove from validator**

In `convex/sync/validators.ts`, delete the three placeholder lines from `loggedSetPayloadValidator` (80-82).

- [ ] **Step 3: Remove from tests**

In `convex/sync.test.ts`:
- Delete the three fields from the `LoggedSetRecord` type (211-213).
- Delete the three fields from the `loggedSetRecord()` fixture default (130-132).
- Delete the three `placeholder*: null` lines wherever a set record is built inline (339-341, 405-407).
- Delete the three `placeholderWeight: 180` etc. lines at 1169-1171 and 1214-1216. Read those two tests; if they asserted placeholder round-tripping, remove those assertions (the migration test in Task 1.2 already covers removal). The migration test inserts placeholder fields via a raw `ctx.db.insert` with extra keys — once the schema no longer declares them, that insert will be rejected. **Delete the migration test added in Task 1.2** (it has served its purpose and can no longer compile against the trimmed schema), or guard it; simplest is to remove it now.

- [ ] **Step 4: Typecheck and run Convex tests**

Run: `pnpm run convex:typecheck && pnpm run convex:test`
Expected: PASS, with no remaining `placeholder` references. Verify: `grep -rn placeholder convex` returns nothing.

- [ ] **Step 5: Deploy the final schema**

Run: `npx convex dev --once`
Expected: schema push succeeds (no document carries the removed fields). If it fails complaining about existing documents, re-run `npx convex run sync:unsetLoggedSetPlaceholders '{}'` BEFORE this step — but that mutation was removed in Step 3, so if needed, temporarily restore it, run, then remove. (Should not be necessary if Task 1.2 Step 4 reported `cleared: 0` on its second run.)

- [ ] **Step 6: Commit**

```bash
git add convex/schema.ts convex/sync/validators.ts convex/sync.test.ts
git commit -m "Remove placeholder fields from Convex schema and validators (migration step 3, #61)"
```

---

## Phase 6 — Final verification & PR

### Task 6.1: Full-suite verification

- [ ] **Step 1: Convex** — `pnpm run convex:typecheck && pnpm run convex:test` → PASS; `grep -rn placeholder convex` → empty.
- [ ] **Step 2: iOS unit tests** — build-and-test `LiftingLogTests` (all) → PASS.
- [ ] **Step 3: iOS UI tests** — build-and-test `LiftingLogUITests` → only the 5 known-failing tests fail (per memory); no new regressions.
- [ ] **Step 4: Grep for stragglers** — `grep -rn "placeholder\|setRPE\|SetRPEField" LiftingLog LiftingLogTests LiftingLogUITests` returns only intentional matches (none expected for `placeholder*` or `setRPE`).
- [ ] **Step 5: Manual smoke (simulator)** — start a workout from a past session: confirm cloned sets are empty, the Previous column shows last time's `weight × reps`, tapping Previous fills the row, tapping ✓ on an empty row fills then completes, the RPE toolbar button + chips set an `@9` badge on the reps field, and the badge re-opens the chips to edit/clear. Use the **run** or **verify** skill.

### Task 6.2: Open the PR

- [ ] **Step 1: Push the branch**

```bash
git push -u origin previous-column-and-rpe-redesign
```

- [ ] **Step 2: Open the PR closing both issues**

```bash
gh pr create --title "Previous column + RPE entry redesign" --body "$(cat <<'EOF'
Replaces the ghost-placeholder mechanic with a read-only Previous column sourced from each exercise's last completed session, and moves RPE entry to a keyboard-toolbar chip picker surfaced as an @9 badge on the reps field.

Set row layout is now: # | Previous | LBS | REPS | ✓.

Backend: the placeholder* fields were removed from the Convex schema/validators via a non-destructive migration (optional → unset existing docs → drop) and from the iOS model, sync payloads, and both unit-conversion paths.

Closes #59
Closes #61

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

## Self-review notes (verification of this plan against the specs)

- **#61 Previous column** — Task 2.1 (lookup) + 3.1/3.2 (UI) + the fill-on-tap and fill-on-empty-complete behaviors (2.2 + 3.1 `completeButtonTapped`). Row layout `# | Previous | LBS | REPS | ✓` in 3.1/3.2. ✓
- **#61 ghost-placeholder + machinery deletion** — `placeholder*` removed from `LoggedSet`, `SyncPayloads`, `ConvexSyncClient`, `SyncCoordinator`, Convex schema/validators (Tasks 2.3 + P1/P5); `WorkoutNumberInputText` retained for weight (still needed for decimal drafts) but the completion-suppression hack (`suppressedCompletionClearField`, `shouldSuppressDecimalClear`, `suppressNextCompletionClearIfNeeded`) is removed in 3.1. ✓
- **#61 cloning copies structure not numbers** — Task 2.3 Step 5 (`startWorkout(fromPast:)`). ✓
- **#61 Convex cleanup + migration caveat** — Phases 1 and 5 implement the optional → unset → drop sequence; non-destructive per the chosen strategy. ✓
- **#59 RPE column removed, moved to toolbar chips** — Tasks 3.1 (no RPE field), 3.2 (no RPE header), 4.1 (chip row + toolbar). ✓
- **#59 badge on reps field, tap to edit/clear, covers post-completion** — 3.1 `rpeBadge` + `onEditRPE`; 4.1 wires badge tap to focus reps + open chips; chip `onClear` clears. ✓
- **#59 RPE stays `Double?`, chips at 0.5 increments, no free-text** — `RPEChipRow.values` + `engine.updateSet(rpe:)`; free-text path gone with the RPE field. ✓
- **#59 no changes to the focus system for entry** — focus order keeps weight→reps; `.setRPE` removed (4.1) but the navigator/adjacency mechanism is otherwise unchanged. ✓
- **Type consistency** — `PreviousSetPerformance(weight:reps:)` used identically in the lookup, engine, tests, and view; `fillSetFromPrevious` signature consistent across 2.2/3.1; `onEditRPE: (LoggedSet) -> Void` consistent across `SetRowView`/`ExerciseCardView`/`WorkoutSessionView`. ✓
- **Open verification items for the implementer** (flagged inline, not placeholders): confirm the real `Exercise(...)` init signature for the new tests; confirm the `AppTheme` on-accent token name in `RPEChipRow`; confirm `createCompletedBenchWorkout`'s logged numbers for the new UI test's expected strings; confirm how internal mutations are invoked in `sync.test.ts`.
