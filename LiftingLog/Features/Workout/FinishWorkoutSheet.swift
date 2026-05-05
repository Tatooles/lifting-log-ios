import SwiftUI

struct FinishWorkoutSheet: View {
    @Bindable var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Capsule()
                .fill(AppTheme.borderStrong)
                .frame(width: 40, height: 5)
                .padding(.top, 8)

            VStack(spacing: 4) {
                Text("Finish Workout?")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Great session — here's your summary")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            HStack(spacing: 10) {
                summaryCard(title: "Duration", value: AppTheme.formatDuration(store.activeWorkout.elapsedSeconds))
                summaryCard(title: "Sets Done", value: "\(store.completedSetCount)/\(store.totalSetCount)")
                summaryCard(title: "Volume", value: "\(store.estimatedCompletedVolume)")
            }

            Button {
                dismiss()
            } label: {
                Text("Save Workout")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(AppTheme.accentGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .buttonStyle(.plain)

            Button("Keep Going") {
                dismiss()
            }
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(AppTheme.textSecondary)
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 20)
        .background(AppTheme.surface)
        .presentationDetents([.height(330)])
        .presentationCornerRadius(28)
    }

    private func summaryCard(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(AppTheme.surfaceMuted)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.border)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
