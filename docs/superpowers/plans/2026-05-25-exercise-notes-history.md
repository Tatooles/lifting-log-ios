# Exercise Notes History Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Display saved exercise notes read-only in workout history detail and exercise history detail, with simulator screenshots for review.

**Architecture:** Keep `LoggedExercise.notes` as the source of truth. Add one small history-local SwiftUI component that owns the trim-for-empty display rule, then call it from the two history detail screens. Add focused unit coverage for grouping, empty notes, and multi-line preservation.

**Tech Stack:** SwiftUI, SwiftData, XCTest, XcodeGen, XcodeBuildMCP or `xcodebuild`.

---

## File Structure

- Create `LiftingLog/Features/History/ExerciseHistoryNoteBlock.swift`: read-only note display component plus static display helper.
- Modify `LiftingLog/Features/History/WorkoutHistoryDetailView.swift`: render `ExerciseHistoryNoteBlock` below each logged exercise set list.
- Modify `LiftingLog/Features/History/ExerciseHistoryDetailView.swift`: render `ExerciseHistoryNoteBlock` below each session group's completed set list.
- Modify `LiftingLog/Features/History/ExerciseHistorySessionGroup.swift`: add a small `exerciseNotes` computed property sourced from the group's matching logged exercise.
- Modify `LiftingLogTests/HistoryPersistenceTests.swift`: add focused tests for group note association and display helper behavior.
- Regenerate `LiftingLog.xcodeproj` with `xcodegen generate` so the new Swift file is included in the app target.

### Task 1: Add Tests For Exercise Note Display Rules

**Files:**
- Modify: `LiftingLogTests/HistoryPersistenceTests.swift`

- [ ] **Step 1: Add failing tests**

Append these tests before `private func completedSessions(in:)` in `LiftingLogTests/HistoryPersistenceTests.swift`:

```swift
    func testExerciseHistoryGroupCarriesExerciseNotes() throws {
        let container = try SwiftDataTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Bench Press", category: .strength, equipment: .barbell, primaryMuscle: "Chest")
        let session = WorkoutSession(
            title: "Push Notes",
            startedAt: Date(timeIntervalSince1970: 500),
            status: .completed,
            source: .blank
        )
        let loggedExercise = LoggedExercise(
            orderIndex: 0,
            exercise: exercise,
            exerciseSnapshotName: exercise.name,
            notes: "Elbow felt better with a closer grip."
        )
        loggedExercise.sets = [
            LoggedSet(orderIndex: 0, weight: 185, reps: 5, rpe: 8, isCompleted: true)
        ]
        session.loggedExercises = [loggedExercise]
        context.insert(exercise)
        context.insert(session)
        try context.save()

        let summary = try XCTUnwrap(ExerciseHistorySummary.makeSummaries(from: [session]).first)
        let groups = ExerciseHistorySessionGroup.makeGroups(from: [session], matching: summary)

        XCTAssertEqual(groups.first?.exerciseNotes, "Elbow felt better with a closer grip.")
    }

    func testExerciseHistoryNoteBlockTreatsWhitespaceOnlyNotesAsAbsent() {
        XCTAssertNil(ExerciseHistoryNoteBlock.displayNote(from: " \n\t "))
    }

    func testExerciseHistoryNoteBlockPreservesMultilineDisplayText() {
        let note = "Line one\nLine two\n\nLine four"

        XCTAssertEqual(ExerciseHistoryNoteBlock.displayNote(from: note), note)
    }
```

- [ ] **Step 2: Run the focused test target and verify failure**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -only-testing:LiftingLogTests/HistoryPersistenceTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: FAIL because `ExerciseHistorySessionGroup.exerciseNotes` and `ExerciseHistoryNoteBlock` do not exist.

- [ ] **Step 3: Commit the failing tests**

```bash
git add LiftingLogTests/HistoryPersistenceTests.swift
git commit -m "Add tests for history exercise notes"
```

### Task 2: Add The Read-Only Note Component

**Files:**
- Create: `LiftingLog/Features/History/ExerciseHistoryNoteBlock.swift`

- [ ] **Step 1: Create the component**

Create `LiftingLog/Features/History/ExerciseHistoryNoteBlock.swift`:

```swift
import SwiftUI

struct ExerciseHistoryNoteBlock: View {
    let note: String

    var body: some View {
        if let displayNote = Self.displayNote(from: note) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Exercise Notes")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(displayNote)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(AppTheme.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    static func displayNote(from note: String) -> String? {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : note
    }
}
```

- [ ] **Step 2: Regenerate the Xcode project**

Run:

```bash
xcodegen generate
```

Expected: `LiftingLog.xcodeproj/project.pbxproj` changes to include `ExerciseHistoryNoteBlock.swift`.

- [ ] **Step 3: Run focused tests and verify partial failure**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -only-testing:LiftingLogTests/HistoryPersistenceTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: the note-block tests pass, while the group note test still fails until `exerciseNotes` exists.

### Task 3: Add Exercise Notes To Exercise History Groups

**Files:**
- Modify: `LiftingLog/Features/History/ExerciseHistorySessionGroup.swift`

