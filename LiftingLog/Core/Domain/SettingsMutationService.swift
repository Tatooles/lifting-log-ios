import Foundation
import SwiftData

@MainActor
struct SettingsMutationService {
    private let recorder = SyncOutboxRecorder()
    private let syncScheduler: SyncScheduler?

    init(syncScheduler: SyncScheduler? = nil) {
        self.syncScheduler = syncScheduler
    }

    func updateWeightUnit(
        _ newUnit: MeasurementUnit,
        settings: UserSettings,
        ownerTokenIdentifier: String? = nil,
        context: ModelContext,
        now: Date = .now
    ) throws {
        let previousUnit = settings.weightUnit
        guard previousUnit != newUnit else { return }
        let effectiveOwner = ownerTokenIdentifier ?? syncScheduler?.currentOwnerTokenIdentifier

        let sets = try context.fetch(FetchDescriptor<LoggedSet>())
        for set in sets where !set.isDeleted {
            var didConvertSet = false
            if let weight = set.weight {
                set.weight = previousUnit.convert(weight, to: newUnit)
                didConvertSet = true
            }
            if let placeholderWeight = set.placeholderWeight {
                set.placeholderWeight = previousUnit.convert(placeholderWeight, to: newUnit)
                didConvertSet = true
            }
            if didConvertSet {
                set.touch(now: now)
                if set.loggedExercise?.session?.status != .active {
                    try recorder.recordUpdate(
                        entityKind: .loggedSet,
                        entityID: set.id,
                        ownerTokenIdentifier: effectiveOwner,
                        context: context,
                        now: now
                    )
                }
            }
        }

        settings.syncOwnerTokenIdentifier = effectiveOwner ?? settings.syncOwnerTokenIdentifier
        settings.weightUnitRaw = newUnit.rawValue
        settings.touch(now: now)
        try recorder.recordUpdate(
            entityKind: .userSettings,
            entityID: settings.id,
            ownerTokenIdentifier: effectiveOwner,
            context: context,
            now: now
        )
        try context.save()
        syncScheduler?.requestSync()
    }

    func updateDefaultRestTimerSeconds(
        _ seconds: Int,
        settings: UserSettings,
        ownerTokenIdentifier: String? = nil,
        context: ModelContext,
        now: Date = .now
    ) throws {
        guard settings.defaultRestTimerSeconds != seconds else { return }
        let effectiveOwner = ownerTokenIdentifier ?? syncScheduler?.currentOwnerTokenIdentifier

        settings.syncOwnerTokenIdentifier = effectiveOwner ?? settings.syncOwnerTokenIdentifier
        settings.defaultRestTimerSeconds = seconds
        settings.touch(now: now)
        try recorder.recordUpdate(
            entityKind: .userSettings,
            entityID: settings.id,
            ownerTokenIdentifier: effectiveOwner,
            context: context,
            now: now
        )
        try context.save()
        syncScheduler?.requestSync()
    }
}
