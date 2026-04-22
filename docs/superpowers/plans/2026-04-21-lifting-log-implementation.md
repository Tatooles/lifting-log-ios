# Lifting Log Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native iOS 17+ SwiftUI app named `Lifting Log` that recreates the supplied workout logging design with mock data, reusable components, and a clean app structure.

**Architecture:** Use a single-app SwiftUI target with an `@Observable` root store, feature folders for Workout, History, and Profile, and a shared design system for colors, typography, spacing, and reusable surfaces. Use XcodeGen to create the Xcode project from source so the repo stays clean and reproducible, and cover stateful behavior with Swift Testing plus one UI smoke test.

**Tech Stack:** Swift 6, SwiftUI, Observation, Swift Testing, XCTest UI tests, XcodeGen, Xcode 26+

---

## File Map

### Create

- `project.yml` — XcodeGen project definition for app, unit tests, and UI tests
- `LiftingLog/App/LiftingLogApp.swift` — app entry point and root store injection
- `LiftingLog/App/AppShellView.swift` — `TabView`, navigation stacks, and tab routing
- `LiftingLog/Shared/DesignSystem/AppTheme.swift` — colors, gradients, spacing, typography helpers, shadows, materials
- `LiftingLog/Shared/Models/WorkoutModels.swift` — workout session, exercise, set, and history models
- `LiftingLog/Shared/Models/ViewState.swift` — loading, loaded, empty, and error state enum
- `LiftingLog/Shared/Mocks/MockRepository.swift` — mock history and active workout fixtures
- `LiftingLog/Shared/Stores/AppStore.swift` — root app state and mutation methods
- `LiftingLog/Shared/Components/SurfaceCard.swift` — reusable card shell and section headers
- `LiftingLog/Shared/Components/StateViews.swift` — loading, empty, and error states
- `LiftingLog/Features/Workout/WorkoutSessionView.swift` — main logging screen
- `LiftingLog/Features/Workout/WorkoutHeaderView.swift` — sticky timer/progress/finish header
- `LiftingLog/Features/Workout/ExerciseCardView.swift` — collapsible exercise card
- `LiftingLog/Features/Workout/SetRowView.swift` — set input row and completion toggle
- `LiftingLog/Features/Workout/FinishWorkoutSheet.swift` — native finish summary sheet
- `LiftingLog/Features/History/HistoryView.swift` — segmented history screen
- `LiftingLog/Features/History/WorkoutHistoryRow.swift` — workout history row
- `LiftingLog/Features/History/ExerciseHistoryRow.swift` — exercise history row
- `LiftingLog/Features/History/WorkoutHistoryDetailView.swift` — native workout detail placeholder
- `LiftingLog/Features/History/ExerciseHistoryDetailView.swift` — native exercise detail placeholder
- `LiftingLog/Features/Profile/ProfileView.swift` — polished placeholder profile screen
- `LiftingLogTests/AppStoreTests.swift` — state mutation and data flow tests
- `LiftingLogTests/FormattingTests.swift` — timer/date/summary formatting tests
- `LiftingLogUITests/LiftingLogUITests.swift` — launch and primary navigation smoke test

### Modify

- `.gitignore` — keep as-is unless Xcode adds a new generated path that needs ignoring

## Task 1: Scaffold The Native Project

**Files:**
- Create: `project.yml`
- Create: `LiftingLog/App/LiftingLogApp.swift`
- Create: `LiftingLog/App/AppShellView.swift`
- Create: `LiftingLogUITests/LiftingLogUITests.swift`

- [ ] **Step 1: Define the XcodeGen project**

