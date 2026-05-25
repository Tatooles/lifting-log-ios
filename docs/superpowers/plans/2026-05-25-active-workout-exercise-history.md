# Active Workout Exercise History Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a header shortcut from each active workout exercise to a quick read-only history sheet, with a full-history action that deep-links into the History tab’s exercise detail.

**Architecture:** Keep the quick reference UI local to the workout flow while preserving the History tab as the canonical full-history surface. Add small, testable data/navigation helpers, reuse shared exercise-history session rendering where practical, then wire the active workout card to present the sheet and route to full history.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, XCTest, XcodeGen project layout.

---

## File Structure

- Create `LiftingLog/Features/History/ExerciseHistoryRoute.swift`
  - Holds a `Hashable` route value for exercise-history deep links, including linked exercise id and snapshot-name fallback.
- Modify `LiftingLog/Features/History/ExerciseHistorySummary.swift`
  - Add a route initializer/helper so workout code can derive a target from a `LoggedExercise`.
- Modify `LiftingLog/Features/History/ExerciseHistorySessionGroup.swift`
  - Add reusable recent-group helper and public note trimming on set entries/groups if needed.
- Create `LiftingLog/Features/History/ExerciseHistorySessionGroupCard.swift`
  - Shared session-group card renderer used by full detail and quick sheet.
- Modify `LiftingLog/Features/History/ExerciseHistoryDetailView.swift`
  - Use the shared group card.
- Modify `LiftingLog/App/AppNavigationState.swift`
  - Add history-route state and helper methods for full-history navigation.
- Modify `LiftingLog/App/AppShellView.swift`
  - Give the History tab a path binding driven by `AppNavigationState`.
- Modify `LiftingLog/Features/History/HistoryView.swift`
  - Bind route-driven navigation and open the requested exercise detail when present.
- Create `LiftingLog/Features/Workout/ExerciseQuickHistorySheet.swift`
  - Quick-history sheet for the active workout flow.
- Modify `LiftingLog/Features/Workout/ExerciseCardView.swift`
  - Add the header history button and action closure.
- Modify `LiftingLog/Features/Workout/WorkoutSessionView.swift`
  - Own selected exercise sheet state and pass full-history navigation callback.
- Modify `LiftingLogTests/HistoryPersistenceTests.swift`
  - Add data helper tests for route matching, recent cap, and notes.
- Create `LiftingLogTests/AppNavigationStateTests.swift`
  - Add navigation route tests.
- Modify `LiftingLogUITests/LiftingLogUITests.swift` only if a focused UI test is practical after implementation; otherwise rely on unit tests and build verification.

## Commands

- Generate project if `project.yml` changes: `xcodegen generate`
- Unit tests: `xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -only-testing:LiftingLogTests -derivedDataPath /private/tmp/codex-ios-app-derived-data`
- Full tests when complete: `xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -derivedDataPath /private/tmp/codex-ios-app-derived-data`

## Task 1: History Route And Recent Group Data

**Files:**
- Create: `LiftingLog/Features/History/ExerciseHistoryRoute.swift`
- Modify: `LiftingLog/Features/History/ExerciseHistorySummary.swift`
- Modify: `LiftingLog/Features/History/ExerciseHistorySessionGroup.swift`
- Modify: `LiftingLogTests/HistoryPersistenceTests.swift`

- [ ] **Step 1: Write failing tests for route creation, route matching, recent cap, and notes**

Add these tests to `LiftingLogTests/HistoryPersistenceTests.swift` before the private helper:

