import Foundation

enum MockRepository {
    static let backSquatExerciseID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    static let romanianDeadliftExerciseID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    static let legPressExerciseID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!

    static func makeActiveWorkout() -> WorkoutSession {
        WorkoutSession(
            name: "Lower Body A",
            date: Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 21)) ?? .now,
            elapsedSeconds: 76,
            exercises: [
                WorkoutExercise(
                    id: backSquatExerciseID,
                    name: "Back Squat",
                    isCollapsed: false,
                    sets: [
                        ExerciseSet(id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1")!, weight: "225", reps: "5", rpe: "7", isDone: true),
                        ExerciseSet(id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2")!, weight: "225", reps: "5", rpe: "7.5", isDone: true),
                        ExerciseSet(id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa3")!, weight: "225", reps: "5", rpe: "8", isDone: false)
                    ],
                    notes: ""
                ),
                WorkoutExercise(
                    id: romanianDeadliftExerciseID,
                    name: "Romanian Deadlift",
                    isCollapsed: false,
                    sets: [
                        ExerciseSet(id: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1")!, weight: "185", reps: "8", rpe: "7", isDone: true),
                        ExerciseSet(id: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2")!, weight: "185", reps: "8", rpe: "", isDone: false)
                    ],
                    notes: ""
                ),
                WorkoutExercise(
                    id: legPressExerciseID,
                    name: "Leg Press",
                    isCollapsed: true,
                    sets: [
                        ExerciseSet(id: UUID(uuidString: "cccccccc-cccc-cccc-cccc-ccccccccccc1")!, weight: "320", reps: "12", rpe: "", isDone: false)
                    ],
                    notes: ""
                )
            ],
            workoutNotes: ""
        )
    }

    static let workoutHistory: [WorkoutHistoryItem] = [
        WorkoutHistoryItem(id: UUID(), name: "Lower Body A", dateLabel: "Mon, Apr 21, 2026", durationLabel: "1:02:14", exerciseCount: 4, setCount: 16),
        WorkoutHistoryItem(id: UUID(), name: "Upper Body Push", dateLabel: "Sat, Apr 19, 2026", durationLabel: "48:33", exerciseCount: 5, setCount: 18),
        WorkoutHistoryItem(id: UUID(), name: "Lower Body B", dateLabel: "Thu, Apr 17, 2026", durationLabel: "55:08", exerciseCount: 4, setCount: 14),
        WorkoutHistoryItem(id: UUID(), name: "Upper Body Pull", dateLabel: "Tue, Apr 15, 2026", durationLabel: "52:47", exerciseCount: 5, setCount: 17),
        WorkoutHistoryItem(id: UUID(), name: "Lower Body A", dateLabel: "Sun, Apr 13, 2026", durationLabel: "1:04:20", exerciseCount: 4, setCount: 16),
        WorkoutHistoryItem(id: UUID(), name: "Upper Body Push", dateLabel: "Fri, Apr 11, 2026", durationLabel: "46:55", exerciseCount: 5, setCount: 18)
    ]

    static let exerciseHistory: [ExerciseHistoryItem] = [
        ExerciseHistoryItem(id: UUID(), name: "Back Squat", lastPerformedLabel: "Apr 21, 2026", completionCount: 18),
        ExerciseHistoryItem(id: UUID(), name: "Romanian Deadlift", lastPerformedLabel: "Apr 21, 2026", completionCount: 14),
        ExerciseHistoryItem(id: UUID(), name: "Leg Press", lastPerformedLabel: "Apr 21, 2026", completionCount: 12),
        ExerciseHistoryItem(id: UUID(), name: "Bench Press", lastPerformedLabel: "Apr 19, 2026", completionCount: 16),
        ExerciseHistoryItem(id: UUID(), name: "Overhead Press", lastPerformedLabel: "Apr 19, 2026", completionCount: 10),
        ExerciseHistoryItem(id: UUID(), name: "Incline DB Press", lastPerformedLabel: "Apr 19, 2026", completionCount: 8),
        ExerciseHistoryItem(id: UUID(), name: "Pull-Up", lastPerformedLabel: "Apr 15, 2026", completionCount: 12),
        ExerciseHistoryItem(id: UUID(), name: "Barbell Row", lastPerformedLabel: "Apr 15, 2026", completionCount: 14),
        ExerciseHistoryItem(id: UUID(), name: "Face Pull", lastPerformedLabel: "Apr 15, 2026", completionCount: 9),
        ExerciseHistoryItem(id: UUID(), name: "Leg Extension", lastPerformedLabel: "Apr 17, 2026", completionCount: 7)
    ]
}
