import SwiftData
import SwiftUI

struct AppShellView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var navigationState: AppNavigationState
    @Bindable var activeWorkoutEngine: ActiveWorkoutEngine
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]

    private var activeSession: WorkoutSession? {
        sessions.first { $0.status == .active }
    }

    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            Group {
                switch navigationState.selectedTab {
                case .history:
                    NavigationStack {
                        HistoryView(navigationState: navigationState)
                    }
                case .workout:
                    NavigationStack {
                        if let activeSession {
                            WorkoutSessionView(session: activeSession, engine: activeWorkoutEngine)
                        } else {
                            StartWorkoutView(navigationState: navigationState, activeWorkoutEngine: activeWorkoutEngine)
                        }
                    }
                case .profile:
                    NavigationStack {
                        ProfileView()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FloatingTabBar(selection: $navigationState.selectedTab, isWorkoutActive: activeSession != nil)
                .padding(.horizontal, AppTheme.bottomBarOuterHorizontalPadding)
                .padding(.top, AppTheme.bottomBarOuterTopPadding)
                .padding(.bottom, AppTheme.bottomBarOuterBottomPadding)
                .background(Color.clear)
        }
        .preferredColorScheme(.dark)
        .task {
            activeWorkoutEngine.loadActiveSession(context: modelContext)
        }
    }
}
