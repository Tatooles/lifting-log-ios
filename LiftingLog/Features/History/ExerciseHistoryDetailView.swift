import SwiftData
import SwiftUI

struct ExerciseHistoryDetailView: View {
    let summary: ExerciseHistorySummary
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]

    private var recentSets: [(Date, LoggedExercise, LoggedSet)] {
        sessions
            .filter { $0.status == .completed }
            .flatMap { session in
                session.sortedLoggedExercises.flatMap { loggedExercise in
                    loggedExercise.sortedSets
                        .filter { set in
                            set.isCompleted && matches(loggedExercise)
                        }
                        .map { (session.startedAt, loggedExercise, $0) }
                }
            }
            .sorted { $0.0 > $1.0 }
    }

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
                            Text(summary.name)
                                .font(.system(size: 24, weight: .bold))
                            Text("Last performed \(summary.lastPerformedLabel)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                }

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Completed Sets")
                            .font(.system(size: 16, weight: .bold))
                        Text("\(summary.completedSetCount) tracked sets across completed workouts.")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }

                ForEach(Array(recentSets.enumerated()), id: \.offset) { _, entry in
                    SurfaceCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(WorkoutFormatters.compactDate(entry.0))
                                    .font(.system(size: 15, weight: .bold))
                                Text(entry.1.exerciseSnapshotName)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            Spacer()
                            Text("\(entry.2.weight.map(WorkoutFormatters.number) ?? "-") x \(entry.2.reps.map(String.init) ?? "-")")
                                .font(.system(size: 16, weight: .bold))
                        }
                    }
                }
            }
            .padding(AppTheme.shellPadding)
            .padding(.bottom, AppTheme.contentBottomInset)
        }
        .background(AppTheme.subtleBackground.ignoresSafeArea())
        .navigationTitle(summary.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func matches(_ loggedExercise: LoggedExercise) -> Bool {
        if let exerciseID = summary.exerciseID {
            return loggedExercise.exercise?.id == exerciseID
        }

        return loggedExercise.exerciseSnapshotName.caseInsensitiveCompare(summary.name) == .orderedSame
    }
}
