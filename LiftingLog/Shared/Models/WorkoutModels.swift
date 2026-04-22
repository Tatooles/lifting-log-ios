import Foundation

enum AppTab: String, CaseIterable, Identifiable {
    case history
    case workout
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .history:
            return "History"
        case .workout:
            return "Add Workout"
        case .profile:
            return "Profile"
        }
    }

    var symbolName: String {
        switch self {
        case .history:
            return "clock"
        case .workout:
            return "plus"
        case .profile:
            return "person"
        }
    }
}

enum HistoryMode: String, CaseIterable, Identifiable {
    case workouts
    case exercises

    var id: String { rawValue }

    var title: String {
        switch self {
        case .workouts:
            return "Workouts"
        case .exercises:
            return "Exercises"
        }
    }
}

struct ExerciseSet: Identifiable, Equatable {
    let id: UUID
    var weight: String
    var reps: String
    var rpe: String
    var isDone: Bool
}

struct WorkoutExercise: Identifiable, Equatable {
    let id: UUID
    var name: String
    var isCollapsed: Bool
    var sets: [ExerciseSet]
    var notes: String
}

struct WorkoutSession: Equatable {
    var name: String
    var date: Date
    var elapsedSeconds: Int
    var exercises: [WorkoutExercise]
    var workoutNotes: String
}

struct WorkoutHistoryItem: Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String
    var dateLabel: String
    var durationLabel: String
    var exerciseCount: Int
    var setCount: Int
}

struct ExerciseHistoryItem: Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String
    var lastPerformedLabel: String
    var completionCount: Int
}
