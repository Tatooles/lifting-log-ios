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
        ownerTokenIdentifier: String?,
        sourceSessionID: UUID? = nil
    ) -> [PreviousSetPerformance] {
        lastCompletedSetsByExerciseID(
            for: [loggedExercise],
            in: sessions,
            ownerTokenIdentifier: ownerTokenIdentifier,
            sourceSessionID: sourceSessionID
        )[loggedExercise.id] ?? []
    }

    static func lastCompletedSetsByExerciseID(
        for loggedExercises: [LoggedExercise],
        in sessions: [WorkoutSession],
        ownerTokenIdentifier: String?,
        sourceSessionID: UUID? = nil
    ) -> [UUID: [PreviousSetPerformance]] {
        let routeIDByLoggedExerciseID = Dictionary(
            uniqueKeysWithValues: loggedExercises.map { loggedExercise in
                (loggedExercise.id, ExerciseHistoryRoute(loggedExercise: loggedExercise).id)
            }
        )
        let requestedRouteIDs = Set(routeIDByLoggedExerciseID.values)
        guard !requestedRouteIDs.isEmpty else { return [:] }

        let previousSetsByRouteID = lastCompletedSetsByRouteID(
            matching: requestedRouteIDs,
            in: sessions,
            ownerTokenIdentifier: ownerTokenIdentifier,
            sourceSessionID: sourceSessionID
        )

        return Dictionary(
            uniqueKeysWithValues: routeIDByLoggedExerciseID.map { loggedExerciseID, routeID in
                (loggedExerciseID, previousSetsByRouteID[routeID] ?? [])
            }
        )
    }

    private static func lastCompletedSetsByRouteID(
        matching routeIDs: Set<String>,
        in sessions: [WorkoutSession],
        ownerTokenIdentifier: String?,
        sourceSessionID: UUID?
    ) -> [String: [PreviousSetPerformance]] {
        let sortedCompletedSessions = WorkoutSession.visibleCompletedSessions(
            from: sessions,
            ownerTokenIdentifier: ownerTokenIdentifier
        )
        .filter { session in
            sourceSessionID.map { session.id == $0 } ?? true
        }
        .sorted { lhs, rhs in
            if lhs.startedAt == rhs.startedAt {
                return lhs.title < rhs.title
            }
            return lhs.startedAt > rhs.startedAt
        }

        var result: [String: [PreviousSetPerformance]] = [:]

        for session in sortedCompletedSessions {
            for loggedExercise in session.sortedLoggedExercises {
                let routeID = ExerciseHistoryRoute(loggedExercise: loggedExercise).id
                guard routeIDs.contains(routeID), result[routeID] == nil else { continue }

                let completedSets = loggedExercise.sortedSets.filter(\.isCompleted)
                guard !completedSets.isEmpty else { continue }

                result[routeID] = completedSets.map { set in
                    PreviousSetPerformance(weight: set.weight, reps: set.reps)
                }
            }

            if result.count == routeIDs.count {
                break
            }
        }

        return result
    }
}
