import Foundation
import SwiftData

@Model
final class LoggedExercise: Identifiable {
    @Attribute(.unique) var id: UUID
    var orderIndex: Int
    var exerciseSnapshotName: String
    var exerciseSnapshotEquipmentRaw: String = ExerciseEquipment.other.rawValue
    var exerciseSnapshotPrimaryMuscleGroupRaw: String = ExerciseMuscleGroup.other.rawValue
    var notes: String
    var referenceNotes: String?
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var exercise: Exercise?
    var session: WorkoutSession?
    @Relationship(deleteRule: .cascade, inverse: \LoggedSet.loggedExercise) var sets: [LoggedSet]

    init(
        id: UUID = UUID(),
        orderIndex: Int,
        exercise: Exercise? = nil,
        exerciseSnapshotName: String? = nil,
        exerciseSnapshotEquipmentRaw: String? = nil,
        exerciseSnapshotPrimaryMuscleGroupRaw: String? = nil,
        notes: String = "",
        referenceNotes: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        deletedAt: Date? = nil,
        sets: [LoggedSet] = []
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.exercise = exercise
        self.exerciseSnapshotName = exerciseSnapshotName ?? exercise?.name ?? "Exercise"
        self.exerciseSnapshotEquipmentRaw = exerciseSnapshotEquipmentRaw ?? exercise?.equipmentRaw ?? ExerciseEquipment.other.rawValue
        self.exerciseSnapshotPrimaryMuscleGroupRaw = exerciseSnapshotPrimaryMuscleGroupRaw ?? exercise?.primaryMuscleGroup.rawValue ?? ExerciseMuscleGroup.other.rawValue
        self.notes = notes
        self.referenceNotes = referenceNotes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.sets = sets

        for set in sets {
            set.loggedExercise = self
        }
    }

    var sortedSets: [LoggedSet] {
        sets
            .filter { !$0.isDeleted }
            .sorted { $0.orderIndex < $1.orderIndex }
    }

    var isDeleted: Bool {
        deletedAt != nil
    }

    var snapshotEquipment: ExerciseEquipment {
        ExerciseEquipment(rawValue: effectiveSnapshotEquipmentRaw) ?? .other
    }

    var snapshotPrimaryMuscleGroup: ExerciseMuscleGroup {
        ExerciseMuscleGroup(rawValue: effectiveSnapshotPrimaryMuscleGroupRaw) ?? .other
    }

    var metadataDisplayText: String {
        "\(snapshotEquipment.displayName) • \(snapshotPrimaryMuscleGroup.displayName)"
    }

    var effectiveSnapshotEquipmentRaw: String {
        guard exerciseSnapshotEquipmentRaw == ExerciseEquipment.other.rawValue else {
            return exerciseSnapshotEquipmentRaw
        }

        return exercise?.equipmentRaw ?? exerciseSnapshotEquipmentRaw
    }

    var effectiveSnapshotPrimaryMuscleGroupRaw: String {
        guard exerciseSnapshotPrimaryMuscleGroupRaw == ExerciseMuscleGroup.other.rawValue else {
            return exerciseSnapshotPrimaryMuscleGroupRaw
        }

        return exercise?.primaryMuscleGroup.rawValue ?? exerciseSnapshotPrimaryMuscleGroupRaw
    }

    func touch(now: Date = .now) {
        updatedAt = now
        session?.touch(now: now)
    }

    func markDeleted(now: Date = .now) {
        deletedAt = now
        updatedAt = now
    }

    func restoreFromDeletion(now: Date = .now) {
        deletedAt = nil
        updatedAt = now
    }
}
