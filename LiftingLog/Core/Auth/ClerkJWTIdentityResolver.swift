import Foundation

enum ClerkJWTIdentityResolver {
    static func ownerTokenIdentifier(from jwt: String) -> String? {
        let segments = jwt.split(separator: ".")
        guard segments.count >= 2,
              let payloadData = base64URLDecodedData(String(segments[1])),
              let claims = try? JSONDecoder().decode(Claims.self, from: payloadData),
              !claims.iss.isEmpty,
              !claims.sub.isEmpty else {
            return nil
        }

        return "\(claims.iss)|\(claims.sub)"
    }

    private static func base64URLDecodedData(_ value: String) -> Data? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let paddingLength = (4 - base64.count % 4) % 4
        if paddingLength > 0 {
            base64.append(String(repeating: "=", count: paddingLength))
        }

        return Data(base64Encoded: base64)
    }

    private struct Claims: Decodable {
        let iss: String
        let sub: String
    }
}
