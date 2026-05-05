import SwiftUI

struct ExerciseHistoryDetailView: View {
    let item: ExerciseHistoryItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SurfaceCard {
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(AppTheme.accentMuted)
                            .frame(width: 60, height: 60)
                            .overlay {
                                Image(systemName: "dumbbell.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(AppTheme.accentBright)
                            }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name)
                                .font(.system(size: 24, weight: .bold))
                            Text("Last performed \(item.lastPerformedLabel)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                }

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("History Summary")
                            .font(.system(size: 16, weight: .bold))
                        Text("Completed \(item.completionCount) tracked sets across recent workouts. This detail screen is a native placeholder inferred from the history list state.")
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
}
