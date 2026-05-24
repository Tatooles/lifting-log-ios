# Cloned Workout Placeholders Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cloned workouts show prior weight and reps as placeholders while keeping today's actual set values blank until the user edits or confirms them.

**Architecture:** Store previous-session reference values as optional metadata on `LoggedSet`, separate from actual `weight`, `reps`, and `rpe`. The clone flow writes placeholder metadata and blank actual values; the set row displays placeholder metadata; the completion path copies placeholder weight/reps into blank actual fields only when a set is checked complete.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, XCTest, Xcode project `LiftingLog.xcodeproj`.

---

## File Structure

- Modify `LiftingLog/Core/Models/LoggedSet.swift`: add persisted optional placeholder fields and initializer parameters.
- Modify `LiftingLog/Features/Workout/ActiveWorkoutEngine.swift`: update clone initialization and completion behavior.
- Modify `LiftingLog/Features/Workout/SetRowView.swift`: show placeholder weight/reps in existing text fields.
- Modify `LiftingLogTests/ActiveWorkoutEngineTests.swift`: cover clone initialization, blank notes, completion auto-commit, manual value precedence, and blank RPE behavior.

No new production files are needed. The change stays inside the existing model, engine, view, and unit test boundaries.

## Commands

Use this focused test command while implementing:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -only-testing:LiftingLogTests/ActiveWorkoutEngineTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected success output includes:

```text
** TEST SUCCEEDED **
```

Use this broader verification before the final commit:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -only-testing:LiftingLogTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected success output includes:

```text
** TEST SUCCEEDED **
```

---

### Task 1: Lock Down Clone Initialization

**Files:**
- Modify: `LiftingLogTests/ActiveWorkoutEngineTests.swift`
- Later implementation target: `LiftingLog/Core/Models/LoggedSet.swift`
- Later implementation target: `LiftingLog/Features/Workout/ActiveWorkoutEngine.swift`

- [ ] **Step 1: Replace the existing clone test with a failing placeholder initialization test**

In `LiftingLogTests/ActiveWorkoutEngineTests.swift`, replace `testStartingFromPastCopiesExerciseOrderAndIncompleteSets` with this test:

```swift
func testStartingFromPastCopiesStructureWithPlaceholderValuesAndBlankActualSetValues() throws {
    let container = try SwiftDataTestSupport.makeInMemoryContainer()
    let context = container.mainContext
    let exercise = Exercise(name: "Back Squat", category: .strength, equipment: .barbell, primaryMuscle: "Quads")
    let past = WorkoutSession(title: "Leg Day", startedAt: .now, status: .completed, source: .blank)
    let loggedExercise = LoggedExercise(orderIndex: 0, exercise: exercise, exerciseSnapshotName: exercise.name, notes: "Use belt")
    loggedExercise.sets = [
        LoggedSet(orderIndex: 0, weight: 315, reps: 5, rpe: 8, kind: .warmup, isCompleted: true),
        LoggedSet(orderIndex: 1, weight: 335, reps: 3, rpe: 9, kind: .working, isCompleted: true)
    ]
    past.loggedExercises = [loggedExercise]
    context.insert(exercise)
    context.insert(past)
    try context.save()

    let engine = ActiveWorkoutEngine()
    let newSession = try engine.startWorkout(fromPast: past, context: context)

    XCTAssertEqual(newSession.source, .pastWorkout)
    XCTAssertEqual(newSession.sourceSessionID, past.id)
    XCTAssertEqual(newSession.title, "Leg Day")
    XCTAssertEqual(newSession.loggedExercises.first?.sets.count, 2)
    let copiedExercise = try XCTUnwrap(newSession.loggedExercises.first)
    XCTAssertEqual(copiedExercise.orderIndex, 0)
    XCTAssertEqual(copiedExercise.exerciseSnapshotName, "Back Squat")
    XCTAssertEqual(copiedExercise.notes, "")

    let copiedSets = copiedExercise.sortedSets
    XCTAssertEqual(copiedSets.map(\.isCompleted), [false, false])
    XCTAssertEqual(copiedSets.map(\.kind), [.warmup, .working])
    XCTAssertEqual(copiedSets.map(\.weight), [nil, nil])
    XCTAssertEqual(copiedSets.map(\.reps), [nil, nil])
    XCTAssertEqual(copiedSets.map(\.rpe), [nil, nil])
    XCTAssertEqual(copiedSets.map(\.placeholderWeight), [315, 335])
    XCTAssertEqual(copiedSets.map(\.placeholderReps), [5, 3])
}
```

- [ ] **Step 2: Add a failing test for cloned workout notes**

Add this test immediately after the clone initialization test:

