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
        guard currentOwnerTokenIdentifier != nil else { return }
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
                let syncOwnerTokenIdentifier = currentOwnerTokenIdentifier
                do {
                    try await coordinator.run(ownerTokenIdentifier: syncOwnerTokenIdentifier, context: modelContext)
                    guard !Task.isCancelled, currentOwnerTokenIdentifier == syncOwnerTokenIdentifier else {
                        break
                    }
                    lastSyncedAt = .now
                    lastFailure = nil
                } catch is CancellationError {
                    break
                } catch {
                    guard !Task.isCancelled, currentOwnerTokenIdentifier == syncOwnerTokenIdentifier else {
                        break
                    }
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
