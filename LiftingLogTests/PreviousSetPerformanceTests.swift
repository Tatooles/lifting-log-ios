import SwiftData
import XCTest
@testable import LiftingLog

@MainActor
final class PreviousSetPerformanceTests: XCTestCase {
    func testReturnsLastCompletedSessionSetsByIndex() throws {
        let container = try SwiftDataTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let exercise = Exercise(
            name: "Bench Press",
            category: .strength,
            equipment: .barbell,
            primaryMuscleGroup: .chest
        )
        context.insert(exercise)

        try insertCompletedSession(
            startedAt: Date(timeIntervalSince1970: 100),
            exercise: exercise,
            sets: [(135, 10), (145, 8)],
            in: context
        )
        try insertCompletedSession(
            startedAt: Date(timeIntervalSince1970: 200),
            exercise: exercise,
            sets: [(155, 6), (160, 5), (165, 3)],
            in: context
        )

        let active = WorkoutSession(
            title: "Today",
            startedAt: Date(timeIntervalSince1970: 300),
            status: .active,
            source: .blank
        )
        let activeLogged = LoggedExercise(orderIndex: 0, exercise: exercise)
        active.loggedExercises.append(activeLogged)
        context.insert(active)
        context.insert(activeLogged)
        for (index, pair) in [(225.0, 1), (230.0, 1), (235.0, 1)].enumerated() {
            let set = LoggedSet(
                orderIndex: index,
                weight: pair.0,
                reps: pair.1,
                kind: .working,
                isCompleted: true,
                completedAt: active.startedAt
            )
            activeLogged.sets.append(set)
            context.insert(set)
        }
        try context.save()

        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
        let previous = PreviousSetPerformance.lastCompletedSets(
            for: activeLogged,
            in: sessions,
            ownerTokenIdentifier: nil
        )

        XCTAssertEqual(previous, [
            PreviousSetPerformance(weight: 155, reps: 6),
            PreviousSetPerformance(weight: 160, reps: 5),
            PreviousSetPerformance(weight: 165, reps: 3),
        ])
    }

    func testReturnsEmptyWhenNoHistory() throws {
        let container = try SwiftDataTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let exercise = Exercise(
            name: "Squat",
            category: .strength,
            equipment: .barbell,
            primaryMuscleGroup: .quads
        )
        context.insert(exercise)
        let active = WorkoutSession(title: "Today", startedAt: .now, status: .active, source: .blank)
        let logged = LoggedExercise(orderIndex: 0, exercise: exercise)
        active.loggedExercises.append(logged)
        context.insert(active)
        context.insert(logged)
        try context.save()

        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
        XCTAssertTrue(
            PreviousSetPerformance.lastCompletedSets(for: logged, in: sessions, ownerTokenIdentifier: nil).isEmpty
        )
    }

    func testDisplayTextIncludesRepsWhenWeightIsMissing() {
        let previous = PreviousSetPerformance(weight: nil, reps: 8)

        XCTAssertEqual(previous.displayText(weightUnit: .pounds), "- × 8")
    }

    private func insertCompletedSession(
        startedAt: Date,
        exercise: Exercise,
        sets: [(Double, Int)],
        in context: ModelContext
    ) throws {
        let session = WorkoutSession(title: "Past", startedAt: startedAt, status: .completed, source: .blank)
        let logged = LoggedExercise(orderIndex: 0, exercise: exercise)
        session.loggedExercises.append(logged)
        context.insert(session)
        context.insert(logged)

        for (index, pair) in sets.enumerated() {
            let set = LoggedSet(
                orderIndex: index,
                weight: pair.0,
                reps: pair.1,
                kind: .working,
                isCompleted: true,
                completedAt: startedAt
            )
            logged.sets.append(set)
            context.insert(set)
        }
        try context.save()
    }
}
