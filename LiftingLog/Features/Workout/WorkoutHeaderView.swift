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
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Circle()
                    .fill(AppTheme.accentBright)
                    .frame(width: 6, height: 6)
                Text(AppTheme.formatDuration(elapsedSeconds))
                    .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(AppTheme.textPrimary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Sets")
                    Spacer()
                    Text("\(completedSets)/\(totalSets)")
                }
                .font(.system(size: 12, weight: .medium))

                ProgressView(value: progressValue)
                    .tint(AppTheme.accentBright)
                    .scaleEffect(x: 1, y: 1.05, anchor: .center)
            }

            Button(action: onFinish) {
                Text("Finish")
                    .font(.system(size: 15, weight: .bold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppTheme.shellPadding)
        .padding(.top, 6)
        .padding(.bottom, 7)
        .background(.ultraThinMaterial.opacity(0.88))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 1)
        }
    }
}
