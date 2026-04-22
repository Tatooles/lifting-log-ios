import SwiftUI

struct FinishWorkoutSheet: View {
    @Bindable var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Capsule()
                .fill(AppTheme.borderStrong)
                .frame(width: 46, height: 5)
                .padding(.top, 10)

            VStack(spacing: 6) {
                Text("Finish Workout?")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Great session — here's your summary")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            HStack(spacing: 12) {
                summaryCard(title: "Duration", value: AppTheme.formatDuration(store.activeWorkout.elapsedSeconds))
                summaryCard(title: "Sets Done", value: "\(store.completedSetCount)/\(store.totalSetCount)")
                summaryCard(title: "Volume", value: "\(store.estimatedCompletedVolume)")
            }

            Button {
                dismiss()
            } label: {
                Text("Save Workout")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(AppTheme.accentGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            .buttonStyle(.plain)

            Button("Keep Going") {
                dismiss()
            }
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(AppTheme.textSecondary)
            .padding(.bottom, 10)
        }
        .padding(.horizontal, 24)
        .background(AppTheme.surface)
        .presentationDetents([.height(360)])
        .presentationCornerRadius(32)
    }

    private func summaryCard(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(AppTheme.surfaceMuted)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(AppTheme.border)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}
