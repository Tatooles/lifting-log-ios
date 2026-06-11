# Weight Unit Display Preference Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the lb/kg setting a display/input preference while storing and syncing all workout weights as canonical pounds.

**Architecture:** Keep the existing SwiftData and Convex schemas. Add explicit conversion helpers to `MeasurementUnit`, stop settings mutations from rewriting workout history, and convert weights only at UI/export boundaries. Sync payloads continue to send canonical stored pounds.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, XCTest, XCUITest, Convex TypeScript backend.

---

## File Structure

- Modify `LiftingLog/Core/Domain/MeasurementUnit.swift`: add canonical pounds conversion helpers.
- Modify `LiftingLog/Core/Models/UserSettings.swift`: stop model-level settings changes from rewriting `LoggedSet` rows.
- Modify `LiftingLog/Core/Domain/SettingsMutationService.swift`: stop sync-aware settings changes from rewriting sets or workout graph parents.
- Modify `LiftingLog/Features/Workout/SetRowView.swift`: convert selected-unit display/input values at the workout entry edge.
- Modify `LiftingLog/Features/History/WorkoutHistoryDetailView.swift`: display selected-unit weights in workout history detail.
- Modify `LiftingLog/Features/History/ExerciseHistoryDetailView.swift`: pass selected unit into exercise history cards.
- Modify `LiftingLog/Features/Workout/ExerciseQuickHistorySheet.swift`: pass selected unit into quick-history cards.
- Modify `LiftingLog/Features/History/ExerciseHistorySessionGroupCard.swift`: format set summaries in the selected unit.
- Modify `LiftingLog/Core/Export/WorkoutDataExportService.swift`: export weights in the selected unit.
- Modify tests in `LiftingLogTests/FormattingTests.swift`, `LiftingLogTests/SettingsTests.swift`, `LiftingLogTests/SyncOutboxIntegrationTests.swift`, `LiftingLogTests/WorkoutDataExportServiceTests.swift`, and `LiftingLogTests/SyncPayloadMappingTests.swift`.
- Modify UI tests in `LiftingLogUITests/LiftingLogUITests.swift`.

## Task 1: Canonical Weight Conversion Helpers

**Files:**
- Modify: `LiftingLog/Core/Domain/MeasurementUnit.swift`
- Test: `LiftingLogTests/FormattingTests.swift`

- [ ] **Step 1: Write failing conversion helper tests**

Add these tests to `FormattingTests` after `testMeasurementUnitProvidesUppercaseWorkoutFieldPlaceholder`:

```swift
func testKilogramDisplayInputRoundTripsThroughCanonicalPounds() {
    let storedPounds = MeasurementUnit.kilograms.canonicalWeight(fromDisplayWeight: 100)

    XCTAssertEqual(storedPounds ?? 0, 220.462262185, accuracy: 0.000_001)
    XCTAssertEqual(MeasurementUnit.kilograms.displayWeight(fromCanonicalPounds: storedPounds), 100, accuracy: 0.000_001)
    XCTAssertEqual(
        storedPounds.flatMap { MeasurementUnit.kilograms.displayWeight(fromCanonicalPounds: $0) }.map(WorkoutFormatters.number),
        "100"
    )
}

func testPoundDisplayInputKeepsCanonicalPoundsUnchanged() {
    XCTAssertEqual(MeasurementUnit.pounds.canonicalWeight(fromDisplayWeight: 185), 185)
    XCTAssertEqual(MeasurementUnit.pounds.displayWeight(fromCanonicalPounds: 185), 185)
}

func testWeightConversionHelpersPreserveNilValues() {
    XCTAssertNil(MeasurementUnit.kilograms.canonicalWeight(fromDisplayWeight: nil))
    XCTAssertNil(MeasurementUnit.kilograms.displayWeight(fromCanonicalPounds: nil))
}
```

- [ ] **Step 2: Run helper tests to verify they fail**

Run:

```bash
xcodebuild test -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:LiftingLogTests/FormattingTests
```

Expected: FAIL because `canonicalWeight(fromDisplayWeight:)` and `displayWeight(fromCanonicalPounds:)` do not exist.

- [ ] **Step 3: Add conversion helpers**

