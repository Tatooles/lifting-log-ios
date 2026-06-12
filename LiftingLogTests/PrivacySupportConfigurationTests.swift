import XCTest
@testable import LiftingLog

final class PrivacySupportConfigurationTests: XCTestCase {
    func testIssue13LinksAreVisibleButUnavailableUntilIssue14ProvidesURLs() {
        let configuration = PrivacySupportConfiguration.issue13Development

        XCTAssertNil(configuration.privacyPolicyURL)
        XCTAssertNil(configuration.supportURL)
        XCTAssertEqual(configuration.unavailableDetailText, "Available before release")
    }
}