```swift
    func testExerciseHistoryRoutePrefersExerciseID() throws {
        let exerciseID = UUID()
        let exercise = Exercise(id: exerciseID, name: "Bench Press", category: .strength, equipment: .barbell, primaryMuscle: "Chest")
        let loggedExercise = LoggedExercise(orderIndex: 0, exercise: exercise, exerciseSnapshotName: "Bench Snapshot")

        let route = ExerciseHistoryRoute(loggedExercise: loggedExercise)

        XCTAssertEqual(route.exerciseID, exerciseID)
        XCTAssertEqual(route.name, "Bench Snapshot")
    }

    func testExerciseHistoryRouteFallsBackToSnapshotName() throws {
        let loggedExercise = LoggedExercise(orderIndex: 0, exercise: nil, exerciseSnapshotName: "Incline DB Press")

        let route = ExerciseHistoryRoute(loggedExercise: loggedExercise)

        XCTAssertNil(route.exerciseID)
        XCTAssertEqual(route.name, "Incline DB Press")
        XCTAssertEqual(route.id, "snapshot-incline db press")
    }

    func testExerciseHistorySummaryCanBeFoundFromRoute() throws {
        let exercise = Exercise(name: "Bench Press", category: .strength, equipment: .barbell, primaryMuscle: "Chest")
        let session = WorkoutSession(title: "Push", startedAt: .now, status: .completed, source: .blank)
        let loggedExercise = LoggedExercise(orderIndex: 0, exercise: exercise, exerciseSnapshotName: "Bench Press")
        loggedExercise.sets = [LoggedSet(orderIndex: 0, weight: 185, reps: 5, rpe: 8, isCompleted: true)]
        session.loggedExercises = [loggedExercise]

        let route = ExerciseHistoryRoute(loggedExercise: loggedExercise)
        let summaries = ExerciseHistorySummary.makeSummaries(from: [session])

        XCTAssertEqual(ExerciseHistorySummary.find(in: summaries, matching: route)?.name, "Bench Press")
    }

    func testRecentExerciseHistoryGroupsCapToThreeNewestSessions() throws {
        let exercise = Exercise(name: "Bench Press", category: .strength, equipment: .barbell, primaryMuscle: "Chest")
        let sessions = (1...4).map { index in
            let session = WorkoutSession(
                title: "Push \(index)",
                startedAt: Date(timeIntervalSince1970: TimeInterval(index)),
                status: .completed,
                source: .blank
            )
            let loggedExercise = LoggedExercise(orderIndex: 0, exercise: exercise, exerciseSnapshotName: exercise.name)
            loggedExercise.sets = [LoggedSet(orderIndex: 0, weight: Double(100 + index), reps: 5, rpe: 8, isCompleted: true)]
            session.loggedExercises = [loggedExercise]
            return session
        }
        let summary = try XCTUnwrap(ExerciseHistorySummary.makeSummaries(from: sessions).first)

        let groups = ExerciseHistorySessionGroup.recentGroups(from: sessions, matching: summary, limit: 3)

        XCTAssertEqual(groups.map(\.title), ["Push 4", "Push 3", "Push 2"])
    }

    func testExerciseHistoryGroupExposesTrimmedExerciseNotes() throws {
        let exercise = Exercise(name: "Bench Press", category: .strength, equipment: .barbell, primaryMuscle: "Chest")
        let session = WorkoutSession(title: "Push", startedAt: .now, status: .completed, source: .blank)
        let loggedExercise = LoggedExercise(orderIndex: 0, exercise: exercise, exerciseSnapshotName: exercise.name, notes: "  Felt strong  ")
        loggedExercise.sets = [LoggedSet(orderIndex: 0, weight: 185, reps: 5, rpe: 8, isCompleted: true)]
        session.loggedExercises = [loggedExercise]
        let summary = try XCTUnwrap(ExerciseHistorySummary.makeSummaries(from: [session]).first)

        let group = try XCTUnwrap(ExerciseHistorySessionGroup.makeGroups(from: [session], matching: summary).first)

        XCTAssertEqual(group.exerciseNotes, "Felt strong")
    }
```

