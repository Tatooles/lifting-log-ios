import SwiftData
import SwiftUI

@main
struct LiftingLogApp: App {
    private let modelContainer: ModelContainer
    @State private var navigationState = AppNavigationState()
    @State private var activeWorkoutEngine = ActiveWorkoutEngine()

    init() {
        do {
            let arguments = ProcessInfo.processInfo.arguments
            let useInMemoryStore = arguments.contains("--uitest-in-memory-store")
            if arguments.contains("--uitest-reset-persistent-store") {
                try ModelContainerFactory.resetPersistentStoreFiles()
            }
            let container = try ModelContainerFactory.makeModelContainer(isStoredInMemoryOnly: useInMemoryStore)
            try SeedDataService.seedIfNeeded(context: container.mainContext)
            modelContainer = container
        } catch {
            fatalError("Unable to initialize Lifting Log persistence: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            AppShellView(
                navigationState: navigationState,
                activeWorkoutEngine: activeWorkoutEngine
            )
            .modelContainer(modelContainer)
        }
    }
}
