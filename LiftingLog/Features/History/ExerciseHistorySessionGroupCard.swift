import SwiftUI

struct ExerciseHistorySessionGroupCard: View {
    let group: ExerciseHistorySessionGroup
    var showsExerciseNotes: Bool = true

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                header
                setEntries
                exerciseNotes
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(group.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(WorkoutFormatters.compactDate(group.startedAt))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            Text(setCountLabel(for: group.completedSetCount))
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AppTheme.surfaceMuted)
                .clipShape(Capsule())
        }
    }

    private var setEntries: some View {
        VStack(spacing: 8) {
            ForEach(group.setEntries) { entry in
                HStack {
                    Text("Set \(entry.displaySetNumber)")
                    Spacer()
                    Text(setSummary(for: entry.set))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    @ViewBuilder
    private var exerciseNotes: some View {
        if showsExerciseNotes, let notes = group.exerciseNotes {
            VStack(alignment: .leading, spacing: 6) {
                Divider()
                    .overlay(AppTheme.border)
                Text("NOTES")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(AppTheme.textTertiary)
                Text(notes)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func setSummary(for set: LoggedSet) -> String {
        let weight = set.weight.map(WorkoutFormatters.number) ?? "-"
        let reps = set.reps.map(String.init) ?? "-"

        if let rpe = set.rpe {
            return "\(weight) x \(reps) @ \(WorkoutFormatters.number(rpe))"
        }

        return "\(weight) x \(reps)"
    }

    private func setCountLabel(for count: Int) -> String {
        count == 1 ? "1 set" : "\(count) sets"
    }
}