```yaml
name: LiftingLog
options:
  bundleIdPrefix: com.kevintatooles
settings:
  base:
    PRODUCT_NAME: LiftingLog
    SWIFT_VERSION: 6.0
    IPHONEOS_DEPLOYMENT_TARGET: 17.0
    DEVELOPMENT_TEAM: ""
targets:
  LiftingLog:
    type: application
    platform: iOS
    deploymentTarget: "17.0"
    sources:
      - path: LiftingLog
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.kevintatooles.LiftingLog
        INFOPLIST_KEY_UIApplicationSceneManifest_Generation: true
        INFOPLIST_KEY_UILaunchScreen_Generation: true
        INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone: UIInterfaceOrientationPortrait
        GENERATE_INFOPLIST_FILE: YES
    scheme:
      testTargets:
        - LiftingLogTests
        - LiftingLogUITests
  LiftingLogTests:
    type: bundle.unit-test
    platform: iOS
    deploymentTarget: "17.0"
    sources:
      - path: LiftingLogTests
    dependencies:
      - target: LiftingLog
    settings:
      base:
        GENERATE_INFOPLIST_FILE: YES
  LiftingLogUITests:
    type: bundle.ui-testing
    platform: iOS
    deploymentTarget: "17.0"
    sources:
      - path: LiftingLogUITests
    dependencies:
      - target: LiftingLog
    settings:
      base:
        GENERATE_INFOPLIST_FILE: YES
```

- [ ] **Step 2: Generate the project**

Run: `command -v xcodegen >/dev/null || brew install xcodegen`

Run: `xcodegen generate`

Expected: output includes `Generating project...` and `Project generated at /Users/kevintatooles/Desktop/Projects/codex-ios-app/LiftingLog.xcodeproj`

- [ ] **Step 3: Create the minimal app entry point and shell placeholders**

```swift
// LiftingLog/App/LiftingLogApp.swift
import SwiftUI

@main
struct LiftingLogApp: App {
    @State private var store = AppStore.preview

    var body: some Scene {
        WindowGroup {
            AppShellView(store: store)
        }
    }
}
```

```swift
// LiftingLog/App/AppShellView.swift
import SwiftUI

struct AppShellView: View {
    @Bindable var store: AppStore

    var body: some View {
        TabView(selection: $store.selectedTab) {
            NavigationStack {
                Text("History Placeholder")
            }
            .tag(AppTab.history)

            NavigationStack {
                Text("Workout Placeholder")
            }
            .tag(AppTab.workout)

            NavigationStack {
                Text("Profile Placeholder")
            }
            .tag(AppTab.profile)
        }
    }
}
```

- [ ] **Step 4: Add a UI smoke test that fails until accessibility labels exist**

```swift
// LiftingLogUITests/LiftingLogUITests.swift
import XCTest

final class LiftingLogUITests: XCTestCase {
    func testAppLaunchesIntoWorkoutTab() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["Workout Placeholder"].waitForExistence(timeout: 3))
    }
}
```

- [ ] **Step 5: Run the UI test to verify the scaffold works**

Run: `xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:LiftingLogUITests`

Expected: PASS with `Test Case '-[LiftingLogUITests testAppLaunchesIntoWorkoutTab]' passed`

- [ ] **Step 6: Commit**

```bash
git add project.yml LiftingLog/App/LiftingLogApp.swift LiftingLog/App/AppShellView.swift LiftingLogUITests/LiftingLogUITests.swift LiftingLog.xcodeproj
git commit -m "chore: scaffold lifting log app project"
```

## Task 2: Build The Design System, Models, And Mock Store

**Files:**
- Create: `LiftingLog/Shared/DesignSystem/AppTheme.swift`
- Create: `LiftingLog/Shared/Models/WorkoutModels.swift`
- Create: `LiftingLog/Shared/Models/ViewState.swift`
- Create: `LiftingLog/Shared/Mocks/MockRepository.swift`
- Create: `LiftingLog/Shared/Stores/AppStore.swift`
- Create: `LiftingLogTests/AppStoreTests.swift`
- Create: `LiftingLogTests/FormattingTests.swift`

- [ ] **Step 1: Write the failing store and formatting tests**

```swift
// LiftingLogTests/AppStoreTests.swift
import Testing
@testable import LiftingLog

struct AppStoreTests {
    @Test func togglingSetUpdatesCompletionCounts() {
        let store = AppStore.preview
        let exerciseID = try! #require(store.activeWorkout.exercises.first?.id)
        let setID = try! #require(store.activeWorkout.exercises.first?.sets.last?.id)

        store.toggleSetDone(exerciseID: exerciseID, setID: setID)

        #expect(store.completedSetCount == 3)
        #expect(store.activeWorkout.exercises[0].sets[2].isDone == true)
    }

    @Test func addingExerciseAppendsEmptyExercise() {
        let store = AppStore.preview

        store.addExercise()

        #expect(store.activeWorkout.exercises.last?.name == "New Exercise")
        #expect(store.activeWorkout.exercises.last?.sets.count == 1)
    }
}
```

