import Foundation

struct ActiveWorkoutSetInput {
    enum Field {
        case weight
        case reps
    }

    struct Values: Equatable {
        var weight: Double?
        var reps: Int?
    }

    struct Commit: Equatable {
        let values: Values
        let shouldPersist: Bool
    }

    private var weightDraft: String?
    private var repsDraft: String?
    private var rejectedWeight = false
    private var rejectedReps = false

    mutating func update(_ text: String, for field: Field, isFocused: Bool) {
        guard !(text.isEmpty && !isFocused) else { return }
        switch field {
        case .weight:
            weightDraft = text
        case .reps:
            repsDraft = text
        }
    }

    func text(for field: Field, values: Values, weightUnit: MeasurementUnit) -> String {
        switch field {
        case .weight:
            let validWeight = WorkoutNumericInputPolicy.validatedWeight(values.weight)
            let displayWeight = weightUnit.displayWeight(fromCanonicalPounds: validWeight)
            return weightDraft ?? displayWeight.map(WorkoutFormatters.number) ?? ""
        case .reps:
            let validReps = WorkoutNumericInputPolicy.validatedReps(values.reps)
            return repsDraft ?? validReps.map(String.init) ?? ""
        }
    }

    mutating func commit(current: Values, weightUnit: MeasurementUnit) -> Commit {
        guard weightDraft != nil || repsDraft != nil else {
            return Commit(
                values: Values(
                    weight: WorkoutNumericInputPolicy.validatedWeight(current.weight),
                    reps: WorkoutNumericInputPolicy.validatedReps(current.reps)
                ),
                shouldPersist: false
            )
        }

        let weight: Double?
        if let weightDraft {
            weight = WorkoutNumericInputPolicy.parseWeight(weightDraft, unit: weightUnit)
            rejectedWeight = !weightDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && weight == nil
        } else {
            weight = WorkoutNumericInputPolicy.validatedWeight(current.weight)
        }

        let reps: Int?
        if let repsDraft {
            reps = WorkoutNumericInputPolicy.parseReps(repsDraft)
            rejectedReps = !repsDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && reps == nil
        } else {
            reps = WorkoutNumericInputPolicy.validatedReps(current.reps)
        }

        self.weightDraft = nil
        self.repsDraft = nil

        return Commit(
            values: Values(weight: weight, reps: reps),
            shouldPersist: true
        )
    }

    func shouldFillBeforeCompletion(
        isCompleted: Bool,
        values: Values,
        previous: PreviousSetPerformance?
    ) -> Bool {
        !rejectedWeight
            && !rejectedReps
            && !isCompleted
            && (values.weight == nil || values.reps == nil)
            && previous != nil
    }

    mutating func clearRejectionsSatisfiedByPreviousFill(_ values: Values) {
        if WorkoutNumericInputPolicy.validatedWeight(values.weight) != nil {
            rejectedWeight = false
        }
        if WorkoutNumericInputPolicy.validatedReps(values.reps) != nil {
            rejectedReps = false
        }
    }
}
