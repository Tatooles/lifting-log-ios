import SwiftUI

struct WorkoutHistoryRow: View {
    let item: WorkoutHistoryItem

    var body: some View {
        SurfaceCard {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppTheme.accentGradient)
                    .frame(width: 4, height: 64)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(item.dateLabel)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                    HStack(spacing: 12) {
                        Label(item.durationLabel, systemImage: "clock")
                        Text("\(item.exerciseCount) exercises")
                        Text("\(item.setCount) sets")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
    }
}
