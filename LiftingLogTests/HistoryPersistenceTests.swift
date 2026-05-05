import SwiftData
import XCTest
@testable import LiftingLog

@MainActor
final class HistoryPersistenceTests: XCTestCase {
    func testFinishedWorkoutAppearsInCompletedHistoryFetch() throws {
        let container = try SwiftDataTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let engine = ActiveWorkoutEngine()
        let session = try engine.startBlankWorkout(context: context)

        try engine.finishWorkout(session, context: context)

        XCTAssertEqual(try completedSessions(in: context).map(\.id), [session.id])
    }

    func testDeletedCompletedWorkoutNoLongerAppears() throws {
        let container = try SwiftDataTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let engine = ActiveWorkoutEngine()
        let session = try engine.startBlankWorkout(context: context)
        try engine.finishWorkout(session, context: context)

        context.delete(session)
        try context.save()

        XCTAssertTrue(try completedSessions(in: context).isEmpty)
    }

    func testExerciseHistoryCountsCompletedSetsOnly() throws {
        let container = try SwiftDataTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Bench Press", category: .strength, equipment: .barbell, primaryMuscle: "Chest")
        let session = WorkoutSession(title: "Push", startedAt: .now, status: .completed, source: .blank)
        let loggedExercise = LoggedExercise(orderIndex: 0, exercise: exercise, exerciseSnapshotName: exercise.name)
        loggedExercise.sets = [
            LoggedSet(orderIndex: 0, weight: 185, reps: 5, rpe: 8, isCompleted: true),
            LoggedSet(orderIndex: 1, weight: 185, reps: 5, rpe: 8, isCompleted: false)
        ]
        session.loggedExercises = [loggedExercise]
        context.insert(exercise)
        context.insert(session)
        try context.save()

        let summaries = ExerciseHistorySummary.makeSummaries(from: [session])

        XCTAssertEqual(summaries.first?.completedSetCount, 1)
    }

    func testStartingFromPastWorkoutDoesNotMutateOriginalPastWorkout() throws {
        let container = try SwiftDataTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Back Squat", category: .strength, equipment: .barbell, primaryMuscle: "Quads")
        let past = WorkoutSession(title: "Leg Day", startedAt: .now, status: .completed, source: .blank)
        let loggedExercise = LoggedExercise(orderIndex: 0, exercise: exercise, exerciseSnapshotName: exercise.name)
        loggedExercise.sets = [LoggedSet(orderIndex: 0, weight: 315, reps: 5, rpe: 8, isCompleted: true)]
        past.loggedExercises = [loggedExercise]
        context.insert(exercise)
        context.insert(past)
        try context.save()

        _ = try ActiveWorkoutEngine().startWorkout(fromPast: past, context: context)

        XCTAssertEqual(past.status, .completed)
        XCTAssertEqual(past.loggedExercises.first?.sets.first?.isCompleted, true)
        XCTAssertEqual(past.loggedExercises.first?.sets.first?.weight, 315)
    }

    private func completedSessions(in context: ModelContext) throws -> [WorkoutSession] {
        try context.fetch(FetchDescriptor<WorkoutSession>()).filter { $0.status == .completed }
    }
}
