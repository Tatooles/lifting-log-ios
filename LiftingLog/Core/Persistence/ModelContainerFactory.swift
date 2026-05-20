import Foundation
import SwiftData

enum ModelContainerFactory {
    static func makeModelContainer(isStoredInMemoryOnly: Bool = false) throws -> ModelContainer {
        let schema = Schema(LiftingLogSchema.models)
        let configuration = ModelConfiguration(isStoredInMemoryOnly: isStoredInMemoryOnly)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