Update `MeasurementUnit.swift` to include these members inside `enum MeasurementUnit`:

```swift
static let canonicalWeightUnit: MeasurementUnit = .pounds

func displayWeight(fromCanonicalPounds canonicalPounds: Double?) -> Double? {
    canonicalPounds.map { Self.canonicalWeightUnit.convert($0, to: self) }
}

func canonicalWeight(fromDisplayWeight displayWeight: Double?) -> Double? {
    displayWeight.map { self.convert($0, to: Self.canonicalWeightUnit) }
}
```

Do not change the existing `poundsPerKilogram` value.

- [ ] **Step 4: Run helper tests to verify they pass**

Run:

```bash
xcodebuild test -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:LiftingLogTests/FormattingTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add LiftingLog/Core/Domain/MeasurementUnit.swift LiftingLogTests/FormattingTests.swift
git commit -m "Add canonical weight conversion helpers"
```

## Task 2: Stop Settings Changes From Rewriting Workout History

**Files:**
- Modify: `LiftingLog/Core/Models/UserSettings.swift`
- Modify: `LiftingLog/Core/Domain/SettingsMutationService.swift`
- Test: `LiftingLogTests/SettingsTests.swift`
- Test: `LiftingLogTests/SyncOutboxIntegrationTests.swift`

- [ ] **Step 1: Replace model-level settings tests**

In `SettingsTests`, replace `testUpdatingWeightUnitConvertsExistingLoggedWeights`, `testUpdatingWeightUnitConvertsPlaceholderWeights`, and `testUpdatingWeightUnitDoesNotConvertTombstonedSets` with:

```swift
func testUpdatingWeightUnitDoesNotRewriteExistingLoggedWeights() throws {
    let container = try SwiftDataTestSupport.makeInMemoryContainer()
    let context = container.mainContext
    try SeedDataService.seedIfNeeded(context: context)
    let settings = try XCTUnwrap(context.fetch(FetchDescriptor<UserSettings>()).first)
    let originalUpdatedAt = Date(timeIntervalSince1970: 50)
    let set = LoggedSet(
        orderIndex: 0,
        weight: 225,
        reps: 5,
        placeholderWeight: 185,
        placeholderReps: 5,
        isCompleted: true,
        updatedAt: originalUpdatedAt
    )
    context.insert(set)
    try context.save()

    try settings.updateWeightUnit(.kilograms, context: context)

    XCTAssertEqual(settings.weightUnit, .kilograms)
    XCTAssertEqual(set.weight, 225)
    XCTAssertEqual(set.placeholderWeight, 185)
    XCTAssertEqual(set.completedVolume, 1125)
    XCTAssertEqual(set.updatedAt, originalUpdatedAt)
}

func testUpdatingWeightUnitDoesNotRewriteTombstonedSets() throws {
    let container = try SwiftDataTestSupport.makeInMemoryContainer()
    let context = container.mainContext
    try SeedDataService.seedIfNeeded(context: context)
    let settings = try XCTUnwrap(context.fetch(FetchDescriptor<UserSettings>()).first)
    let set = LoggedSet(
        orderIndex: 0,
        weight: 225,
        reps: 5,
        placeholderWeight: 225,
        placeholderReps: 5,
        isCompleted: true,
        updatedAt: Date(timeIntervalSince1970: 100)
    )
    let deletedAt = Date(timeIntervalSince1970: 200)
    set.markDeleted(now: deletedAt)
    context.insert(set)
    try context.save()

    try settings.updateWeightUnit(.kilograms, context: context)

    XCTAssertEqual(set.weight, 225)
    XCTAssertEqual(set.placeholderWeight, 225)
    XCTAssertEqual(set.updatedAt, deletedAt)
    XCTAssertEqual(set.deletedAt, deletedAt)
}
```

- [ ] **Step 2: Replace sync-aware settings tests**

In `SyncOutboxIntegrationTests`, replace `testSettingsWeightUnitConversionRecordsSettingsAndConvertedSetUpdates` with:

```swift
func testSettingsWeightUnitChangeRecordsOnlySettingsUpdate() throws {
    let container = try SwiftDataTestSupport.makeInMemoryContainer()
    let context = container.mainContext
    let service = SettingsMutationService()
    let settings = UserSettings(weightUnit: .pounds)
    let completedUpdatedAt = Date(timeIntervalSince1970: 40)
    let placeholderUpdatedAt = Date(timeIntervalSince1970: 45)
    let completedSet = LoggedSet(
        orderIndex: 0,
        weight: 225,
        reps: 5,
        isCompleted: true,
        updatedAt: completedUpdatedAt
    )
    let placeholderSet = LoggedSet(
        orderIndex: 1,
        placeholderWeight: 135,
        placeholderReps: 8,
        updatedAt: placeholderUpdatedAt
    )
    context.insert(settings)
    context.insert(completedSet)
    context.insert(placeholderSet)
    try context.save()

    try service.updateWeightUnit(
        .kilograms,
        settings: settings,
        context: context,
        now: Date(timeIntervalSince1970: 100)
    )

    XCTAssertEqual(settings.weightUnit, .kilograms)
    XCTAssertEqual(completedSet.weight, 225)
    XCTAssertEqual(completedSet.updatedAt, completedUpdatedAt)
    XCTAssertEqual(placeholderSet.placeholderWeight, 135)
    XCTAssertEqual(placeholderSet.updatedAt, placeholderUpdatedAt)

    let entries = try fetchEntries(context)
    XCTAssertEqual(entries.count, 1)
    assertEntry(entries, kind: .userSettings, id: settings.id, operation: .update)
}
```

Replace `testSettingsWeightUnitConversionKeepsActiveDraftSetOutboxLocalUntilFinish` with:

```swift
func testSettingsWeightUnitChangeKeepsActiveDraftSetCanonicalUntilFinish() throws {
    let container = try SwiftDataTestSupport.makeInMemoryContainer()
    let context = container.mainContext
    let settings = UserSettings(weightUnit: .pounds)
    let exercise = Exercise(
        name: "Bench Press",
        category: .strength,
        equipment: .barbell,
        primaryMuscle: "Chest"
    )
    context.insert(settings)
    context.insert(exercise)

    let engine = ActiveWorkoutEngine()
    let session = try engine.startBlankWorkout(context: context, now: Date(timeIntervalSince1970: 100))
    let loggedExercise = try engine.addExercise(exercise, to: session, context: context)
    let set = try XCTUnwrap(loggedExercise.sets.first)
    try engine.updateSet(set, weight: 225, reps: 5, rpe: 8, context: context)

    try SettingsMutationService().updateWeightUnit(
        .kilograms,
        settings: settings,
        context: context,
        now: Date(timeIntervalSince1970: 200)
    )

    XCTAssertEqual(set.weight, 225)
    var entries = try fetchEntries(context)
    XCTAssertEqual(entries.count, 1)
    assertEntry(entries, kind: .userSettings, id: settings.id, operation: .update)
    XCTAssertFalse(entries.contains { $0.entityKind == .loggedSet })
    XCTAssertFalse(entries.contains { $0.entityKind == .loggedExercise })
    XCTAssertFalse(entries.contains { $0.entityKind == .workoutSession })

    try engine.finishWorkout(session, context: context, now: Date(timeIntervalSince1970: 400))

    entries = try fetchEntries(context)
    XCTAssertEqual(entries.count, 4)
    assertEntry(entries, kind: .userSettings, id: settings.id, operation: .update)
    assertEntry(entries, kind: .workoutSession, id: session.id, operation: .create)
    assertEntry(entries, kind: .loggedExercise, id: loggedExercise.id, operation: .create)
    assertEntry(entries, kind: .loggedSet, id: set.id, operation: .create)
}
```

Replace `testSettingsWeightUnitConversionClaimsEveryOwnerlessCompletedWorkoutParentForSetIntents` with:

```swift
func testSettingsWeightUnitChangeDoesNotClaimOwnerlessCompletedWorkoutGraph() throws {
    let container = try SwiftDataTestSupport.makeInMemoryContainer()
    let context = container.mainContext
    let scheduler = SyncScheduler()
    scheduler.currentOwnerTokenIdentifier = "issuer|owner_a"
    let settings = UserSettings(weightUnit: .pounds, syncOwnerTokenIdentifier: "issuer|owner_a")
    let session = WorkoutSession(
        title: "Legacy Push",
        startedAt: Date(timeIntervalSince1970: 100),
        status: .completed,
        source: .blank
    )
    let loggedExercise = LoggedExercise(orderIndex: 0, exerciseSnapshotName: "Bench Press")
    let set = LoggedSet(orderIndex: 0, weight: 225, reps: 5, isCompleted: true)
    set.loggedExercise = loggedExercise
    loggedExercise.session = session
    loggedExercise.sets.append(set)
    session.loggedExercises.append(loggedExercise)
    context.insert(settings)
    context.insert(session)
    context.insert(loggedExercise)
    context.insert(set)
    try context.save()

    try SettingsMutationService(syncScheduler: scheduler).updateWeightUnit(
        .kilograms,
        settings: settings,
        context: context,
        now: Date(timeIntervalSince1970: 200)
    )

    let entries = try fetchEntries(context)
    XCTAssertEqual(set.weight, 225)
    XCTAssertNil(session.syncOwnerTokenIdentifier)
    XCTAssertEqual(entries.count, 1)
    assertEntry(entries, kind: .userSettings, id: settings.id, operation: .update)
    XCTAssertTrue(entries.allSatisfy { $0.ownerTokenIdentifier == "issuer|owner_a" })
    XCTAssertEqual(scheduler.requestCount, 1)
}
```

- [ ] **Step 3: Run settings tests to verify they fail**

Run:

```bash
xcodebuild test -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:LiftingLogTests/SettingsTests -only-testing:LiftingLogTests/SyncOutboxIntegrationTests
```

Expected: FAIL because current settings mutations still convert and touch sets.

- [ ] **Step 4: Simplify `UserSettings.updateWeightUnit`**

Replace `UserSettings.updateWeightUnit` with:

```swift
func updateWeightUnit(_ newUnit: MeasurementUnit, context: ModelContext) throws {
    guard weightUnit != newUnit else { return }

    weightUnit = newUnit
    try context.save()
}
```

- [ ] **Step 5: Simplify `SettingsMutationService.updateWeightUnit`**

Replace `SettingsMutationService.updateWeightUnit` with:

```swift
func updateWeightUnit(
    _ newUnit: MeasurementUnit,
    settings: UserSettings,
    ownerTokenIdentifier: String? = nil,
    context: ModelContext,
    now: Date = .now
) throws {
    guard settings.weightUnit != newUnit else { return }
    let effectiveOwner = try mutationOwner(
        currentOwner: settings.syncOwnerTokenIdentifier,
        requestedOwner: ownerTokenIdentifier ?? syncScheduler?.currentOwnerTokenIdentifier
    )

    settings.syncOwnerTokenIdentifier = effectiveOwner ?? settings.syncOwnerTokenIdentifier
    settings.weightUnitRaw = newUnit.rawValue
    settings.touch(now: now)
    try recorder.recordUpdate(
        entityKind: .userSettings,
        entityID: settings.id,
        ownerTokenIdentifier: effectiveOwner,
        context: context,
        now: now
    )
    try context.save()
    syncScheduler?.requestSync()
}
```

Delete these now-unused private methods from `SettingsMutationService`:

```swift
private func canApplyWeightUnitChange(to set: LoggedSet, ownerTokenIdentifier: String?) -> Bool
private func recordWorkoutGraphParentsForExplicitSetIntent(
    _ set: LoggedSet,
    ownerTokenIdentifier: String?,
    context: ModelContext,
    now: Date
) throws
```

- [ ] **Step 6: Run settings tests to verify they pass**

Run:

```bash
xcodebuild test -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:LiftingLogTests/SettingsTests -only-testing:LiftingLogTests/SyncOutboxIntegrationTests
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add LiftingLog/Core/Models/UserSettings.swift LiftingLog/Core/Domain/SettingsMutationService.swift LiftingLogTests/SettingsTests.swift LiftingLogTests/SyncOutboxIntegrationTests.swift
git commit -m "Stop weight unit changes from rewriting history"
```

## Task 3: Convert Workout Entry Display and Input at the Edge

**Files:**
- Modify: `LiftingLog/Features/Workout/SetRowView.swift`
- Test: `LiftingLogUITests/LiftingLogUITests.swift`

