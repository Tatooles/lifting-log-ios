import SwiftUI

struct ExerciseHistoryDetailView: View {
    let item: ExerciseHistoryItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SurfaceCard {
                    HStack(spacing: 16) {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(AppTheme.accentMuted)
                            .frame(width: 72, height: 72)
                            .overlay {
                                Image(systemName: "dumbbell.fill")
                                    .font(.system(size: 26))
                                    .foregroundStyle(AppTheme.accentBright)
                            }
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.name)
                                .font(.system(size: 28, weight: .bold))
                            Text("Last performed \(item.lastPerformedLabel)")
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                }

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("History Summary")
                            .font(.system(size: 18, weight: .bold))
                        Text("Completed \(item.completionCount) tracked sets across recent workouts. This detail screen is a native placeholder inferred from the history list state.")
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
}
