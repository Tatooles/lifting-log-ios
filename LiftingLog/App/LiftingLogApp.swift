import SwiftUI

@main
struct LiftingLogApp: App {
    @State private var store = AppStore.preview

    var body: some Scene {
        WindowGroup {
            AppShellView(store: store)
        }
    }
}
