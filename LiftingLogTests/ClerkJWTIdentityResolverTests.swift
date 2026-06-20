import XCTest
@testable import LiftingLog

final class ClerkJWTIdentityResolverTests: XCTestCase {
    func testOwnerTokenIdentifierUsesIssuerAndSubjectClaims() {
        let jwt = makeJWT(payload: #"{"iss":"https://clerk.auth.liftinglog.app","sub":"user_123"}"#)

        XCTAssertEqual(
            ClerkJWTIdentityResolver.ownerTokenIdentifier(from: jwt),
            "https://clerk.auth.liftinglog.app|user_123"
        )
    }

    func testOwnerTokenIdentifierRejectsMalformedToken() {
        XCTAssertNil(ClerkJWTIdentityResolver.ownerTokenIdentifier(from: "not-a-jwt"))
    }

    func testOwnerTokenIdentifierRejectsMissingRequiredClaims() {
        let jwt = makeJWT(payload: #"{"iss":"https://clerk.auth.liftinglog.app"}"#)

        XCTAssertNil(ClerkJWTIdentityResolver.ownerTokenIdentifier(from: jwt))
    }

    private func makeJWT(payload: String) -> String {
        [
            base64URL("{}"),
            base64URL(payload),
            "signature",
        ].joined(separator: ".")
    }

    private func base64URL(_ value: String) -> String {
        Data(value.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
