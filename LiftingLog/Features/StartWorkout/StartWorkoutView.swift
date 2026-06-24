import SwiftData
import SwiftUI

struct StartWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncScheduler.self) private var syncScheduler
    @Bindable var navigationState: AppNavigationState
    @Bindable var activeWorkoutEngine: ActiveWorkoutEngine
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @State private var selectedPastWorkoutSession: WorkoutSession?

    private var completedSessions: [WorkoutSession] {
        WorkoutSession.visibleCompletedSessions(
            from: sessions,
            ownerTokenIdentifier: syncScheduler.currentOwnerTokenIdentifier
        )
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Start Workout")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .accessibilityIdentifier("StartWorkoutTitle")

                Button {
                    startBlankWorkout()
                } label: {
                    SurfaceCard {
                        HStack(spacing: 14) {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(AppTheme.accentGradient)
                                .frame(width: 56, height: 56)
                                .overlay {
                                    Image(systemName: "plus")
                                        .font(.title2.weight(.bold))
                                        .foregroundStyle(AppTheme.onAccent)
                                }
                                .shadow(color: AppTheme.accentGlow, radius: 10, y: 4)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Blank Workout")
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Text("Start logging sets from scratch.")
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }

                            Spacer()
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("StartBlankWorkoutButton")

                VStack(alignment: .leading, spacing: 10) {
                    Text("Use Past Workout")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)

                    PastWorkoutPickerView(sessions: completedSessions) { session in
                        selectedPastWorkoutSession = session
                    }
                }
            }
            .padding(AppTheme.shellPadding)
        }
        .background(AppTheme.subtleBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $selectedPastWorkoutSession) { session in
            StartFromPastWorkoutSheet(session: session) {
                startWorkout(fromPast: session)
            }
        }
    }

    private func startBlankWorkout() {
        do {
            _ = try activeWorkoutEngine.startBlankWorkout(
                ownerTokenIdentifier: syncScheduler.currentOwnerTokenIdentifier,
                context: modelContext
            )
            navigationState.selectedTab = .workout
        } catch {
            activeWorkoutEngine.lastErrorMessage = error.localizedDescription
        }
    }

    private func startWorkout(fromPast session: WorkoutSession) {
        do {
            _ = try activeWorkoutEngine.startWorkout(
                fromPast: session,
                ownerTokenIdentifier: syncScheduler.currentOwnerTokenIdentifier,
                context: modelContext
            )
            selectedPastWorkoutSession = nil
            navigationState.selectedTab = .workout
        } catch {
            activeWorkoutEngine.lastErrorMessage = error.localizedDescription
        }
    }
}

private struct StartFromPastWorkoutSheet: View {
    @Environment(\.dismiss) private var dismiss
    let session: WorkoutSession
    let onConfirm: () -> Void

    private var metrics: WorkoutMetrics {
        WorkoutMetrics(session: session)
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "square.on.square")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(AppTheme.accentBright)
                .frame(width: 56, height: 56)
                .background(AppTheme.accentMuted, in: Circle())
                .padding(.top, 22)

            VStack(spacing: 8) {
                Text("Start from \(session.title)?")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .accessibilityIdentifier("StartFromPastWorkoutSheetTitle")

                Text("This creates a new workout by copying this completed one. Exercises and set types are copied; weights, reps, and notes stay blank with past values shown as reference.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("StartFromPastWorkoutExplanation")
            }

            HStack(spacing: 10) {
                summaryCard(value: "\(WorkoutHistoryRow.exerciseCount(for: session))", label: "Exercises")
                summaryCard(value: "\(metrics.totalSetCount)", label: "Sets")
            }

            Button {
                onConfirm()
            } label: {
                Text("Create New Workout")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.glassProminent)
            .tint(AppTheme.accentBright)
            .accessibilityIdentifier("StartFromPastWorkoutConfirmButton")

            Button("Cancel") {
                dismiss()
            }
            .font(.callout.weight(.medium))
            .foregroundStyle(AppTheme.textSecondary)
            .accessibilityIdentifier("StartFromPastWorkoutCancelButton")
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 20)
        .presentationDetents([.height(430)])
        .presentationCornerRadius(36)
        .presentationDragIndicator(.visible)
    }

    private func summaryCard(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            AppTheme.surfaceMuted,
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
    }
}
