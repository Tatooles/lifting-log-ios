# Local Release Baseline Audit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Audit the local/offline LiftingLog release baseline and apply only narrow blocker fixes that protect workout logging, history, settings, and SwiftData persistence.

**Architecture:** Treat this as an audit-first workflow with a blocker gate. The first pass gathers automated and manual evidence, writes an audit report, then only enters TDD fix work if a finding meets the approved blocker criteria from the design spec.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, XCTest, XCUITest, XcodeBuildMCP, iOS Simulator.

---

## Source Spec

- `docs/superpowers/specs/2026-05-24-local-release-baseline-audit-design.md`
- `docs/initial-release-roadmap.md`
- GitHub issue #3: Audit and stabilize local release baseline

## File Structure

Create:

- `docs/audits/2026-05-24-local-release-baseline-audit.md`
  - Records automated test results, manual verification results, blocker decisions, fixes made, and follow-up gaps.

Potentially modify only if a blocker is confirmed:

- `LiftingLog/Features/Workout/ActiveWorkoutEngine.swift`
  - Workout creation, active session cleanup, exercise/set edits, finish, and discard behavior.
- `LiftingLog/Features/Workout/WorkoutSessionView.swift`
  - Active workout UI bindings, focus behavior, add exercise presentation, and finish sheet presentation.
- `LiftingLog/Features/Workout/ExerciseCardView.swift`
  - Logged exercise UI, set list, notes, remove exercise, and add set controls.
- `LiftingLog/Features/Workout/SetRowView.swift`
  - Set input parsing, completion toggle, remove set behavior, and focus handling.
- `LiftingLog/Features/Workout/FinishWorkoutSheet.swift`
  - Finish/discard action UI and save error handling.
- `LiftingLog/Features/StartWorkout/StartWorkoutView.swift`
  - Blank workout and past-workout creation entry points.
- `LiftingLog/Features/History/HistoryView.swift`
  - Completed workout and exercise history visibility.
- `LiftingLog/Features/History/WorkoutHistoryDetailView.swift`
  - Completed workout detail and delete behavior.
- `LiftingLog/Features/Exercises/ExerciseLibraryView.swift`
  - Exercise removal/archive behavior from the library.
- `LiftingLog/Features/Exercises/ExerciseEditorView.swift`
  - Exercise create/edit validation.
- `LiftingLog/Features/Profile/SettingsView.swift`
  - Weight unit and rest timer persistence.
- `LiftingLog/Core/Models/WorkoutSession.swift`
  - Workout status, duration, relationships, timestamps, and sorted logged exercises.
- `LiftingLog/Core/Models/LoggedExercise.swift`
  - Logged exercise relationships, ordering, snapshots, and timestamps.
- `LiftingLog/Core/Models/LoggedSet.swift`
  - Set values, completion state, volume, relationships, and timestamps.
- `LiftingLog/Core/Models/Exercise.swift`
  - Exercise update, archive, and archive-or-delete behavior.
- `LiftingLog/Core/Models/UserSettings.swift`
  - Weight unit conversion and settings timestamp behavior.
- `LiftingLog/Core/Persistence/SeedDataService.swift`
  - Launch-time seeded exercises and settings singleton behavior.
- `LiftingLog/Core/Persistence/ModelContainerFactory.swift`
  - SwiftData container creation behavior.

Potentially add or modify tests only if they support audit evidence or blocker fixes:

- `LiftingLogTests/ActiveWorkoutEngineTests.swift`
- `LiftingLogTests/HistoryPersistenceTests.swift`
- `LiftingLogTests/ModelPersistenceTests.swift`
- `LiftingLogTests/SettingsTests.swift`
- `LiftingLogTests/SeedDataServiceTests.swift`
- `LiftingLogTests/WorkoutFocusNavigatorTests.swift`
- `LiftingLogUITests/LiftingLogUITests.swift`

Do not modify:

- Sync, authentication, export, account deletion, App Store submission, HealthKit, analytics, subscriptions, widgets, or charting code.