```swift
// LiftingLogTests/FormattingTests.swift
import Testing
@testable import LiftingLog

struct FormattingTests {
    @Test func durationFormatterUsesHourStyleWhenNeeded() {
        #expect(AppTheme.formatDuration(3674) == "1:01:14")
    }

    @Test func durationFormatterUsesMinuteStyleForShorterValues() {
        #expect(AppTheme.formatDuration(76) == "01:16")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:LiftingLogTests`

Expected: FAIL with messages indicating `Cannot find 'AppStore' in scope` and `Cannot find 'AppTheme' in scope`

- [ ] **Step 3: Implement the design tokens and data model layer**

```swift
// LiftingLog/Shared/Models/WorkoutModels.swift
import Foundation

enum AppTab: Hashable {
    case history
    case workout
    case profile
}

enum HistoryMode: String, CaseIterable, Identifiable {
    case workouts
    case exercises

    var id: Self { self }
}

struct ExerciseSet: Identifiable, Equatable {
    let id: UUID
    var weight: String
    var reps: String
    var rpe: String
    var isDone: Bool
}

struct WorkoutExercise: Identifiable, Equatable {
    let id: UUID
    var name: String
    var isCollapsed: Bool
    var sets: [ExerciseSet]
    var notes: String
}

struct WorkoutSession: Equatable {
    var name: String
    var date: Date
    var elapsedSeconds: Int
    var exercises: [WorkoutExercise]
    var workoutNotes: String
}

struct WorkoutHistoryItem: Identifiable, Equatable {
    let id: UUID
    var name: String
    var dateLabel: String
    var durationLabel: String
    var exerciseCount: Int
    var setCount: Int
}

struct ExerciseHistoryItem: Identifiable, Equatable {
    let id: UUID
    var name: String
    var lastPerformedLabel: String
    var completionCount: Int
}
```

```swift
// LiftingLog/Shared/Models/ViewState.swift
enum ViewState<Value: Equatable>: Equatable {
    case loading
    case loaded(Value)
    case empty(message: String)
    case error(message: String)
}
```

```swift
// LiftingLog/Shared/DesignSystem/AppTheme.swift
import SwiftUI

enum AppTheme {
    static let background = Color(red: 13 / 255, green: 13 / 255, blue: 13 / 255)
    static let surface = Color(red: 34 / 255, green: 34 / 255, blue: 34 / 255)
    static let surfaceMuted = Color(red: 46 / 255, green: 46 / 255, blue: 46 / 255)
    static let surfaceStrong = Color(red: 56 / 255, green: 56 / 255, blue: 56 / 255)
    static let border = Color.white.opacity(0.12)
    static let borderStrong = Color.white.opacity(0.2)
    static let accent = Color(red: 192 / 255, green: 57 / 255, blue: 43 / 255)
    static let accentBright = Color(red: 232 / 255, green: 76 / 255, blue: 61 / 255)
    static let accentMuted = accent.opacity(0.18)
    static let textPrimary = Color(red: 240 / 255, green: 240 / 255, blue: 240 / 255)
    static let textSecondary = textPrimary.opacity(0.55)
    static let textTertiary = textPrimary.opacity(0.32)
    static let accentGradient = LinearGradient(colors: [accent, accentBright], startPoint: .topLeading, endPoint: .bottomTrailing)

    static func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainder = seconds % 60
        if hours > 0 {
            return "\(hours):\(String(format: "%02d", minutes)):\(String(format: "%02d", remainder))"
        }
        return "\(String(format: "%02d", minutes)):\(String(format: "%02d", remainder))"
    }
}
```

- [ ] **Step 4: Implement the mock repository and root store**

