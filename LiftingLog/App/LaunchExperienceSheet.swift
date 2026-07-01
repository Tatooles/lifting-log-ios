import SwiftUI

enum LaunchExperiencePresentation: Identifiable, Equatable {
    case welcome
    case whatsNew(WhatsNewRelease)

    var id: String {
        switch self {
        case .welcome:
            "welcome"
        case .whatsNew(let release):
            "whats-new-\(release.version)"
        }
    }
}

struct LaunchExperienceSheet: View {
    let presentation: LaunchExperiencePresentation
    let primaryAction: () -> Void

    private var title: String {
        switch presentation {
        case .welcome:
            "Welcome to LiftingLog"
        case .whatsNew(let release):
            release.title
        }
    }

    private var summary: String {
        switch presentation {
        case .welcome:
            "Track workouts quickly, keep data on this iPhone, and sign in when you want cloud sync."
        case .whatsNew(let release):
            release.summary
        }
    }

    private var buttonTitle: String {
        switch presentation {
        case .welcome:
            "Continue"
        case .whatsNew:
            "Got It"
        }
    }

    private var items: [WhatsNewItem] {
        switch presentation {
        case .welcome:
            [
                WhatsNewItem(
                    id: "offline",
                    systemImage: "iphone",
                    title: "Log offline",
                    detail: "Workouts are saved on this iPhone immediately, even without network."
                ),
                WhatsNewItem(
                    id: "sync",
                    systemImage: "icloud",
                    title: "Sync when signed in",
                    detail: "Completed workouts, exercises, and settings sync after you sign in."
                ),
                WhatsNewItem(
                    id: "active-workouts",
                    systemImage: "checkmark.circle",
                    title: "Finish to sync",
                    detail: "Active workouts stay local until you finish them."
                ),
                WhatsNewItem(
                    id: "data",
                    systemImage: "lock.shield",
                    title: "Control your data",
                    detail: "Export history and manage privacy from Settings."
                ),
            ]
        case .whatsNew(let release):
            release.items
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 44, weight: .semibold))
                            .foregroundStyle(AppTheme.accentBright)
                            .accessibilityHidden(true)

                        Text(title)
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .accessibilityIdentifier("LaunchExperienceTitle")

                        Text(summary)
                            .font(.body)
                            .foregroundStyle(AppTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("LaunchExperienceSummary")
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(items) { item in
                            LaunchExperienceItemRow(item: item)
                        }
                    }
                }
                .padding(AppTheme.shellPadding)
            }
            .background(AppTheme.subtleBackground.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                Button(buttonTitle, action: primaryAction)
                    .buttonStyle(.glassProminent)
                    .tint(AppTheme.accentBright)
                    .frame(maxWidth: .infinity)
                    .padding(AppTheme.shellPadding)
                    .background(.regularMaterial)
                    .accessibilityIdentifier("LaunchExperiencePrimaryButton")
            }
        }
        .interactiveDismissDisabled()
    }
}

private struct LaunchExperienceItemRow: View {
    let item: WhatsNewItem

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: item.systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.accentBright)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Text(item.detail)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