## Task 1: Confirm Workspace And Scope

**Files:**

- Read: `docs/superpowers/specs/2026-05-24-local-release-baseline-audit-design.md`
- Read: `docs/initial-release-roadmap.md`
- Read: `README.md`
- Read: `project.yml`

- [ ] **Step 1: Confirm branch and worktree state**

Run:

```bash
git status --short --branch
```

Expected:

- Current branch is `3-audit-and-stabilize-local-release-baseline`.
- No unrelated unstaged or staged changes are present. If unrelated changes are present, leave them alone and mention them in the audit report.

- [ ] **Step 2: Re-read the approved design spec**

Run:

```bash
sed -n '1,220p' docs/superpowers/specs/2026-05-24-local-release-baseline-audit-design.md
```

Expected:

- Scope covers local/offline workout creation, editing, finishing, history, exercise library, settings, SwiftData persistence, and tests.
- XcodeBuildMCP is the preferred verification path.
- Small fixes are allowed only for approved blocker categories.

- [ ] **Step 3: Re-read roadmap Phase 0**

Run:

```bash
sed -n '1,80p' docs/initial-release-roadmap.md
```

Expected:

- Phase 0 confirms this issue is about stabilizing the current local app before cloud complexity.

- [ ] **Step 4: Re-read project verification docs**

Run:

```bash
sed -n '1,180p' README.md
sed -n '1,220p' project.yml
```

Expected:

- Scheme is `LiftingLog`.
- Project is `LiftingLog.xcodeproj`.
- Test targets are `LiftingLogTests` and `LiftingLogUITests`.
- README commands are available as fallback reference only.

## Task 2: Configure XcodeBuildMCP Verification

**Files:**

- No file changes.

- [ ] **Step 1: Show existing XcodeBuildMCP defaults**

MCP call:

```json
{
  "tool": "mcp__xcodebuildmcp__session_show_defaults",
  "arguments": {}
}
```

Expected:

- Defaults include project or workspace, scheme, and iOS simulator.
- If any required default is missing or wrong, continue to Step 2.

- [ ] **Step 2: Set defaults if required**

MCP call:

```json
{
  "tool": "mcp__xcodebuildmcp__session_set_defaults",
  "arguments": {
    "projectPath": "/Users/kevintatooles/Developer/Projects/codex-ios-app/LiftingLog.xcodeproj",
    "scheme": "LiftingLog",
    "simulatorName": "iPhone 16",
    "simulatorPlatform": "iOS Simulator",
    "useLatestOS": true,
    "derivedDataPath": "/private/tmp/codex-ios-app-derived-data"
  }
}
```

Expected:

- XcodeBuildMCP accepts the defaults for the current session.
- Do not persist defaults unless the user explicitly requests it.

- [ ] **Step 3: Confirm defaults after setting them**

MCP call:

```json
{
  "tool": "mcp__xcodebuildmcp__session_show_defaults",
  "arguments": {}
}
```

Expected:

- Project path, scheme, simulator, and derived data path match Step 2.

## Task 3: Run Automated Baseline Tests

**Files:**

- No file changes unless a blocker is found later.

- [ ] **Step 1: Run the full XCTest and XCUITest suite with XcodeBuildMCP**

MCP call:

```json
{
  "tool": "mcp__xcodebuildmcp__test_sim",
  "arguments": {
    "progress": true
  }
}
```

Expected:

- PASS for `LiftingLogTests`.
- PASS for `LiftingLogUITests`.
- Record the exact result, duration if available, and any failing test names in the audit report.

- [ ] **Step 2: If the full suite fails, isolate unit tests**

Run this step only when Step 1 fails.

MCP call:

```json
{
  "tool": "mcp__xcodebuildmcp__test_sim",
  "arguments": {
    "progress": true,
    "extraArgs": [
      "-only-testing:LiftingLogTests"
    ]
  }
}
```

Expected:

- Unit tests either pass or produce a focused list of failing unit tests.
- Record each failing test and the observed failure text.