```swift
func testStartingFromPastCopiesTitleAndBlanksWorkoutNotes() throws {
    let container = try SwiftDataTestSupport.makeInMemoryContainer()
    let context = container.mainContext
    let past = WorkoutSession(
        title: "Push Day",
        startedAt: .now,
        notes: "Shoulders felt rough",
        status: .completed,
        source: .blank
    )
    context.insert(past)
    try context.save()

    let engine = ActiveWorkoutEngine()
    let newSession = try engine.startWorkout(fromPast: past, context: context)

    XCTAssertEqual(newSession.title, "Push Day")
    XCTAssertEqual(newSession.notes, "")
}
```

- [ ] **Step 3: Run the focused test file and verify it fails for missing model properties and current clone behavior**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -only-testing:LiftingLogTests/ActiveWorkoutEngineTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: FAIL. Before implementation, compile errors should mention missing `placeholderWeight` or `placeholderReps`, or assertions should fail because cloned `weight`, `reps`, `rpe`, and notes still copy real values.

- [ ] **Step 4: Commit the failing tests**

```bash
git add LiftingLogTests/ActiveWorkoutEngineTests.swift
git commit -m "test: define cloned workout placeholder initialization"
```

---

### Task 2: Implement Placeholder Storage And Clone Initialization

**Files:**
- Modify: `LiftingLog/Core/Models/LoggedSet.swift`
- Modify: `LiftingLog/Features/Workout/ActiveWorkoutEngine.swift`
- Test: `LiftingLogTests/ActiveWorkoutEngineTests.swift`

- [ ] **Step 1: Add placeholder fields to `LoggedSet`**

In `LiftingLog/Core/Models/LoggedSet.swift`, add stored properties after `rpe`:

```swift
var placeholderWeight: Double?
var placeholderReps: Int?
```

Update the initializer signature to include placeholder parameters after `rpe`:

```swift
placeholderWeight: Double? = nil,
placeholderReps: Int? = nil,
```

Set those properties in the initializer immediately after `self.rpe = rpe`:

```swift
self.placeholderWeight = placeholderWeight
self.placeholderReps = placeholderReps
```

The full initializer should look like this after the edit:

```swift
init(
    id: UUID = UUID(),
    orderIndex: Int,
    weight: Double? = nil,
    reps: Int? = nil,
    rpe: Double? = nil,
    placeholderWeight: Double? = nil,
    placeholderReps: Int? = nil,
    kind: SetKind = .working,
    isCompleted: Bool = false,
    completedAt: Date? = nil,
    notes: String = "",
    createdAt: Date = .now,
    updatedAt: Date = .now,
    healthLinkID: UUID? = nil
) {
    self.id = id
    self.orderIndex = orderIndex
    self.weight = weight
    self.reps = reps
    self.rpe = rpe
    self.placeholderWeight = placeholderWeight
    self.placeholderReps = placeholderReps
    self.kindRaw = kind.rawValue
    self.isCompleted = isCompleted
    self.completedAt = completedAt
    self.notes = notes
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.healthLinkID = healthLinkID
}
```

- [ ] **Step 2: Change cloned workouts to write placeholders and blank actual values**

In `LiftingLog/Features/Workout/ActiveWorkoutEngine.swift`, inside `startWorkout(fromPast:context:now:)`, change the new `WorkoutSession` construction so notes are blank:

```swift
let session = WorkoutSession(
    title: pastSession.title,
    startedAt: now,
    status: .active,
    source: .pastWorkout,
    sourceSessionID: pastSession.id,
    createdAt: now,
    updatedAt: now
)
```

In the cloned `LoggedExercise` construction, remove the copied notes argument so notes default to blank:

```swift
let loggedExercise = LoggedExercise(
    orderIndex: pastLoggedExercise.orderIndex,
    exercise: pastLoggedExercise.exercise,
    exerciseSnapshotName: pastLoggedExercise.exerciseSnapshotName,
    createdAt: now,
    updatedAt: now
)
```

In the cloned `LoggedSet` construction, store past weight/reps as placeholders and keep actual values blank:

```swift
let set = LoggedSet(
    orderIndex: pastSet.orderIndex,
    placeholderWeight: pastSet.weight,
    placeholderReps: pastSet.reps,
    kind: pastSet.kind,
    isCompleted: false,
    createdAt: now,
    updatedAt: now
)
```

- [ ] **Step 3: Run the focused tests and verify Task 1 tests pass**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -only-testing:LiftingLogTests/ActiveWorkoutEngineTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: PASS for the clone initialization and notes tests. Other tests in the file should also pass because default initializer values keep blank and add-set behavior unchanged.

- [ ] **Step 4: Commit placeholder storage and clone initialization**

```bash
git add LiftingLog/Core/Models/LoggedSet.swift LiftingLog/Features/Workout/ActiveWorkoutEngine.swift
git commit -m "feat: store cloned workout placeholder values"
```

---