- [ ] **Step 1: Add a kilogram-first UI regression test**

Add this UI test near `testSettingsWeightUnitConversionRoundsDisplayedWorkoutValues`:

```swift
@MainActor
func testKilogramFirstWorkoutEntryDisplaysCleanWeightAndPlaceholder() {
    let app = makeApp()
    app.launch()

    app.buttons["ProfileTab"].tap()
    app.buttons["ProfileSettingsLink"].tap()
    XCTAssertTrue(app.segmentedControls["WeightUnitPicker"].waitForExistence(timeout: 3))
    app.segmentedControls["WeightUnitPicker"].buttons["Kilograms"].tap()

    app.buttons["WorkoutTab"].tap()
    app.buttons["StartBlankWorkoutButton"].tap()
    XCTAssertTrue(app.textFields["WorkoutTitle"].waitForExistence(timeout: 3))
    addBenchPress(in: app)

    let firstWeightField = app.textFields["SetWeightField-0-0"]
    firstWeightField.tap()
    firstWeightField.typeText("100")
    dismissKeyboardIfNeeded(in: app)
    XCTAssertEqual(firstWeightField.value as? String, "100")

    app.buttons["AddSetButton-0"].tap()
    let secondWeightField = app.textFields["SetWeightField-0-1"]
    XCTAssertTrue(secondWeightField.waitForExistence(timeout: 3))
    XCTAssertEqual(secondWeightField.value as? String, "100")
}
```

- [ ] **Step 2: Run the UI test as a regression baseline**

Run:

```bash
xcodebuild test -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:LiftingLogUITests/LiftingLogUITests/testKilogramFirstWorkoutEntryDisplaysCleanWeightAndPlaceholder
```

Expected: PASS. This test protects a visible kg-first experience that may already appear correct before storage semantics are fixed; the canonical storage behavior is covered by unit and integration tests.

- [ ] **Step 3: Convert `SetRowView` display and input**

In `SetRowView`, replace `weightBinding` and `weightPlaceholder` with:

```swift
private var weightBinding: Binding<String> {
    Binding(
        get: { weightInputText.displayText(for: weightUnit.displayWeight(fromCanonicalPounds: set.weight)) },
        set: { value in
            if shouldSuppressDecimalClear(value, field: .setWeight(set.id)) {
                weightInputText.endEditing()
                return
            }

            weightInputText.updateDraft(value)
            let displayWeight = WorkoutFormatters.parseNumber(value)
            let canonicalWeight = weightUnit.canonicalWeight(fromDisplayWeight: displayWeight)
            try? engine.updateSet(set, weight: canonicalWeight, reps: set.reps, rpe: set.rpe, context: modelContext)
        }
    )
}

private var weightPlaceholder: String {
    return weightUnit.displayWeight(fromCanonicalPounds: set.placeholderWeight).map(WorkoutFormatters.number)
        ?? weightUnit.fieldPlaceholder
}
```

Leave `repsBinding`, `rpeBinding`, and `WorkoutNumberInputText` unchanged.

- [ ] **Step 4: Run the kg-first UI test**

Run:

```bash
xcodebuild test -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:LiftingLogUITests/LiftingLogUITests/testKilogramFirstWorkoutEntryDisplaysCleanWeightAndPlaceholder
```

Expected: PASS.

- [ ] **Step 5: Run focused unit tests affected by active workout placeholders**

Run:

```bash
xcodebuild test -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:LiftingLogTests/ActiveWorkoutEngineTests -only-testing:LiftingLogTests/FormattingTests
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add LiftingLog/Features/Workout/SetRowView.swift LiftingLogUITests/LiftingLogUITests.swift
git commit -m "Convert workout entry weights at display boundary"
```

## Task 4: Convert History and Quick History Display

**Files:**
- Modify: `LiftingLog/Features/History/WorkoutHistoryDetailView.swift`
- Modify: `LiftingLog/Features/History/ExerciseHistoryDetailView.swift`
- Modify: `LiftingLog/Features/Workout/ExerciseQuickHistorySheet.swift`
- Modify: `LiftingLog/Features/History/ExerciseHistorySessionGroupCard.swift`
- Test: `LiftingLogUITests/LiftingLogUITests.swift`

