import Foundation
import SwiftUI

struct SyncStatusDisplayState {
    enum Kind: Equatable {
        case localOnly
        case syncing
        case waiting
        case upToDate
        case needsAttention
    }

    let kind: Kind
    let title: String
    let subtitle: String
    let detailText: String?
    let trailingText: String
    let systemImage: String
    let tint: Color
    let canRetry: Bool
    let showsGlobalFailureNotice: Bool
    let userVisibleFailureMessage: String?

    static func make(
        ownerTokenIdentifier: String?,
        isSyncing: Bool,
        lastSyncedAt: Date?,
        lastFailureMessage: String?,
        pendingCount: Int,
        failedCount: Int,
        now: Date = .now
    ) -> SyncStatusDisplayState {
        guard ownerTokenIdentifier != nil else {
            return SyncStatusDisplayState(
                kind: .localOnly,
                title: "Sync Status",
                subtitle: "Cloud sync starts after you sign in.",
                detailText: nil,
                trailingText: "Local only",
                systemImage: "icloud.slash",
                tint: .secondary,
                canRetry: false,
                showsGlobalFailureNotice: false,
                userVisibleFailureMessage: nil
            )
        }

        if isSyncing {
            return SyncStatusDisplayState(
                kind: .syncing,
                title: "Sync Status",
                subtitle: "Sending and receiving changes.",
                detailText: countsText(pendingCount: pendingCount, failedCount: failedCount, lastSyncedAt: lastSyncedAt, now: now),
                trailingText: "Syncing",
                systemImage: "arrow.triangle.2.circlepath.icloud",
                tint: AppTheme.accentBright,
                canRetry: false,
                showsGlobalFailureNotice: false,
                userVisibleFailureMessage: nil
            )
        }

        if failedCount > 0 || lastFailureMessage != nil {
            let defaultMessage = "Cloud sync could not finish. Your data is saved on this iPhone."
            return SyncStatusDisplayState(
                kind: .needsAttention,
                title: "Sync Status",
                subtitle: defaultMessage,
                detailText: countsText(pendingCount: pendingCount, failedCount: failedCount, lastSyncedAt: lastSyncedAt, now: now)
                    ?? sanitizedFailureReason(from: lastFailureMessage ?? ""),
                trailingText: "Retry",
                systemImage: "exclamationmark.icloud",
                tint: AppTheme.accentBright,
                canRetry: true,
                showsGlobalFailureNotice: true,
                userVisibleFailureMessage: defaultMessage
            )
        }

        if pendingCount > 0 {
            return SyncStatusDisplayState(
                kind: .waiting,
                title: "Sync Status",
                subtitle: "\(pendingCount) \(pendingCount == 1 ? "change" : "changes") waiting for cloud sync.",
                detailText: lastSyncedText(lastSyncedAt, now: now).map { "Last synced \($0)." },
                trailingText: "Waiting",
                systemImage: "icloud.and.arrow.up",
                tint: .secondary,
                canRetry: true,
                showsGlobalFailureNotice: false,
                userVisibleFailureMessage: nil
            )
        }

        return SyncStatusDisplayState(
            kind: .upToDate,
            title: "Sync Status",
            subtitle: lastSyncedText(lastSyncedAt, now: now).map { "Last synced \($0)." } ?? "Cloud sync is ready.",
            detailText: nil,
            trailingText: "Up to date",
            systemImage: "checkmark.icloud",
            tint: .secondary,
            canRetry: false,
            showsGlobalFailureNotice: false,
            userVisibleFailureMessage: nil
        )
    }

    static func sanitizedFailureReason(from message: String) -> String {
        let lowercased = message.lowercased()
        if lowercased.contains("offline") || lowercased.contains("internet connection") || lowercased.contains("network") {
            return "The network appears to be offline."
        }
        if lowercased.contains("unauthorized") || lowercased.contains("auth") || lowercased.contains("sign in") {
            return "Sign in again to continue syncing."
        }
        if lowercased.contains("timed out") || lowercased.contains("could not connect") || lowercased.contains("service") {
            return "The service could not be reached."
        }
        return "Cloud sync could not finish. Your data is saved on this iPhone."
    }

    private static func countsText(
        pendingCount: Int,
        failedCount: Int,
        lastSyncedAt: Date?,
        now: Date
    ) -> String? {
        var workParts: [String] = []
        if failedCount > 0 {
            workParts.append("\(failedCount) failed")
        }
        if pendingCount > 0 {
            workParts.append("\(pendingCount) waiting")
        }
        var sentences: [String] = []
        if !workParts.isEmpty {
            sentences.append(workParts.joined(separator: ", "))
        }
        if let lastSynced = lastSyncedText(lastSyncedAt, now: now) {
            sentences.append("Last synced \(lastSynced)")
        }
        guard !sentences.isEmpty else { return nil }
        return sentences.joined(separator: ". ") + "."
    }

    private static func lastSyncedText(_ date: Date?, now: Date) -> String? {
        guard let date else { return nil }
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        if seconds < 60 { return "just now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes) min ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours) hr ago" }
        let days = hours / 24
        return "\(days) d ago"
    }
}
