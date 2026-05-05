import SwiftData
import XCTest
@testable import LiftingLog

@MainActor
final class SettingsTests: XCTestCase {
    func testSettingsSingletonExistsAfterSeed() throws {
        let container = try SwiftDataTestSupport.makeInMemoryContainer()
        let context = container.mainContext

        try SeedDataService.seedIfNeeded(context: context)

        let settings = try context.fetch(FetchDescriptor<UserSettings>())
        XCTAssertEqual(settings.count, 1)
        XCTAssertEqual(settings.first?.weightUnit, .pounds)
    }

    func testUpdatingWeightUnitPersists() throws {
        let container = try SwiftDataTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        try SeedDataService.seedIfNeeded(context: context)

        let settings = try XCTUnwrap(context.fetch(FetchDescriptor<UserSettings>()).first)
        settings.weightUnit = .kilograms
        try context.save()

        let fetched = try XCTUnwrap(context.fetch(FetchDescriptor<UserSettings>()).first)
        XCTAssertEqual(fetched.weightUnit, .kilograms)
    }

    func testSeedDoesNotOverwriteUserEditedSettings() throws {
        let container = try SwiftDataTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        try SeedDataService.seedIfNeeded(context: context)

        let settings = try XCTUnwrap(context.fetch(FetchDescriptor<UserSettings>()).first)
        settings.weightUnit = .kilograms
        settings.defaultRestTimerSeconds = 120
        try context.save()

        try SeedDataService.seedIfNeeded(context: context)

        let fetched = try XCTUnwrap(context.fetch(FetchDescriptor<UserSettings>()).first)
        XCTAssertEqual(fetched.weightUnit, .kilograms)
        XCTAssertEqual(fetched.defaultRestTimerSeconds, 120)
    }
}
