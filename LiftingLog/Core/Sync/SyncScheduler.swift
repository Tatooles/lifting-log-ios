import Foundation
import SwiftData

@MainActor
@Observable
final class SyncScheduler {
    var currentOwnerTokenIdentifier: String?
    private(set) var requestCount = 0
    private var coordinator: SettingsExerciseSyncCoordinator?
    private var modelContext: ModelContext?

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
        let ownerTokenIdentifier = currentOwnerTokenIdentifier
        Task { @MainActor in
            try? await coordinator.run(ownerTokenIdentifier: ownerTokenIdentifier, context: modelContext)
        }
    }
}
