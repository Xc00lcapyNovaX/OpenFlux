import SwiftUI

/// Theme-aware color extension
extension Color {
    static func themeBackground(_ manager: ThemeManager = .shared) -> Color {
        manager.colors(for: manager.currentTheme).background
    }
    
    static func themeSecondaryBackground(_ manager: ThemeManager = .shared) -> Color {
        manager.colors(for: manager.currentTheme).secondaryBackground
    }
    
    static func themeCardBackground(_ manager: ThemeManager = .shared) -> Color {
        manager.colors(for: manager.currentTheme).cardBackground
    }
    
    static func themePrimary(_ manager: ThemeManager = .shared) -> Color {
        manager.colors(for: manager.currentTheme).primary
    }
    
    static func themeSecondary(_ manager: ThemeManager = .shared) -> Color {
        manager.colors(for: manager.currentTheme).secondary
    }
    
    static func themeAccent(_ manager: ThemeManager = .shared) -> Color {
        manager.colors(for: manager.currentTheme).accent
    }
    
    static func themeDestructive(_ manager: ThemeManager = .shared) -> Color {
        manager.colors(for: manager.currentTheme).destructive
    }
    
    static func themeSuccess(_ manager: ThemeManager = .shared) -> Color {
        manager.colors(for: manager.currentTheme).success
    }
    
    static func themeWarning(_ manager: ThemeManager = .shared) -> Color {
        manager.colors(for: manager.currentTheme).warning
    }
    
    static func themeText(_ manager: ThemeManager = .shared) -> Color {
        manager.colors(for: manager.currentTheme).text
    }
    
    static func themeSecondaryText(_ manager: ThemeManager = .shared) -> Color {
        manager.colors(for: manager.currentTheme).secondaryText
    }
}

/// View extension for theme-aware styling
extension View {
    func themedBackground(_ manager: ThemeManager = .shared) -> some View {
        self.background(Color.themeBackground(manager))
    }
    
    func themedCard(_ manager: ThemeManager = .shared) -> some View {
        self
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.themeCardBackground(manager))
                    .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
            )
    }
    
    func themedText(_ manager: ThemeManager = .shared) -> some View {
        self.foregroundStyle(Color.themeText(manager))
    }
    
    func themedSecondaryText(_ manager: ThemeManager = .shared) -> some View {
        self.foregroundStyle(Color.themeSecondaryText(manager))
    }
}
