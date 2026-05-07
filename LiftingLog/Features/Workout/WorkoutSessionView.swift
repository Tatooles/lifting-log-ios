import SwiftData
import SwiftUI

enum WorkoutField: Hashable {
    case workoutTitle
    case workoutNotes
    case exerciseNotes(UUID)
    case setWeight(UUID)
    case setReps(UUID)
    case setRPE(UUID)
}

struct WorkoutSessionView: View {
    @Environment(\.modelContext) private var modelContext
    let session: WorkoutSession
    @Bindable var engine: ActiveWorkoutEngine
    @State private var isFinishSheetPresented = false
    @State private var isAddExercisePresented = false
    @State private var pendingFocusedField: WorkoutField?
    @State private var pendingScrollTarget: UUID?
    @FocusState private var focusedField: WorkoutField?
    private let contentBottomPadding: CGFloat = 96

    var body: some View {
        ScrollViewReader { scrollProxy in
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            TextField("Workout Name", text: workoutTitleBinding)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(AppTheme.textPrimary)
                                .focused($focusedField, equals: .workoutTitle)
                                .accessibilityIdentifier("WorkoutTitle")
                            Text(AppTheme.formatDate(session.startedAt))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(AppTheme.textSecondary)
                        }

                        ForEach(Array(session.sortedLoggedExercises.enumerated()), id: \.element.id) { exerciseIndex, loggedExercise in
                            ExerciseCardView(
                                loggedExercise: loggedExercise,
                                exerciseIndex: exerciseIndex,
                                engine: engine,
                                focusedField: $focusedField
                            )
                            .id(loggedExercise.id)
                        }

                        Button {
                            isAddExercisePresented = true
                        } label: {
                            Label("Add Exercise", systemImage: "plus")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(AppTheme.accentBright)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .frame(minHeight: 44)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18)
                                        .stroke(style: StrokeStyle(lineWidth: 1.25, dash: [6, 4]))
                                        .foregroundStyle(AppTheme.accentBright.opacity(0.45))
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("AddExerciseButton")

                        SurfaceCard {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("WORKOUT NOTES")
                                    .font(.system(size: 10, weight: .bold))
                                    .tracking(1.8)
                                    .foregroundStyle(AppTheme.textSecondary)
                                TextField(
                                    "How did this session feel? Any notes for next time...",
                                    text: workoutNotesBinding,
                                    axis: .vertical
                                )
                                .font(.system(size: 15))
                                .foregroundStyle(AppTheme.textPrimary)
                                .lineLimit(4...6)
                                .focused($focusedField, equals: .workoutNotes)
                            }
                        }
                    }
                    .padding(.horizontal, AppTheme.shellPadding)
                    .padding(.top, 8)
                    .padding(.bottom, contentBottomPadding)
                }
                .safeAreaInset(edge: .top, spacing: 0) {
                    let metrics = WorkoutMetrics(session: session, now: timeline.date)
                    WorkoutHeaderView(
                        elapsedSeconds: metrics.durationSeconds,
                        completedSets: metrics.completedSetCount,
                        totalSets: metrics.totalSetCount
                    ) {
                        isFinishSheetPresented = true
                    }
                }
            }
            .onChange(of: isAddExercisePresented) { _, isPresented in
                guard !isPresented else { return }

                if let pendingScrollTarget {
                    self.pendingScrollTarget = nil
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
                        scrollProxy.scrollTo(pendingScrollTarget, anchor: .top)
                    }
                }

                guard let pendingFocusedField else { return }
                self.pendingFocusedField = nil
                DispatchQueue.main.async {
                    focusedField = pendingFocusedField
                }
            }
        }
        .background(AppTheme.subtleBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedField = nil
                }
                .font(.system(size: 16, weight: .semibold))
                .accessibilityIdentifier("DismissKeyboardButton")
            }
        }
        .sheet(isPresented: $isFinishSheetPresented) {
            FinishWorkoutSheet(session: session, engine: engine)
        }
        .sheet(isPresented: $isAddExercisePresented) {
            AddExerciseSheet(session: session, engine: engine) { loggedExercise in
                pendingScrollTarget = loggedExercise.id
                pendingFocusedField = loggedExercise.sortedSets.first.map { .setWeight($0.id) }
            }
        }
    }

    private var workoutTitleBinding: Binding<String> {
        Binding(
            get: { session.title },
            set: { newValue in
                try? engine.updateWorkoutTitle(newValue, session: session, context: modelContext)
            }
        )
    }

    private var workoutNotesBinding: Binding<String> {
        Binding(
            get: { session.notes },
            set: { newValue in
                try? engine.updateWorkoutNotes(newValue, session: session, context: modelContext)
            }
        )
    }
}
