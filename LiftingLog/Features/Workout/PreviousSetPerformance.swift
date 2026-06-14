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
        if let sourceSessionID {
            return lastCompletedSetsByExerciseIDFromSourceSession(
                for: loggedExercises,
                in: sessions,
                ownerTokenIdentifier: ownerTokenIdentifier,
                sourceSessionID: sourceSessionID
            )
        }

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
            ownerTokenIdentifier: ownerTokenIdentifier
        )

        return Dictionary(
            uniqueKeysWithValues: routeIDByLoggedExerciseID.map { loggedExerciseID, routeID in
                (loggedExerciseID, previousSetsByRouteID[routeID] ?? [])
            }
        )
    }

    private static func lastCompletedSetsByExerciseIDFromSourceSession(
        for loggedExercises: [LoggedExercise],
        in sessions: [WorkoutSession],
        ownerTokenIdentifier: String?,
        sourceSessionID: UUID
    ) -> [UUID: [PreviousSetPerformance]] {
        guard let sourceSession = WorkoutSession.visibleCompletedSessions(
            from: sessions,
            ownerTokenIdentifier: ownerTokenIdentifier
        ).first(where: { $0.id == sourceSessionID }) else {
            return Dictionary(uniqueKeysWithValues: loggedExercises.map { ($0.id, []) })
        }

        let sourceEntriesByRouteID = Dictionary(grouping: sourceSession.sortedLoggedExercises) { loggedExercise in
            ExerciseHistoryRoute(loggedExercise: loggedExercise).id
        }
        var consumedSourceEntryCountByRouteID: [String: Int] = [:]

        return Dictionary(
            uniqueKeysWithValues: loggedExercises.map { loggedExercise in
                let routeID = ExerciseHistoryRoute(loggedExercise: loggedExercise).id
                let sourceIndex = consumedSourceEntryCountByRouteID[routeID, default: 0]
                consumedSourceEntryCountByRouteID[routeID] = sourceIndex + 1

                let sourceEntries = sourceEntriesByRouteID[routeID] ?? []
                let sourceLoggedExercise = sourceIndex < sourceEntries.count ? sourceEntries[sourceIndex] : nil
                return (
                    loggedExercise.id,
                    sourceLoggedExercise.map { completedSetPerformances(for: $0) } ?? []
                )
            }
        )
    }

    private static func lastCompletedSetsByRouteID(
        matching routeIDs: Set<String>,
        in sessions: [WorkoutSession],
        ownerTokenIdentifier: String?
    ) -> [String: [PreviousSetPerformance]] {
        let sortedCompletedSessions = WorkoutSession.visibleCompletedSessions(
            from: sessions,
            ownerTokenIdentifier: ownerTokenIdentifier
        )
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

                result[routeID] = completedSets.map { makePerformance(from: $0) }
            }

            if result.count == routeIDs.count {
                break
            }
        }

        return result
    }

    private static func completedSetPerformances(for loggedExercise: LoggedExercise) -> [PreviousSetPerformance] {
        loggedExercise.sortedSets
            .filter(\.isCompleted)
            .map { makePerformance(from: $0) }
    }

    private static func makePerformance(from set: LoggedSet) -> PreviousSetPerformance {
        PreviousSetPerformance(weight: set.weight, reps: set.reps)
    }
}
