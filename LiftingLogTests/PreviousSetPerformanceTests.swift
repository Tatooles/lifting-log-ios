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

    func testUsesOnlyFirstMatchingLoggedExerciseFromPreviousSession() throws {
        let container = try SwiftDataTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let exercise = Exercise(
            name: "Bench Press",
            category: .strength,
            equipment: .barbell,
            primaryMuscleGroup: .chest
        )
        context.insert(exercise)

        let previousSession = WorkoutSession(
            title: "Duplicate Bench",
            startedAt: Date(timeIntervalSince1970: 100),
            status: .completed,
            source: .blank
        )
        let firstPrevious = LoggedExercise(orderIndex: 0, exercise: exercise)
        firstPrevious.sets.append(
            LoggedSet(orderIndex: 0, weight: 185, reps: 5, isCompleted: true, completedAt: previousSession.startedAt)
        )
        let secondPrevious = LoggedExercise(orderIndex: 1, exercise: exercise)
        secondPrevious.sets.append(
            LoggedSet(orderIndex: 0, weight: 195, reps: 3, isCompleted: true, completedAt: previousSession.startedAt)
        )
        previousSession.loggedExercises.append(contentsOf: [firstPrevious, secondPrevious])
        context.insert(previousSession)
        context.insert(firstPrevious)
        context.insert(secondPrevious)

        let active = WorkoutSession(
            title: "Today",
            startedAt: Date(timeIntervalSince1970: 200),
            status: .active,
            source: .blank
        )
        let activeLogged = LoggedExercise(orderIndex: 0, exercise: exercise)
        active.loggedExercises.append(activeLogged)
        context.insert(active)
        context.insert(activeLogged)
        try context.save()

        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
        let previous = PreviousSetPerformance.lastCompletedSets(
            for: activeLogged,
            in: sessions,
            ownerTokenIdentifier: nil
        )

        XCTAssertEqual(previous, [
            PreviousSetPerformance(weight: 185, reps: 5),
        ])
    }

    func testBatchLookupUsesSinglePreviousEntryPerActiveExercise() throws {
        let container = try SwiftDataTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let bench = Exercise(
            name: "Bench Press",
            category: .strength,
            equipment: .barbell,
            primaryMuscleGroup: .chest
        )
        let squat = Exercise(
            name: "Back Squat",
            category: .strength,
            equipment: .barbell,
            primaryMuscleGroup: .quads
        )
        context.insert(bench)
        context.insert(squat)

        let previousSession = WorkoutSession(
            title: "Past",
            startedAt: Date(timeIntervalSince1970: 100),
            status: .completed,
            source: .blank
        )
        let firstBench = LoggedExercise(orderIndex: 0, exercise: bench)
        firstBench.sets.append(
            LoggedSet(orderIndex: 0, weight: 185, reps: 5, isCompleted: true, completedAt: previousSession.startedAt)
        )
        let secondBench = LoggedExercise(orderIndex: 1, exercise: bench)
        secondBench.sets.append(
            LoggedSet(orderIndex: 0, weight: 195, reps: 3, isCompleted: true, completedAt: previousSession.startedAt)
        )
        let previousSquat = LoggedExercise(orderIndex: 2, exercise: squat)
        previousSquat.sets.append(
            LoggedSet(orderIndex: 0, weight: 225, reps: 8, isCompleted: true, completedAt: previousSession.startedAt)
        )
        previousSession.loggedExercises.append(contentsOf: [firstBench, secondBench, previousSquat])
        context.insert(previousSession)
        context.insert(firstBench)
        context.insert(secondBench)
        context.insert(previousSquat)

        let active = WorkoutSession(
            title: "Today",
            startedAt: Date(timeIntervalSince1970: 200),
            status: .active,
            source: .blank
        )
        let activeBench = LoggedExercise(orderIndex: 0, exercise: bench)
        let activeSquat = LoggedExercise(orderIndex: 1, exercise: squat)
        active.loggedExercises.append(contentsOf: [activeBench, activeSquat])
        context.insert(active)
        context.insert(activeBench)
        context.insert(activeSquat)
        try context.save()

        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
        let lookup = PreviousSetPerformance.lastCompletedSetsByExerciseID(
            for: active.sortedLoggedExercises,
            in: sessions,
            ownerTokenIdentifier: nil
        )

        XCTAssertEqual(lookup[activeBench.id], [
            PreviousSetPerformance(weight: 185, reps: 5),
        ])
        XCTAssertEqual(lookup[activeSquat.id], [
            PreviousSetPerformance(weight: 225, reps: 8),
        ])
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
