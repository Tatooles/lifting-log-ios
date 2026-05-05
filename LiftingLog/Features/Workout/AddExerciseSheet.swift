import SwiftData
import SwiftUI

struct AddExerciseSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let session: WorkoutSession
    @Bindable var engine: ActiveWorkoutEngine

    var body: some View {
        NavigationStack {
            ExercisePickerView { exercise in
                do {
                    _ = try engine.addExercise(exercise, to: session, context: modelContext)
                    dismiss()
                } catch {
                    engine.lastErrorMessage = error.localizedDescription
                }
            }
        }
        .presentationDetents([.large])
    }
}
