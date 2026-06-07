import Foundation

struct UserSettingsSyncPayload: Codable, Equatable {
    let clientId: String
    let createdAt: Double
    let updatedAt: Double
    let deletedAt: Double?
    let weightUnitRaw: String
    let defaultRestTimerSeconds: Int
    let hasCompletedOnboarding: Bool
}

struct ExerciseSyncPayload: Codable, Equatable {
    let clientId: String
    let createdAt: Double
    let updatedAt: Double
    let deletedAt: Double?
    let seedIdentifier: String?
    let name: String
    let categoryRaw: String
    let equipmentRaw: String
    let primaryMuscleRaw: String
    let primaryMuscleGroupRaw: String
    let notes: String
    let isArchived: Bool
    let isSeeded: Bool
}

enum SyncPayloadMapper {
    static func userSettingsPayload(from settings: UserSettings) -> UserSettingsSyncPayload {
        UserSettingsSyncPayload(
            clientId: settings.id.uuidString.lowercased(),
            createdAt: settings.createdAt.timeIntervalSince1970,
            updatedAt: settings.updatedAt.timeIntervalSince1970,
            deletedAt: settings.deletedAt?.timeIntervalSince1970,
            weightUnitRaw: settings.weightUnitRaw,
            defaultRestTimerSeconds: settings.defaultRestTimerSeconds,
            hasCompletedOnboarding: settings.hasCompletedOnboarding
        )
    }

    static func exercisePayload(from exercise: Exercise) -> ExerciseSyncPayload {
        ExerciseSyncPayload(
            clientId: exercise.id.uuidString.lowercased(),
            createdAt: exercise.createdAt.timeIntervalSince1970,
            updatedAt: exercise.updatedAt.timeIntervalSince1970,
            deletedAt: exercise.deletedAt?.timeIntervalSince1970,
            seedIdentifier: exercise.seedIdentifier,
            name: exercise.name,
            categoryRaw: exercise.categoryRaw,
            equipmentRaw: exercise.equipmentRaw,
            primaryMuscleRaw: exercise.primaryMuscleRaw,
            primaryMuscleGroupRaw: exercise.primaryMuscleGroupRaw,
            notes: exercise.notes,
            isArchived: exercise.isArchived,
            isSeeded: exercise.isSeeded
        )
    }
}
