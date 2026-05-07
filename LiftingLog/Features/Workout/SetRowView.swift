import SwiftData
import SwiftUI

struct SetRowView: View {
    @Environment(\.modelContext) private var modelContext
    let set: LoggedSet
    let exerciseIndex: Int
    let index: Int
    @Bindable var engine: ActiveWorkoutEngine
    var focusedField: FocusState<WorkoutField?>.Binding

    var body: some View {
        HStack(spacing: 10) {
            Text("\(index + 1)")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.textTertiary)
                .frame(width: 18)

            numericField(
                placeholder: "lbs",
                text: weightBinding,
                keyboard: .numberPad,
                focusTarget: .setWeight(set.id),
                accessibilityIdentifier: "SetWeightField-\(exerciseIndex)-\(index)"
            )

            numericField(
                placeholder: "reps",
                text: repsBinding,
                keyboard: .numberPad,
                focusTarget: .setReps(set.id),
                accessibilityIdentifier: "SetRepsField-\(exerciseIndex)-\(index)"
            )

            numericField(
                placeholder: "RPE",
                text: rpeBinding,
                keyboard: .decimalPad,
                focusTarget: .setRPE(set.id),
                accessibilityIdentifier: "SetRPEField-\(exerciseIndex)-\(index)"
            )

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    try? engine.toggleSetCompletion(set, context: modelContext)
                }
            } label: {
                Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(set.isCompleted ? AppTheme.accentBright : AppTheme.borderStrong)
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                try? engine.removeSet(set, context: modelContext)
            } label: {
                Image(systemName: "minus.circle")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            .buttonStyle(.plain)
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
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundStyle(AppTheme.textPrimary)
            .focused(focusedField, equals: focusTarget)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(AppTheme.surfaceStrong)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppTheme.borderStrong)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var weightBinding: Binding<String> {
        Binding(
            get: { set.weight.map(WorkoutFormatters.number) ?? "" },
            set: { value in
                try? engine.updateSet(set, weight: Double(value), reps: set.reps, rpe: set.rpe, context: modelContext)
            }
        )
    }

    private var repsBinding: Binding<String> {
        Binding(
            get: { set.reps.map(String.init) ?? "" },
            set: { value in
                try? engine.updateSet(set, weight: set.weight, reps: Int(value), rpe: set.rpe, context: modelContext)
            }
        )
    }

    private var rpeBinding: Binding<String> {
        Binding(
            get: { set.rpe.map(WorkoutFormatters.number) ?? "" },
            set: { value in
                try? engine.updateSet(set, weight: set.weight, reps: set.reps, rpe: Double(value), context: modelContext)
            }
        )
    }
}