- [ ] **Step 1: Update the existing UI conversion test for history display**

Replace `testSettingsWeightUnitConversionRoundsDisplayedWorkoutValues` with:

```swift
@MainActor
func testSettingsWeightUnitPreferenceRoundsDisplayedWorkoutAndHistoryValues() {
    let app = makeApp()
    app.launch()

    createCompletedBenchWorkout(in: app, title: "Metric Display")

    app.buttons["ProfileTab"].tap()
    app.buttons["ProfileSettingsLink"].tap()
    XCTAssertTrue(app.segmentedControls["WeightUnitPicker"].waitForExistence(timeout: 3))
    app.segmentedControls["WeightUnitPicker"].buttons["Kilograms"].tap()

    app.buttons["HistoryTab"].tap()
    XCTAssertTrue(app.buttons["WorkoutHistoryButton-0"].waitForExistence(timeout: 3))
    app.buttons["WorkoutHistoryButton-0"].tap()
    XCTAssertTrue(app.staticTexts["83.91"].waitForExistence(timeout: 3))

    app.navigationBars.buttons.element(boundBy: 0).tap()
    app.segmentedControls["HistoryModePicker"].buttons["Exercises"].tap()
    XCTAssertTrue(app.buttons["ExerciseHistoryButton-0"].waitForExistence(timeout: 3))
    app.buttons["ExerciseHistoryButton-0"].tap()
    XCTAssertTrue(app.staticTexts["83.91 x 5 @ 8"].waitForExistence(timeout: 3))
}
```

- [ ] **Step 2: Run the updated UI test to verify it fails**

Run:

```bash
xcodebuild test -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:LiftingLogUITests/LiftingLogUITests/testSettingsWeightUnitPreferenceRoundsDisplayedWorkoutAndHistoryValues
```

Expected: FAIL after Task 2 because settings no longer rewrites the stored completed workout weight, and history still formats stored pounds directly.

- [ ] **Step 3: Add selected-unit lookup to workout history detail**

In `WorkoutHistoryDetailView`, add this query near the existing properties:

```swift
@Query(sort: \UserSettings.createdAt) private var settingsRecords: [UserSettings]

private var weightUnit: MeasurementUnit {
    UserSettings.visibleSettingsRecords(
        from: settingsRecords,
        ownerTokenIdentifier: syncScheduler.currentOwnerTokenIdentifier
    ).first?.weightUnit ?? .pounds
}
```

Replace the direct weight text:

```swift
Text(set.weight.map(WorkoutFormatters.number) ?? "-")
```

with:

```swift
Text(weightText(for: set))
```

Add this helper inside `WorkoutHistoryDetailView`:

```swift
private func weightText(for set: LoggedSet) -> String {
    guard let displayWeight = weightUnit.displayWeight(fromCanonicalPounds: set.weight) else {
        return "-"
    }

    return WorkoutFormatters.number(displayWeight)
}
```

- [ ] **Step 4: Pass selected unit into exercise history cards**

In `ExerciseHistorySessionGroupCard`, change the stored properties to:

```swift
let group: ExerciseHistorySessionGroup
var weightUnit: MeasurementUnit = .pounds
var showsExerciseNotes: Bool = true
```

Replace `setSummary(for:)` with:

```swift
private func setSummary(for set: LoggedSet) -> String {
    let weight = weightUnit.displayWeight(fromCanonicalPounds: set.weight).map(WorkoutFormatters.number) ?? "-"
    let reps = set.reps.map(String.init) ?? "-"

    if let rpe = set.rpe {
        return "\(weight) x \(reps) @ \(WorkoutFormatters.number(rpe))"
    }

    return "\(weight) x \(reps)"
}
```

In `ExerciseHistoryDetailView`, add:

```swift
@Query(sort: \UserSettings.createdAt) private var settingsRecords: [UserSettings]

private var weightUnit: MeasurementUnit {
    UserSettings.visibleSettingsRecords(
        from: settingsRecords,
        ownerTokenIdentifier: syncScheduler.currentOwnerTokenIdentifier
    ).first?.weightUnit ?? .pounds
}
```

