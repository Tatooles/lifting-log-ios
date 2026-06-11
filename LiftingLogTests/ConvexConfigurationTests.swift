import XCTest
import ConvexMobile
@testable import LiftingLog

final class ConvexConfigurationTests: XCTestCase {
    func testDeploymentURLUsesHTTPSConvexCloudHost() {
        XCTAssertEqual(ConvexConfiguration.deploymentURL.scheme, "https")
        XCTAssertEqual(ConvexConfiguration.deploymentURL.host, "glad-cow-603.convex.cloud")
    }

    func testDeploymentURLStringHasNoTrailingSlash() {
        XCTAssertEqual(
            ConvexConfiguration.deploymentURLString,
            "https://glad-cow-603.convex.cloud"
        )
    }

    @MainActor
    func testAuthenticatedClientFactoryReusesSingleInstance() {
        let firstClient = ConvexClientFactory.makeAuthenticatedClient()
        let secondClient = ConvexClientFactory.makeAuthenticatedClient()

        XCTAssertTrue(firstClient === secondClient)
    }
}