### Task 3: Commit Placeholders On Set Completion

**Files:**
- Modify: `LiftingLogTests/ActiveWorkoutEngineTests.swift`
- Modify: `LiftingLog/Features/Workout/ActiveWorkoutEngine.swift`

- [ ] **Step 1: Add failing tests for completion behavior**

Add these tests after `testCompletingSetUpdatesMetrics` in `LiftingLogTests/ActiveWorkoutEngineTests.swift`:

```swift
func testCompletingSetCommitsBlankWeightAndRepsFromPlaceholders() throws {
    let container = try SwiftDataTestSupport.makeInMemoryContainer()
    let context = container.mainContext
    let engine = ActiveWorkoutEngine()
    let session = try engine.startBlankWorkout(context: context)
    let exercise = Exercise(name: "Bench Press", category: .strength, equipment: .barbell, primaryMuscle: "Chest")
    context.insert(exercise)
    let loggedExercise = try engine.addExercise(exercise, to: session, context: context)
    let set = loggedExercise.sets[0]
    set.placeholderWeight = 185
    set.placeholderReps = 5

    try engine.toggleSetCompletion(set, context: context, now: Date(timeIntervalSince1970: 300))

    XCTAssertTrue(set.isCompleted)
    XCTAssertEqual(set.weight, 185)
    XCTAssertEqual(set.reps, 5)
    XCTAssertNil(set.rpe)
}

func testCompletingSetDoesNotOverwriteManualWeightOrRepsWithPlaceholders() throws {
    let container = try SwiftDataTestSupport.makeInMemoryContainer()
    let context = container.mainContext
    let engine = ActiveWorkoutEngine()
    let session = try engine.startBlankWorkout(context: context)
    let exercise = Exercise(name: "Bench Press", category: .strength, equipment: .barbell, primaryMuscle: "Chest")
    context.insert(exercise)
    let loggedExercise = try engine.addExercise(exercise, to: session, context: context)
    let set = loggedExercise.sets[0]
    set.placeholderWeight = 185
    set.placeholderReps = 5
    try engine.updateSet(set, weight: 195, reps: 4, rpe: 8.5, context: context)

    try engine.toggleSetCompletion(set, context: context, now: Date(timeIntervalSince1970: 300))

    XCTAssertTrue(set.isCompleted)
    XCTAssertEqual(set.weight, 195)
    XCTAssertEqual(set.reps, 4)
    XCTAssertEqual(set.rpe, 8.5)
}

func testUncheckingCompletedSetDoesNotApplyPlaceholders() throws {
    let container = try SwiftDataTestSupport.makeInMemoryContainer()
    let context = container.mainContext
    let engine = ActiveWorkoutEngine()
    let session = try engine.startBlankWorkout(context: context)
    let exercise = Exercise(name: "Bench Press", category: .strength, equipment: .barbell, primaryMuscle: "Chest")
    context.insert(exercise)
    let loggedExercise = try engine.addExercise(exercise, to: session, context: context)
    let set = loggedExercise.sets[0]
    set.placeholderWeight = 185
    set.placeholderReps = 5
    try engine.updateSet(set, weight: 195, reps: 4, rpe: nil, context: context)
    try engine.toggleSetCompletion(set, context: context, now: Date(timeIntervalSince1970: 300))

    try engine.toggleSetCompletion(set, context: context, now: Date(timeIntervalSince1970: 360))

    XCTAssertFalse(set.isCompleted)
    XCTAssertEqual(set.weight, 195)
    XCTAssertEqual(set.reps, 4)
    XCTAssertNil(set.completedAt)
}
```

- [ ] **Step 2: Run the focused tests and verify completion auto-commit fails before implementation**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -only-testing:LiftingLogTests/ActiveWorkoutEngineTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: FAIL. `testCompletingSetCommitsBlankWeightAndRepsFromPlaceholders` should fail because `toggleSetCompletion` does not yet copy placeholder values into blank actual fields.

- [ ] **Step 3: Implement placeholder commit on completion**

In `LiftingLog/Features/Workout/ActiveWorkoutEngine.swift`, replace `toggleSetCompletion` with:

```swift
func toggleSetCompletion(_ set: LoggedSet, context: ModelContext, now: Date = .now) throws {
    let willComplete = !set.isCompleted
    if willComplete {
        applyPlaceholderValuesIfNeeded(to: set)
    }

    set.isCompleted.toggle()
    set.completedAt = set.isCompleted ? now : nil
    set.touch(now: now)
    try context.save()
}
```

Add this private helper near the other private helpers:

```swift
private func applyPlaceholderValuesIfNeeded(to set: LoggedSet) {
    if set.weight == nil, let placeholderWeight = set.placeholderWeight {
        set.weight = placeholderWeight
    }

    if set.reps == nil, let placeholderReps = set.placeholderReps {
        set.reps = placeholderReps
    }
}
```

