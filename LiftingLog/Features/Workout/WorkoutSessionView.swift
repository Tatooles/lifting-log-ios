import SwiftUI

struct WorkoutSessionView: View {
    @Bindable var store: AppStore
    @State private var isFinishSheetPresented = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    TextField("Workout Name", text: $store.activeWorkout.name)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .accessibilityIdentifier("WorkoutTitle")
                    Text(AppTheme.formatDate(store.activeWorkout.date))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                ForEach(store.activeWorkout.exercises) { exercise in
                    ExerciseCardView(store: store, exercise: exercise)
                }

                Button {
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.86)) {
                        store.addExercise()
                    }
                } label: {
                    Label("Add Exercise", systemImage: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppTheme.accentBright)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(style: StrokeStyle(lineWidth: 1.25, dash: [6, 4]))
                                .foregroundStyle(AppTheme.accentBright.opacity(0.45))
                        )
                }
                .buttonStyle(.plain)

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("WORKOUT NOTES")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.8)
                            .foregroundStyle(AppTheme.textSecondary)
                        TextField(
                            "How did this session feel? Any PRs or notes for next time...",
                            text: $store.activeWorkout.workoutNotes,
                            axis: .vertical
                        )
                        .font(.system(size: 15))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(3...5)
                    }
                }
            }
            .padding(.horizontal, AppTheme.shellPadding)
            .padding(.top, 8)
            .padding(.bottom, AppTheme.contentBottomInset)
        }
        .background(AppTheme.subtleBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) {
            WorkoutHeaderView(
                elapsedSeconds: store.activeWorkout.elapsedSeconds,
                completedSets: store.completedSetCount,
                totalSets: store.totalSetCount
            ) {
                isFinishSheetPresented = true
            }
        }
        .sheet(isPresented: $isFinishSheetPresented) {
            FinishWorkoutSheet(store: store)
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                await MainActor.run {
                    store.tickElapsed()
                }
            }
        }
    }
}