Change:

```swift
ExerciseHistorySessionGroupCard(group: group)
```

to:

```swift
ExerciseHistorySessionGroupCard(group: group, weightUnit: weightUnit)
```

In `ExerciseQuickHistorySheet`, add:

```swift
@Query(sort: \UserSettings.createdAt) private var settingsRecords: [UserSettings]

private var weightUnit: MeasurementUnit {
    UserSettings.visibleSettingsRecords(
        from: settingsRecords,
        ownerTokenIdentifier: syncScheduler.currentOwnerTokenIdentifier
    ).first?.weightUnit ?? .pounds
}
```

Change:

```swift
ExerciseHistorySessionGroupCard(group: group)
```

to:

```swift
ExerciseHistorySessionGroupCard(group: group, weightUnit: weightUnit)
```

- [ ] **Step 5: Run the updated UI test**

Run:

```bash
xcodebuild test -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:LiftingLogUITests/LiftingLogUITests/testSettingsWeightUnitPreferenceRoundsDisplayedWorkoutAndHistoryValues
```

Expected: PASS.

- [ ] **Step 6: Run history unit tests**

Run:

```bash
xcodebuild test -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:LiftingLogTests/HistoryPersistenceTests
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add LiftingLog/Features/History/WorkoutHistoryDetailView.swift LiftingLog/Features/History/ExerciseHistoryDetailView.swift LiftingLog/Features/Workout/ExerciseQuickHistorySheet.swift LiftingLog/Features/History/ExerciseHistorySessionGroupCard.swift LiftingLogUITests/LiftingLogUITests.swift
git commit -m "Display history weights in selected unit"
```

## Task 5: Convert CSV Export and Preserve Canonical Sync Payloads

**Files:**
- Modify: `LiftingLog/Core/Export/WorkoutDataExportService.swift`
- Test: `LiftingLogTests/WorkoutDataExportServiceTests.swift`
- Test: `LiftingLogTests/SyncPayloadMappingTests.swift`

- [ ] **Step 1: Add export conversion test**

Add this test to `WorkoutDataExportServiceTests` near the existing unit/export tests:

```swift
func testCSVConvertsCanonicalPoundsToSelectedKilogramUnit() throws {
    let session = WorkoutSession(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000009001")!,
        title: "Metric Export",
        startedAt: Date(timeIntervalSince1970: 100),
        endedAt: Date(timeIntervalSince1970: 200),
        status: .completed,
        source: .blank
    )
    let loggedExercise = LoggedExercise(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000009002")!,
        orderIndex: 0,
        exerciseSnapshotName: "Bench Press"
    )
    let set = LoggedSet(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000009003")!,
        orderIndex: 0,
        weight: 220.462262185,
        reps: 5,
        rpe: 8,
        isCompleted: true
    )
    set.loggedExercise = loggedExercise
    loggedExercise.session = session
    loggedExercise.sets.append(set)
    session.loggedExercises.append(loggedExercise)

    let rows = try parseCSV(WorkoutDataExportService().csv(for: [session], unit: .kilograms))

    XCTAssertEqual(rows[1][9], "100")
    XCTAssertEqual(rows[1][11], "kilograms")
}
```

- [ ] **Step 2: Add sync payload canonical test**

Add this test to `SyncPayloadMappingTests` near the existing logged set payload test:

```swift
func testLoggedSetPayloadSendsCanonicalStoredPounds() throws {
    let set = LoggedSet(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000004301")!,
        orderIndex: 0,
        weight: MeasurementUnit.kilograms.canonicalWeight(fromDisplayWeight: 100),
        reps: 5,
        placeholderWeight: MeasurementUnit.kilograms.canonicalWeight(fromDisplayWeight: 80),
        placeholderReps: 5,
        isCompleted: true
    )

    let payload = SyncPayloadMapper.loggedSetPayload(from: set)

    XCTAssertEqual(payload.weight ?? 0, 220.462262185, accuracy: 0.000_001)
    XCTAssertEqual(payload.placeholderWeight ?? 0, 176.369809748, accuracy: 0.000_001)
}
```

- [ ] **Step 3: Run export and sync tests to verify export fails**

Run:

