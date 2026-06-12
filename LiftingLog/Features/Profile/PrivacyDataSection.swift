import ClerkKit
import SwiftData
import SwiftUI

struct PrivacyDataSection: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accountDeletionFactory) private var accountDeletionFactory
    @Environment(\.openURL) private var openURL
    @Environment(Clerk.self) private var clerk
    @Environment(SyncScheduler.self) private var syncScheduler

    let exportWorkoutHistory: () -> Void
    let links: PrivacySupportConfiguration

    private var isSignedInForDeletion: Bool {
        syncScheduler.currentOwnerTokenIdentifier != nil
    }

    var body: some View {
        Section("Privacy & Data") {
            Button(action: exportWorkoutHistory) {
                Label("Export Workout History", systemImage: "square.and.arrow.up")
            }
            .accessibilityIdentifier("ExportWorkoutHistoryButton")

            linkRow(title: "Privacy Policy", systemImage: "hand.raised", url: links.privacyPolicyURL)
                .accessibilityIdentifier("SettingsPrivacyPolicyRow")

            linkRow(title: "Support", systemImage: "questionmark.circle", url: links.supportURL)
                .accessibilityIdentifier("SettingsSupportRow")

            NavigationLink {
                DeleteDataConfirmationView(
                    mode: isSignedInForDeletion ? .account : .localData,
                    coordinator: accountDeletionFactory.makeCoordinator(
                        modelContext,
                        syncScheduler,
                        clerk
                    )
                )
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(isSignedInForDeletion ? "Delete Account" : "Delete Local Data")
                            .foregroundStyle(.red)
                        Text(isSignedInForDeletion ? "Delete cloud account and data." : "Delete data saved on this iPhone.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: isSignedInForDeletion ? "person.crop.circle.badge.xmark" : "trash")
                        .foregroundStyle(.red)
                }
            }
            .accessibilityIdentifier(isSignedInForDeletion ? "SettingsDeleteAccountRow" : "SettingsDeleteLocalDataRow")
        }
    }

    @ViewBuilder
    private func linkRow(title: String, systemImage: String, url: URL?) -> some View {
        if let url {
            Button {
                openURL(url)
            } label: {
                Label(title, systemImage: systemImage)
            }
        } else {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                    Text(links.unavailableDetailText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.secondary)
        }
    }
}
