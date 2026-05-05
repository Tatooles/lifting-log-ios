import Foundation
import SwiftData

@Model
final class UserSettings: Identifiable {
    @Attribute(.unique) var id: UUID
    var weightUnitRaw: String
    var defaultRestTimerSeconds: Int
    var hasCompletedOnboarding: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        weightUnit: MeasurementUnit = .pounds,
        defaultRestTimerSeconds: Int = 90,
        hasCompletedOnboarding: Bool = true,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.weightUnitRaw = weightUnit.rawValue
        self.defaultRestTimerSeconds = defaultRestTimerSeconds
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var weightUnit: MeasurementUnit {
        get { MeasurementUnit(rawValue: weightUnitRaw) ?? .pounds }
        set {
            weightUnitRaw = newValue.rawValue
            touch()
        }
    }

    func touch(now: Date = .now) {
        updatedAt = now
    }
}
