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
        let sourceEntriesByID = Dictionary(
            uniqueKeysWithValues: sourceSession.sortedLoggedExercises.map { ($0.id, $0) }
        )
        var consumedSourceEntryCountByRouteID: [String: Int] = [:]

        return Dictionary(
            uniqueKeysWithValues: loggedExercises.map { loggedExercise in
                if let sourceLoggedExerciseID = loggedExercise.sourceLoggedExerciseID,
                   let sourceLoggedExercise = sourceEntriesByID[sourceLoggedExerciseID] {
                    return (
                        loggedExercise.id,
                        sourceSetPerformances(for: loggedExercise, in: sourceLoggedExercise)
                    )
                }

                let routeID = ExerciseHistoryRoute(loggedExercise: loggedExercise).id
                let sourceIndex = consumedSourceEntryCountByRouteID[routeID, default: 0]
                consumedSourceEntryCountByRouteID[routeID] = sourceIndex + 1

                let sourceEntries = sourceEntriesByRouteID[routeID] ?? []
                let sourceLoggedExercise = sourceIndex < sourceEntries.count ? sourceEntries[sourceIndex] : nil
                return (
                    loggedExercise.id,
                    sourceLoggedExercise.map { sourceSetPerformances(for: loggedExercise, in: $0) } ?? []
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

    private static func sourceSetPerformances(
        for activeLoggedExercise: LoggedExercise,
        in sourceLoggedExercise: LoggedExercise
    ) -> [PreviousSetPerformance] {
        let activeSets = activeLoggedExercise.sortedSets

        // Legacy clones (created before sets carried a stable source link) and
        // lower-level callers without active rows fall back to source order.
        guard activeSets.contains(where: { $0.sourceLoggedSetID != nil }) else {
            return setPerformances(for: sourceLoggedExercise)
        }

        // Align each active row to its specific source set so cloned rows keep
        // their own previous values even after an earlier row is deleted or the
        // rows are reordered. Rows added after cloning have no source set.
        let sourceSets = sourceLoggedExercise.sortedSets
        let sourceSetsByID = Dictionary(uniqueKeysWithValues: sourceSets.map { ($0.id, $0) })

        return activeSets.enumerated().map { index, activeSet in
            if let sourceSetID = activeSet.sourceLoggedSetID,
               let sourceSet = sourceSetsByID[sourceSetID] {
                return makePerformance(from: sourceSet)
            }

            if index < sourceSets.count {
                return makePerformance(from: sourceSets[index])
            }

            return PreviousSetPerformance(weight: nil, reps: nil)
        }
    }

    private static func setPerformances(for loggedExercise: LoggedExercise) -> [PreviousSetPerformance] {
        loggedExercise.sortedSets
            .map { makePerformance(from: $0) }
    }

    private static func makePerformance(from set: LoggedSet) -> PreviousSetPerformance {
        PreviousSetPerformance(weight: set.weight, reps: set.reps)
    }
}
