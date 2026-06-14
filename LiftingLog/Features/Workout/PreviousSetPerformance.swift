import Foundation

struct PreviousSetPerformance: Equatable {
    let weight: Double?
    let reps: Int?

    static func lastCompletedSets(
        for loggedExercise: LoggedExercise,
        in sessions: [WorkoutSession],
        ownerTokenIdentifier: String?
    ) -> [PreviousSetPerformance] {
        let route = ExerciseHistoryRoute(loggedExercise: loggedExercise)
        let summaries = ExerciseHistorySummary.makeSummaries(
            from: sessions,
            ownerTokenIdentifier: ownerTokenIdentifier
        )
        guard let summary = ExerciseHistorySummary.find(in: summaries, matching: route),
              let group = ExerciseHistorySessionGroup.recentGroups(
                from: sessions,
                matching: summary,
                ownerTokenIdentifier: ownerTokenIdentifier,
                limit: 1
              ).first else {
            return []
        }

        return group.setEntries.map { setEntry in
            PreviousSetPerformance(weight: setEntry.set.weight, reps: setEntry.set.reps)
        }
    }
}
