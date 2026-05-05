import Foundation

struct WorkoutBlueprint: Equatable {
    var title: String
    var notes: String
    var exercises: [WorkoutBlueprintExercise]

    static func blank(now: Date = .now) -> WorkoutBlueprint {
        WorkoutBlueprint(title: "Workout", notes: "", exercises: [])
    }

    static func fromCompletedSession(_ session: WorkoutSession) -> WorkoutBlueprint {
        WorkoutBlueprint(
            title: session.title,
            notes: session.notes,
            exercises: session.sortedLoggedExercises.map { loggedExercise in
                WorkoutBlueprintExercise(
                    exerciseID: loggedExercise.exercise?.id ?? loggedExercise.id,
                    exerciseName: loggedExercise.exerciseSnapshotName,
                    notes: loggedExercise.notes,
                    sets: loggedExercise.sortedSets.map { set in
                        WorkoutBlueprintSet(
                            weight: set.weight,
                            reps: set.reps,
                            rpe: set.rpe,
                            kind: set.kind
                        )
                    }
                )
            }
        )
    }
}

struct WorkoutBlueprintExercise: Equatable, Identifiable {
    var exerciseID: UUID
    var exerciseName: String
    var notes: String
    var sets: [WorkoutBlueprintSet]

    var id: UUID { exerciseID }
}

struct WorkoutBlueprintSet: Equatable, Identifiable {
    let id = UUID()
    var weight: Double?
    var reps: Int?
    var rpe: Double?
    var kind: SetKind
}
