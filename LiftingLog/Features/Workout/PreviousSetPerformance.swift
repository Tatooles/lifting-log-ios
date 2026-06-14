import Foundation

struct PreviousSetPerformance: Equatable {
    let weight: Double?
    let reps: Int?

    func displayText(weightUnit: MeasurementUnit) -> String {
        let displayWeight = weightUnit.displayWeight(fromCanonicalPounds: weight)
        let weightText = displayWeight.map(WorkoutFormatters.number)
        let repsText = reps.map { WorkoutFormatters.number(Double($0)) }

        switch (weightText, repsText) {
        case let (.some(weightText), .some(repsText)):
            return "\(weightText) × \(repsText)"
        case let (.none, .some(repsText)):
            return "- × \(repsText)"
        case let (.some(weightText), .none):
            return "\(weightText) × -"
        case (.none, .none):
            return "—"
        }
    }

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

        return (group.loggedExerciseEntries.first?.setEntries ?? []).map { setEntry in
            PreviousSetPerformance(weight: setEntry.set.weight, reps: setEntry.set.reps)
        }
    }
}