```swift
// LiftingLog/Shared/Mocks/MockRepository.swift
import Foundation

enum MockRepository {
    static let activeWorkout = WorkoutSession(
        name: "Lower Body A",
        date: .now,
        elapsedSeconds: 76,
        exercises: [
            WorkoutExercise(
                id: UUID(),
                name: "Back Squat",
                isCollapsed: false,
                sets: [
                    ExerciseSet(id: UUID(), weight: "225", reps: "5", rpe: "7", isDone: true),
                    ExerciseSet(id: UUID(), weight: "225", reps: "5", rpe: "7.5", isDone: true),
                    ExerciseSet(id: UUID(), weight: "225", reps: "5", rpe: "8", isDone: false)
                ],
                notes: ""
            )
        ],
        workoutNotes: ""
    )
}
```

```swift
// LiftingLog/Shared/Stores/AppStore.swift
import Foundation
import Observation

@Observable
final class AppStore {
    var selectedTab: AppTab = .workout
    var historyMode: HistoryMode = .workouts
    var activeWorkout: WorkoutSession
    var workoutHistoryState: ViewState<[WorkoutHistoryItem]>
    var exerciseHistoryState: ViewState<[ExerciseHistoryItem]>

    init(
        activeWorkout: WorkoutSession,
        workoutHistoryState: ViewState<[WorkoutHistoryItem]>,
        exerciseHistoryState: ViewState<[ExerciseHistoryItem]>
    ) {
        self.activeWorkout = activeWorkout
        self.workoutHistoryState = workoutHistoryState
        self.exerciseHistoryState = exerciseHistoryState
    }

    static let preview = AppStore(
        activeWorkout: MockRepository.activeWorkout,
        workoutHistoryState: .loading,
        exerciseHistoryState: .loading
    )

    var completedSetCount: Int {
        activeWorkout.exercises.flatMap(\.sets).filter(\.isDone).count
    }

    func toggleSetDone(exerciseID: UUID, setID: UUID) {
        guard let exerciseIndex = activeWorkout.exercises.firstIndex(where: { $0.id == exerciseID }),
              let setIndex = activeWorkout.exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID }) else { return }
        activeWorkout.exercises[exerciseIndex].sets[setIndex].isDone.toggle()
    }

    func addExercise() {
        activeWorkout.exercises.append(
            WorkoutExercise(
                id: UUID(),
                name: "New Exercise",
                isCollapsed: false,
                sets: [ExerciseSet(id: UUID(), weight: "", reps: "", rpe: "", isDone: false)],
                notes: ""
            )
        )
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:LiftingLogTests`

Expected: PASS with `Executed 4 tests, with 0 failures`

- [ ] **Step 6: Commit**

```bash
git add LiftingLog/Shared LiftingLogTests
git commit -m "feat: add lifting log design system and mock store"
```

## Task 3: Implement The Workout Screen And Reusable Surfaces

**Files:**
- Create: `LiftingLog/Shared/Components/SurfaceCard.swift`
- Create: `LiftingLog/Features/Workout/WorkoutSessionView.swift`
- Create: `LiftingLog/Features/Workout/WorkoutHeaderView.swift`
- Create: `LiftingLog/Features/Workout/ExerciseCardView.swift`
- Create: `LiftingLog/Features/Workout/SetRowView.swift`
- Modify: `LiftingLog/App/AppShellView.swift`
- Modify: `LiftingLogTests/AppStoreTests.swift`

- [ ] **Step 1: Write the failing tests for workout mutations**

```swift
@Test func addingSetCopiesLastWeightAndReps() {
    let store = AppStore.preview
    let exerciseID = try! #require(store.activeWorkout.exercises.first?.id)

    store.addSet(to: exerciseID)

    let sets = store.activeWorkout.exercises[0].sets
    #expect(sets.count == 4)
    #expect(sets.last?.weight == "225")
    #expect(sets.last?.reps == "5")
    #expect(sets.last?.rpe == "")
}

@Test func togglingCardCollapseUpdatesExerciseState() {
    let store = AppStore.preview
    let exerciseID = try! #require(store.activeWorkout.exercises.first?.id)

    store.toggleExerciseCollapsed(exerciseID)

    #expect(store.activeWorkout.exercises[0].isCollapsed == true)
}
```

- [ ] **Step 2: Run the targeted tests to verify they fail**

Run: `xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:LiftingLogTests/AppStoreTests`

Expected: FAIL with `Value of type 'AppStore' has no member 'addSet'`

- [ ] **Step 3: Implement the reusable surface and workout UI**

