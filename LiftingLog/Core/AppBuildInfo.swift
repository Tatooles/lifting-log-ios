import Foundation
import UIKit

struct DeviceSystemInfo: Equatable {
    let model: String
    let systemName: String
    let systemVersion: String

    static var current: DeviceSystemInfo {
        let device = UIDevice.current
        return DeviceSystemInfo(
            model: device.model,
            systemName: device.systemName,
            systemVersion: device.systemVersion
        )
    }
}

struct AppBuildInfo: Equatable {
    let displayName: String
    let bundleIdentifier: String
    let version: String
    let buildNumber: String
    let environmentName: String

    init(infoDictionary: [String: Any] = Bundle.main.infoDictionary ?? [:]) {
        self.displayName = Self.stringValue(
            forKey: "CFBundleDisplayName",
            in: infoDictionary,
            fallback: "Lifting Log"
        )
        self.bundleIdentifier = Self.stringValue(
            forKey: "CFBundleIdentifier",
            in: infoDictionary,
            fallback: "Unknown"
        )
        self.version = Self.stringValue(
            forKey: "CFBundleShortVersionString",
            in: infoDictionary,
            fallback: "Unknown"
        )
        self.buildNumber = Self.stringValue(
            forKey: "CFBundleVersion",
            in: infoDictionary,
            fallback: "Unknown"
        )
        self.environmentName = Self.stringValue(
            forKey: "LiftingLogEnvironment",
            in: infoDictionary,
            fallback: "Unknown"
        )
    }

    static let current = AppBuildInfo()

    var versionAndBuild: String {
        "\(version) (\(buildNumber))"
    }

    var settingsVersionText: String {
        "Version \(versionAndBuild)"
    }

    func supportSummary(device: DeviceSystemInfo) -> String {
        """
        App: \(displayName)
        Version: \(versionAndBuild)
        Environment: \(environmentName)
        Bundle ID: \(bundleIdentifier)
        Device: \(device.model)
        OS: \(device.systemName) \(device.systemVersion)
        """
    }

    private static func stringValue(forKey key: String, in infoDictionary: [String: Any], fallback: String) -> String {
        guard let value = infoDictionary[key] as? String, !value.isEmpty else {
            return fallback
        }
        return value
    }
}
