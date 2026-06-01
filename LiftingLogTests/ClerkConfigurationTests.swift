import XCTest
@testable import LiftingLog

final class ClerkConfigurationTests: XCTestCase {
    func testDevelopmentPublishableKeyUsesTestPrefix() {
        XCTAssertTrue(ClerkConfiguration.publishableKey.hasPrefix("pk_test_"))
    }

    func testAssociatedDomainUsesWebCredentialsWithoutScheme() {
        XCTAssertEqual(
            ClerkConfiguration.associatedDomain,
            "webcredentials:glad-krill-22.clerk.accounts.dev"
        )
        XCTAssertFalse(ClerkConfiguration.associatedDomain.contains("https://"))
    }
}