```swift
// LiftingLog/Shared/Components/SurfaceCard.swift
import SwiftUI

struct SurfaceCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(AppTheme.surface)
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(AppTheme.border))
            .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}
```

```swift
// LiftingLog/Features/Workout/WorkoutHeaderView.swift
import SwiftUI

struct WorkoutHeaderView: View {
    let elapsedSeconds: Int
    let completedSets: Int
    let totalSets: Int
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Label(AppTheme.formatDuration(elapsedSeconds), systemImage: "circle.fill")
                    .font(.system(size: 16, weight: .bold, design: .rounded).monospacedDigit())
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Sets")
                        Spacer()
                        Text("\(completedSets)/\(totalSets)")
                    }
                    ProgressView(value: totalSets == 0 ? 0 : Double(completedSets), total: Double(max(totalSets, 1)))
                        .tint(AppTheme.accentBright)
                }
                Button("Finish", action: onFinish)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial.opacity(0.9))
    }
}
```

```swift
// LiftingLog/Features/Workout/WorkoutSessionView.swift
import SwiftUI

struct WorkoutSessionView: View {
    @Bindable var store: AppStore
    @State private var isFinishSheetPresented = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Workout Name", text: $store.activeWorkout.name)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(store.activeWorkout.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(store.activeWorkout.exercises) { exercise in
                    ExerciseCardView(store: store, exercise: exercise)
                }

                Button(action: store.addExercise) {
                    Label("Add Exercise", systemImage: "plus")
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 140)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .safeAreaInset(edge: .top) {
            WorkoutHeaderView(
                elapsedSeconds: store.activeWorkout.elapsedSeconds,
                completedSets: store.completedSetCount,
                totalSets: store.totalSetCount
            ) {
                isFinishSheetPresented = true
            }
        }
        .sheet(isPresented: $isFinishSheetPresented) {
            FinishWorkoutSheet(store: store)
        }
    }
}
```

- [ ] **Step 4: Add the missing store mutations and wire the workout screen into the shell**

```swift
// AppStore additions
var totalSetCount: Int {
    activeWorkout.exercises.flatMap(\.sets).count
}

func toggleExerciseCollapsed(_ exerciseID: UUID) {
    guard let exerciseIndex = activeWorkout.exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
    activeWorkout.exercises[exerciseIndex].isCollapsed.toggle()
}

func addSet(to exerciseID: UUID) {
    guard let exerciseIndex = activeWorkout.exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
    let lastSet = activeWorkout.exercises[exerciseIndex].sets.last
    activeWorkout.exercises[exerciseIndex].sets.append(
        ExerciseSet(
            id: UUID(),
            weight: lastSet?.weight ?? "",
            reps: lastSet?.reps ?? "",
            rpe: "",
            isDone: false
        )
    )
}
```

```swift
// AppShellView.swift replacement body
var body: some View {
    TabView(selection: $store.selectedTab) {
        NavigationStack { HistoryView(store: store) }
            .tabItem { Label("History", systemImage: "clock") }
            .tag(AppTab.history)

        NavigationStack { WorkoutSessionView(store: store) }
            .tabItem { Label("Add Workout", systemImage: "plus.circle.fill") }
            .tag(AppTab.workout)

        NavigationStack { ProfileView() }
            .tabItem { Label("Profile", systemImage: "person") }
            .tag(AppTab.profile)
    }
    .preferredColorScheme(.dark)
}
```

- [ ] **Step 5: Run the targeted unit tests and UI smoke test**

Run: `xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:LiftingLogTests/AppStoreTests -only-testing:LiftingLogUITests`

Expected: PASS with the workout tab visible and no failing store assertions

- [ ] **Step 6: Commit**

```bash
git add LiftingLog/App/AppShellView.swift LiftingLog/Shared/Components/SurfaceCard.swift LiftingLog/Features/Workout LiftingLogTests/AppStoreTests.swift
git commit -m "feat: implement workout logging screen"
```

## Task 4: Implement History Lists, Detail Views, And Explicit View States

