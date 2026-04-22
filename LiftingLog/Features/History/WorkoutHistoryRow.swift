import SwiftUI

struct WorkoutHistoryRow: View {
    let item: WorkoutHistoryItem

    var body: some View {
        SurfaceCard {
            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppTheme.accentGradient)
                    .frame(width: 4, height: 76)

                VStack(alignment: .leading, spacing: 6) {
                    Text(item.name)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(item.dateLabel)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                    HStack(spacing: 14) {
                        Label(item.durationLabel, systemImage: "clock")
                        Text("\(item.exerciseCount) exercises")
                        Text("\(item.setCount) sets")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
    }
}