- [ ] **Step 3: If the full suite fails, isolate UI tests**

Run this step only when Step 1 fails.

MCP call:

```json
{
  "tool": "mcp__xcodebuildmcp__test_sim",
  "arguments": {
    "progress": true,
    "extraArgs": [
      "-only-testing:LiftingLogUITests"
    ]
  }
}
```

Expected:

- UI tests either pass or produce a focused list of failing UI tests.
- Record each failing test and the observed failure text.

- [ ] **Step 4: Use CLI fallback only if XcodeBuildMCP is unavailable**

Run only if XcodeBuildMCP cannot run tests.

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected:

- This fallback produces equivalent test coverage.
- Record that fallback was used and why MCP was unavailable.

## Task 4: Map Existing Automated Coverage

**Files:**

- Read: `LiftingLogTests/*.swift`
- Read: `LiftingLogUITests/LiftingLogUITests.swift`
- Update later: `docs/audits/2026-05-24-local-release-baseline-audit.md`

- [ ] **Step 1: List test files and test methods**

Run:

```bash
rg -n "final class .*Tests|func test" LiftingLogTests LiftingLogUITests
```

Expected:

- Output includes test methods for active workout engine, history persistence, model persistence, settings, seed data, formatting, focus navigation, and UI smoke flows.

- [ ] **Step 2: Map coverage to audit domains**

Use the test list from Step 1 to classify coverage into these domains:

```markdown
| Domain | Existing automated coverage | Missing release-critical coverage |
| --- | --- | --- |
| Workout creation |  |  |
| Active workout editing |  |  |
| Finish/discard/delete |  |  |
| History |  |  |
| Exercise library |  |  |
| Settings |  |  |
| SwiftData persistence |  |  |
| UI smoke flows |  |  |
```

Expected:

- Each row has concrete test method names or the phrase `No direct automated coverage found`.
- Missing coverage is described in terms of user-visible risk, not implementation preference.

## Task 5: Manual Local Workflow Audit

**Files:**

- Update later: `docs/audits/2026-05-24-local-release-baseline-audit.md`

- [ ] **Step 1: Build, install, and launch the app with XcodeBuildMCP**

MCP call:

```json
{
  "tool": "mcp__xcodebuildmcp__build_run_sim",
  "arguments": {}
}
```

Expected:

- App launches on the configured iOS simulator.
- Runtime log path is captured if the tool returns one.

- [ ] **Step 2: Verify fresh local launch and seed data**

Manual simulator actions:

1. Launch the app.
2. Confirm the app opens to the Start workout tab when no active workout is present.
3. Tap Profile.
4. Tap Exercise Library.
5. Confirm seeded exercises are visible.

Expected:

- App launches without a persistence fatal error.
- Exercise library contains seeded exercises such as Back Squat and Bench Press.
- Profile shows local/offline state and settings entry.

- [ ] **Step 3: Verify blank workout flow**

Manual simulator actions:

1. Tap Start or Workout tab.
2. Tap Blank Workout.
3. Tap Add Exercise.
4. Select Bench Press.
5. Enter weight `185`, reps `5`, and RPE `8`.
6. Mark the set complete.
7. Add a second set and confirm previous values copy where expected.
8. Finish the workout.
9. Save the workout.

Expected:

- One active workout is created.
- Exercise and set edits persist while the workout is active.
- Completed set count and volume update.
- Save moves the workout into history and clears the active workout.

- [ ] **Step 4: Verify history flow**

Manual simulator actions:

1. Tap History.
2. Open the completed workout from Step 3.
3. Confirm duration, exercise count, completed set count, volume, set values, and completion state.
4. Switch History mode to Exercises.
5. Open Bench Press history.

Expected:

- Completed workout appears in Workouts history.
- Bench Press appears in exercise history.
- Exercise history counts completed sets only.
- Set values match what was entered.

- [ ] **Step 5: Verify past-workout reuse**

Manual simulator actions:

