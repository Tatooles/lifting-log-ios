import Foundation

struct WhatsNewRelease: Equatable {
    let version: String
    let title: String
    let summary: String
    let items: [WhatsNewItem]
    let shouldAutoShow: Bool
}

struct WhatsNewItem: Identifiable, Equatable {
    let id: String
    let systemImage: String
    let title: String
    let detail: String
}

enum WhatsNewContent {
    static func current(buildInfo: AppBuildInfo = .current) -> WhatsNewRelease {
        WhatsNewRelease(
            version: buildInfo.version,
            title: "Welcome to LiftingLog",
            summary: "A focused first release for logging workouts, keeping history safe, and syncing completed work when you sign in.",
            items: [
                WhatsNewItem(
                    id: "offline-first",
                    systemImage: "iphone",
                    title: "Offline-first logging",
                    detail: "Start and finish workouts even when the network is unavailable."
                ),
                WhatsNewItem(
                    id: "cloud-sync",
                    systemImage: "icloud",
                    title: "Cloud sync",
                    detail: "Sign in to sync completed workouts, exercises, and settings."
                ),
                WhatsNewItem(
                    id: "data-controls",
                    systemImage: "square.and.arrow.up",
                    title: "Data controls",
                    detail: "Export workout history and manage privacy from Settings."
                ),
            ],
            shouldAutoShow: true
        )
    }
}