- [ ] **Step 4: Run the focused tests and verify completion behavior passes**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -only-testing:LiftingLogTests/ActiveWorkoutEngineTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: PASS with `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit completion behavior**

```bash
git add LiftingLogTests/ActiveWorkoutEngineTests.swift LiftingLog/Features/Workout/ActiveWorkoutEngine.swift
git commit -m "feat: confirm cloned set placeholders on completion"
```

---

### Task 4: Display Placeholder Values In Set Fields

**Files:**
- Modify: `LiftingLog/Features/Workout/SetRowView.swift`
- Test: `LiftingLogTests/ActiveWorkoutEngineTests.swift`

- [ ] **Step 1: Update the weight field placeholder**

In `LiftingLog/Features/Workout/SetRowView.swift`, change the weight field call from:

```swift
placeholder: weightUnit.fieldPlaceholder,
```

to:

```swift
placeholder: weightPlaceholder,
```

- [ ] **Step 2: Update the reps field placeholder**

In the same file, change the reps field call from:

```swift
placeholder: "reps",
```

to:

```swift
placeholder: repsPlaceholder,
```

- [ ] **Step 3: Add computed placeholder helpers**

Add these computed properties near the existing binding properties:

```swift
private var weightPlaceholder: String {
    set.placeholderWeight.map(WorkoutFormatters.number) ?? weightUnit.fieldPlaceholder
}

private var repsPlaceholder: String {
    set.placeholderReps.map(String.init) ?? "reps"
}
```

Do not change the RPE field call. It should remain:

```swift
placeholder: "RPE",
```

- [ ] **Step 4: Run the focused unit tests**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -only-testing:LiftingLogTests/ActiveWorkoutEngineTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: PASS with `** TEST SUCCEEDED **`. These tests do not inspect SwiftUI placeholder rendering, but they protect the data behavior that drives the UI.

- [ ] **Step 5: Commit set row placeholder display**

```bash
git add LiftingLog/Features/Workout/SetRowView.swift
git commit -m "feat: show cloned set values as placeholders"
```

---

### Task 5: Final Verification

**Files:**
- Verify: `LiftingLog/Core/Models/LoggedSet.swift`
- Verify: `LiftingLog/Features/Workout/ActiveWorkoutEngine.swift`
- Verify: `LiftingLog/Features/Workout/SetRowView.swift`
- Verify: `LiftingLogTests/ActiveWorkoutEngineTests.swift`

- [ ] **Step 1: Run all unit tests**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -only-testing:LiftingLogTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: PASS with `** TEST SUCCEEDED **`.

- [ ] **Step 2: Inspect the final diff**

Run:

```bash
git diff HEAD~4...HEAD -- LiftingLog/Core/Models/LoggedSet.swift LiftingLog/Features/Workout/ActiveWorkoutEngine.swift LiftingLog/Features/Workout/SetRowView.swift LiftingLogTests/ActiveWorkoutEngineTests.swift
```

Expected: The diff shows only placeholder fields, clone initialization changes, completion auto-commit logic, set-row placeholder display, and tests for those behaviors.

- [ ] **Step 3: Confirm no unrelated working tree changes**

Run:

```bash
git status --short
```

Expected: no output. If the plan document itself is still uncommitted because the implementation worker started from this plan, commit it separately before code changes.

- [ ] **Step 4: Record manual simulator check if a simulator is available**

Build and run the app on the configured simulator. Start from a completed workout that has weight, reps, notes, and RPE. Confirm:

- The cloned workout title is filled.
- Workout notes are blank.
- Exercise notes are blank.
- Weight and reps appear as field placeholders.
- RPE is blank with the normal `RPE` placeholder.
- Tapping a set checkmark fills blank weight/reps from placeholders and leaves RPE blank.

- [ ] **Step 5: Final commit if any verification-only edits were made**

If verification required additional code or test edits, commit them:

```bash
git add LiftingLog/Core/Models/LoggedSet.swift LiftingLog/Features/Workout/ActiveWorkoutEngine.swift LiftingLog/Features/Workout/SetRowView.swift LiftingLogTests/ActiveWorkoutEngineTests.swift
git commit -m "test: verify cloned workout placeholder behavior"
```

If no verification-only edits were made, do not create an empty commit.

---

## Plan Self-Review

- Spec coverage: clone title, blank notes, placeholder weight/reps, blank actual values, blank RPE, completion commit, manual value precedence, and tests are all covered by Tasks 1-5.
- Placeholder scan: no unresolved implementation placeholders remain in this plan. Every code-changing step includes concrete code or exact replacement text.
- Type consistency: the plan uses `placeholderWeight: Double?` and `placeholderReps: Int?` consistently across model, engine, view, and tests.