1. Return to Start or Workout tab when no workout is active.
2. Select the completed workout from Use Past Workout.
3. Confirm Bench Press is copied into the new active workout.
4. Confirm copied sets are incomplete.
5. Change a copied set value.
6. Discard the active workout.
7. Reopen the original workout in History.

Expected:

- Past workout copy creates a new active workout.
- Original completed workout remains completed and unchanged.
- Discarded copy does not appear in completed history.

- [ ] **Step 6: Verify settings**

Manual simulator actions:

1. Tap Profile.
2. Tap Settings.
3. Change Weight Unit from Pounds to Kilograms.
4. Return to the completed workout history detail.
5. Confirm prior logged weight displays as converted data where existing UI exposes it.
6. Return to Settings.
7. Change rest timer value.

Expected:

- Weight unit setting persists.
- Logged set weights are converted in storage.
- Rest timer changes persist within the current app session.

- [ ] **Step 7: Verify exercise library behavior**

Manual simulator actions:

1. Open Profile.
2. Open Exercise Library.
3. Create a custom exercise named `Audit Row`.
4. Edit `Audit Row` to `Audit Chest Supported Row`.
5. Attempt to create another active exercise with the same name.
6. Remove the custom exercise.
7. Search for the removed exercise.

Expected:

- Custom exercise can be created and edited.
- Duplicate active name is rejected.
- Removed custom exercise no longer appears in the active library.

- [ ] **Step 8: Verify completed workout delete behavior**

Manual simulator actions:

1. Open History.
2. Open the completed workout created in Step 3.
3. Tap Delete Workout.
4. Confirm the workout no longer appears in Workouts history.
5. Confirm exercise history no longer counts sets from the deleted workout.

Expected:

- Deleted completed workout disappears from history.
- Related logged exercises and sets no longer contribute to exercise history.

## Task 6: Create The Audit Report

**Files:**

- Create: `docs/audits/2026-05-24-local-release-baseline-audit.md`

- [ ] **Step 1: Create the audit directory**

Run:

```bash
mkdir -p docs/audits
```

Expected:

- `docs/audits` exists.

- [ ] **Step 2: Write the report with concrete observed results**

Create `docs/audits/2026-05-24-local-release-baseline-audit.md` with this structure:

```markdown
# Local Release Baseline Audit

## Summary

- Branch: `3-audit-and-stabilize-local-release-baseline`
- Scope: Local/offline Phase 0 baseline for workout creation, editing, finishing, history, settings, SwiftData persistence, and tests.
- Result: Pass, Pass with follow-ups, or Blocked by release-critical issue.

## Automated Verification

| Check | Tool | Result | Notes |
| --- | --- | --- | --- |
| Full test suite | XcodeBuildMCP `test_sim` | Pass, Fail, or Not run | Include exact failing test names or successful run summary. |
| Unit tests | XcodeBuildMCP `test_sim -only-testing:LiftingLogTests` | Pass, Fail, or Not run | Include exact failing test names or successful run summary. |
| UI tests | XcodeBuildMCP `test_sim -only-testing:LiftingLogUITests` | Pass, Fail, or Not run | Include exact failing test names or successful run summary. |

## Coverage Map

| Domain | Existing automated coverage | Missing release-critical coverage |
| --- | --- | --- |
| Workout creation | Include test method names. | Include gaps or `No release-critical gap found`. |
| Active workout editing | Include test method names. | Include gaps or `No release-critical gap found`. |
| Finish/discard/delete | Include test method names. | Include gaps or `No release-critical gap found`. |
| History | Include test method names. | Include gaps or `No release-critical gap found`. |
| Exercise library | Include test method names. | Include gaps or `No release-critical gap found`. |
| Settings | Include test method names. | Include gaps or `No release-critical gap found`. |
| SwiftData persistence | Include test method names. | Include gaps or `No release-critical gap found`. |
| UI smoke flows | Include test method names. | Include gaps or `No release-critical gap found`. |

## Manual Verification

| Workflow | Result | Notes |
| --- | --- | --- |
| Fresh launch and seed data | Pass or Fail | Include observed seeded exercise and settings behavior. |
| Blank workout creation and finish | Pass or Fail | Include observed saved history behavior. |
| History detail and exercise history | Pass or Fail | Include observed metrics and set values. |
| Past-workout reuse | Pass or Fail | Include copied set completion and original workout integrity. |
| Settings and unit conversion | Pass or Fail | Include observed unit and rest timer behavior. |
| Exercise library create/edit/remove | Pass or Fail | Include duplicate-name and removal behavior. |
| Completed workout delete | Pass or Fail | Include observed history cleanup behavior. |

## Blocker Review

| Finding | Blocker? | Rationale | Action |
| --- | --- | --- | --- |
| Include each failing automated or manual finding. | Yes or No | Tie to approved blocker criteria. | Fixed in this issue, follow-up issue, or no action required. |

## Fixes Made

- List each code or test fix committed for this audit.
- If no fixes were made, write: `No blocker fixes were required.`

## Follow-Up Notes

- List non-blocking coverage gaps, polish issues, or later roadmap work.
- Do not include sync, auth, or export implementation as Phase 0 work.
```

