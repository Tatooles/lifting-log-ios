import SwiftUI

struct SetRowView: View {
    @Bindable var store: AppStore
    let exerciseID: UUID
    let set: ExerciseSet
    let index: Int

    var body: some View {
        HStack(spacing: 12) {
            Text("\(index + 1)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.textTertiary)
                .frame(width: 20)

            numericField(
                placeholder: "lbs",
                text: Binding(
                    get: { set.weight },
                    set: { store.updateSetWeight(exerciseID: exerciseID, setID: set.id, value: $0) }
                ),
                keyboard: .numberPad
            )

            numericField(
                placeholder: "reps",
                text: Binding(
                    get: { set.reps },
                    set: { store.updateSetReps(exerciseID: exerciseID, setID: set.id, value: $0) }
                ),
                keyboard: .numberPad
            )

            numericField(
                placeholder: "RPE",
                text: Binding(
                    get: { set.rpe },
                    set: { store.updateSetRPE(exerciseID: exerciseID, setID: set.id, value: $0) }
                ),
                keyboard: .decimalPad
            )

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    store.toggleSetDone(exerciseID: exerciseID, setID: set.id)
                }
            } label: {
                Image(systemName: set.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 30, weight: .regular))
                    .foregroundStyle(set.isDone ? AppTheme.accentBright : AppTheme.borderStrong)
            }
            .buttonStyle(.plain)
        }
    }

    private func numericField(
        placeholder: String,
        text: Binding<String>,
        keyboard: UIKeyboardType
    ) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(keyboard)
            .multilineTextAlignment(.center)
            .font(.system(size: 18, weight: .semibold, design: .rounded))
            .foregroundStyle(AppTheme.textPrimary)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(AppTheme.surfaceStrong)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(AppTheme.borderStrong)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}
