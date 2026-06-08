import Foundation
import SwiftData

@MainActor
@Observable
final class SyncScheduler {
    var currentOwnerTokenIdentifier: String? {
        didSet {
            guard oldValue != currentOwnerTokenIdentifier else { return }
            cancelInFlightSync()
        }
    }
    private(set) var requestCount = 0
    private var coordinator: SettingsExerciseSyncCoordinator?
    private var modelContext: ModelContext?
    private var syncTask: Task<Void, Never>?
    private var needsSync = false

    init(coordinator: SettingsExerciseSyncCoordinator? = nil, modelContext: ModelContext? = nil) {
        self.coordinator = coordinator
        self.modelContext = modelContext
    }

    func configure(coordinator: SettingsExerciseSyncCoordinator, modelContext: ModelContext) {
        self.coordinator = coordinator
        self.modelContext = modelContext
    }

    func requestSync() {
        requestCount += 1
        guard let coordinator, let modelContext else { return }
        guard syncTask == nil else {
            needsSync = true
            return
        }

        startSyncTask(coordinator: coordinator, modelContext: modelContext)
    }

    func seedDefaultsForCurrentOwner() {
        guard let currentOwnerTokenIdentifier, let modelContext else { return }
        try? SeedDataService.seedIfNeeded(context: modelContext, ownerTokenIdentifier: currentOwnerTokenIdentifier)
    }

    private func cancelInFlightSync() {
        guard let syncTask else { return }
        needsSync = false
        syncTask.cancel()
    }

    private func startSyncTask(coordinator: SettingsExerciseSyncCoordinator, modelContext: ModelContext) {
        syncTask = Task { @MainActor in
            while true {
                needsSync = false
                do {
                    try await coordinator.run(ownerTokenIdentifier: currentOwnerTokenIdentifier, context: modelContext)
                } catch is CancellationError {
                    break
                } catch {
                    break
                }
                if Task.isCancelled {
                    break
                }
                guard needsSync else { break }
            }

            let shouldStartQueuedSync = needsSync && currentOwnerTokenIdentifier != nil
            needsSync = false
            syncTask = nil
            if shouldStartQueuedSync {
                startSyncTask(coordinator: coordinator, modelContext: modelContext)
            }
        }
    }
}
