import SwiftUI

struct FloatingTabBar: View {
    @Binding var selection: AppTab
    let isWorkoutActive: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            tabButton(for: .history)
            tabButton(for: .workout)
            tabButton(for: .profile)
        }
        .padding(.horizontal, AppTheme.bottomBarInnerHorizontalPadding)
        .padding(.vertical, AppTheme.bottomBarInnerVerticalPadding)
        .frame(minHeight: AppTheme.bottomBarMinHeight)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.bottomBarCornerRadius)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.bottomBarCornerRadius)
                        .stroke(Color.white.opacity(0.12))
                )
                .shadow(color: .black.opacity(0.22), radius: 18, y: 8)
        )
    }

    private func tabButton(for tab: AppTab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selection = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.symbolName(isWorkoutActive: isWorkoutActive))
                    .font(.system(size: AppTheme.bottomBarIconSize, weight: selection == tab ? .semibold : .regular))
                    .foregroundStyle(selection == tab ? AppTheme.accentBright : AppTheme.textSecondary)

                Text(tab.title(isWorkoutActive: isWorkoutActive))
                    .font(.system(size: AppTheme.bottomBarLabelSize, weight: selection == tab ? .semibold : .medium))
                    .foregroundStyle(selection == tab ? AppTheme.accentBright : AppTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier(for: tab))
    }

    private func identifier(for tab: AppTab) -> String {
        switch tab {
        case .history:
            return "HistoryTab"
        case .workout:
            return "WorkoutTab"
        case .profile:
            return "ProfileTab"
        }
    }
}
