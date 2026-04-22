import SwiftUI

struct WorkoutHeaderView: View {
    let elapsedSeconds: Int
    let completedSets: Int
    let totalSets: Int
    let onFinish: () -> Void

    private var progressValue: Double {
        guard totalSets > 0 else { return 0 }
        return Double(completedSets) / Double(totalSets)
    }

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 8) {
                Circle()
                    .fill(AppTheme.accentBright)
                    .frame(width: 8, height: 8)
                Text(AppTheme.formatDuration(elapsedSeconds))
                    .font(.system(size: 18, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(AppTheme.textPrimary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(AppTheme.surfaceMuted)
            .overlay(
                Capsule()
                    .stroke(AppTheme.borderStrong)
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Sets")
                    Spacer()
                    Text("\(completedSets)/\(totalSets)")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)

                ProgressView(value: progressValue)
                    .tint(AppTheme.accentBright)
                    .scaleEffect(x: 1, y: 1.3, anchor: .center)
            }

            Button(action: onFinish) {
                Text("Finish")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 26)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(AppTheme.accentGradient)
                            .shadow(color: AppTheme.accentGlow, radius: 18, y: 8)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppTheme.shellPadding)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .background(.ultraThinMaterial.opacity(0.92))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 1)
        }
    }
}
