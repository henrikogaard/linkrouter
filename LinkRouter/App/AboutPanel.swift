import AppKit
import SwiftUI

@MainActor
enum AboutPanel {
    private static var window: NSWindow?

    static func show() {
        NSApp.setActivationPolicy(.regular)
        let window = self.window ?? makeWindow()
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private static func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        let content = NSHostingController(rootView: AboutView().tint(LR.accent))
        window.contentViewController = content
        window.setContentSize(content.view.fittingSize)
        window.title = String(localized: "About LinkRouter")
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
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
