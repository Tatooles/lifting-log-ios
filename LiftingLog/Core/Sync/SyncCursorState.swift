import Foundation
import SwiftData

@Model
final class SyncCursorState: Identifiable {
    @Attribute(.unique) var id: UUID
    var ownerTokenIdentifier: String
    var userSettingsCursor: Double
    var exercisesCursor: Double

    init(
        id: UUID = UUID(),
        ownerTokenIdentifier: String,
        userSettingsCursor: Double = 0,
        exercisesCursor: Double = 0
    ) {
        self.id = id
        self.ownerTokenIdentifier = ownerTokenIdentifier
        self.userSettingsCursor = userSettingsCursor
        self.exercisesCursor = exercisesCursor
    }

    static func state(for ownerTokenIdentifier: String, context: ModelContext) throws -> SyncCursorState {
        let existing = try context.fetch(FetchDescriptor<SyncCursorState>())
            .first { $0.ownerTokenIdentifier == ownerTokenIdentifier }
        if let existing {
            return existing
        }

        let state = SyncCursorState(ownerTokenIdentifier: ownerTokenIdentifier)
        context.insert(state)
        return state
    }
}
