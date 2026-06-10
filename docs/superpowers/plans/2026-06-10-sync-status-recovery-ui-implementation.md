# Sync Status and Recovery UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the v1 sync status and recovery UI for issue #12: failure-only global notice, real Settings sync state, retry, details routing, and user-safe error text.

**Architecture:** `SyncScheduler` owns observable runtime sync state, while `SyncOutboxEntry` remains the durable source of queued/failed sync intent. A small display mapper combines scheduler state plus outbox counts into user-facing labels and actions. SwiftUI surfaces stay focused: Settings shows full status, and `AppShellView` shows only a non-blocking failure banner.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, Observation, XCTest, XCUITest, existing Xcode project and scheme.

---

## File Structure

- Modify `LiftingLog/Core/Sync/SyncScheduler.swift`: expose `isSyncing`, queued request state, last success/failure metadata, and retry-safe request behavior.
- Create `LiftingLog/Core/Sync/SyncStatusDisplayState.swift`: pure display model and error sanitization logic for Settings and the banner.
- Modify `LiftingLog/App/AppNavigationState.swift`: add a profile navigation route so banner `Details` can open Settings.
- Modify `LiftingLog/App/AppShellView.swift`: host the global failure banner and route `Details` to Settings.
- Modify `LiftingLog/App/LiftingLogApp.swift`: add UI-test hooks for failure status while preserving production behavior.
- Modify `LiftingLog/Features/Profile/ProfileView.swift`: support profile navigation path and keep Settings navigation addressable.
- Modify `LiftingLog/Features/Profile/SettingsAccountSection.swift`: replace the placeholder sync row with real status, counts, and retry action.
- Create `LiftingLogTests/SyncSchedulerStatusTests.swift`: unit tests for scheduler runtime state.
- Create `LiftingLogTests/SyncStatusDisplayStateTests.swift`: unit tests for display mapping and error normalization.
- Modify `LiftingLogUITests/LiftingLogUITests.swift`: update Account shell expectations and add banner/retry coverage.

## Commands

Use the repo's existing test commands:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -only-testing:LiftingLogTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -only-testing:LiftingLogUITests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

This repo's README uses `iPhone 16,OS=18.6`; keep that destination unless the local Xcode installation reports a different available simulator during execution.

---

### Task 1: Scheduler Runtime State

**Files:**
- Modify: `LiftingLog/Core/Sync/SyncScheduler.swift`
- Create: `LiftingLogTests/SyncSchedulerStatusTests.swift`

- [ ] **Step 1: Write failing scheduler status tests**

Create `LiftingLogTests/SyncSchedulerStatusTests.swift`:

```swift
import SwiftData
import XCTest
@testable import LiftingLog

@MainActor
final class SyncSchedulerStatusTests: XCTestCase {
    func testSchedulerReportsSyncingDuringActiveRunAndSuccessAfterCompletion() async throws {
        let container = try SwiftDataTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let client = FakeSyncClient()
        let coordinator = SyncCoordinator(client: client)
        let scheduler = SyncScheduler(coordinator: coordinator, modelContext: context)
        scheduler.currentOwnerTokenIdentifier = "issuer|owner_a"

        let syncStarted = expectation(description: "sync started")
        client.onFetchChanges = {
            XCTAssertTrue(scheduler.isSyncing)
            syncStarted.fulfill()
        }

        scheduler.requestSync()
        await fulfillment(of: [syncStarted], timeout: 1.0)
        try await waitUntil { !scheduler.isSyncing }

        XCTAssertFalse(scheduler.isSyncing)
        XCTAssertFalse(scheduler.hasQueuedSyncRequest)
        XCTAssertNotNil(scheduler.lastSyncedAt)
        XCTAssertNil(scheduler.lastFailure)
    }

    func testSchedulerRecordsFailureAndRetryUsesSameRequestPath() async throws {
        struct FetchError: LocalizedError {
            var errorDescription: String? { "Convex function sync:fetchChanges failed" }
        }

        let container = try SwiftDataTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let client = FakeSyncClient()
        client.fetchError = FetchError()
        let scheduler = SyncScheduler(coordinator: SyncCoordinator(client: client), modelContext: context)
        scheduler.currentOwnerTokenIdentifier = "issuer|owner_a"

        scheduler.requestSync()
        try await waitUntil { scheduler.lastFailure != nil }

        XCTAssertFalse(scheduler.isSyncing)
        XCTAssertEqual(scheduler.requestCount, 1)
        XCTAssertEqual(scheduler.lastFailure?.message, "Convex function sync:fetchChanges failed")

        client.fetchError = nil
        scheduler.retrySync()
        try await waitUntil { scheduler.lastSyncedAt != nil }

        XCTAssertEqual(scheduler.requestCount, 2)
        XCTAssertNil(scheduler.lastFailure)
    }

    func testOwnerChangeClearsRuntimeFailureAndCancelsQueuedState() async throws {
        let scheduler = SyncScheduler()
        scheduler.currentOwnerTokenIdentifier = "issuer|owner_a"
        scheduler.recordFailureForTesting(message: "offline", at: Date(timeIntervalSince1970: 100))

        XCTAssertNotNil(scheduler.lastFailure)

        scheduler.currentOwnerTokenIdentifier = "issuer|owner_b"

        XCTAssertNil(scheduler.lastFailure)
        XCTAssertFalse(scheduler.hasQueuedSyncRequest)
        XCTAssertFalse(scheduler.isSyncing)
    }

    private func waitUntil(
        timeout: TimeInterval = 1.0,
        condition: @MainActor @escaping () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Condition was not met before timeout")
    }
}
```

