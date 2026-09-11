import AppKit
import SwiftUI

enum AboutPanel {
    static func show() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .linkRouterOpenAbout, object: nil)
    }
}

extension Notification.Name {
    static let linkRouterOpenAbout = Notification.Name("LinkRouterOpenAbout")
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)
            Text("LinkRouter")
                .font(.system(size: 14, weight: .semibold))
            Text("Henrik Øgård")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Text("Version \(version)")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(width: 260)
        .padding(.top, 36)
        .padding(.bottom, 24)
        .padding(.horizontal, 24)
    }

    private var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(short) (\(build))"
    }
}
