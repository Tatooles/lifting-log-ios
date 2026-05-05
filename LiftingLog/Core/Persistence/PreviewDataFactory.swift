import Foundation
import SwiftData

enum PreviewDataFactory {
    @MainActor
    static func makePreviewContainer(includeActiveWorkout: Bool = true) -> ModelContainer {
        do {
            let container = try ModelContainerFactory.makeModelContainer(isStoredInMemoryOnly: true)
            let context = container.mainContext
            try SeedDataService.seedIfNeeded(context: context)
            try addPreviewData(context: context, includeActiveWorkout: includeActiveWorkout)
            return container
        } catch {
            fatalError("Failed to create preview container: \(error)")
        }
    }

    @MainActor
    private static func addPreviewData(context: ModelContext, includeActiveWorkout: Bool) throws {
        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        guard let squat = exercises.first(where: { $0.seedIdentifier == "back-squat" }),
              let bench = exercises.first(where: { $0.seedIdentifier == "bench-press" }) else {
            return
        }

        let completed = WorkoutSession(
            title: "Lower Body",
            startedAt: Date().addingTimeInterval(-86_400),
            endedAt: Date().addingTimeInterval(-82_800),
            durationSeconds: 3_600,
            notes: "Strong first session.",
            status: .completed,
            source: .blank
        )
        let completedSquat = LoggedExercise(orderIndex: 0, exercise: squat)
        completedSquat.sets = [
            LoggedSet(orderIndex: 0, weight: 275, reps: 5, rpe: 8, isCompleted: true),
            LoggedSet(orderIndex: 1, weight: 295, reps: 3, rpe: 8.5, isCompleted: true)
        ]
        completed.loggedExercises = [completedSquat]
        context.insert(completed)

        if includeActiveWorkout {
            let active = WorkoutSession(title: "Upper Body", startedAt: Date().addingTimeInterval(-900), status: .active, source: .blank)
            let activeBench = LoggedExercise(orderIndex: 0, exercise: bench)
            activeBench.sets = [
                LoggedSet(orderIndex: 0, weight: 185, reps: 5, rpe: 8, isCompleted: true),
                LoggedSet(orderIndex: 1, weight: 195, reps: 5, rpe: nil, isCompleted: false)
            ]
            active.loggedExercises = [activeBench]
            context.insert(active)
        }

        try context.save()
    }
}
