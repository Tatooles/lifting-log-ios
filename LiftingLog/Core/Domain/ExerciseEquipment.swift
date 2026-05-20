import Foundation

enum ExerciseEquipment: String, CaseIterable, Codable, Identifiable {
    case barbell
    case dumbbell
    case machine
    case cable
    case bodyweight
    case kettlebell
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .barbell:
            return "Barbell"
        case .dumbbell:
            return "Dumbbell"
        case .machine:
            return "Machine"
        case .cable:
            return "Cable"
        case .bodyweight:
            return "Bodyweight"
        case .kettlebell:
            return "Kettlebell"
        case .other:
            return "Other"
        }
    }
}
