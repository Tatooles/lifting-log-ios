import SwiftData
import XCTest
@testable import LiftingLog

@MainActor
final class ModelPersistenceTests: XCTestCase {
    func testCreatingExerciseSavesAndFetchesByID() throws {
        let container = try SwiftDataTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let exercise = Exercise(
            name: "Safety Bar Squat",
            category: .strength,
            equipment: .barbell,
            primaryMuscle: "Quads"
        )

        context.insert(exercise)
        try context.save()

        let id = exercise.id
        let descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.id == id })
        let fetched = try context.fetch(descriptor)
        XCTAssertEqual(fetched.first?.name, "Safety Bar Squat")
        XCTAssertEqual(fetched.first?.category, .strength)
    }

    func testWorkoutSessionPersistsLoggedExerciseAndSetRelationships() throws {
        let container = try SwiftDataTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Bench Press", category: .strength, equipment: .barbell, primaryMuscle: "Chest")
        let session = WorkoutSession(title: "Push", startedAt: .now, status: .active, source: .blank)
        let loggedExercise = LoggedExercise(orderIndex: 0, exercise: exercise, exerciseSnapshotName: exercise.name)
        let set = LoggedSet(orderIndex: 0, weight: 185, reps: 5, rpe: 8, isCompleted: true)

        loggedExercise.sets.append(set)
        session.loggedExercises.append(loggedExercise)
        context.insert(exercise)
        context.insert(session)
        try context.save()

        let sessionID = session.id
        let descriptor = FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.id == sessionID })
        let fetched = try XCTUnwrap(context.fetch(descriptor).first)
        XCTAssertEqual(fetched.loggedExercises.count, 1)
        XCTAssertEqual(fetched.loggedExercises.first?.sets.count, 1)
        XCTAssertEqual(fetched.loggedExercises.first?.sets.first?.completedVolume, 925)
    }

    func testCompletedSetVolumeRequiresWeightRepsAndCompletion() throws {
        let completed = LoggedSet(orderIndex: 0, weight: 100, reps: 5, rpe: nil, isCompleted: true)
        let missingWeight = LoggedSet(orderIndex: 1, weight: nil, reps: 5, rpe: nil, isCompleted: true)
        let missingReps = LoggedSet(orderIndex: 2, weight: 100, reps: nil, rpe: nil, isCompleted: true)
        let incomplete = LoggedSet(orderIndex: 3, weight: 100, reps: 5, rpe: nil, isCompleted: false)

        XCTAssertEqual(completed.completedVolume, 500)
        XCTAssertEqual(missingWeight.completedVolume, 0)
        XCTAssertEqual(missingReps.completedVolume, 0)
        XCTAssertEqual(incomplete.completedVolume, 0)
    }

    func testHealthDataLinkStoresFutureProviderWithoutFrameworkImport() throws {
        let container = try SwiftDataTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let localID = UUID()
        let link = HealthDataLink(
            providerRaw: "healthKit",
            localEntityKindRaw: "workoutSession",
            localEntityID: localID,
            externalIdentifier: "external-workout-id",
            externalType: "workout",
            syncStatus: .notSynced
        )

        context.insert(link)
        try context.save()

        let descriptor = FetchDescriptor<HealthDataLink>()
        let fetched = try XCTUnwrap(context.fetch(descriptor).first)
        XCTAssertEqual(fetched.providerRaw, "healthKit")
        XCTAssertEqual(fetched.localEntityID, localID)
    }

    func testWorkoutTemplateCanBeCreatedWithoutDrivingUI() throws {
        let container = try SwiftDataTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let template = WorkoutTemplate(name: "Future Template", notes: "Stored for later")

        context.insert(template)
        try context.save()

        let templates = try context.fetch(FetchDescriptor<WorkoutTemplate>())
        XCTAssertEqual(templates.map(\.name), ["Future Template"])
    }

    func testCustomExerciseCanBeCreatedEditedAndArchived() throws {
        let container = try SwiftDataTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let exercise = Exercise(name: "Seal Row", category: .strength, equipment: .dumbbell, primaryMuscle: "Back")

        context.insert(exercise)
        try context.save()

        exercise.name = "Chest Supported Row"
        exercise.archive()
        try context.save()

        let activeExercises = try context.fetch(FetchDescriptor<Exercise>()).filter { !$0.isArchived }
        XCTAssertFalse(activeExercises.contains { $0.id == exercise.id })
    }

    func testSeededExerciseWithHistoryArchivesInsteadOfHardDeleting() throws {
        let container = try SwiftDataTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let exercise = Exercise(
            seedIdentifier: "bench-press",
            name: "Bench Press",
            category: .strength,
            equipment: .barbell,
            primaryMuscle: "Chest",
            isSeeded: true
        )
        let session = WorkoutSession(title: "Push", startedAt: .now, status: .completed, source: .blank)
        let loggedExercise = LoggedExercise(orderIndex: 0, exercise: exercise, exerciseSnapshotName: exercise.name)
        session.loggedExercises.append(loggedExercise)

        context.insert(exercise)
        context.insert(session)
        try context.save()

        try exercise.archiveOrDelete(context: context)
        try context.save()

        let allExercises = try context.fetch(FetchDescriptor<Exercise>())
        XCTAssertTrue(allExercises.contains { $0.id == exercise.id && $0.isArchived })
    }
}