- [ ] **Step 2: Run tests and verify they fail**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -only-testing:LiftingLogTests/SyncSchedulerStatusTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: FAIL because `isSyncing`, `hasQueuedSyncRequest`, `lastSyncedAt`, `lastFailure`, `retrySync()`, and `recordFailureForTesting(message:at:)` do not exist yet.

- [ ] **Step 3: Implement scheduler runtime state**

In `LiftingLog/Core/Sync/SyncScheduler.swift`, replace the file with:

```swift
import Foundation
import SwiftData

@MainActor
@Observable
final class SyncScheduler {
    struct Failure: Equatable {
        let message: String
        let occurredAt: Date
    }

    var currentOwnerTokenIdentifier: String? {
        didSet {
            guard oldValue != currentOwnerTokenIdentifier else { return }
            cancelInFlightSync()
            clearRuntimeStateForOwnerChange()
        }
    }
    private(set) var requestCount = 0
    private(set) var isSyncing = false
    private(set) var hasQueuedSyncRequest = false
    private(set) var lastSyncedAt: Date?
    private(set) var lastFailure: Failure?

    private var coordinator: SyncCoordinator?
    private var modelContext: ModelContext?
    private var syncTask: Task<Void, Never>?
    private var needsSync = false

    init(coordinator: SyncCoordinator? = nil, modelContext: ModelContext? = nil) {
        self.coordinator = coordinator
        self.modelContext = modelContext
    }

    func configure(coordinator: SyncCoordinator, modelContext: ModelContext) {
        self.coordinator = coordinator
        self.modelContext = modelContext
    }

    func requestSync() {
        requestCount += 1
        guard let coordinator, let modelContext else { return }
        guard syncTask == nil else {
            needsSync = true
            hasQueuedSyncRequest = true
            return
        }

        startSyncTask(coordinator: coordinator, modelContext: modelContext)
    }

    func retrySync() {
        requestSync()
    }

    func seedDefaultsForCurrentOwner() {
        guard let currentOwnerTokenIdentifier, let modelContext else { return }
        let hasBootstrapped = (try? SyncCursorState.state(
            for: currentOwnerTokenIdentifier,
            context: modelContext
        ).hasBootstrappedSettingsExercises) ?? true
        try? SeedDataService.seedIfNeeded(
            context: modelContext,
            ownerTokenIdentifier: currentOwnerTokenIdentifier,
            claimOwnerlessVisibleDefaults: !hasBootstrapped
        )
    }

    func seedDefaultsForLocalMode() {
        guard let modelContext else { return }
        try? SeedDataService.seedIfNeeded(context: modelContext)
    }

    func recordFailureForTesting(message: String, at date: Date = .now) {
        lastFailure = Failure(message: message, occurredAt: date)
    }

    private func cancelInFlightSync() {
        guard let syncTask else { return }
        needsSync = false
        syncTask.cancel()
    }

    private func clearRuntimeStateForOwnerChange() {
        hasQueuedSyncRequest = false
        isSyncing = false
        lastSyncedAt = nil
        lastFailure = nil
    }

    private func startSyncTask(coordinator: SyncCoordinator, modelContext: ModelContext) {
        syncTask = Task { @MainActor in
            isSyncing = true
            while true {
                needsSync = false
                hasQueuedSyncRequest = false
                do {
                    try await coordinator.run(ownerTokenIdentifier: currentOwnerTokenIdentifier, context: modelContext)
                    lastSyncedAt = .now
                    lastFailure = nil
                } catch is CancellationError {
                    break
                } catch {
                    lastFailure = Failure(message: error.localizedDescription, occurredAt: .now)
                    break
                }
                if Task.isCancelled {
                    break
                }
                guard needsSync else { break }
            }

            let shouldStartQueuedSync = needsSync && currentOwnerTokenIdentifier != nil
            needsSync = false
            hasQueuedSyncRequest = false
            isSyncing = false
            syncTask = nil
            if shouldStartQueuedSync {
                startSyncTask(coordinator: coordinator, modelContext: modelContext)
            }
        }
    }
}
```