Expected:

- The report contains concrete observed results from Tasks 3, 4, and 5.
- No row is left blank.
- No finding is marked as a blocker unless it matches the blocker criteria in the design spec.

- [ ] **Step 3: Review the report for empty cells**

Run:

```bash
rg -n "\\|\\s*\\|" docs/audits/2026-05-24-local-release-baseline-audit.md
```

Expected:

- No table rows contain empty cells.
- Rows may contain explicit values such as `Not run` or `No release-critical gap found`.

## Task 7: Blocker Gate

**Files:**

- Read: `docs/audits/2026-05-24-local-release-baseline-audit.md`
- Potentially modify test and app files listed in File Structure.

- [ ] **Step 1: Classify every failing finding**

Use the approved blocker criteria:

```markdown
A finding is a Phase 0 blocker if it can cause lost or inaccessible workout data, incorrect saved workout history, broken active workout creation/editing/finish/discard flow, app launch or SwiftData initialization failure, settings data corruption, or a release-critical local workflow with no practical recovery path.
```

Expected:

- Each failure in the audit report has `Blocker?` set to `Yes` or `No`.
- Each `Yes` has a concrete user impact.
- Each `No` has a follow-up note or a reason no action is needed.

- [ ] **Step 2: If there are no blockers, commit the audit report**

Run only when all findings are non-blocking or all checks pass.

```bash
git add docs/audits/2026-05-24-local-release-baseline-audit.md
git commit -m "Document local release baseline audit"
```

Expected:

- Commit contains only the audit report.
- Proceed to Task 10.

- [ ] **Step 3: If blockers exist, choose the smallest owner file**

Use this owner map:

```markdown
| Blocker area | Primary implementation file | Primary test file |
| --- | --- | --- |
| Active session lifecycle | `LiftingLog/Features/Workout/ActiveWorkoutEngine.swift` | `LiftingLogTests/ActiveWorkoutEngineTests.swift` |
| Workout graph persistence | `LiftingLog/Core/Models/WorkoutSession.swift`, `LiftingLog/Core/Models/LoggedExercise.swift`, or `LiftingLog/Core/Models/LoggedSet.swift` | `LiftingLogTests/ModelPersistenceTests.swift` |
| History visibility or grouping | `LiftingLog/Features/History/HistoryView.swift`, `LiftingLog/Features/History/ExerciseHistorySummary.swift`, or `LiftingLog/Features/History/ExerciseHistorySessionGroup.swift` | `LiftingLogTests/HistoryPersistenceTests.swift` |
| Settings conversion or persistence | `LiftingLog/Core/Models/UserSettings.swift` or `LiftingLog/Features/Profile/SettingsView.swift` | `LiftingLogTests/SettingsTests.swift` |
| Exercise archive/delete | `LiftingLog/Core/Models/Exercise.swift` or `LiftingLog/Features/Exercises/ExerciseLibraryView.swift` | `LiftingLogTests/ModelPersistenceTests.swift` |
| Keyboard or critical UI workflow | Matching SwiftUI view file | `LiftingLogUITests/LiftingLogUITests.swift` |
```

