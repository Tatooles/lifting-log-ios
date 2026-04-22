import SwiftUI

struct WorkoutHistoryDetailView: View {
    let item: WorkoutHistoryItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.name)
                            .font(.system(size: 30, weight: .bold))
                        Text(item.dateLabel)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }

                HStack(spacing: 12) {
                    metricCard(title: "Duration", value: item.durationLabel)
                    metricCard(title: "Exercises", value: "\(item.exerciseCount)")
                    metricCard(title: "Sets", value: "\(item.setCount)")
                }

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Details")
                            .font(.system(size: 18, weight: .bold))
                        Text("Detailed workout screen designs were not provided, so this native summary view is an inferred placeholder for history drill-down.")
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
            .padding(AppTheme.shellPadding)
            .padding(.bottom, 120)
        }
        .background(AppTheme.subtleBackground.ignoresSafeArea())
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func metricCard(title: String, value: String) -> some View {
        SurfaceCard {
            VStack(spacing: 6) {
                Text(value)
                    .font(.system(size: 22, weight: .bold))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
