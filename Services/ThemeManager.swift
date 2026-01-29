import SwiftUI

/// Theme Manager - Handles all UI theming
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var currentTheme: Theme = .midnight
    
    enum Theme: String, CaseIterable {
        case midnight = "Midnight"
        case spaceBlack = "Space Black"
        case blue = "Blue"
        case silver = "Silver"
        case neon = "Neon"
        case forest = "Forest"
        case ocean = "Ocean"
        case sunset = "Sunset"
        case minimal = "Minimal"
        case synthwave = "Synthwave"
    }
    
    struct Colors {
        let background: Color
        let secondaryBackground: Color
        let cardBackground: Color
        let primary: Color
        let secondary: Color
        let accent: Color
        let destructive: Color
        let success: Color
        let warning: Color
        let text: Color
        let secondaryText: Color
    }
    
    func colors(for theme: Theme) -> Colors {
        switch theme {
        case .midnight:
            return Colors(
                background: Color(red: 0.05, green: 0.05, blue: 0.1),
                secondaryBackground: Color(red: 0.08, green: 0.08, blue: 0.15),
                cardBackground: Color(red: 0.1, green: 0.1, blue: 0.18),
                primary: Color(red: 0.2, green: 0.6, blue: 1.0),
                secondary: Color(red: 0.3, green: 0.7, blue: 1.0),
                accent: Color(red: 0.0, green: 1.0, blue: 0.8),
                destructive: Color(red: 1.0, green: 0.3, blue: 0.3),
                success: Color(red: 0.2, green: 0.8, blue: 0.4),
                warning: Color(red: 1.0, green: 0.7, blue: 0.2),
                text: Color(red: 0.95, green: 0.95, blue: 1.0),
                secondaryText: Color(red: 0.6, green: 0.65, blue: 0.8)
            )
            
        case .spaceBlack:
            return Colors(
                background: Color(red: 0.02, green: 0.02, blue: 0.03),
                secondaryBackground: Color(red: 0.04, green: 0.04, blue: 0.06),
                cardBackground: Color(red: 0.06, green: 0.06, blue: 0.08),
                primary: Color(red: 0.5, green: 0.8, blue: 1.0),
                secondary: Color(red: 0.6, green: 0.85, blue: 1.0),
                accent: Color(red: 0.3, green: 1.0, blue: 0.9),
                destructive: Color(red: 1.0, green: 0.4, blue: 0.4),
                success: Color(red: 0.3, green: 0.9, blue: 0.5),
                warning: Color(red: 1.0, green: 0.7, blue: 0.2),
                text: Color(red: 0.98, green: 0.98, blue: 1.0),
                secondaryText: Color(red: 0.7, green: 0.75, blue: 0.9)
            )
            
        case .blue:
            return Colors(
                background: Color(red: 0.08, green: 0.12, blue: 0.2),
                secondaryBackground: Color(red: 0.12, green: 0.16, blue: 0.26),
                cardBackground: Color(red: 0.15, green: 0.2, blue: 0.3),
                primary: Color(red: 0.3, green: 0.7, blue: 1.0),
                secondary: Color(red: 0.4, green: 0.75, blue: 1.0),
                accent: Color(red: 0.2, green: 0.95, blue: 1.0),
                destructive: Color(red: 1.0, green: 0.3, blue: 0.3),
                success: Color(red: 0.2, green: 0.85, blue: 0.4),
                warning: Color(red: 1.0, green: 0.7, blue: 0.1),
                text: Color(red: 0.95, green: 0.97, blue: 1.0),
                secondaryText: Color(red: 0.65, green: 0.75, blue: 0.9)
            )
            
        case .silver:
            return Colors(
                background: Color(red: 0.15, green: 0.15, blue: 0.17),
                secondaryBackground: Color(red: 0.2, green: 0.2, blue: 0.22),
                cardBackground: Color(red: 0.25, green: 0.25, blue: 0.27),
                primary: Color(red: 0.3, green: 0.6, blue: 0.9),
                secondary: Color(red: 0.4, green: 0.7, blue: 1.0),
                accent: Color(red: 0.6, green: 0.85, blue: 1.0),
                destructive: Color(red: 1.0, green: 0.3, blue: 0.3),
                success: Color(red: 0.2, green: 0.8, blue: 0.4),
                warning: Color(red: 1.0, green: 0.7, blue: 0.1),
                text: Color(red: 0.95, green: 0.95, blue: 0.95),
                secondaryText: Color(red: 0.7, green: 0.7, blue: 0.75)
            )
            
        case .neon:
            return Colors(
                background: Color(red: 0.0, green: 0.0, blue: 0.05),
                secondaryBackground: Color(red: 0.05, green: 0.0, blue: 0.1),
                cardBackground: Color(red: 0.1, green: 0.0, blue: 0.15),
                primary: Color(red: 1.0, green: 0.0, blue: 0.5),
                secondary: Color(red: 0.0, green: 1.0, blue: 1.0),
                accent: Color(red: 0.0, green: 1.0, blue: 0.0),
                destructive: Color(red: 1.0, green: 0.2, blue: 0.2),
                success: Color(red: 0.0, green: 1.0, blue: 0.5),
                warning: Color(red: 1.0, green: 1.0, blue: 0.0),
                text: Color.white,
                secondaryText: Color(red: 0.7, green: 0.7, blue: 0.9)
            )
            
        case .forest:
            return Colors(
                background: Color(red: 0.08, green: 0.12, blue: 0.08),
                secondaryBackground: Color(red: 0.12, green: 0.16, blue: 0.12),
                cardBackground: Color(red: 0.15, green: 0.2, blue: 0.15),
                primary: Color(red: 0.3, green: 0.8, blue: 0.4),
                secondary: Color(red: 0.4, green: 0.9, blue: 0.5),
                accent: Color(red: 0.8, green: 0.9, blue: 0.3),
                destructive: Color(red: 1.0, green: 0.4, blue: 0.3),
                success: Color(red: 0.3, green: 0.9, blue: 0.4),
                warning: Color(red: 1.0, green: 0.8, blue: 0.2),
                text: Color(red: 0.9, green: 0.95, blue: 0.9),
                secondaryText: Color(red: 0.6, green: 0.75, blue: 0.65)
            )
            
        case .ocean:
            return Colors(
                background: Color(red: 0.05, green: 0.1, blue: 0.15),
                secondaryBackground: Color(red: 0.08, green: 0.14, blue: 0.2),
                cardBackground: Color(red: 0.1, green: 0.16, blue: 0.24),
                primary: Color(red: 0.2, green: 0.7, blue: 1.0),
                secondary: Color(red: 0.3, green: 0.8, blue: 1.0),
                accent: Color(red: 0.0, green: 1.0, blue: 0.7),
                destructive: Color(red: 1.0, green: 0.4, blue: 0.4),
                success: Color(red: 0.2, green: 0.9, blue: 0.6),
                warning: Color(red: 1.0, green: 0.8, blue: 0.2),
                text: Color(red: 0.9, green: 0.95, blue: 1.0),
                secondaryText: Color(red: 0.6, green: 0.75, blue: 0.9)
            )
            
        case .sunset:
            return Colors(
                background: Color(red: 0.15, green: 0.08, blue: 0.05),
                secondaryBackground: Color(red: 0.2, green: 0.1, blue: 0.08),
                cardBackground: Color(red: 0.24, green: 0.12, blue: 0.1),
                primary: Color(red: 1.0, green: 0.6, blue: 0.2),
                secondary: Color(red: 1.0, green: 0.4, blue: 0.2),
                accent: Color(red: 1.0, green: 0.8, blue: 0.4),
                destructive: Color(red: 0.9, green: 0.3, blue: 0.2),
                success: Color(red: 0.3, green: 0.8, blue: 0.4),
                warning: Color(red: 1.0, green: 0.7, blue: 0.1),
                text: Color(red: 1.0, green: 0.95, blue: 0.9),
                secondaryText: Color(red: 0.9, green: 0.75, blue: 0.6)
            )
            
        case .minimal:
            return Colors(
                background: Color(red: 0.97, green: 0.97, blue: 0.98),
                secondaryBackground: Color(red: 0.93, green: 0.93, blue: 0.95),
                cardBackground: Color.white,
                primary: Color(red: 0.2, green: 0.3, blue: 0.6),
                secondary: Color(red: 0.4, green: 0.5, blue: 0.8),
                accent: Color(red: 0.8, green: 0.2, blue: 0.4),
                destructive: Color(red: 0.8, green: 0.2, blue: 0.2),
                success: Color(red: 0.2, green: 0.7, blue: 0.3),
                warning: Color(red: 1.0, green: 0.6, blue: 0.0),
                text: Color(red: 0.1, green: 0.1, blue: 0.15),
                secondaryText: Color(red: 0.5, green: 0.5, blue: 0.55)
            )
            
        case .synthwave:
            return Colors(
                background: Color(red: 0.06, green: 0.05, blue: 0.15),
                secondaryBackground: Color(red: 0.1, green: 0.08, blue: 0.2),
                cardBackground: Color(red: 0.12, green: 0.1, blue: 0.25),
                primary: Color(red: 1.0, green: 0.0, blue: 0.75),
                secondary: Color(red: 0.0, green: 1.0, blue: 1.0),
                accent: Color(red: 1.0, green: 0.5, blue: 0.0),
                destructive: Color(red: 1.0, green: 0.2, blue: 0.2),
                success: Color(red: 0.0, green: 1.0, blue: 0.5),
                warning: Color(red: 1.0, green: 1.0, blue: 0.0),
                text: Color.white,
                secondaryText: Color(red: 0.8, green: 0.8, blue: 1.0)
            )
        }
    }
    
    func themeDescription(_ theme: Theme) -> String {
        switch theme {
        case .midnight:
            return "Cool blues and cyans on a dark background. Perfect for long sessions."
        case .spaceBlack:
            return "Darkest space-inspired blacks with cool blues. Ultimate immersion."
        case .blue:
            return "Professional blue tones on dark background. Clean and focused."
        case .silver:
            return "Sleek silver grays with blue accents. Modern and sophisticated."
        case .neon:
            return "Vibrant neon colors with maximum contrast. High energy gaming vibes."
        case .forest:
            return "Calming greens with natural tones. Relaxing on the eyes."
        case .ocean:
            return "Cool blues and teals. Serene and professional."
        case .sunset:
            return "Warm oranges and reds. Cozy and inviting."
        case .minimal:
            return "Clean light theme. Classic and distraction-free."
        case .synthwave:
            return "Retro 80s vibes. Magenta, cyan, and neon aesthetics."
        }
    }
    
    func setTheme(_ theme: Theme) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentTheme = theme
        }
        UserDefaults.standard.set(theme.rawValue, forKey: "selectedTheme")
    }
    
    func loadTheme() {
        if let savedTheme = UserDefaults.standard.string(forKey: "selectedTheme"),
           let theme = Theme(rawValue: savedTheme) {
            currentTheme = theme
        } else {
            currentTheme = .midnight
        }
    }
}