**Files:**
- Create: `LiftingLog/Shared/Components/StateViews.swift`
- Create: `LiftingLog/Features/History/HistoryView.swift`
- Create: `LiftingLog/Features/History/WorkoutHistoryRow.swift`
- Create: `LiftingLog/Features/History/ExerciseHistoryRow.swift`
- Create: `LiftingLog/Features/History/WorkoutHistoryDetailView.swift`
- Create: `LiftingLog/Features/History/ExerciseHistoryDetailView.swift`
- Modify: `LiftingLog/Shared/Mocks/MockRepository.swift`
- Modify: `LiftingLog/Shared/Stores/AppStore.swift`
- Modify: `LiftingLogUITests/LiftingLogUITests.swift`

- [ ] **Step 1: Write the failing tests for history loading**

```swift
@Test func loadingHistoryTransitionsToLoadedState() async {
    let store = AppStore.preview

    await store.loadHistory()

    guard case let .loaded(workouts) = store.workoutHistoryState else {
        Issue.record("Workout history was not loaded")
        return
    }
    #expect(workouts.count > 3)
}
```

- [ ] **Step 2: Run the failing test**

Run: `xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:LiftingLogTests/AppStoreTests`

Expected: FAIL with `Value of type 'AppStore' has no member 'loadHistory'`

- [ ] **Step 3: Implement the shared loading, empty, and error views**

```swift
// LiftingLog/Shared/Components/StateViews.swift
import SwiftUI

struct LoadingStateView: View {
    let title: String

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(title).foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
            Text(title).font(.headline)
            Text(message).foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
    }
}
```

- [ ] **Step 4: Implement mock history data, async loading, and the segmented history screen**

```swift
// MockRepository additions
static let workoutHistory: [WorkoutHistoryItem] = [
    .init(id: UUID(), name: "Lower Body A", dateLabel: "Mon, Apr 21, 2026", durationLabel: "1:02:14", exerciseCount: 4, setCount: 16),
    .init(id: UUID(), name: "Upper Body Push", dateLabel: "Sat, Apr 19, 2026", durationLabel: "48:33", exerciseCount: 5, setCount: 18)
]

static let exerciseHistory: [ExerciseHistoryItem] = [
    .init(id: UUID(), name: "Back Squat", lastPerformedLabel: "Apr 21, 2026", completionCount: 18),
    .init(id: UUID(), name: "Romanian Deadlift", lastPerformedLabel: "Apr 21, 2026", completionCount: 14)
]
```

```swift
// AppStore additions
@MainActor
func loadHistory() async {
    try? await Task.sleep(for: .milliseconds(200))
    workoutHistoryState = MockRepository.workoutHistory.isEmpty
        ? .empty(message: "No workouts logged yet.")
        : .loaded(MockRepository.workoutHistory)
    exerciseHistoryState = MockRepository.exerciseHistory.isEmpty
        ? .empty(message: "No exercises logged yet.")
        : .loaded(MockRepository.exerciseHistory)
}
```

```swift
// LiftingLog/Features/History/HistoryView.swift
import SwiftUI

struct HistoryView: View {
    @Bindable var store: AppStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("History").font(.system(size: 40, weight: .bold))
                Picker("History Mode", selection: $store.historyMode) {
                    Text("Workouts").tag(HistoryMode.workouts)
                    Text("Exercises").tag(HistoryMode.exercises)
                }
                .pickerStyle(.segmented)

                switch store.historyMode {
                case .workouts:
                    workoutContent
                case .exercises:
                    exerciseContent
                }
            }
            .padding(16)
        }
        .task { await store.loadHistory() }
        .background(AppTheme.background.ignoresSafeArea())
    }
}
```

- [ ] **Step 5: Expand the UI smoke test for real navigation**

```swift
func testTabNavigationShowsHistoryAndProfile() {
    let app = XCUIApplication()
    app.launch()

    app.tabBars.buttons["History"].tap()
    XCTAssertTrue(app.staticTexts["History"].waitForExistence(timeout: 2))

    app.tabBars.buttons["Profile"].tap()
    XCTAssertTrue(app.staticTexts["Profile"].waitForExistence(timeout: 2))
}
```

- [ ] **Step 6: Run unit tests and UI tests**

Run: `xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 16'`

Expected: PASS with both Swift Testing and UI tests green

- [ ] **Step 7: Commit**