- [ ] **Step 2: Run the targeted tests and verify they fail**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -only-testing:LiftingLogTests/HistoryPersistenceTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: FAIL because `ExerciseHistoryRoute`, `ExerciseHistorySummary.find`, `ExerciseHistorySessionGroup.recentGroups`, and `exerciseNotes` do not exist yet.

- [ ] **Step 3: Add `ExerciseHistoryRoute`**

Create `LiftingLog/Features/History/ExerciseHistoryRoute.swift`:

```swift
import Foundation

struct ExerciseHistoryRoute: Hashable, Identifiable {
    let exerciseID: UUID?
    let name: String

    var id: String {
        if let exerciseID {
            return "exercise-\(exerciseID.uuidString)"
        }

        return "snapshot-\(name.lowercased())"
    }

    init(exerciseID: UUID?, name: String) {
        self.exerciseID = exerciseID
        self.name = name
    }

    init(summary: ExerciseHistorySummary) {
        self.init(exerciseID: summary.exerciseID, name: summary.name)
    }

    init(loggedExercise: LoggedExercise) {
        self.init(exerciseID: loggedExercise.exercise?.id, name: loggedExercise.exerciseSnapshotName)
    }
}
```

- [ ] **Step 4: Add summary lookup and recent group helpers**

In `ExerciseHistorySummary.swift`, add this static method inside `ExerciseHistorySummary`:

```swift
    static func find(in summaries: [ExerciseHistorySummary], matching route: ExerciseHistoryRoute) -> ExerciseHistorySummary? {
        summaries.first { summary in
            if let exerciseID = route.exerciseID {
                return summary.exerciseID == exerciseID
            }

            return summary.exerciseID == nil && summary.name.caseInsensitiveCompare(route.name) == .orderedSame
        }
    }
```

In `ExerciseHistorySessionGroup.swift`, add the `exerciseNotes` computed property and `recentGroups` helper inside `ExerciseHistorySessionGroup`:

```swift
    var exerciseNotes: String? {
        let notes = setEntries
            .map(\.loggedExercise)
            .first?
            .notes
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return notes.isEmpty ? nil : notes
    }

    static func recentGroups(
        from sessions: [WorkoutSession],
        matching summary: ExerciseHistorySummary,
        limit: Int = 3
    ) -> [ExerciseHistorySessionGroup] {
        Array(makeGroups(from: sessions, matching: summary).prefix(limit))
    }
```

- [ ] **Step 5: Run tests and commit**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -only-testing:LiftingLogTests/HistoryPersistenceTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: PASS for `HistoryPersistenceTests`.

Commit:

```bash
git add LiftingLog/Features/History/ExerciseHistoryRoute.swift LiftingLog/Features/History/ExerciseHistorySummary.swift LiftingLog/Features/History/ExerciseHistorySessionGroup.swift LiftingLogTests/HistoryPersistenceTests.swift
git commit -m "Add exercise history route data helpers"
```

## Task 2: Shared Exercise History Session Card

**Files:**
- Create: `LiftingLog/Features/History/ExerciseHistorySessionGroupCard.swift`
- Modify: `LiftingLog/Features/History/ExerciseHistoryDetailView.swift`

- [ ] **Step 1: Create shared card view**

Create `LiftingLog/Features/History/ExerciseHistorySessionGroupCard.swift`:

```swift
import SwiftUI

struct ExerciseHistorySessionGroupCard: View {
    let group: ExerciseHistorySessionGroup
    var showsExerciseNotes: Bool = true

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                header
                setEntries
                exerciseNotes
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(group.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(WorkoutFormatters.compactDate(group.startedAt))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            Text(setCountLabel(for: group.completedSetCount))
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AppTheme.surfaceMuted)
                .clipShape(Capsule())
        }
    }

    private var setEntries: some View {
        VStack(spacing: 8) {
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
        }
    }

    @ViewBuilder
    private var exerciseNotes: some View {
        if showsExerciseNotes, let notes = group.exerciseNotes {
            VStack(alignment: .leading, spacing: 6) {
                Divider()
                    .overlay(AppTheme.border)
                Text("NOTES")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(AppTheme.textTertiary)
                Text(notes)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func setSummary(for set: LoggedSet) -> String {
        let weight = set.weight.map(WorkoutFormatters.number) ?? "-"
        let reps = set.reps.map(String.init) ?? "-"

        if let rpe = set.rpe {
            return "\(weight) x \(reps) @ \(WorkoutFormatters.number(rpe))"
        }

        return "\(weight) x \(reps)"
    }

    private func setCountLabel(for count: Int) -> String {
        count == 1 ? "1 set" : "\(count) sets"
    }
}
```

