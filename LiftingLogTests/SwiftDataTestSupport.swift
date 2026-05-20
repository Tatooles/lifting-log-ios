import SwiftData
@testable import LiftingLog

@MainActor
enum SwiftDataTestSupport {
    static func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(LiftingLogSchema.models)
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