```bash
git add LiftingLog/Shared/Components/StateViews.swift LiftingLog/Shared/Mocks/MockRepository.swift LiftingLog/Shared/Stores/AppStore.swift LiftingLog/Features/History LiftingLogUITests/LiftingLogUITests.swift
git commit -m "feat: add history screens and state handling"
```

## Task 5: Finish The Native Polish For Profile, Summary Sheet, And Visual Fidelity

**Files:**
- Create: `LiftingLog/Features/Profile/ProfileView.swift`
- Create: `LiftingLog/Features/Workout/FinishWorkoutSheet.swift`
- Modify: `LiftingLog/Features/Workout/WorkoutSessionView.swift`
- Modify: `LiftingLog/Features/Workout/ExerciseCardView.swift`
- Modify: `LiftingLog/Features/Workout/SetRowView.swift`
- Modify: `LiftingLog/Shared/DesignSystem/AppTheme.swift`

- [ ] **Step 1: Write the failing test for derived finish metrics**

```swift
@Test func estimatedVolumeSumsCompletedWeightsAndReps() {
    let store = AppStore.preview
    let volume = store.estimatedCompletedVolume
    #expect(volume == 2250)
}
```

- [ ] **Step 2: Run the failing test**

Run: `xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:LiftingLogTests/AppStoreTests`

Expected: FAIL with `Value of type 'AppStore' has no member 'estimatedCompletedVolume'`

- [ ] **Step 3: Implement finish metrics, summary sheet, and the profile placeholder**

```swift
// AppStore addition
var estimatedCompletedVolume: Int {
    activeWorkout.exercises
        .flatMap(\.sets)
        .filter(\.isDone)
        .reduce(into: 0) { total, set in
            total += (Int(set.weight) ?? 0) * (Int(set.reps) ?? 0)
        }
}
```

```swift
// LiftingLog/Features/Workout/FinishWorkoutSheet.swift
import SwiftUI

struct FinishWorkoutSheet: View {
    @Bindable var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Capsule().fill(AppTheme.borderStrong).frame(width: 44, height: 5)
            Text("Finish Workout?")
                .font(.system(size: 28, weight: .bold))
            HStack(spacing: 12) {
                summaryCard("Duration", value: AppTheme.formatDuration(store.activeWorkout.elapsedSeconds))
                summaryCard("Sets Done", value: "\(store.completedSetCount)/\(store.totalSetCount)")
                summaryCard("Volume", value: "\(store.estimatedCompletedVolume)")
            }
            Button("Save Workout") { dismiss() }
                .buttonStyle(.borderedProminent)
            Button("Keep Going") { dismiss() }
                .buttonStyle(.plain)
        }
        .padding(24)
        .presentationDetents([.height(340)])
        .presentationCornerRadius(28)
    }
}
```

```swift
// LiftingLog/Features/Profile/ProfileView.swift
import SwiftUI

struct ProfileView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Profile").font(.system(size: 40, weight: .bold))
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Kevin")
                        Text("Mock athlete profile")
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
            .padding(16)
        }
        .background(AppTheme.background.ignoresSafeArea())
    }
}
```

- [ ] **Step 4: Refine visual fidelity for the workout controls**

```swift
// ExerciseCardView core layout
import SwiftUI

struct ExerciseCardView: View {
    @Bindable var store: AppStore
    let exercise: WorkoutExercise

    var body: some View {
        SurfaceCard {
            VStack(spacing: 14) {
                Button {
                    store.toggleExerciseCollapsed(exercise.id)
                } label: {
                    HStack {
                        Image(systemName: "chevron.down")
                            .rotationEffect(.degrees(exercise.isCollapsed ? -90 : 0))
                        Text(exercise.name)
                            .font(.system(size: 20, weight: .bold))
                        Spacer()
                        Text("\(exercise.sets.filter(\\.isDone).count)/\(exercise.sets.count)")
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                .buttonStyle(.plain)

                if !exercise.isCollapsed {
                    VStack(spacing: 10) {
                        ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                            SetRowView(store: store, exerciseID: exercise.id, set: set, index: index)
                        }

                        Button(action: { store.addSet(to: exercise.id) }) {
                            Label("Add Set", systemImage: "plus")
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.vertical, 12)
                        .background(AppTheme.surfaceMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
        }
    }
}
```