- [ ] **Step 2: Refactor full detail view to use shared card**

In `ExerciseHistoryDetailView.swift`, replace the `ForEach(sessionGroups)` block with:

```swift
                ForEach(sessionGroups) { group in
                    ExerciseHistorySessionGroupCard(group: group)
                }
```

Then remove the now-unused private `sessionGroupCard`, `setSummary`, and `setCountLabel` methods from `ExerciseHistoryDetailView`.

- [ ] **Step 3: Build and commit**

Run:

```bash
xcodebuild build -project LiftingLog.xcodeproj -scheme LiftingLog -destination generic/platform=iOS\ Simulator -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: BUILD SUCCEEDED.

Commit:

```bash
git add LiftingLog/Features/History/ExerciseHistorySessionGroupCard.swift LiftingLog/Features/History/ExerciseHistoryDetailView.swift
git commit -m "Share exercise history session card"
```

## Task 3: History Tab Deep-Link Navigation

**Files:**
- Modify: `LiftingLog/App/AppNavigationState.swift`
- Modify: `LiftingLog/App/AppShellView.swift`
- Modify: `LiftingLog/Features/History/HistoryView.swift`
- Create: `LiftingLogTests/AppNavigationStateTests.swift`

- [ ] **Step 1: Write navigation-state tests**

Create `LiftingLogTests/AppNavigationStateTests.swift`:

```swift
import XCTest
@testable import LiftingLog

@MainActor
final class AppNavigationStateTests: XCTestCase {
    func testOpenExerciseHistorySelectsHistoryExercisesAndStoresRoute() {
        let navigationState = AppNavigationState(selectedTab: .workout, historyMode: .workouts)
        let route = ExerciseHistoryRoute(exerciseID: UUID(), name: "Bench Press")

        navigationState.openExerciseHistory(route)

        XCTAssertEqual(navigationState.selectedTab, .history)
        XCTAssertEqual(navigationState.historyMode, .exercises)
        XCTAssertEqual(navigationState.historyPath, [.exercise(route)])
    }

    func testClearHistoryPathRemovesRoute() {
        let route = ExerciseHistoryRoute(exerciseID: UUID(), name: "Bench Press")
        let navigationState = AppNavigationState(selectedTab: .history, historyMode: .exercises)
        navigationState.openExerciseHistory(route)

        navigationState.historyPath = []

        XCTAssertTrue(navigationState.historyPath.isEmpty)
    }
}
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -only-testing:LiftingLogTests/AppNavigationStateTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: FAIL because `HistoryRoute`, `historyPath`, and `openExerciseHistory` do not exist.

- [ ] **Step 3: Add navigation route state**

In `AppNavigationState.swift`, add this enum after `HistoryMode`:

```swift
enum HistoryRoute: Hashable {
    case exercise(ExerciseHistoryRoute)
}
```

Add a property and helper to `AppNavigationState`:

```swift
    var historyPath: [HistoryRoute]
```

Update the initializer:

```swift
    init(
        selectedTab: AppTab = .workout,
        historyMode: HistoryMode = .workouts,
        historyPath: [HistoryRoute] = []
    ) {
        self.selectedTab = selectedTab
        self.historyMode = historyMode
        self.historyPath = historyPath
    }
```

Add the helper:

