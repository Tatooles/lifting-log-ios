import XCTest
@testable import Baros

final class ActiveWorkoutSetInputTests: XCTestCase {
    func testFillsBeforeCompletionWhenEitherWeightOrRepsIsMissing() {
        let input = ActiveWorkoutSetInput()
        let previous = PreviousSetPerformance(weight: 185, reps: 5)

        XCTAssertTrue(input.shouldFillBeforeCompletion(
            isCompleted: false,
            values: .init(weight: 200, reps: nil),
            previous: previous
        ))
        XCTAssertTrue(input.shouldFillBeforeCompletion(
            isCompleted: false,
            values: .init(weight: nil, reps: 8),
            previous: previous
        ))
    }

    func testDoesNotFillBeforeCompletionWithoutPreviousOrAfterCompletion() {
        let input = ActiveWorkoutSetInput()

        XCTAssertFalse(input.shouldFillBeforeCompletion(
            isCompleted: false,
            values: .init(weight: nil, reps: nil),
            previous: nil
        ))
        XCTAssertFalse(input.shouldFillBeforeCompletion(
            isCompleted: true,
            values: .init(weight: nil, reps: nil),
            previous: PreviousSetPerformance(weight: 185, reps: 5)
        ))
    }

    func testRejectedWeightStillBlocksPreviousFillAfterEditingEnds() {
        var input = ActiveWorkoutSetInput()
        input.update("10001", for: .weight, isFocused: true)

        let commit = input.commit(
            current: .init(weight: nil, reps: 5),
            weightUnit: .pounds
        )

        XCTAssertEqual(commit.values, .init(weight: nil, reps: 5))
        XCTAssertTrue(commit.shouldPersist)
        XCTAssertFalse(input.shouldFillBeforeCompletion(
            isCompleted: false,
            values: commit.values,
            previous: PreviousSetPerformance(weight: 185, reps: 5)
        ))
    }

    func testRejectedRepsStillBlocksPreviousFillAfterEditingEnds() {
        var input = ActiveWorkoutSetInput()
        input.update("1001", for: .reps, isFocused: true)

        let commit = input.commit(
            current: .init(weight: 185, reps: nil),
            weightUnit: .pounds
        )

        XCTAssertEqual(commit.values, .init(weight: 185, reps: nil))
        XCTAssertTrue(commit.shouldPersist)
        XCTAssertFalse(input.shouldFillBeforeCompletion(
            isCompleted: false,
            values: commit.values,
            previous: PreviousSetPerformance(weight: 185, reps: 5)
        ))
    }

    func testExplicitPreviousFillClearsRejectionForTheFieldItFills() {
        var input = ActiveWorkoutSetInput()
        input.update("10001", for: .weight, isFocused: true)
        _ = input.commit(
            current: .init(weight: nil, reps: nil),
            weightUnit: .pounds
        )

        let values = ActiveWorkoutSetInput.Values(weight: 185, reps: nil)
        input.clearRejectionsSatisfiedByPreviousFill(values)

        XCTAssertTrue(input.shouldFillBeforeCompletion(
            isCompleted: false,
            values: values,
            previous: PreviousSetPerformance(weight: 185, reps: 5)
        ))
    }

    func testRejectedFieldStaysRejectedWhenPreviousFillIsInvalid() {
        var input = ActiveWorkoutSetInput()
        input.update("10001", for: .weight, isFocused: true)
        _ = input.commit(
            current: .init(weight: nil, reps: 5),
            weightUnit: .pounds
        )

        let invalidFill = ActiveWorkoutSetInput.Values(weight: 10_001, reps: 5)
        input.clearRejectionsSatisfiedByPreviousFill(invalidFill)

        XCTAssertFalse(input.shouldFillBeforeCompletion(
            isCompleted: false,
            values: .init(weight: nil, reps: 5),
            previous: PreviousSetPerformance(weight: 185, reps: 5)
        ))
    }

    func testWeightDisplayPreservesInProgressDecimalEntry() {
        var input = ActiveWorkoutSetInput()
        input.update("8.", for: .weight, isFocused: true)

        XCTAssertEqual(
            input.text(
                for: .weight,
                values: .init(weight: 8, reps: nil),
                weightUnit: .pounds
            ),
            "8."
        )
    }

    func testInvalidStoredValuesAreExposedAsMissingInsteadOfDisplayed() {
        var input = ActiveWorkoutSetInput()
        let invalidValues = ActiveWorkoutSetInput.Values(weight: 10_001, reps: 1_001)

        XCTAssertEqual(input.text(for: .weight, values: invalidValues, weightUnit: .pounds), "")
        XCTAssertEqual(input.text(for: .reps, values: invalidValues, weightUnit: .pounds), "")
        XCTAssertEqual(
            input.commit(current: invalidValues, weightUnit: .pounds),
            .init(values: .init(weight: nil, reps: nil), shouldPersist: false)
        )
    }

    func testIgnoresEmptyWriteWhenFieldIsNotFocused() {
        var input = ActiveWorkoutSetInput()
        input.update("", for: .weight, isFocused: false)

        XCTAssertEqual(
            input.commit(current: .init(weight: 185, reps: 5), weightUnit: .pounds),
            .init(values: .init(weight: 185, reps: 5), shouldPersist: false)
        )
    }

    func testHonorsEmptyWriteWhileFieldIsFocused() {
        var input = ActiveWorkoutSetInput()
        input.update("", for: .weight, isFocused: true)

        XCTAssertEqual(
            input.commit(current: .init(weight: 185, reps: 5), weightUnit: .pounds),
            .init(values: .init(weight: nil, reps: 5), shouldPersist: true)
        )
    }

    func testHonorsNonEmptyWriteRegardlessOfFocus() {
        var input = ActiveWorkoutSetInput()
        input.update("200", for: .weight, isFocused: false)

        XCTAssertEqual(
            input.commit(current: .init(weight: 185, reps: 5), weightUnit: .pounds),
            .init(values: .init(weight: 200, reps: 5), shouldPersist: true)
        )
    }
}