```swift
// SetRowView core layout
import SwiftUI

struct SetRowView: View {
    @Bindable var store: AppStore
    let exerciseID: UUID
    let set: ExerciseSet
    let index: Int

    var body: some View {
        HStack(spacing: 12) {
            Text("\(index + 1)")
                .foregroundStyle(AppTheme.textTertiary)
                .frame(width: 24)

            TextField("lbs", text: .constant(set.weight))
                .multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .padding(.vertical, 14)
                .background(AppTheme.surfaceStrong)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            TextField("reps", text: .constant(set.reps))
                .multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .padding(.vertical, 14)
                .background(AppTheme.surfaceStrong)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            TextField("RPE", text: .constant(set.rpe))
                .multilineTextAlignment(.center)
                .keyboardType(.decimalPad)
                .padding(.vertical, 14)
                .background(AppTheme.surfaceStrong)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            Button {
                store.toggleSetDone(exerciseID: exerciseID, setID: set.id)
            } label: {
                Image(systemName: set.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 28))
                    .foregroundStyle(set.isDone ? AppTheme.accentBright : AppTheme.borderStrong)
            }
            .buttonStyle(.plain)
        }
    }
}
```

- [ ] **Step 5: Run all tests and a simulator build**

Run: `xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 16'`

Run: `xcodebuild build -project LiftingLog.xcodeproj -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 16 Pro'`

Expected: `** TEST SUCCEEDED **` followed by `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add LiftingLog/Features/Profile/ProfileView.swift LiftingLog/Features/Workout/FinishWorkoutSheet.swift LiftingLog/Features/Workout/WorkoutSessionView.swift LiftingLog/Features/Workout/ExerciseCardView.swift LiftingLog/Features/Workout/SetRowView.swift LiftingLog/Shared/DesignSystem/AppTheme.swift LiftingLogTests/AppStoreTests.swift
git commit -m "feat: polish workout summary and profile placeholder"
```

## Task 6: Final Verification, Assumption Capture, And Delivery Notes

**Files:**
- Modify: `docs/superpowers/specs/2026-04-21-lifting-log-design.md`
- Create: `README.md`

- [ ] **Step 1: Add a short project README**

```md
# Lifting Log

Native SwiftUI workout logging app for iPhone, built from a Claude design export.

## Requirements

- Xcode 26+
- iOS 17 simulator runtime
- XcodeGen

## Commands

- `xcodegen generate`
- `xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 16'`
```

- [ ] **Step 2: Capture final assumptions and substitutions in the design spec**

```md
Add a short “Implemented Assumptions” note to the bottom of the design spec listing:
- profile screen shipped as a placeholder because no comp was supplied
- history detail screens were inferred
- SF Symbols were used where no custom icon asset existed
```

- [ ] **Step 3: Run the full verification pass**

Run: `xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 16'`

Run: `xcodebuild build -project LiftingLog.xcodeproj -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)'`

Expected: both commands succeed without compile errors

- [ ] **Step 4: Commit**

```bash
git add README.md docs/superpowers/specs/2026-04-21-lifting-log-design.md
git commit -m "docs: add setup notes and implementation assumptions"
```

## Self-Review

### Spec Coverage

- Workout logging screen: covered by Task 3 and Task 5
- History workouts and exercises modes: covered by Task 4
- Profile placeholder: covered by Task 5
- Finish workout sheet: covered by Task 5
- Mock architecture and reusable components: covered by Task 2 and Task 3
- Explicit loading, empty, and error states: covered by Task 4
- Build verification and assumption capture: covered by Task 6

### Placeholder Scan

- No `TODO` or `TBD` markers remain
- All verification commands include an expected outcome
- Each task names exact files and concrete commands

### Type Consistency

- `AppStore`, `AppTab`, `HistoryMode`, `WorkoutSession`, `WorkoutExercise`, and `ExerciseSet` are defined before later tasks build on them
- `completedSetCount`, `totalSetCount`, `estimatedCompletedVolume`, `toggleSetDone`, `toggleExerciseCollapsed`, `addSet`, `addExercise`, and `loadHistory` use consistent names across tasks