```bash
xcodebuild test -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:LiftingLogTests/WorkoutDataExportServiceTests -only-testing:LiftingLogTests/SyncPayloadMappingTests
```

Expected: FAIL for the new CSV conversion test because export currently writes stored pounds directly. The sync payload test should PASS once Task 1 helpers exist.

- [ ] **Step 4: Convert export weight values**

In `WorkoutDataExportService.row(for:loggedExercise:session:unit:)`, replace:

```swift
set.weight.map(Self.formatDouble) ?? "",
```

with:

```swift
unit.displayWeight(fromCanonicalPounds: set.weight).map(Self.formatDouble) ?? "",
```

Keep the existing `unit.rawValue` column unchanged.

- [ ] **Step 5: Run export and sync tests**

Run:

```bash
xcodebuild test -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:LiftingLogTests/WorkoutDataExportServiceTests -only-testing:LiftingLogTests/SyncPayloadMappingTests
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add LiftingLog/Core/Export/WorkoutDataExportService.swift LiftingLogTests/WorkoutDataExportServiceTests.swift LiftingLogTests/SyncPayloadMappingTests.swift
git commit -m "Export weights in selected unit"
```

## Task 6: Final Verification

**Files:**
- Verify all modified files.

- [ ] **Step 1: Search for remaining direct weight display call sites**

Run:

```bash
rg -n "set\\.weight\\.map\\(WorkoutFormatters\\.number\\)|placeholderWeight\\.map\\(WorkoutFormatters\\.number\\)|set\\.weight\\.map\\(Self\\.formatDouble\\)" LiftingLog LiftingLogTests
```

Expected: no remaining direct user-facing formatting of stored set weights. If matches remain in tests that intentionally assert canonical values, leave them. If matches remain in app UI/export code, convert them through `MeasurementUnit.displayWeight(fromCanonicalPounds:)`.

- [ ] **Step 2: Run the main unit test suite**

Run:

```bash
xcodebuild test -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:LiftingLogTests
```

Expected: PASS.

- [ ] **Step 3: Run focused UI tests**

Run:

```bash
xcodebuild test -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:LiftingLogUITests/LiftingLogUITests/testKilogramFirstWorkoutEntryDisplaysCleanWeightAndPlaceholder -only-testing:LiftingLogUITests/LiftingLogUITests/testSettingsWeightUnitPreferenceRoundsDisplayedWorkoutAndHistoryValues
```

Expected: PASS.

- [ ] **Step 4: Run Convex tests**

Run:

```bash
pnpm test
```

Expected: PASS. This change should not require Convex schema or validator edits.

- [ ] **Step 5: Review git diff**

Run:

```bash
git diff --stat
git diff -- LiftingLog/Core/Domain/MeasurementUnit.swift LiftingLog/Core/Models/UserSettings.swift LiftingLog/Core/Domain/SettingsMutationService.swift LiftingLog/Features/Workout/SetRowView.swift LiftingLog/Features/History/WorkoutHistoryDetailView.swift LiftingLog/Features/History/ExerciseHistoryDetailView.swift LiftingLog/Features/Workout/ExerciseQuickHistorySheet.swift LiftingLog/Features/History/ExerciseHistorySessionGroupCard.swift LiftingLog/Core/Export/WorkoutDataExportService.swift
```

Expected: changes are limited to conversion helpers, settings mutation behavior, display/export call sites, and tests.

- [ ] **Step 6: Commit final verification fixes if any were needed**

If Step 1 or Step 5 required fixes, commit them:

```bash
git add LiftingLog LiftingLogTests LiftingLogUITests
git commit -m "Finish weight unit display preference"
```

If no fixes were needed, do not create an empty commit.

## Self-Review

- Spec coverage: canonical pounds helpers are in Task 1; settings-only updates are in Task 2; workout entry conversion is in Task 3; history and quick history display are in Task 4; CSV export and canonical sync are in Task 5; UI test coverage and final verification are in Tasks 3, 4, and 6.
- Placeholder scan: no placeholder markers are intentionally left in this plan.
- Type consistency: all new helper names are `displayWeight(fromCanonicalPounds:)` and `canonicalWeight(fromDisplayWeight:)`; those names are used consistently in later tasks.
