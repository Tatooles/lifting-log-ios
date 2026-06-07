import SwiftData
import XCTest
@testable import LiftingLog

@MainActor
final class SyncCursorStateTests: XCTestCase {
    func testCursorStatePersistsOwnerAndCursors() throws {
        let container = try SwiftDataTestSupport.makeInMemoryContainer()
        let context = container.mainContext
        let state = SyncCursorState(
            ownerTokenIdentifier: "issuer|owner_a",
            userSettingsCursor: 12,
            exercisesCursor: 34
        )

        context.insert(state)
        try context.save()

        let fetched = try XCTUnwrap(context.fetch(FetchDescriptor<SyncCursorState>()).first)
        XCTAssertEqual(fetched.ownerTokenIdentifier, "issuer|owner_a")
        XCTAssertEqual(fetched.userSettingsCursor, 12)
        XCTAssertEqual(fetched.exercisesCursor, 34)
    }

    func testCursorStateLookupCreatesMissingOwnerState() throws {
        let container = try SwiftDataTestSupport.makeInMemoryContainer()
        let context = container.mainContext

        let state = try SyncCursorState.state(for: "issuer|owner_a", context: context)
        try context.save()

        XCTAssertEqual(state.ownerTokenIdentifier, "issuer|owner_a")
        XCTAssertEqual(state.userSettingsCursor, 0)
        XCTAssertEqual(state.exercisesCursor, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<SyncCursorState>()).count, 1)
    }
}
