import SwiftUI

struct FloatingTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            tabButton(for: .history)
            tabButton(for: .workout, isCenter: true)
            tabButton(for: .profile)
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(
            RoundedRectangle(cornerRadius: 34)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 34)
                        .stroke(Color.white.opacity(0.12))
                )
                .shadow(color: .black.opacity(0.25), radius: 24, y: 12)
        )
    }

    @ViewBuilder
    private func tabButton(for tab: AppTab, isCenter: Bool = false) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selection = tab
            }
        } label: {
            VStack(spacing: isCenter ? 6 : 8) {
                if isCenter {
                    ZStack {
                        Circle()
                            .fill(AppTheme.accentGradient)
                            .frame(width: 68, height: 68)
                            .shadow(color: AppTheme.accentGlow, radius: 18, y: 8)
                        Image(systemName: tab.symbolName)
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(Color.white)
                    }
                    .offset(y: -6)
                } else {
                    Image(systemName: tab.symbolName)
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(selection == tab ? AppTheme.accentBright : AppTheme.textSecondary)
                }

                Text(tab.title)
                    .font(.system(size: 12, weight: selection == tab ? .semibold : .medium))
                    .foregroundStyle(isCenter ? AppTheme.accentBright : (selection == tab ? AppTheme.accentBright : AppTheme.textSecondary))
            }
            .frame(maxWidth: .infinity)
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