```swift
    func openExerciseHistory(_ route: ExerciseHistoryRoute) {
        selectedTab = .history
        historyMode = .exercises
        historyPath = [.exercise(route)]
    }
```

- [ ] **Step 4: Bind the History navigation stack**

In `AppShellView.swift`, replace the History tab `NavigationStack` with:

```swift
            NavigationStack(path: $navigationState.historyPath) {
                HistoryView(navigationState: navigationState)
            }
```

In `HistoryView.swift`, add a `navigationDestination` modifier after `.toolbar(.hidden, for: .navigationBar)`:

```swift
        .navigationDestination(for: HistoryRoute.self) { route in
            switch route {
            case .exercise(let exerciseRoute):
                if let summary = ExerciseHistorySummary.find(in: exerciseSummaries, matching: exerciseRoute) {
                    ExerciseHistoryDetailView(summary: summary)
                } else {
                    EmptyStateView(
                        title: "No Exercise History",
                        message: "Completed sets for this exercise will appear here."
                    )
                    .background(AppTheme.subtleBackground.ignoresSafeArea())
                }
            }
        }
```

- [ ] **Step 5: Run tests and commit**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -only-testing:LiftingLogTests/AppNavigationStateTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: PASS for `AppNavigationStateTests`.

Commit:

```bash
git add LiftingLog/App/AppNavigationState.swift LiftingLog/App/AppShellView.swift LiftingLog/Features/History/HistoryView.swift LiftingLogTests/AppNavigationStateTests.swift
git commit -m "Add exercise history deep link navigation"
```

## Task 4: Quick History Sheet And Workout Header Action

**Files:**
- Create: `LiftingLog/Features/Workout/ExerciseQuickHistorySheet.swift`
- Modify: `LiftingLog/Features/Workout/ExerciseCardView.swift`
- Modify: `LiftingLog/Features/Workout/WorkoutSessionView.swift`

- [ ] **Step 1: Create quick-history sheet**

Create `LiftingLog/Features/Workout/ExerciseQuickHistorySheet.swift`:

```swift
import SwiftData
import SwiftUI

struct ExerciseQuickHistorySheet: View {
    let loggedExercise: LoggedExercise
    let openFullHistory: (ExerciseHistoryRoute) -> Void
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]

    private var route: ExerciseHistoryRoute {
        ExerciseHistoryRoute(loggedExercise: loggedExercise)
    }

    private var completedSessions: [WorkoutSession] {
        sessions.filter { $0.status == .completed }
    }

    private var summary: ExerciseHistorySummary? {
        ExerciseHistorySummary.find(
            in: ExerciseHistorySummary.makeSummaries(from: completedSessions),
            matching: route
        )
    }

    private var recentGroups: [ExerciseHistorySessionGroup] {
        guard let summary else { return [] }
        return ExerciseHistorySessionGroup.recentGroups(from: completedSessions, matching: summary, limit: 3)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    if recentGroups.isEmpty {
                        EmptyStateView(
                            title: "No History Yet",
                            message: "Completed workouts for this exercise will appear here."
                        )
                    } else {
                        ForEach(recentGroups) { group in
                            ExerciseHistorySessionGroupCard(group: group)
                        }
                    }
                }
                .padding(AppTheme.shellPadding)
            }
            .background(AppTheme.subtleBackground.ignoresSafeArea())
            .navigationTitle(loggedExercise.exerciseSnapshotName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                if summary != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Full History") {
                            dismiss()
                            openFullHistory(route)
                        }
                        .accessibilityIdentifier("FullExerciseHistoryButton")
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 2: Add card header action**

In `ExerciseCardView.swift`, add this stored property after `focusedField`:

```swift
    let viewHistory: () -> Void
```

In the header `HStack`, add this button between the collapsible title button and the trash button:

```swift
                    Button(action: viewHistory) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("View exercise history")
                    .accessibilityIdentifier("ExerciseHistoryButton-\(exerciseIndex)")
