import SwiftUI

struct HistoryView: View {
    @Bindable var store: AppStore

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Text("History")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .accessibilityIdentifier("HistoryTitle")

                Picker("History Mode", selection: $store.historyMode) {
                    ForEach(HistoryMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                switch store.historyMode {
                case .workouts:
                    workoutContent
                case .exercises:
                    exerciseContent
                }
            }
            .padding(AppTheme.shellPadding)
            .padding(.bottom, 120)
        }
        .background(AppTheme.subtleBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await store.loadHistory()
        }
    }

    @ViewBuilder
    private var workoutContent: some View {
        switch store.workoutHistoryState {
        case .loading:
            LoadingStateView(title: "Loading workouts...")
        case let .empty(message):
            EmptyStateView(title: "No Workouts Yet", message: message)
        case let .error(message):
            ErrorStateView(title: "Couldn't Load Workouts", message: message) {
                Task { await store.retryHistoryLoad() }
            }
        case let .loaded(items):
            VStack(spacing: 12) {
                ForEach(items) { item in
                    NavigationLink {
                        WorkoutHistoryDetailView(item: item)
                    } label: {
                        WorkoutHistoryRow(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var exerciseContent: some View {
        switch store.exerciseHistoryState {
        case .loading:
            LoadingStateView(title: "Loading exercises...")
        case let .empty(message):
            EmptyStateView(title: "No Exercise History", message: message)
        case let .error(message):
            ErrorStateView(title: "Couldn't Load Exercises", message: message) {
                Task { await store.retryHistoryLoad() }
            }
        case let .loaded(items):
            SurfaceCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        NavigationLink {
                            ExerciseHistoryDetailView(item: item)
                        } label: {
                            ExerciseHistoryRow(item: item, showsDivider: index < items.count - 1)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
