import SwiftData
import SwiftUI

struct AppShellView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncScheduler.self) private var syncScheduler
    @Bindable var navigationState: AppNavigationState
    @Bindable var activeWorkoutEngine: ActiveWorkoutEngine
    @State private var dismissedSyncFailureSignature: String?
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @Query(sort: \SyncOutboxEntry.updatedAt, order: .reverse) private var outboxEntries: [SyncOutboxEntry]

    private var activeSession: WorkoutSession? {
        WorkoutSession.visibleActiveSessions(
            from: sessions,
            ownerTokenIdentifier: syncScheduler.currentOwnerTokenIdentifier
        ).first
    }

    private var activeV1OutboxEntries: [SyncOutboxEntry] {
        outboxEntries.filter { entry in
            guard entry.isActive else { return false }
            guard entry.entityKind?.isV1Synced == true else { return false }
            if let owner = syncScheduler.currentOwnerTokenIdentifier {
                return entry.ownerTokenIdentifier == owner || entry.ownerTokenIdentifier == nil
            }
            return false
        }
    }

    private var syncDisplayState: SyncStatusDisplayState {
        let activeEntries = activeV1OutboxEntries
        return SyncStatusDisplayState.make(
            ownerTokenIdentifier: syncScheduler.currentOwnerTokenIdentifier,
            isSyncing: syncScheduler.isSyncing,
            lastSyncedAt: syncScheduler.lastSyncedAt,
            lastFailureMessage: syncScheduler.lastFailure?.message,
            pendingCount: activeEntries.filter { $0.status == .pending || $0.status == .inFlight }.count,
            failedCount: activeEntries.filter { $0.status == .failed }.count
        )
    }

    private var currentSyncFailureSignature: String? {
        var components: [String] = []
        if let lastFailure = syncScheduler.lastFailure {
            components.append("scheduler:\(lastFailure.occurredAt.timeIntervalSince1970):\(lastFailure.message)")
        }
        let failedEntries = activeV1OutboxEntries
            .filter { $0.status == .failed }
            .sorted { lhs, rhs in lhs.id.uuidString < rhs.id.uuidString }
        for entry in failedEntries {
            components.append(
                [
                    entry.id.uuidString,
                    entry.entityKindRaw,
                    entry.operationRaw,
                    entry.statusRaw,
                    String(entry.attemptCount),
                    String(entry.updatedAt.timeIntervalSince1970),
                    entry.lastErrorMessage ?? "",
                ].joined(separator: "|")
            )
        }
        guard !components.isEmpty else { return nil }
        return components.joined(separator: "\n")
    }

    private var shouldShowGlobalSyncFailureBanner: Bool {
        SyncFailureNoticePresentation().shouldShowNotice(
            showsGlobalFailureNotice: syncDisplayState.showsGlobalFailureNotice,
            currentFailureSignature: currentSyncFailureSignature,
            dismissedFailureSignature: dismissedSyncFailureSignature
        )
    }

    var body: some View {
        TabView(selection: $navigationState.selectedTab) {
            NavigationStack(path: $navigationState.historyPath) {
                HistoryView(navigationState: navigationState)
            }
            .tabItem {
                Label(AppTab.history.title(isWorkoutActive: activeSession != nil), systemImage: AppTab.history.symbolName(isWorkoutActive: activeSession != nil))
                    .accessibilityIdentifier(AppTab.history.accessibilityIdentifier)
            }
            .tag(AppTab.history)

            NavigationStack {
                if let activeSession {
                    WorkoutSessionView(session: activeSession, engine: activeWorkoutEngine, navigationState: navigationState)
                } else {
                    StartWorkoutView(navigationState: navigationState, activeWorkoutEngine: activeWorkoutEngine)
                }
            }
            .tabItem {
                Label(AppTab.workout.title(isWorkoutActive: activeSession != nil), systemImage: AppTab.workout.symbolName(isWorkoutActive: activeSession != nil))
                    .accessibilityIdentifier(AppTab.workout.accessibilityIdentifier)
            }
            .tag(AppTab.workout)

            NavigationStack(path: $navigationState.profilePath) {
                ProfileView(navigationState: navigationState)
            }
            .tabItem {
                Label(AppTab.profile.title(isWorkoutActive: activeSession != nil), systemImage: AppTab.profile.symbolName(isWorkoutActive: activeSession != nil))
                    .accessibilityIdentifier(AppTab.profile.accessibilityIdentifier)
            }
            .tag(AppTab.profile)
        }
        .tint(AppTheme.accentBright)
        .preferredColorScheme(.dark)
        .safeAreaInset(edge: .bottom) {
            if shouldShowGlobalSyncFailureBanner {
                GlobalSyncFailureBanner(
                    retry: { syncScheduler.retrySync() },
                    details: { navigationState.openSyncSettings() },
                    dismiss: { dismissGlobalSyncFailureBanner() }
                )
                .padding(.horizontal, AppTheme.shellPadding)
                .padding(.bottom, 8)
            }
        }
        .task {
            activeWorkoutEngine.loadActiveSession(
                ownerTokenIdentifier: syncScheduler.currentOwnerTokenIdentifier,
                context: modelContext
            )
        }
    }

    private func dismissGlobalSyncFailureBanner() {
        dismissedSyncFailureSignature = SyncFailureNoticePresentation().dismissedSignature(
            currentFailureSignature: currentSyncFailureSignature,
            dismissedFailureSignature: dismissedSyncFailureSignature
        )
    }
}

private struct GlobalSyncFailureBanner: View {
    let retry: () -> Void
    let details: () -> Void
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.icloud")
                    .foregroundStyle(AppTheme.accentBright)
                    .font(.system(size: 20, weight: .semibold))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Cloud sync failed")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Your data is saved on this iPhone.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                Button(action: dismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
                .accessibilityIdentifier("GlobalSyncDismissButton")
            }

            HStack(spacing: 8) {
                Button("Retry", action: retry)
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accentBright)
                    .accessibilityIdentifier("GlobalSyncRetryButton")
                Button("Details", action: details)
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("GlobalSyncDetailsButton")
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(12)
        .background(AppTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppTheme.accentBright.opacity(0.45))
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    if abs(value.translation.width) > 40 || abs(value.translation.height) > 40 {
                        dismiss()
                    }
                }
        )
        .accessibilityAction(.escape, dismiss)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("GlobalSyncFailureBanner")
    }
}
