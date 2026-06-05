import Foundation

struct ExerciseHistoryRoute: Hashable, Identifiable {
    let exerciseID: UUID?
    let name: String
    let equipmentRaw: String

    var id: String {
        if let exerciseID {
            return "exercise-\(exerciseID.uuidString)"
        }

        return "snapshot-\(name.lowercased())-\(equipmentRaw.lowercased())"
    }

    init(exerciseID: UUID?, name: String, equipmentRaw: String = ExerciseEquipment.other.rawValue) {
        self.exerciseID = exerciseID
        self.name = name
        self.equipmentRaw = equipmentRaw
    }

    init(summary: ExerciseHistorySummary) {
        self.init(exerciseID: summary.exerciseID, name: summary.name, equipmentRaw: summary.equipmentRaw)
    }

    init(loggedExercise: LoggedExercise) {
        self.init(
            exerciseID: loggedExercise.exercise?.id,
            name: loggedExercise.exerciseSnapshotName,
            equipmentRaw: loggedExercise.effectiveSnapshotEquipmentRaw
        )
    }
}
