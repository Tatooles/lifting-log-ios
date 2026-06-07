import Foundation
import SwiftData

@MainActor
final class SettingsExerciseSyncCoordinator {
    private let client: SettingsExerciseSyncClient
    private let recorder = SyncOutboxRecorder()
    private var isRunning = false

    init(client: SettingsExerciseSyncClient) {
        self.client = client
    }

    func prepareForSync(ownerTokenIdentifier: String, context: ModelContext) throws {
        for settings in try context.fetch(FetchDescriptor<UserSettings>()) {
            if settings.syncOwnerTokenIdentifier == nil {
                settings.syncOwnerTokenIdentifier = ownerTokenIdentifier
            }
        }

        for exercise in try context.fetch(FetchDescriptor<Exercise>()) {
            if exercise.syncOwnerTokenIdentifier == nil {
                exercise.syncOwnerTokenIdentifier = ownerTokenIdentifier
            }
        }

        for entry in try context.fetch(FetchDescriptor<SyncOutboxEntry>()) {
            guard entry.entityKind == .userSettings || entry.entityKind == .exercise else {
                continue
            }

            if entry.ownerTokenIdentifier == nil {
                entry.ownerTokenIdentifier = ownerTokenIdentifier
            }
            if entry.ownerTokenIdentifier == ownerTokenIdentifier, entry.status == .inFlight {
                recorder.markPendingForRetry(entry, now: .now)
            }
        }

        try context.save()
    }
}