- [ ] **Step 4: Run scheduler tests and verify they pass**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -only-testing:LiftingLogTests/SyncSchedulerStatusTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: PASS.

- [ ] **Step 5: Run existing sync outbox integration tests**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -only-testing:LiftingLogTests/SyncOutboxIntegrationTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: PASS. Existing `requestCount` behavior remains unchanged.

- [ ] **Step 6: Commit**

```bash
git add LiftingLog/Core/Sync/SyncScheduler.swift LiftingLogTests/SyncSchedulerStatusTests.swift
git commit -m "Track sync scheduler status"
```

---

### Task 2: Sync Display Model and Error Sanitization

**Files:**
- Create: `LiftingLog/Core/Sync/SyncStatusDisplayState.swift`
- Create: `LiftingLogTests/SyncStatusDisplayStateTests.swift`

- [ ] **Step 1: Write failing display model tests**

Create `LiftingLogTests/SyncStatusDisplayStateTests.swift`:

```swift
import Foundation
import XCTest
@testable import LiftingLog

final class SyncStatusDisplayStateTests: XCTestCase {
    func testSignedOutMapsToLocalOnly() {
        let state = SyncStatusDisplayState.make(
            ownerTokenIdentifier: nil,
            isSyncing: false,
            lastSyncedAt: nil,
            lastFailureMessage: nil,
            pendingCount: 0,
            failedCount: 0,
            now: Date(timeIntervalSince1970: 1_000)
        )

        XCTAssertEqual(state.kind, .localOnly)
        XCTAssertEqual(state.title, "Sync Status")
        XCTAssertEqual(state.subtitle, "Cloud sync starts after you sign in.")
        XCTAssertEqual(state.trailingText, "Local only")
        XCTAssertFalse(state.canRetry)
        XCTAssertFalse(state.showsGlobalFailureNotice)
    }

    func testSyncingStateWinsOverQueuedWork() {
        let state = SyncStatusDisplayState.make(
            ownerTokenIdentifier: "issuer|owner_a",
            isSyncing: true,
            lastSyncedAt: nil,
            lastFailureMessage: nil,
            pendingCount: 3,
            failedCount: 0,
            now: Date(timeIntervalSince1970: 1_000)
        )

        XCTAssertEqual(state.kind, .syncing)
        XCTAssertEqual(state.subtitle, "Sending and receiving changes.")
        XCTAssertEqual(state.trailingText, "Syncing")
        XCTAssertFalse(state.canRetry)
    }

    func testFailedEntriesMapToNeedsAttentionAndGlobalNotice() {
        let state = SyncStatusDisplayState.make(
            ownerTokenIdentifier: "issuer|owner_a",
            isSyncing: false,
            lastSyncedAt: Date(timeIntervalSince1970: 940),
            lastFailureMessage: "Convex function sync:fetchChanges failed for token issuer|owner_a",
            pendingCount: 2,
            failedCount: 1,
            now: Date(timeIntervalSince1970: 1_000)
        )

        XCTAssertEqual(state.kind, .needsAttention)
        XCTAssertEqual(state.subtitle, "Cloud sync could not finish. Your data is saved on this iPhone.")
        XCTAssertEqual(state.detailText, "1 failed, 2 waiting. Last synced 1 min ago.")
        XCTAssertEqual(state.trailingText, "Retry")
        XCTAssertTrue(state.canRetry)
        XCTAssertTrue(state.showsGlobalFailureNotice)
        XCTAssertEqual(state.userVisibleFailureMessage, "Cloud sync could not finish. Your data is saved on this iPhone.")
    }

    func testPendingWorkMapsToWaitingToSync() {
        let state = SyncStatusDisplayState.make(
            ownerTokenIdentifier: "issuer|owner_a",
            isSyncing: false,
            lastSyncedAt: nil,
            lastFailureMessage: nil,
            pendingCount: 4,
            failedCount: 0,
            now: Date(timeIntervalSince1970: 1_000)
        )

        XCTAssertEqual(state.kind, .waiting)
        XCTAssertEqual(state.subtitle, "4 changes waiting for cloud sync.")
        XCTAssertEqual(state.trailingText, "Waiting")
        XCTAssertTrue(state.canRetry)
        XCTAssertFalse(state.showsGlobalFailureNotice)
    }

    func testLastSyncedUsesRelativeMinutes() {
        let state = SyncStatusDisplayState.make(
            ownerTokenIdentifier: "issuer|owner_a",
            isSyncing: false,
            lastSyncedAt: Date(timeIntervalSince1970: 700),
            lastFailureMessage: nil,
            pendingCount: 0,
            failedCount: 0,
            now: Date(timeIntervalSince1970: 1_000)
        )

        XCTAssertEqual(state.kind, .upToDate)
        XCTAssertEqual(state.subtitle, "Last synced 5 min ago.")
        XCTAssertEqual(state.trailingText, "Up to date")
        XCTAssertFalse(state.canRetry)
    }

    func testKnownOfflineErrorUsesShortReason() {
        XCTAssertEqual(
            SyncStatusDisplayState.sanitizedFailureReason(from: "The Internet connection appears to be offline."),
            "The network appears to be offline."
        )
    }
}
```

