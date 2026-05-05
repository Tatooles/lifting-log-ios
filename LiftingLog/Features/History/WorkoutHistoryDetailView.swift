import SwiftUI

struct WorkoutHistoryDetailView: View {
    let item: WorkoutHistoryItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.name)
                            .font(.system(size: 26, weight: .bold))
                        Text(item.dateLabel)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }

                HStack(spacing: 10) {
                    metricCard(title: "Duration", value: item.durationLabel)
                    metricCard(title: "Exercises", value: "\(item.exerciseCount)")
                    metricCard(title: "Sets", value: "\(item.setCount)")
                }

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Details")
                            .font(.system(size: 16, weight: .bold))
                        Text("Detailed workout screen designs were not provided, so this native summary view is an inferred placeholder for history drill-down.")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
            .padding(AppTheme.shellPadding)
            .padding(.bottom, AppTheme.contentBottomInset)
        }
        .background(AppTheme.subtleBackground.ignoresSafeArea())
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func metricCard(title: String, value: String) -> some View {
        SurfaceCard {
            VStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
