import Foundation

struct PrivacySupportConfiguration: Equatable {
    let privacyPolicyURL: URL?
    let supportURL: URL?
    let unavailableDetailText: String

    static let issue13Development = PrivacySupportConfiguration(
        privacyPolicyURL: nil,
        supportURL: nil,
        unavailableDetailText: "Available before release"
    )
}
