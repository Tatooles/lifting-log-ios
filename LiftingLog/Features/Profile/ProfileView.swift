import SwiftUI

struct ProfileView: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Profile")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .accessibilityIdentifier("ProfileTitle")

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Kevin")
                            .font(.system(size: 24, weight: .bold))
                        Text("Mock athlete profile")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }

                HStack(spacing: 10) {
                    statCard(title: "Workouts", value: "28")
                    statCard(title: "Exercises", value: "14")
                    statCard(title: "PRs", value: "6")
                }

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 14) {
                        row("Units", value: "Pounds")
                        row("Theme", value: "Dark")
                        row("Data Source", value: "Mock")
                    }
                }
            }
            .padding(AppTheme.shellPadding)
            .padding(.bottom, AppTheme.contentBottomInset)
        }
        .background(AppTheme.subtleBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private func statCard(title: String, value: String) -> some View {
        SurfaceCard {
            VStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 22, weight: .bold))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func row(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(AppTheme.textPrimary)
            Spacer()
            Text(value)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .font(.system(size: 16, weight: .medium))
    }
}
