import XCTest
@testable import LiftingLog

final class AppStoreTests: XCTestCase {
    func testTogglingSetUpdatesCompletionCounts() {
        let store = AppStore.preview
        let exerciseID = try! XCTUnwrap(store.activeWorkout.exercises.first?.id)
        let setID = try! XCTUnwrap(store.activeWorkout.exercises.first?.sets.last?.id)

        store.toggleSetDone(exerciseID: exerciseID, setID: setID)

        XCTAssertEqual(store.completedSetCount, 4)
        XCTAssertTrue(store.activeWorkout.exercises[0].sets[2].isDone)
    }

    func testAddingExerciseAppendsEmptyExercise() {
        let store = AppStore.preview

        store.addExercise()

        XCTAssertEqual(store.activeWorkout.exercises.last?.name, "New Exercise")
        XCTAssertEqual(store.activeWorkout.exercises.last?.sets.count, 1)
    }

    func testAddingSetCopiesLastWeightAndReps() {
        let store = AppStore.preview
        let exerciseID = try! XCTUnwrap(store.activeWorkout.exercises.first?.id)

        store.addSet(to: exerciseID)

        let sets = store.activeWorkout.exercises[0].sets
        XCTAssertEqual(sets.count, 4)
        XCTAssertEqual(sets.last?.weight, "225")
        XCTAssertEqual(sets.last?.reps, "5")
        XCTAssertEqual(sets.last?.rpe, "")
    }

    func testTogglingCardCollapseUpdatesExerciseState() {
        let store = AppStore.preview
        let exerciseID = try! XCTUnwrap(store.activeWorkout.exercises.first?.id)

        store.toggleExerciseCollapsed(exerciseID)

        XCTAssertTrue(store.activeWorkout.exercises[0].isCollapsed)
    }

    func testEstimatedVolumeSumsCompletedWeightsAndReps() {
        let store = AppStore.preview

        XCTAssertEqual(store.estimatedCompletedVolume, 2250 + 1480)
    }

    @MainActor
    func testLoadingHistoryTransitionsToLoadedState() async {
        let store = AppStore.preview

        await store.loadHistory()

        switch store.workoutHistoryState {
        case let .loaded(workouts):
            XCTAssertGreaterThan(workouts.count, 3)
        default:
            XCTFail("Workout history was not loaded")
        }

        switch store.exerciseHistoryState {
        case let .loaded(exercises):
            XCTAssertGreaterThan(exercises.count, 5)
        default:
            XCTFail("Exercise history was not loaded")
        }
    }
}
