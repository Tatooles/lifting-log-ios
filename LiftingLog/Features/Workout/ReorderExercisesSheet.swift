import SwiftData
import SwiftUI

private struct ReorderExerciseDraft: Identifiable, Equatable {
    let id: UUID
    let name: String
    let completedSets: Int
    let totalSets: Int

    init(loggedExercise: LoggedExercise) {
        let visibleSets = loggedExercise.sortedSets
        id = loggedExercise.id
        name = loggedExercise.exerciseSnapshotName
        completedSets = visibleSets.filter(\.isCompleted).count
        totalSets = visibleSets.count
    }

    var progressText: String {
        "\(completedSets)/\(totalSets) sets"
    }
}

struct ReorderExercisesSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let session: WorkoutSession
    @Bindable var engine: ActiveWorkoutEngine
    @State private var draftExercises: [ReorderExerciseDraft] = []
    @State private var editMode: EditMode = .active

    var body: some View {
        NavigationStack {
            List {
                ForEach(draftExercises) { exercise in
                    HStack(spacing: 12) {
                        Text(exercise.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineLimit(1)

                        Spacer(minLength: 12)

                        Text(exercise.progressText)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                            .monospacedDigit()
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("ReorderExerciseRow-\(exercise.name)")
                }
                .onMove(perform: moveExercises)
            }
            .accessibilityIdentifier("ReorderExercisesList")
            .environment(\.editMode, $editMode)
            .navigationTitle("Reorder Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("CancelReorderExercisesButton")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveOrder()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .disabled(draftExercises.count < 2)
                    .accessibilityIdentifier("DoneReorderExercisesButton")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            if draftExercises.isEmpty {
                draftExercises = session.sortedLoggedExercises.map(ReorderExerciseDraft.init)
            }
        }
    }

    private func moveExercises(from source: IndexSet, to destination: Int) {
        draftExercises.move(fromOffsets: source, toOffset: destination)
    }

    private func saveOrder() {
        do {
            try engine.reorderLoggedExercises(
                in: session,
                orderedIDs: draftExercises.map(\.id),
                context: modelContext
            )
            dismiss()
        } catch {
            engine.lastErrorMessage = error.localizedDescription
        }
    }
}
