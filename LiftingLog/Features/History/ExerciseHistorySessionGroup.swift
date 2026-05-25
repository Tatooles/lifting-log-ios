import Foundation

struct ExerciseHistorySetEntry: Identifiable {
    let loggedExercise: LoggedExercise
    let set: LoggedSet

    var id: UUID { self.set.id }
    var displaySetNumber: Int { self.set.orderIndex + 1 }
}

struct ExerciseHistorySessionGroup: Identifiable {
    let session: WorkoutSession
    let setEntries: [ExerciseHistorySetEntry]

    var id: UUID { session.id }
    var title: String { session.title }
    var startedAt: Date { session.startedAt }
    var completedSetCount: Int { setEntries.count }
    var exerciseNotes: String {
        setEntries.first?.loggedExercise.notes ?? ""
    }

    static func makeGroups(
        from sessions: [WorkoutSession],
        matching summary: ExerciseHistorySummary
    ) -> [ExerciseHistorySessionGroup] {
        sessions
            .filter { $0.status == .completed }
            .compactMap { session in
                let entries = session.sortedLoggedExercises.flatMap { loggedExercise in
                    guard matches(loggedExercise, summary: summary) else { return [ExerciseHistorySetEntry]() }

                    return loggedExercise.sortedSets
                        .filter(\.isCompleted)
                        .map { ExerciseHistorySetEntry(loggedExercise: loggedExercise, set: $0) }
                }

                guard !entries.isEmpty else { return nil }
                return ExerciseHistorySessionGroup(session: session, setEntries: entries)
            }
            .sorted { lhs, rhs in
                if lhs.startedAt == rhs.startedAt {
                    return lhs.title < rhs.title
                }
                return lhs.startedAt > rhs.startedAt
            }
    }

    private static func matches(_ loggedExercise: LoggedExercise, summary: ExerciseHistorySummary) -> Bool {
        if let exerciseID = summary.exerciseID {
            return loggedExercise.exercise?.id == exerciseID
        }

        return loggedExercise.exerciseSnapshotName.caseInsensitiveCompare(summary.name) == .orderedSame
    }
}
