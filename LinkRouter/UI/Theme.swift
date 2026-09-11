import AppKit
import SwiftUI

extension AppearanceMode {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    func apply() {
        guard NSApp != nil else { return }
        switch self {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}

enum LR {
    static let accent = Color.primary
    static let sidebarWidth: CGFloat = 216
    static let titlebar: CGFloat = 36
    static let pageInset: CGFloat = 28
    static let rowRadius: CGFloat = 12

    static var sidebarFill: Color {
        Color(nsColor: .controlBackgroundColor)
    }

    static var pageFill: Color {
        Color(nsColor: .windowBackgroundColor)
    }

    static var rowFill: Color {
        Color.primary.opacity(0.045)
    }

    static var hairline: Color {
        Color.primary.opacity(0.10)
    }
}