Expected:

- Each blocker has one primary implementation owner and one primary test owner.
- Avoid broad refactors.

## Task 8: Fix Confirmed Blockers With TDD

**Files:**

- Modify only the owner files selected in Task 7.

- [ ] **Step 1: Write or update a failing test for the first blocker**

Add the smallest test that reproduces the blocker. Use these patterns by blocker type.

For active workout lifecycle issues, add a test to `LiftingLogTests/ActiveWorkoutEngineTests.swift`:

```swift
func testDescriptiveBlockerBehavior() throws {
    let container = try SwiftDataTestSupport.makeInMemoryContainer()
    let context = container.mainContext
    let engine = ActiveWorkoutEngine()

    // Arrange the exact failing local workflow from the audit.
    // Act through ActiveWorkoutEngine methods.
    // Assert the release-critical expected state.
}
```

For persistence issues, add a test to `LiftingLogTests/ModelPersistenceTests.swift`:

```swift
func testDescriptivePersistenceBlockerBehavior() throws {
    let container = try SwiftDataTestSupport.makeInMemoryContainer()
    let context = container.mainContext

    // Arrange the SwiftData model graph that failed the audit.
    // Save and fetch through ModelContext.
    // Assert the graph, values, and relationships are intact.
}
```

For history issues, add a test to `LiftingLogTests/HistoryPersistenceTests.swift`:

```swift
func testDescriptiveHistoryBlockerBehavior() throws {
    let container = try SwiftDataTestSupport.makeInMemoryContainer()
    let context = container.mainContext

    // Arrange completed, active, or discarded sessions from the audit.
    // Build summaries or groups through existing history helpers.
    // Assert only release-eligible data appears.
}
```

For settings issues, add a test to `LiftingLogTests/SettingsTests.swift`:

```swift
func testDescriptiveSettingsBlockerBehavior() throws {
    let container = try SwiftDataTestSupport.makeInMemoryContainer()
    let context = container.mainContext
    try SeedDataService.seedIfNeeded(context: context)

    // Arrange settings and logged data from the audit.
    // Act through UserSettings or SettingsView-facing model methods.
    // Assert persisted values and converted data are correct.
}
```

For UI-only blockers, add a test to `LiftingLogUITests/LiftingLogUITests.swift`:

```swift
@MainActor
func testDescriptiveUIBlockerBehavior() {
    let app = makeApp()
    app.launch()

    // Reproduce the exact failing user workflow from the audit.
    // Assert the recovery path or final visible state.
}
```

Expected:

- The test name describes the behavior, not the implementation.
- The test fails before the fix for the same reason the audit found.

- [ ] **Step 2: Run the focused failing test**

Use XcodeBuildMCP with `extraArgs` narrowed to the test class or method.

Example for a unit test:

```json
{
  "tool": "mcp__xcodebuildmcp__test_sim",
  "arguments": {
    "progress": true,
    "extraArgs": [
      "-only-testing:LiftingLogTests/ActiveWorkoutEngineTests/testDescriptiveBlockerBehavior"
    ]
  }
}
```

Expected:

- FAIL before the implementation change.
- Failure matches the audited blocker.

- [ ] **Step 3: Implement the minimal fix**

Modify only the selected implementation owner file. Keep the change narrow:

```swift
// Prefer adding or adjusting the smallest existing method branch.
// Do not introduce sync metadata, auth state, export types, or broad architecture changes.
```

Expected:

- Code changes are directly tied to the failing test.
- Existing public behavior remains unchanged outside the blocker.

- [ ] **Step 4: Run the focused test again**

Use the same XcodeBuildMCP call from Step 2.

Expected:

