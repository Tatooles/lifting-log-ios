import SwiftData
import XCTest
@testable import LiftingLog

@MainActor
final class SeedDataServiceTests: XCTestCase {
    func testSeedServiceInsertsExpectedExercises() throws {
        let container = try SwiftDataTestSupport.makeInMemoryContainer()
        let context = container.mainContext

        try SeedDataService.seedIfNeeded(context: context)

        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        XCTAssertEqual(exercises.filter(\.isSeeded).count, 20)
        let backSquat = try XCTUnwrap(exercises.first { $0.seedIdentifier == "back-squat" })
        XCTAssertEqual(backSquat.name, "Back Squat")
        XCTAssertEqual(backSquat.category, .strength)
        XCTAssertEqual(backSquat.equipment, .barbell)
    }

    func testSeedServiceIsIdempotent() throws {
        let container = try SwiftDataTestSupport.makeInMemoryContainer()
        let context = container.mainContext

        try SeedDataService.seedIfNeeded(context: context)
        try SeedDataService.seedIfNeeded(context: context)

        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        let metadata = try context.fetch(FetchDescriptor<SeedMetadata>())
        XCTAssertEqual(exercises.filter(\.isSeeded).count, 20)
        XCTAssertEqual(metadata.filter { $0.key == "exerciseSeed" }.count, 1)
    }

    func testSettingsSingletonIsCreatedExactlyOnce() throws {
        let container = try SwiftDataTestSupport.makeInMemoryContainer()
        let context = container.mainContext

        try SeedDataService.seedIfNeeded(context: context)
        try SeedDataService.seedIfNeeded(context: context)

        XCTAssertEqual(try context.fetch(FetchDescriptor<UserSettings>()).count, 1)
    }
}
