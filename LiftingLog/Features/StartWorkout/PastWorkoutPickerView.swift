import SwiftUI

struct PastWorkoutPickerView: View {
    let sessions: [WorkoutSession]
    let onSelect: (WorkoutSession) -> Void

    var body: some View {
        if sessions.isEmpty {
            EmptyStateView(
                title: "No Past Workouts",
                message: "Finished workouts will appear here as reusable starting points."
            )
        } else {
            VStack(spacing: 10) {
                ForEach(sessions.prefix(6)) { session in
                    Button {
                        onSelect(session)
                    } label: {
                        WorkoutHistoryRow(session: session)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("PastWorkoutButton-\(session.id.uuidString)")
                }
            }
        }
    }
}