```

- [ ] **Step 3: Wire sheet state and deep-link callback**

In `WorkoutSessionView.swift`, add state:

```swift
    @State private var selectedHistoryExercise: LoggedExercise?
```

Update the `ExerciseCardView` initializer:

```swift
                            ExerciseCardView(
                                loggedExercise: loggedExercise,
                                exerciseIndex: exerciseIndex,
                                engine: engine,
                                isCollapsed: isCollapsedBinding(for: loggedExercise),
                                focusedField: $focusedField,
                                viewHistory: {
                                    selectedHistoryExercise = loggedExercise
                                }
                            )
```

Add a sheet modifier after the existing add-exercise sheet:

```swift
        .sheet(item: $selectedHistoryExercise) { loggedExercise in
            ExerciseQuickHistorySheet(loggedExercise: loggedExercise) { _ in
                selectedHistoryExercise = nil
            }
        }
```

- [ ] **Step 4: Pass app navigation into the workout session**

Modify `WorkoutSessionView` to accept navigation state:

```swift
    @Bindable var navigationState: AppNavigationState
```

Update `AppShellView.swift` where `WorkoutSessionView` is created:

```swift
                    WorkoutSessionView(
                        session: activeSession,
                        navigationState: navigationState,
                        engine: activeWorkoutEngine
                    )
```

Update the sheet callback in `WorkoutSessionView.swift`:

```swift
        .sheet(item: $selectedHistoryExercise) { loggedExercise in
            ExerciseQuickHistorySheet(loggedExercise: loggedExercise) { route in
                selectedHistoryExercise = nil
                navigationState.openExerciseHistory(route)
            }
        }
```

- [ ] **Step 5: Build and commit**

Run:

```bash
xcodebuild build -project LiftingLog.xcodeproj -scheme LiftingLog -destination generic/platform=iOS\ Simulator -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: BUILD SUCCEEDED.

Commit:

```bash
git add LiftingLog/Features/Workout/ExerciseQuickHistorySheet.swift LiftingLog/Features/Workout/ExerciseCardView.swift LiftingLog/Features/Workout/WorkoutSessionView.swift LiftingLog/App/AppShellView.swift
git commit -m "Add active workout exercise history sheet"
```

## Task 5: Final Verification And Polish

**Files:**
- Modify only files required to fix build/test/UI issues found during verification.

- [ ] **Step 1: Run focused unit tests**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -only-testing:LiftingLogTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: PASS for all unit tests.

- [ ] **Step 2: Run full test suite**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: PASS for unit and UI tests.

- [ ] **Step 3: Fix any verification failures minimally**

If a compile error references initializer argument order, update call sites to match the final initializer signature. If a SwiftUI sheet/dismiss timing issue appears, keep the callback synchronous and set `selectedHistoryExercise = nil` before calling `navigationState.openExerciseHistory(route)`.

- [ ] **Step 4: Commit verification fixes if needed**

If Step 3 changed `LiftingLog/Features/Workout/ExerciseQuickHistorySheet.swift`, `LiftingLog/Features/Workout/ExerciseCardView.swift`, `LiftingLog/Features/Workout/WorkoutSessionView.swift`, `LiftingLog/App/AppShellView.swift`, `LiftingLog/App/AppNavigationState.swift`, `LiftingLog/Features/History/HistoryView.swift`, or test files, run:

```bash
git add LiftingLog/Features/Workout/ExerciseQuickHistorySheet.swift LiftingLog/Features/Workout/ExerciseCardView.swift LiftingLog/Features/Workout/WorkoutSessionView.swift LiftingLog/App/AppShellView.swift LiftingLog/App/AppNavigationState.swift LiftingLog/Features/History/HistoryView.swift LiftingLogTests
git commit -m "Polish exercise history shortcut"
```

If no files changed, do not create an empty commit.