- [ ] **Step 2: Run tests and verify they fail**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -only-testing:LiftingLogTests/SyncStatusDisplayStateTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: FAIL because `SyncStatusDisplayState` does not exist.

- [ ] **Step 3: Implement display model**

Create `LiftingLog/Core/Sync/SyncStatusDisplayState.swift`:

```swift
import Foundation
import SwiftUI

struct SyncStatusDisplayState {
    enum Kind: Equatable {
        case localOnly
        case syncing
        case waiting
        case upToDate
        case needsAttention
    }

    let kind: Kind
    let title: String
    let subtitle: String
    let detailText: String?
    let trailingText: String
    let systemImage: String
    let tint: Color
    let canRetry: Bool
    let showsGlobalFailureNotice: Bool
    let userVisibleFailureMessage: String?

    static func make(
        ownerTokenIdentifier: String?,
        isSyncing: Bool,
        lastSyncedAt: Date?,
        lastFailureMessage: String?,
        pendingCount: Int,
        failedCount: Int,
        now: Date = .now
    ) -> SyncStatusDisplayState {
        guard ownerTokenIdentifier != nil else {
            return SyncStatusDisplayState(
                kind: .localOnly,
                title: "Sync Status",
                subtitle: "Cloud sync starts after you sign in.",
                detailText: nil,
                trailingText: "Local only",
                systemImage: "icloud.slash",
                tint: .secondary,
                canRetry: false,
                showsGlobalFailureNotice: false,
                userVisibleFailureMessage: nil
            )
        }

        if isSyncing {
            return SyncStatusDisplayState(
                kind: .syncing,
                title: "Sync Status",
                subtitle: "Sending and receiving changes.",
                detailText: countsText(pendingCount: pendingCount, failedCount: failedCount, lastSyncedAt: lastSyncedAt, now: now),
                trailingText: "Syncing",
                systemImage: "arrow.triangle.2.circlepath.icloud",
                tint: AppTheme.accentBright,
                canRetry: false,
                showsGlobalFailureNotice: false,
                userVisibleFailureMessage: nil
            )
        }

        if failedCount > 0 || lastFailureMessage != nil {
            let defaultMessage = "Cloud sync could not finish. Your data is saved on this iPhone."
            return SyncStatusDisplayState(
                kind: .needsAttention,
                title: "Sync Status",
                subtitle: defaultMessage,
                detailText: countsText(pendingCount: pendingCount, failedCount: failedCount, lastSyncedAt: lastSyncedAt, now: now)
                    ?? sanitizedFailureReason(from: lastFailureMessage ?? ""),
                trailingText: "Retry",
                systemImage: "exclamationmark.icloud",
                tint: AppTheme.accentBright,
                canRetry: true,
                showsGlobalFailureNotice: true,
                userVisibleFailureMessage: defaultMessage
            )
        }

        if pendingCount > 0 {
            return SyncStatusDisplayState(
                kind: .waiting,
                title: "Sync Status",
                subtitle: "\(pendingCount) \(pendingCount == 1 ? "change" : "changes") waiting for cloud sync.",
                detailText: lastSyncedText(lastSyncedAt, now: now).map { "Last synced \($0)." },
                trailingText: "Waiting",
                systemImage: "icloud.and.arrow.up",
                tint: .secondary,
                canRetry: true,
                showsGlobalFailureNotice: false,
                userVisibleFailureMessage: nil
            )
        }

        return SyncStatusDisplayState(
            kind: .upToDate,
            title: "Sync Status",
            subtitle: lastSyncedText(lastSyncedAt, now: now).map { "Last synced \($0)." } ?? "Cloud sync is ready.",
            detailText: nil,
            trailingText: "Up to date",
            systemImage: "checkmark.icloud",
            tint: .secondary,
            canRetry: false,
            showsGlobalFailureNotice: false,
            userVisibleFailureMessage: nil
        )
    }

    static func sanitizedFailureReason(from message: String) -> String {
        let lowercased = message.lowercased()
        if lowercased.contains("offline") || lowercased.contains("internet connection") || lowercased.contains("network") {
            return "The network appears to be offline."
        }
        if lowercased.contains("unauthorized") || lowercased.contains("auth") || lowercased.contains("sign in") {
            return "Sign in again to continue syncing."
        }
        if lowercased.contains("timed out") || lowercased.contains("could not connect") || lowercased.contains("service") {
            return "The service could not be reached."
        }
        return "Cloud sync could not finish. Your data is saved on this iPhone."
    }

    private static func countsText(
        pendingCount: Int,
        failedCount: Int,
        lastSyncedAt: Date?,
        now: Date
    ) -> String? {
        var workParts: [String] = []
        if failedCount > 0 {
            workParts.append("\(failedCount) failed")
        }
        if pendingCount > 0 {
            workParts.append("\(pendingCount) waiting")
        }
        var sentences: [String] = []
        if !workParts.isEmpty {
            sentences.append(workParts.joined(separator: ", "))
        }
        if let lastSynced = lastSyncedText(lastSyncedAt, now: now) {
            sentences.append("Last synced \(lastSynced)")
        }
        guard !sentences.isEmpty else { return nil }
        return sentences.joined(separator: ". ") + "."
    }

    private static func lastSyncedText(_ date: Date?, now: Date) -> String? {
        guard let date else { return nil }
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        if seconds < 60 { return "just now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes) min ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours) hr ago" }
        let days = hours / 24
        return "\(days) d ago"
    }
}
```

