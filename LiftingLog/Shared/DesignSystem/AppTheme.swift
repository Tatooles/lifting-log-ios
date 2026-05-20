import SwiftUI

enum AppTheme {
    static let background = Color(red: 13 / 255, green: 13 / 255, blue: 13 / 255)
    static let backgroundTop = Color(red: 23 / 255, green: 23 / 255, blue: 23 / 255)
    static let surface = Color(red: 34 / 255, green: 34 / 255, blue: 34 / 255)
    static let surfaceMuted = Color(red: 46 / 255, green: 46 / 255, blue: 46 / 255)
    static let surfaceStrong = Color(red: 56 / 255, green: 56 / 255, blue: 56 / 255)
    static let border = Color.white.opacity(0.12)
    static let borderStrong = Color.white.opacity(0.2)
    static let accent = Color(red: 192 / 255, green: 57 / 255, blue: 43 / 255)
    static let accentBright = Color(red: 232 / 255, green: 76 / 255, blue: 61 / 255)
    static let accentMuted = accent.opacity(0.18)
    static let accentGlow = Color(red: 192 / 255, green: 57 / 255, blue: 43 / 255).opacity(0.34)
    static let textPrimary = Color(red: 240 / 255, green: 240 / 255, blue: 240 / 255)
    static let textSecondary = textPrimary.opacity(0.55)
    static let textTertiary = textPrimary.opacity(0.3)
    static let accentGradient = LinearGradient(
        colors: [accent, accentBright],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let subtleBackground = LinearGradient(
        colors: [backgroundTop, background],
        startPoint: .top,
        endPoint: .bottom
    )

    static let cardCornerRadius: CGFloat = 22
    static let shellPadding: CGFloat = 16

    static func formatDuration(_ seconds: Int) -> String {
        WorkoutFormatters.duration(seconds)
    }

    static func formatDate(_ date: Date) -> String {
        WorkoutFormatters.date(date)
    }
}
