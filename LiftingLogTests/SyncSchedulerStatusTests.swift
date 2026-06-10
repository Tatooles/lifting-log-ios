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

    func testSchedulerDoesNotRecordSuccessWithoutOwner() async throws {
        let container = try SwiftDataTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let client = FakeSyncClient()
        let scheduler = SyncScheduler(coordinator: SyncCoordinator(client: client), modelContext: context)

        scheduler.requestSync()
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(scheduler.requestCount, 1)
        XCTAssertNil(scheduler.lastSyncedAt)
        XCTAssertNil(scheduler.lastFailure)
        XCTAssertFalse(scheduler.isSyncing)
    }

    func testOwnerChangeClearsRuntimeFailureAndCancelsQueuedState() async throws {
        let container = try SwiftDataTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let client = FakeSyncClient()
        let scheduler = SyncScheduler(coordinator: SyncCoordinator(client: client), modelContext: context)
        scheduler.currentOwnerTokenIdentifier = "issuer|owner_a"
        scheduler.recordFailureForTesting(message: "offline", at: Date(timeIntervalSince1970: 100))

        XCTAssertNotNil(scheduler.lastFailure)

        let syncStarted = expectation(description: "sync started")
        client.onFetchChanges = {
            XCTAssertTrue(scheduler.isSyncing)
            scheduler.requestSync()
            XCTAssertTrue(scheduler.hasQueuedSyncRequest)
            scheduler.currentOwnerTokenIdentifier = "issuer|owner_b"
            syncStarted.fulfill()
        }

        scheduler.requestSync()
        await fulfillment(of: [syncStarted], timeout: 1.0)
        try await waitUntil { !scheduler.isSyncing }

        XCTAssertNil(scheduler.lastFailure)
        XCTAssertNil(scheduler.lastSyncedAt)
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
