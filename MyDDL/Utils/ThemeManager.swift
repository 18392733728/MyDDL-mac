import SwiftUI

// MARK: - Theme Types
enum AppTheme: String, CaseIterable, Codable {
    case dark = "dark"          // 灰色（当前深色主题）
    case cream = "cream"        // 奶白色
    case lightGray = "lightGray" // 灰白色

    var displayName: String {
        switch self {
        case .dark: return "深灰色"
        case .cream: return "奶白色"
        case .lightGray: return "灰白色"
        }
    }

    var icon: String {
        switch self {
        case .dark: return "moon.fill"
        case .cream: return "sun.max.fill"
        case .lightGray: return "cloud.fill"
        }
    }
}

// MARK: - Theme Manager
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var currentTheme: AppTheme {
        didSet {
            saveTheme()
        }
    }

    var current: ThemeColors {
        ThemeColors.colors(for: currentTheme)
    }

    private let themeKey = "app_theme"

    private init() {
        if let savedTheme = UserDefaults.standard.string(forKey: themeKey),
           let theme = AppTheme(rawValue: savedTheme) {
            self.currentTheme = theme
        } else {
            self.currentTheme = .dark
        }
    }

    private func saveTheme() {
        UserDefaults.standard.set(currentTheme.rawValue, forKey: themeKey)
    }
}

// MARK: - Theme Colors
struct ThemeColors {
    let background: Color
    let secondaryBackground: Color
    let cardBackground: Color
    let elevatedBackground: Color

    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color

    let border: Color
    let divider: Color
    let hover: Color
    let selected: Color

    // 主题色保持不变
    static let accent = Color(red: 0.45, green: 0.55, blue: 1.0)
    static let accentLight = Color(red: 0.60, green: 0.70, blue: 1.0)
    static let success = Color(red: 0.30, green: 0.85, blue: 0.60)
    static let successLight = Color(red: 0.45, green: 0.92, blue: 0.72)
    static let warning = Color(red: 1.0, green: 0.75, blue: 0.30)
    static let warningLight = Color(red: 1.0, green: 0.85, blue: 0.50)
    static let danger = Color(red: 1.0, green: 0.45, blue: 0.50)
    static let dangerLight = Color(red: 1.0, green: 0.60, blue: 0.65)

    // 深灰色主题（当前）
    static let dark = ThemeColors(
        background: Color(red: 0.11, green: 0.11, blue: 0.12),
        secondaryBackground: Color(red: 0.15, green: 0.15, blue: 0.16),
        cardBackground: Color(red: 0.18, green: 0.18, blue: 0.20),
        elevatedBackground: Color(red: 0.22, green: 0.22, blue: 0.24),
        textPrimary: Color(red: 0.95, green: 0.95, blue: 0.97),
        textSecondary: Color(red: 0.70, green: 0.70, blue: 0.75),
        textTertiary: Color(red: 0.50, green: 0.50, blue: 0.55),
        border: Color.white.opacity(0.12),
        divider: Color.white.opacity(0.08),
        hover: Color.white.opacity(0.08),
        selected: Color.white.opacity(0.15)
    )

    // 奶白色主题
    static let cream = ThemeColors(
        background: Color(red: 0.98, green: 0.96, blue: 0.93),
        secondaryBackground: Color(red: 0.96, green: 0.94, blue: 0.90),
        cardBackground: Color(red: 1.0, green: 0.98, blue: 0.95),
        elevatedBackground: Color(red: 1.0, green: 1.0, blue: 0.98),
        textPrimary: Color(red: 0.15, green: 0.15, blue: 0.15),
        textSecondary: Color(red: 0.40, green: 0.40, blue: 0.38),
        textTertiary: Color(red: 0.55, green: 0.55, blue: 0.52),
        border: Color.black.opacity(0.10),
        divider: Color.black.opacity(0.06),
        hover: Color.black.opacity(0.04),
        selected: Color.black.opacity(0.08)
    )

    // 灰白色主题
    static let lightGray = ThemeColors(
        background: Color(red: 0.94, green: 0.94, blue: 0.96),
        secondaryBackground: Color(red: 0.92, green: 0.92, blue: 0.94),
        cardBackground: Color(red: 0.98, green: 0.98, blue: 0.99),
        elevatedBackground: Color(red: 1.0, green: 1.0, blue: 1.0),
        textPrimary: Color(red: 0.12, green: 0.12, blue: 0.15),
        textSecondary: Color(red: 0.38, green: 0.38, blue: 0.42),
        textTertiary: Color(red: 0.55, green: 0.55, blue: 0.58),
        border: Color.black.opacity(0.10),
        divider: Color.black.opacity(0.06),
        hover: Color.black.opacity(0.04),
        selected: Color.black.opacity(0.08)
    )

    static func colors(for theme: AppTheme) -> ThemeColors {
        switch theme {
        case .dark: return .dark
        case .cream: return .cream
        case .lightGray: return .lightGray
        }
    }
}
