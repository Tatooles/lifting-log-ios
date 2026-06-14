import XCTest
@testable import LiftingLog

final class SetCompletionPreviousFillPolicyTests: XCTestCase {
    func testFillsBeforeCompletionWhenEitherWeightOrRepsIsMissing() {
        let previous = PreviousSetPerformance(weight: 185, reps: 5)

        XCTAssertTrue(SetCompletionPreviousFillPolicy.shouldFillBeforeCompletion(
            isCompleted: false,
            weight: 200,
            reps: nil,
            previous: previous
        ))
        XCTAssertTrue(SetCompletionPreviousFillPolicy.shouldFillBeforeCompletion(
            isCompleted: false,
            weight: nil,
            reps: 8,
            previous: previous
        ))
    }

    func testDoesNotFillBeforeCompletionWithoutPreviousOrAfterCompletion() {
        XCTAssertFalse(SetCompletionPreviousFillPolicy.shouldFillBeforeCompletion(
            isCompleted: false,
            weight: nil,
            reps: nil,
            previous: nil
        ))
        XCTAssertFalse(SetCompletionPreviousFillPolicy.shouldFillBeforeCompletion(
            isCompleted: true,
            weight: nil,
            reps: nil,
            previous: PreviousSetPerformance(weight: 185, reps: 5)
        ))
    }

    func testCompletionEmptyWriteSuppressorConsumesOnlyMatchingEmptyWrite() {
        let setID = UUID()
        var suppressor = CompletionEmptyWriteSuppressor()

        suppressor.suppress(.setWeight(setID))

        XCTAssertFalse(suppressor.shouldSuppress(value: "185", field: .setWeight(setID)))
        XCTAssertFalse(suppressor.shouldSuppress(value: "", field: .setReps(setID)))
        XCTAssertTrue(suppressor.shouldSuppress(value: "", field: .setWeight(setID)))
        XCTAssertFalse(suppressor.shouldSuppress(value: "", field: .setWeight(setID)))
    }

    func testCompletionEmptyWriteSuppressorExpiresMatchingField() {
        let setID = UUID()
        var suppressor = CompletionEmptyWriteSuppressor()

        suppressor.suppress(.setWeight(setID))
        suppressor.expire(.setWeight(setID))

        XCTAssertFalse(suppressor.shouldSuppress(value: "", field: .setWeight(setID)))
    }
}
