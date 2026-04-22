import Foundation
import Observation

@Observable
final class AppStore {
    var selectedTab: AppTab
    var historyMode: HistoryMode
    var activeWorkout: WorkoutSession
    var workoutHistoryState: ViewState<[WorkoutHistoryItem]>
    var exerciseHistoryState: ViewState<[ExerciseHistoryItem]>

    init(
        selectedTab: AppTab = .workout,
        historyMode: HistoryMode = .workouts,
        activeWorkout: WorkoutSession,
        workoutHistoryState: ViewState<[WorkoutHistoryItem]> = .loading,
        exerciseHistoryState: ViewState<[ExerciseHistoryItem]> = .loading
    ) {
        self.selectedTab = selectedTab
        self.historyMode = historyMode
        self.activeWorkout = activeWorkout
        self.workoutHistoryState = workoutHistoryState
        self.exerciseHistoryState = exerciseHistoryState
    }

    static var preview: AppStore {
        AppStore(activeWorkout: MockRepository.makeActiveWorkout())
    }

    var completedSetCount: Int {
        activeWorkout.exercises.flatMap(\.sets).filter(\.isDone).count
    }

    var totalSetCount: Int {
        activeWorkout.exercises.flatMap(\.sets).count
    }

    var estimatedCompletedVolume: Int {
        activeWorkout.exercises
            .flatMap(\.sets)
            .filter(\.isDone)
            .reduce(into: 0) { total, set in
                total += (Int(set.weight) ?? 0) * (Int(set.reps) ?? 0)
            }
    }

    func tickElapsed() {
        activeWorkout.elapsedSeconds += 1
    }

    func toggleSetDone(exerciseID: UUID, setID: UUID) {
        guard let exerciseIndex = activeWorkout.exercises.firstIndex(where: { $0.id == exerciseID }),
              let setIndex = activeWorkout.exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID }) else { return }

        activeWorkout.exercises[exerciseIndex].sets[setIndex].isDone.toggle()
    }

    func updateSetWeight(exerciseID: UUID, setID: UUID, value: String) {
        updateSet(exerciseID: exerciseID, setID: setID) { $0.weight = value }
    }

    func updateSetReps(exerciseID: UUID, setID: UUID, value: String) {
        updateSet(exerciseID: exerciseID, setID: setID) { $0.reps = value }
    }

    func updateSetRPE(exerciseID: UUID, setID: UUID, value: String) {
        updateSet(exerciseID: exerciseID, setID: setID) { $0.rpe = value }
    }

    func toggleExerciseCollapsed(_ exerciseID: UUID) {
        guard let exerciseIndex = activeWorkout.exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        activeWorkout.exercises[exerciseIndex].isCollapsed.toggle()
    }

    func addSet(to exerciseID: UUID) {
        guard let exerciseIndex = activeWorkout.exercises.firstIndex(where: { $0.id == exerciseID }) else { return }

        let lastSet = activeWorkout.exercises[exerciseIndex].sets.last
        activeWorkout.exercises[exerciseIndex].sets.append(
            ExerciseSet(
                id: UUID(),
                weight: lastSet?.weight ?? "",
                reps: lastSet?.reps ?? "",
                rpe: "",
                isDone: false
            )
        )
    }

    func addExercise() {
        activeWorkout.exercises.append(
            WorkoutExercise(
                id: UUID(),
                name: "New Exercise",
                isCollapsed: false,
                sets: [ExerciseSet(id: UUID(), weight: "", reps: "", rpe: "", isDone: false)],
                notes: ""
            )
        )
    }

    func updateExerciseNotes(exerciseID: UUID, notes: String) {
        guard let exerciseIndex = activeWorkout.exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        activeWorkout.exercises[exerciseIndex].notes = notes
    }

    @MainActor
    func loadHistory() async {
        if case .loaded = workoutHistoryState, case .loaded = exerciseHistoryState {
            return
        }

        workoutHistoryState = .loading
        exerciseHistoryState = .loading

        try? await Task.sleep(for: .milliseconds(150))

        workoutHistoryState = MockRepository.workoutHistory.isEmpty
            ? .empty(message: "No workouts logged yet.")
            : .loaded(MockRepository.workoutHistory)

        exerciseHistoryState = MockRepository.exerciseHistory.isEmpty
            ? .empty(message: "No exercises logged yet.")
            : .loaded(MockRepository.exerciseHistory)
    }

    @MainActor
    func retryHistoryLoad() async {
        await loadHistory()
    }

    private func updateSet(exerciseID: UUID, setID: UUID, mutation: (inout ExerciseSet) -> Void) {
        guard let exerciseIndex = activeWorkout.exercises.firstIndex(where: { $0.id == exerciseID }),
              let setIndex = activeWorkout.exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID }) else { return }

        mutation(&activeWorkout.exercises[exerciseIndex].sets[setIndex])
    }
}