- PASS after the implementation change.

- [ ] **Step 5: Run the relevant test target**

For unit-test fixes:

```json
{
  "tool": "mcp__xcodebuildmcp__test_sim",
  "arguments": {
    "progress": true,
    "extraArgs": [
      "-only-testing:LiftingLogTests"
    ]
  }
}
```

For UI-test fixes:

```json
{
  "tool": "mcp__xcodebuildmcp__test_sim",
  "arguments": {
    "progress": true,
    "extraArgs": [
      "-only-testing:LiftingLogUITests"
    ]
  }
}
```

Expected:

- Relevant target passes.

- [ ] **Step 6: Update the audit report with the fix**

Edit `docs/audits/2026-05-24-local-release-baseline-audit.md`:

- Add the failing test name.
- Add the implementation file changed.
- Add the verification result.
- Mark the finding action as `Fixed in this issue`.

Expected:

- The report clearly links the blocker, fix, and verification.

- [ ] **Step 7: Commit the blocker fix**

Run:

```bash
git status --short
git add docs/audits/2026-05-24-local-release-baseline-audit.md LiftingLog LiftingLogTests LiftingLogUITests
git commit -m "Fix local release baseline blocker"
```

Expected:

- Commit contains only the audit report plus files directly required for the blocker fix.
- If multiple unrelated blockers exist, commit each blocker separately with a specific commit message.

## Task 9: Final Verification

**Files:**

- Update: `docs/audits/2026-05-24-local-release-baseline-audit.md`

- [ ] **Step 1: Run the full suite with XcodeBuildMCP**

MCP call:

```json
{
  "tool": "mcp__xcodebuildmcp__test_sim",
  "arguments": {
    "progress": true
  }
}
```

Expected:

- Full suite passes.
- If it fails, classify the new failure through Task 7 before making any further code change.

- [ ] **Step 2: Re-run manual workflows touched by any blocker fix**

Manual simulator actions:

- Re-run the exact failed workflow from Task 5.
- Re-run any adjacent workflow that shares the same implementation owner file.

Expected:

- The original blocker is fixed.
- Adjacent local workflow still behaves as expected.

- [ ] **Step 3: Update final audit report verification section**

Edit `docs/audits/2026-05-24-local-release-baseline-audit.md`:

- Record final full-suite result.
- Record manual retest results.
- Record remaining non-blocking follow-up notes.

Expected:

- Audit report has final status and no stale pre-fix failure status.

- [ ] **Step 4: Commit final audit report updates if needed**

Run only if Task 9 changed the report after the last commit.

```bash
git add docs/audits/2026-05-24-local-release-baseline-audit.md
git commit -m "Update local baseline audit verification"
```

Expected:

- Final report state is committed.

## Task 10: Final Handoff

**Files:**

- Read: `docs/audits/2026-05-24-local-release-baseline-audit.md`

- [ ] **Step 1: Confirm final git state**

Run:

```bash
git status --short --branch
git log --oneline -5
```

Expected:

- Worktree is clean except for unrelated user changes if they existed before execution.
- Recent commits include the audit report and any blocker fixes.

- [ ] **Step 2: Summarize outcome**

Final response must include:

- Audit result: pass, pass with follow-ups, or blocked.
- XcodeBuildMCP verification result.
- Manual verification result.
- Blocker fixes made, if any.
- Follow-up notes for non-blocking gaps.
- Links to the audit report and changed files.

Expected:

- User can decide whether issue #3 is ready to close or needs follow-up work.

## Self-Review

- Spec coverage: The plan covers workout creation, active editing, finish/discard/delete, history, exercise library, settings, SwiftData persistence, automated tests, manual verification, blocker classification, and small blocker fixes.
- Placeholder scan: The plan does not contain unfinished marker text or unscoped implementation instructions. Variable audit results are explicitly recorded during execution as concrete observed results.
- Type consistency: File names, test target names, scheme, project, branch, and XcodeBuildMCP tool names match the inspected repository and available MCP tools.
