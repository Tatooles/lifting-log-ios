import SwiftUI

struct ExerciseCardView: View {
    @Bindable var store: AppStore
    let exercise: WorkoutExercise

    var body: some View {
        SurfaceCard(padding: 0) {
            VStack(spacing: 0) {
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                        store.toggleExerciseCollapsed(exercise.id)
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .rotationEffect(.degrees(exercise.isCollapsed ? -90 : 0))

                        Text(exercise.name)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)

                        Spacer()

                        Text("\(exercise.sets.filter(\.isDone).count)/\(exercise.sets.count)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(exercise.sets.allSatisfy(\.isDone) ? AppTheme.accentBright : AppTheme.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AppTheme.surfaceMuted)
                            .clipShape(Capsule())
                    }
                    .padding(16)
                }
                .buttonStyle(.plain)

                if !exercise.isCollapsed {
                    VStack(spacing: 14) {
                        HStack(spacing: 10) {
                            Color.clear.frame(width: 18)
                            columnHeader("LBS")
                            columnHeader("REPS")
                            columnHeader("RPE")
                            Color.clear.frame(width: 28)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(AppTheme.border)
                                .frame(height: 1)
                                .padding(.horizontal, 16)
                        }

                        VStack(spacing: 12) {
                            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                                SetRowView(store: store, exerciseID: exercise.id, set: set, index: index)
                                    .padding(.horizontal, 16)
                            }
                        }

                        Button {
                            withAnimation(.spring(response: 0.26, dampingFraction: 0.85)) {
                                store.addSet(to: exercise.id)
                            }
                        } label: {
                            Label("Add Set", systemImage: "plus")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(AppTheme.accentBright)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18)
                                        .stroke(style: StrokeStyle(lineWidth: 1.25, dash: [5, 4]))
                                        .foregroundStyle(AppTheme.borderStrong)
                                )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)

                        TextField(
                            "Exercise notes...",
                            text: Binding(
                                get: { exercise.notes },
                                set: { store.updateExerciseNotes(exerciseID: exercise.id, notes: $0) }
                            ),
                            axis: .vertical
                        )
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.textPrimary)
                        .padding(14)
                        .frame(minHeight: 92, alignment: .topLeading)
                        .background(AppTheme.surfaceMuted)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(AppTheme.border)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private func columnHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(AppTheme.textTertiary)
            .frame(maxWidth: .infinity)
    }
}
