import Foundation

enum LiftingLogEnvironment: String {
    case development = "Development"
    case production = "Production"
}

struct AppEnvironmentConfiguration: Equatable {
    let environment: LiftingLogEnvironment
    let clerkPublishableKey: String
    let clerkAssociatedDomain: String
    let convexDeploymentURL: URL

    init(infoDictionary: [String: Any] = Bundle.main.infoDictionary ?? [:]) {
        self.environment = LiftingLogEnvironment(
            rawValue: AppEnvironmentConfiguration.string(
                forKey: "LiftingLogEnvironment",
                in: infoDictionary,
                fallback: AppEnvironmentConfiguration.developmentEnvironment.rawValue
            )
        ) ?? .development
        self.clerkPublishableKey = AppEnvironmentConfiguration.string(
            forKey: "ClerkPublishableKey",
            in: infoDictionary,
            fallback: AppEnvironmentConfiguration.developmentClerkPublishableKey
        )
        self.clerkAssociatedDomain = AppEnvironmentConfiguration.string(
            forKey: "ClerkAssociatedDomain",
            in: infoDictionary,
            fallback: AppEnvironmentConfiguration.developmentClerkAssociatedDomain
        )

        let deploymentURLString = AppEnvironmentConfiguration.string(
            forKey: "ConvexDeploymentURL",
            in: infoDictionary,
            fallback: AppEnvironmentConfiguration.developmentConvexDeploymentURLString
        )
        guard let deploymentURL = URL(string: deploymentURLString) else {
            preconditionFailure("Invalid ConvexDeploymentURL: \(deploymentURLString)")
        }
        self.convexDeploymentURL = deploymentURL
    }

    static let current = AppEnvironmentConfiguration()

    private static let developmentEnvironment = LiftingLogEnvironment.development
    private static let developmentClerkPublishableKey = "pk_test_Z2xhZC1rcmlsbC0yMi5jbGVyay5hY2NvdW50cy5kZXYk"
    private static let developmentClerkAssociatedDomain = "webcredentials:glad-krill-22.clerk.accounts.dev"
    private static let developmentConvexDeploymentURLString = "https://glad-cow-603.convex.cloud"

    private static func string(forKey key: String, in infoDictionary: [String: Any], fallback: String) -> String {
        guard let value = infoDictionary[key] as? String, !value.isEmpty else {
            return fallback
        }
        return value
    }
}

enum ClerkConfiguration {
    static let publishableKey = AppEnvironmentConfiguration.current.clerkPublishableKey
    static let associatedDomain = AppEnvironmentConfiguration.current.clerkAssociatedDomain
}