- [ ] **Step 1: Add an exercise note accessor**

In `ExerciseHistorySessionGroup`, add this computed property after `completedSetCount`:

```swift
    var exerciseNotes: String {
        setEntries.first?.loggedExercise.notes ?? ""
    }
```

The top of the struct should read:

```swift
struct ExerciseHistorySessionGroup: Identifiable {
    let session: WorkoutSession
    let setEntries: [ExerciseHistorySetEntry]

    var id: UUID { session.id }
    var title: String { session.title }
    var startedAt: Date { session.startedAt }
    var completedSetCount: Int { setEntries.count }
    var exerciseNotes: String {
        setEntries.first?.loggedExercise.notes ?? ""
    }
```

- [ ] **Step 2: Run focused tests and verify pass**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -only-testing:LiftingLogTests/HistoryPersistenceTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: PASS for `HistoryPersistenceTests`.

- [ ] **Step 3: Commit component and model support**

```bash
git add LiftingLog/Features/History/ExerciseHistoryNoteBlock.swift LiftingLog/Features/History/ExerciseHistorySessionGroup.swift LiftingLog.xcodeproj/project.pbxproj
git commit -m "Add read-only exercise note display helper"
```

### Task 4: Render Notes In Workout History Detail

**Files:**
- Modify: `LiftingLog/Features/History/WorkoutHistoryDetailView.swift`

- [ ] **Step 1: Render the note below each exercise set list**

Inside the `ForEach(session.sortedLoggedExercises)` card, add `ExerciseHistoryNoteBlock` after the set rows and before the closing `VStack`.

The exercise card body should become:

```swift
                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(loggedExercise.exerciseSnapshotName)
                                .font(.system(size: 18, weight: .bold))

                            ForEach(loggedExercise.sortedSets) { set in
                                HStack {
                                    Text("Set \(set.orderIndex + 1)")
                                    Spacer()
                                    Text(set.weight.map(WorkoutFormatters.number) ?? "-")
                                    Text("x")
                                    Text(set.reps.map(String.init) ?? "-")
                                    Text(set.isCompleted ? "Done" : "Open")
                                        .foregroundStyle(set.isCompleted ? AppTheme.accentBright : AppTheme.textSecondary)
                                }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(AppTheme.textSecondary)
                            }

                            ExerciseHistoryNoteBlock(note: loggedExercise.notes)
                        }
                    }
```

- [ ] **Step 2: Run focused tests**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -only-testing:LiftingLogTests/HistoryPersistenceTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: PASS.

### Task 5: Render Notes In Exercise History Detail

**Files:**
- Modify: `LiftingLog/Features/History/ExerciseHistoryDetailView.swift`

- [ ] **Step 1: Render the note below each session group's set list**

In `sessionGroupCard(_:)`, add `ExerciseHistoryNoteBlock(note: group.exerciseNotes)` after the `ForEach(group.setEntries)` loop.

The lower part of the session group card should become:

```swift
                ForEach(group.setEntries) { entry in
                    HStack {
                        Text("Set \(entry.displaySetNumber)")
                        Spacer()
                        Text(setSummary(for: entry.set))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                }

                ExerciseHistoryNoteBlock(note: group.exerciseNotes)
```

- [ ] **Step 2: Run focused tests**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -only-testing:LiftingLogTests/HistoryPersistenceTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: PASS.

- [ ] **Step 3: Commit rendering changes**

```bash
git add LiftingLog/Features/History/WorkoutHistoryDetailView.swift LiftingLog/Features/History/ExerciseHistoryDetailView.swift
git commit -m "Show exercise notes in history"
```

### Task 6: Full Verification And Simulator Screenshots

**Files:**
- No source changes expected.
- Optional artifacts: screenshots saved under `/private/tmp/codex-ios-app-derived-data` or another temporary path.

- [ ] **Step 1: Run the full unit test target**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -only-testing:LiftingLogTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: PASS.

- [ ] **Step 2: Build and run the app on a simulator**

Prefer XcodeBuildMCP for simulator work. First call `session_show_defaults`; if project, scheme, and simulator are configured, call `build_run_sim`.

Expected: LiftingLog launches successfully in Simulator.

- [ ] **Step 3: Create or use seed data that covers screenshot cases**

In the running app, create a completed workout with:

- A workout-level note.
- One exercise with a multi-line exercise note, for example:

```text
Elbow felt better with a closer grip.
Keep shoulders pinned next time.
```

- One exercise with no exercise note.

Expected: the completed workout appears in History.

- [ ] **Step 4: Capture simulator screenshots for review**

Capture and return these screenshots to the user:

- Workout history detail showing an exercise note below that exercise's set list.
- Exercise history detail showing the same note below completed sets.
- An empty-note case showing an exercise with sets and no note block.

Expected: screenshots clearly show read-only note placement and the absence of a note block for the empty-note exercise.

- [ ] **Step 5: Final status**

Report:

- Test commands run and whether they passed.
- Screenshot file paths or embedded images.
- Any residual risk, especially if simulator screenshot setup could not be completed.