- [ ] **Step 4: Run display model tests and verify they pass**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -only-testing:LiftingLogTests/SyncStatusDisplayStateTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add LiftingLog/Core/Sync/SyncStatusDisplayState.swift LiftingLogTests/SyncStatusDisplayStateTests.swift
git commit -m "Add sync status display model"
```

---

### Task 3: Settings Sync Status Row

**Files:**
- Modify: `LiftingLog/Features/Profile/SettingsAccountSection.swift`
- Modify: `LiftingLogUITests/LiftingLogUITests.swift`

- [ ] **Step 1: Update failing UI test expectations for the Settings row**

In `LiftingLogUITests/LiftingLogUITests.swift`, update `testSettingsShowsAccountShellAndDeleteAccountPlaceholder()`:

```swift
    @MainActor
    func testSettingsShowsAccountShellAndDeleteAccountPlaceholder() {
        let app = makeApp()
        app.launchArguments.append("--uitest-force-signed-out-auth")
        app.launch()

        app.buttons["ProfileTab"].tap()
        XCTAssertTrue(app.staticTexts["ProfileTitle"].waitForExistence(timeout: 3))
        app.buttons["ProfileSettingsLink"].tap()

        XCTAssertTrue(app.staticTexts["Account"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Sync Status"].exists)
        XCTAssertTrue(app.staticTexts["Local only"].exists)
        XCTAssertTrue(app.staticTexts["Cloud sync starts after you sign in."].exists)
        XCTAssertFalse(app.staticTexts["Cloud sync is not configured yet."].exists)
        XCTAssertTrue(app.buttons["SettingsDeleteAccountRow"].exists)

        app.buttons["SettingsDeleteAccountRow"].tap()

        XCTAssertTrue(app.staticTexts["SettingsDeleteAccountPlaceholder"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Account deletion is not available yet."].exists)
        let placeholderMessage = "This release still stores your workouts locally. Account deletion will be available before release after cloud data deletion is connected."
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label == %@", placeholderMessage)).firstMatch.exists)
        XCTAssertFalse(app.buttons["Delete"].exists)
    }
```

- [ ] **Step 2: Run the UI test and verify it fails**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -only-testing:LiftingLogUITests/LiftingLogUITests/testSettingsShowsAccountShellAndDeleteAccountPlaceholder -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: FAIL because Settings still shows "Cloud sync is not configured yet."

- [ ] **Step 3: Replace Settings placeholder with real display state**

Replace `LiftingLog/Features/Profile/SettingsAccountSection.swift` with:

```swift
import SwiftData
import SwiftUI

struct SettingsAccountSection: View {
    @Environment(SyncScheduler.self) private var syncScheduler
    @Query(sort: \SyncOutboxEntry.updatedAt, order: .reverse) private var outboxEntries: [SyncOutboxEntry]

    private var displayState: SyncStatusDisplayState {
        let entries = relevantOutboxEntries
        return SyncStatusDisplayState.make(
            ownerTokenIdentifier: syncScheduler.currentOwnerTokenIdentifier,
            isSyncing: syncScheduler.isSyncing,
            lastSyncedAt: syncScheduler.lastSyncedAt,
            lastFailureMessage: syncScheduler.lastFailure?.message,
            pendingCount: entries.filter { $0.status == .pending || $0.status == .inFlight }.count,
            failedCount: entries.filter { $0.status == .failed }.count
        )
    }

    private var relevantOutboxEntries: [SyncOutboxEntry] {
        outboxEntries.filter { entry in
            guard entry.isActive else { return false }
            guard entry.entityKind?.isV1Synced == true else { return false }
            if let owner = syncScheduler.currentOwnerTokenIdentifier {
                return entry.ownerTokenIdentifier == owner || entry.ownerTokenIdentifier == nil
            }
            return entry.ownerTokenIdentifier == nil
        }
    }

    var body: some View {
        Section {
            syncStatusRow

            #if DEBUG
            NavigationLink {
                DeveloperDiagnosticsView()
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Developer Diagnostics")
                        Text("Convex auth smoke checks.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "stethoscope")
                        .foregroundStyle(AppTheme.accentBright)
                }
            }
            .accessibilityIdentifier("SettingsDeveloperDiagnosticsRow")
            #endif

            NavigationLink {
                DeleteAccountPlaceholderView()
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Delete Account")
                            .foregroundStyle(.red)
                        Text("Available before release.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "person.crop.circle.badge.xmark")
                        .foregroundStyle(.red)
                }
            }
            .accessibilityIdentifier("SettingsDeleteAccountRow")
        } header: {
            Text("Account")
                .accessibilityIdentifier("Account")
        }
    }

    private var syncStatusRow: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: displayState.systemImage)
                .foregroundStyle(displayState.tint)

            VStack(alignment: .leading, spacing: 4) {
                Text(displayState.title)
                Text(displayState.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let detailText = displayState.detailText {
                    Text(detailText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if displayState.canRetry {
                Button("Retry") {
                    syncScheduler.retrySync()
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("SettingsSyncRetryButton")
            } else {
                Text(displayState.trailingText)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("SettingsSyncStatusRow")
    }
}

private struct DeleteAccountPlaceholderView: View {
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "person.crop.circle.badge.xmark")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(.red)

                    Text("Account deletion is not available yet.")
                        .font(.headline)
                        .accessibilityIdentifier("SettingsDeleteAccountPlaceholder")

                    Text("This release still stores your workouts locally. Account deletion will be available before release after cloud data deletion is connected.")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.subtleBackground.ignoresSafeArea())
        .navigationTitle("Delete Account")
        .navigationBarTitleDisplayMode(.inline)
    }
}
```

- [ ] **Step 4: Run focused UI test and verify it passes**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -only-testing:LiftingLogUITests/LiftingLogUITests/testSettingsShowsAccountShellAndDeleteAccountPlaceholder -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: PASS.

- [ ] **Step 5: Run sync display unit tests again**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -only-testing:LiftingLogTests/SyncStatusDisplayStateTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add LiftingLog/Features/Profile/SettingsAccountSection.swift LiftingLogUITests/LiftingLogUITests.swift
git commit -m "Show real sync status in settings"
```

---

### Task 4: Global Failure Banner and Details Routing

**Files:**
- Modify: `LiftingLog/App/AppNavigationState.swift`
- Modify: `LiftingLog/App/AppShellView.swift`
- Modify: `LiftingLog/Features/Profile/ProfileView.swift`
- Modify: `LiftingLog/App/LiftingLogApp.swift`
- Modify: `LiftingLogUITests/LiftingLogUITests.swift`

- [ ] **Step 1: Write failing UI test for banner retry and details**

Add this test to `LiftingLogUITests/LiftingLogUITests.swift` near the other settings/account tests:

```swift
    @MainActor
    func testFailedSyncBannerShowsRetryAndRoutesToSettingsDetails() {
        let app = makeApp(extraArguments: [
            "--uitest-sync-owner", "issuer|ui_owner",
            "--uitest-show-sync-failure",
        ])
        app.launch()

        XCTAssertTrue(app.staticTexts["Cloud sync failed"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Your data is saved on this iPhone."].exists)

        app.buttons["GlobalSyncRetryButton"].tap()
        XCTAssertTrue(app.staticTexts["UITestSyncRequestCount-1"].waitForExistence(timeout: 3))

        app.buttons["GlobalSyncDetailsButton"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Sync Status"].exists)
        XCTAssertTrue(app.staticTexts["Cloud sync could not finish. Your data is saved on this iPhone."].exists)
    }
```

- [ ] **Step 2: Run the UI test and verify it fails**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -only-testing:LiftingLogUITests/LiftingLogUITests/testFailedSyncBannerShowsRetryAndRoutesToSettingsDetails -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: FAIL because the launch argument, banner, and details routing do not exist.

- [ ] **Step 3: Add profile route to navigation state**

In `LiftingLog/App/AppNavigationState.swift`, add `ProfileRoute` and update `AppNavigationState`:

```swift
enum ProfileRoute: Hashable {
    case settings
}

@Observable
final class AppNavigationState {
    var selectedTab: AppTab
    var historyMode: HistoryMode
    var historyPath: [HistoryRoute]
    var profilePath: [ProfileRoute]

    init(
        selectedTab: AppTab = .workout,
        historyMode: HistoryMode = .workouts,
        historyPath: [HistoryRoute] = [],
        profilePath: [ProfileRoute] = []
    ) {
        self.selectedTab = selectedTab
        self.historyMode = historyMode
        self.historyPath = historyPath
        self.profilePath = profilePath
    }

    func openExerciseHistory(_ route: ExerciseHistoryRoute) {
        selectedTab = .history
        historyMode = .exercises
        historyPath = [.exercise(route)]
    }

    func openSyncSettings() {
        selectedTab = .profile
        profilePath = [.settings]
    }
}
```

Keep the existing `AppTab`, `HistoryMode`, and `HistoryRoute` definitions unchanged.

- [ ] **Step 4: Update Profile navigation**

In `LiftingLog/Features/Profile/ProfileView.swift`, change the struct to accept navigation state:

```swift
struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncScheduler.self) private var syncScheduler
    @Query(sort: \UserSettings.createdAt) private var settingsRecords: [UserSettings]
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    @Bindable var navigationState: AppNavigationState
```

Add a navigation destination near the existing `.toolbar(.hidden, for: .navigationBar)` modifier:

```swift
        .navigationDestination(for: ProfileRoute.self) { route in
            switch route {
            case .settings:
                if let settings {
                    SettingsView(settings: settings)
                }
            }
        }
```

Leave the existing visible `NavigationLink` to `SettingsView(settings:)` in place.

- [ ] **Step 5: Add banner host to AppShell**

In `LiftingLog/App/AppShellView.swift`, add an outbox query and display state:

```swift
    @Query(sort: \SyncOutboxEntry.updatedAt, order: .reverse) private var outboxEntries: [SyncOutboxEntry]

    private var syncDisplayState: SyncStatusDisplayState {
        let activeEntries = outboxEntries.filter { entry in
            guard entry.isActive else { return false }
            guard entry.entityKind?.isV1Synced == true else { return false }
            if let owner = syncScheduler.currentOwnerTokenIdentifier {
                return entry.ownerTokenIdentifier == owner || entry.ownerTokenIdentifier == nil
            }
            return false
        }
        return SyncStatusDisplayState.make(
            ownerTokenIdentifier: syncScheduler.currentOwnerTokenIdentifier,
            isSyncing: syncScheduler.isSyncing,
            lastSyncedAt: syncScheduler.lastSyncedAt,
            lastFailureMessage: syncScheduler.lastFailure?.message,
            pendingCount: activeEntries.filter { $0.status == .pending || $0.status == .inFlight }.count,
            failedCount: activeEntries.filter { $0.status == .failed }.count
        )
    }
```

Change the Profile tab content from:

```swift
            NavigationStack {
                ProfileView()
            }
```

to:

```swift
            NavigationStack(path: $navigationState.profilePath) {
                ProfileView(navigationState: navigationState)
            }
```

Add this modifier after `.preferredColorScheme(.dark)`:

```swift
        .safeAreaInset(edge: .bottom) {
            if syncDisplayState.showsGlobalFailureNotice {
                GlobalSyncFailureBanner(
                    retry: { syncScheduler.retrySync() },
                    details: { navigationState.openSyncSettings() }
                )
                .padding(.horizontal, AppTheme.shellPadding)
                .padding(.bottom, 8)
            }
        }
```

Add the banner view at the bottom of `AppShellView.swift`:

```swift
private struct GlobalSyncFailureBanner: View {
    let retry: () -> Void
    let details: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.icloud")
                .foregroundStyle(AppTheme.accentBright)
                .font(.system(size: 20, weight: .semibold))

            VStack(alignment: .leading, spacing: 4) {
                Text("Cloud sync failed")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Your data is saved on this iPhone.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                Button("Retry", action: retry)
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accentBright)
                    .accessibilityIdentifier("GlobalSyncRetryButton")
                Button("Details", action: details)
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("GlobalSyncDetailsButton")
            }
        }
        .padding(12)
        .background(AppTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppTheme.accentBright.opacity(0.45))
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityIdentifier("GlobalSyncFailureBanner")
    }
}
```

- [ ] **Step 6: Add UI-test failure launch hook**

In `LiftingLog/App/LiftingLogApp.swift`, inside the `.task` block where `uiTestSyncOwner` is handled, replace:

```swift
                if let uiTestSyncOwner {
                    syncScheduler.currentOwnerTokenIdentifier = uiTestSyncOwner
                    return
                }
```

with:

```swift
                if let uiTestSyncOwner {
                    syncScheduler.currentOwnerTokenIdentifier = uiTestSyncOwner
                    if ProcessInfo.processInfo.arguments.contains("--uitest-show-sync-failure") {
                        syncScheduler.recordFailureForTesting(
                            message: "Convex function sync:fetchChanges failed for token \(uiTestSyncOwner)"
                        )
                    }
                    return
                }
```

- [ ] **Step 7: Run the focused banner UI test**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -only-testing:LiftingLogUITests/LiftingLogUITests/testFailedSyncBannerShowsRetryAndRoutesToSettingsDetails -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: PASS.

- [ ] **Step 8: Update and run existing app navigation tests**

Add this test to `LiftingLogTests/AppNavigationStateTests.swift`:

```swift
    func testOpenSyncSettingsSelectsProfileAndPushesSettingsRoute() {
        let navigationState = AppNavigationState()

        navigationState.openSyncSettings()

        XCTAssertEqual(navigationState.selectedTab, .profile)
        XCTAssertEqual(navigationState.profilePath, [.settings])
    }
```

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -only-testing:LiftingLogTests/AppNavigationStateTests -only-testing:LiftingLogUITests/LiftingLogUITests/testTabNavigationAndFinishSheetSmoke -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add LiftingLog/App/AppNavigationState.swift LiftingLog/App/AppShellView.swift LiftingLog/App/LiftingLogApp.swift LiftingLog/Features/Profile/ProfileView.swift LiftingLogUITests/LiftingLogUITests.swift LiftingLogTests/AppNavigationStateTests.swift
git commit -m "Add sync failure recovery banner"
```

---

### Task 5: Final Verification and Release QA Notes

**Files:**
- Modify: `docs/qa/2026-06-10-sync-status-recovery-ui-manual-qa.md`

- [ ] **Step 1: Create manual QA checklist**

Create `docs/qa/2026-06-10-sync-status-recovery-ui-manual-qa.md`:

```markdown
# Sync Status and Recovery UI Manual QA

Date: 2026-06-10

Issue: #12 Add sync status, retry, and error recovery UI

## Scenarios

- Signed out:
  - Settings Account section shows `Sync Status`, `Local only`, and `Cloud sync starts after you sign in.`
  - Workout logging remains available.
  - No global sync failure banner appears.

- Signed in and healthy:
  - Settings can show `Syncing` during an active run.
  - Settings shows `Up to date` after a successful run.
  - No global sync failure banner appears.

- Signed in with pending work:
  - Settings shows `Waiting to sync`.
  - Retry is available if sync is not already active.
  - No global failure banner appears until a failure occurs.

- Failed sync:
  - Global banner says `Cloud sync failed`.
  - Banner message says `Your data is saved on this iPhone.`
  - `Retry` requests sync without blocking app interaction.
  - `Details` opens Settings.
  - Settings shows `Cloud sync could not finish. Your data is saved on this iPhone.`

- Connectivity recovery:
  - Create or finish a workout while the network is unavailable.
  - Restore connectivity.
  - Tap Retry.
  - Failed state clears after a successful sync.

## Test Hook Coverage

- `--uitest-sync-owner issuer|ui_owner --uitest-show-sync-failure` displays the failure banner.
- Tapping `GlobalSyncRetryButton` increments `UITestSyncRequestCount`.
```

- [ ] **Step 2: Run unit sync tests**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -only-testing:LiftingLogTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: PASS.

- [ ] **Step 3: Run UI tests**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination platform=iOS\ Simulator,name=iPhone\ 16,OS=18.6 -only-testing:LiftingLogUITests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: PASS.

- [ ] **Step 4: Review changed UI text**

Run:

```bash
rg -n "Cloud sync is not configured yet|Cloud sync failed|Your data is saved on this iPhone|Cloud sync starts after you sign in|Sync Status" LiftingLog LiftingLogTests LiftingLogUITests docs
```

Expected:
- No production reference remains to `Cloud sync is not configured yet`.
- Production references exist for the new safe sync status copy.
- Tests assert the new copy.

- [ ] **Step 5: Commit**

```bash
git add docs/qa/2026-06-10-sync-status-recovery-ui-manual-qa.md
git commit -m "Document sync recovery QA"
```

---

## Self-Review Checklist

- Spec coverage:
  - Scheduler-owned runtime state is covered in Task 1.
  - User-safe display state and error normalization are covered in Task 2.
  - Settings status and retry are covered in Task 3.
  - Failure-only global notice, Retry, and Details routing are covered in Task 4.
  - QA coverage for airplane mode, bad network, sign-in state, relaunch, and offline completion is covered in Task 5.
- Scope:
  - No sync coordinator rewrite.
  - No persistent sync-status SwiftData table.
  - No diagnostics-heavy UI or raw outbox browser.
- Verification:
  - Focused unit tests first.
  - Focused UI tests around Settings and banner behavior.
  - Full unit and UI suites at the end.
