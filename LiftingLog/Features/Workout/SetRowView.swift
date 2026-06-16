import SwiftData
import SwiftUI

struct SetRowView: View {
    @Environment(\.modelContext) private var modelContext
    let set: LoggedSet
    let exerciseIndex: Int
    let index: Int
    @Bindable var engine: ActiveWorkoutEngine
    var focusedField: FocusState<WorkoutField?>.Binding
    let weightUnit: MeasurementUnit
    let previous: PreviousSetPerformance?
    let onEditRPE: (LoggedSet) -> Void
    @State private var weightInputText = WorkoutNumberInputText()

    var body: some View {
        SwipeToDeleteRow(
            deleteAccessibilityLabel: "Remove set",
            deleteAccessibilityIdentifier: "DeleteSetButton-\(exerciseIndex)-\(index)"
        ) {
            try? engine.removeSet(set, context: modelContext)
        } content: {
            rowContent
        }
    }

    private var rowContent: some View {
        HStack(spacing: 10) {
            Text("\(index + 1)")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(AppTheme.textTertiary)
                .frame(width: 18)

            previousColumn

            numericField(
                placeholder: weightUnit.fieldPlaceholder,
                text: weightBinding,
                keyboard: .decimalPad,
                focusTarget: .setWeight(set.id),
                accessibilityIdentifier: "SetWeightField-\(exerciseIndex)-\(index)"
            )

            repsField

            Button {
                completeButtonTapped()
            } label: {
                Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(set.isCompleted ? AppTheme.accentBright : AppTheme.textTertiary)
                    .symbolEffect(.bounce, value: set.isCompleted)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(set.isCompleted ? "Mark set incomplete" : "Mark set complete")
            .accessibilityIdentifier("SetCompletionButton-\(exerciseIndex)-\(index)")
        }
        .onChange(of: focusedField.wrappedValue) { previousField, newField in
            if previousField == .setWeight(set.id), newField != .setWeight(set.id) {
                weightInputText.endEditing()
            }
        }
    }

    private var previousColumn: some View {
        Button {
            guard let previous, !set.isCompleted else { return }
            fillFromPrevious(previous)
        } label: {
            Text(previousText)
                .font(.footnote.weight(.medium).monospacedDigit())
                .foregroundStyle(AppTheme.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(previous == nil || set.isCompleted)
        .accessibilityIdentifier("SetPreviousValue-\(exerciseIndex)-\(index)")
        .accessibilityLabel(previous == nil ? "No previous set" : "Previous: \(previousText)")
    }

    private var previousText: String {
        guard let previous else {
            return "—"
        }

        return previous.displayText(weightUnit: weightUnit)
    }

    private var repsField: some View {
        numericField(
            placeholder: "REPS",
            text: repsBinding,
            keyboard: .numberPad,
            focusTarget: .setReps(set.id),
            accessibilityIdentifier: "SetRepsField-\(exerciseIndex)-\(index)"
        )
        .overlay(alignment: .topTrailing) {
            rpeBadge
        }
    }

    @ViewBuilder
    private var rpeBadge: some View {
        if let rpe = set.rpe {
            Button {
                onEditRPE(set)
            } label: {
                Text("@\(WorkoutFormatters.number(rpe))")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppTheme.accentBright)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(AppTheme.accentMuted, in: Capsule())
                    .offset(x: -4, y: 4)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("SetRPEBadge-\(exerciseIndex)-\(index)")
            .accessibilityLabel("RPE \(WorkoutFormatters.number(rpe)), tap to edit")
        }
    }

    private func numericField(
        placeholder: String,
        text: Binding<String>,
        keyboard: UIKeyboardType,
        focusTarget: WorkoutField,
        accessibilityIdentifier: String
    ) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(keyboard)
            .multilineTextAlignment(.center)
            .font(.body.weight(.semibold))
            .fontDesign(.rounded)
            .foregroundStyle(AppTheme.textPrimary)
            .focused(focusedField, equals: focusTarget)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                AppTheme.fieldFill,
                in: RoundedRectangle(cornerRadius: AppTheme.fieldCornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.fieldCornerRadius, style: .continuous)
                    .strokeBorder(
                        focusedField.wrappedValue == focusTarget ? AppTheme.accentBright.opacity(0.7) : .clear,
                        lineWidth: 1.5
                    )
            )
            .animation(.easeOut(duration: 0.15), value: focusedField.wrappedValue == focusTarget)
            .accessibilityIdentifier(accessibilityIdentifier)
            .id(focusTarget)
    }

    private var weightBinding: Binding<String> {
        Binding(
            get: { weightInputText.displayText(for: weightUnit.displayWeight(fromCanonicalPounds: set.weight)) },
            set: { value in
                if CompletionEmptyWriteGuard.shouldIgnoreEmptyWrite(
                    value: value,
                    isFieldFocused: focusedField.wrappedValue == .setWeight(set.id)
                ) {
                    weightInputText.endEditing()
                    return
                }

                weightInputText.updateDraft(value)
                let displayWeight = WorkoutFormatters.parseNumber(value)
                let canonicalWeight = weightUnit.canonicalWeight(fromDisplayWeight: displayWeight)
                try? engine.updateSet(set, weight: canonicalWeight, reps: set.reps, rpe: set.rpe, context: modelContext)
            }
        )
    }

    private var repsBinding: Binding<String> {
        Binding(
            get: { set.reps.map(String.init) ?? "" },
            set: { value in
                if CompletionEmptyWriteGuard.shouldIgnoreEmptyWrite(
                    value: value,
                    isFieldFocused: focusedField.wrappedValue == .setReps(set.id)
                ) {
                    return
                }

                try? engine.updateSet(set, weight: set.weight, reps: Int(value), rpe: set.rpe, context: modelContext)
            }
        )
    }

    private func completeButtonTapped() {
        clearFocusedFieldForThisSet()
        if SetCompletionPreviousFillPolicy.shouldFillBeforeCompletion(
            isCompleted: set.isCompleted,
            weight: set.weight,
            reps: set.reps,
            previous: previous
        ), let previous {
            fillFromPrevious(previous)
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            try? engine.toggleSetCompletion(set, context: modelContext)
        }
    }

    private func fillFromPrevious(_ previous: PreviousSetPerformance) {
        weightInputText.endEditing()
        try? engine.fillSetFromPrevious(set, previous: previous, context: modelContext)
    }

    private func clearFocusedFieldForThisSet() {
        if focusedField.wrappedValue == .setWeight(set.id)
            || focusedField.wrappedValue == .setReps(set.id) {
            focusedField.wrappedValue = nil
        }
    }
}

enum SetCompletionPreviousFillPolicy {
    static func shouldFillBeforeCompletion(
        isCompleted: Bool,
        weight: Double?,
        reps: Int?,
        previous: PreviousSetPerformance?
    ) -> Bool {
        !isCompleted && (weight == nil || reps == nil) && previous != nil
    }
}

struct WorkoutNumberInputText {
    private var draft: String?

    mutating func updateDraft(_ value: String) {
        draft = value
    }

    mutating func endEditing() {
        draft = nil
    }

    func displayText(for value: Double?) -> String {
        draft ?? value.map(WorkoutFormatters.number) ?? ""
    }
}

enum CompletionEmptyWriteGuard {
    /// A blank text write is only legitimate while the field is focused, i.e. the
    /// user is actively clearing it. When the field is not focused, an empty write
    /// is a spurious commit-on-resign — for example the keyboard dismissal that
    /// follows auto-filling a blank set from Previous on completion — and must be
    /// ignored, otherwise it would wipe the value that was just filled.
    ///
    /// This is deterministic: it keys off the live focus state rather than a timing
    /// window, so it holds regardless of how late the resign write is delivered.
    static func shouldIgnoreEmptyWrite(value: String, isFieldFocused: Bool) -> Bool {
        value.isEmpty && !isFieldFocused
    }
}
