import AppKit
import SwiftUI

extension AppearanceMode {
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
    static let accent = Color("AccentColor")
}
