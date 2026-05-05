import SwiftUI

struct AppShellView: View {
    @Bindable var store: AppStore

    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            Group {
                switch store.selectedTab {
                case .history:
                    NavigationStack {
                        HistoryView(store: store)
                    }
                case .workout:
                    NavigationStack {
                        WorkoutSessionView(store: store)
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
            FloatingTabBar(selection: $store.selectedTab)
                .padding(.horizontal, AppTheme.bottomBarOuterHorizontalPadding)
                .padding(.top, AppTheme.bottomBarOuterTopPadding)
                .padding(.bottom, AppTheme.bottomBarOuterBottomPadding)
                .background(Color.clear)
        }
        .preferredColorScheme(.dark)
    }
}
