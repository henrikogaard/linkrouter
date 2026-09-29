import AppKit
import SwiftUI

final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class PromptCountdown: ObservableObject {
    @Published var remaining: Int?
}

@MainActor
final class PromptController {
    private var panel: KeyPanel?
    private var hosting: NSHostingView<AnyView>?
    private var timeoutTimer: Timer?
    private var resignKeyObserver: NSObjectProtocol?
    private var onPick: ((UUID?, Bool) -> Void)?
    let countdown = PromptCountdown()

    var isVisible: Bool { panel != nil }

    func show(
        items: [PromptItem],
        link: IncomingLink,
        timeout: Int = 0,
        onPick: @escaping (UUID?, Bool) -> Void,
        onAlways: @escaping (UUID) -> Void,
        onTimeout: @escaping () -> Void = {}
    ) {
        dismiss()
        guard !items.isEmpty else { return }
        self.onPick = onPick

        let contentWidth = CGFloat(max(items.count, 1) + 1) * 86 + 22
        let width = max(contentWidth, 320)
        let height: CGFloat = items.count > 6 ? 208 : 194
        var origin = originForPointer(
            size: NSSize(width: width, height: height),
            firstCenterX: 14 + 40 + (width - contentWidth) / 2
        )

        let view = PromptView(
            items: items,
            link: link,
            onPick: { [weak self] id, keepOpen in
                if !keepOpen { self?.dismiss() }
                onPick(id, keepOpen)
            },
            onAlways: { [weak self] id in
                self?.dismiss()
                onAlways(id)
            },
            onCopy: { [weak self] in
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(link.url.absoluteString, forType: .string)
                self?.dismiss()
                onPick(nil, false)
            },
            onCancel: { [weak self] in
                self?.dismiss()
                onPick(nil, false)
            },
            countdown: countdown
        )

        // Theme.swift (LR) is app-target only; this file is shared with the test target.
        let hosting = NSHostingView(rootView: AnyView(view.tint(Color("AccentColor"))))
        hosting.frame = NSRect(x: 0, y: 0, width: width, height: height)

        // .nonactivatingPanel: the picker takes key status and keyboard input
        // without activating the app — activating would reopen the Settings
        // scene and steal key focus from the panel.
        let panel = KeyPanel(
            contentRect: NSRect(origin: origin, size: NSSize(width: width, height: height)),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.contentView = hosting
        panel.acceptsMouseMovedEvents = true

        self.panel = panel
        self.hosting = hosting

        if timeout > 0 {
            countdown.remaining = timeout
            timeoutTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    guard let remaining = self.countdown.remaining, remaining > 1 else {
                        self.dismiss()
                        onTimeout()
                        return
                    }
                    self.countdown.remaining = remaining - 1
                }
            }
        }

        resignKeyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.panel != nil else { return }
                self.dismiss()
                self.onPick?(nil, false)
            }
        }
        panel.makeKeyAndOrderFront(nil)
        origin = clamped(origin, size: panel.frame.size)
        panel.setFrameOrigin(origin)
    }

    func dismiss() {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
        countdown.remaining = nil
        if let resignKeyObserver {
            NotificationCenter.default.removeObserver(resignKeyObserver)
            self.resignKeyObserver = nil
        }
        // Nil the panel before ordering out so the resulting resign-key
        // notification isn't handled as a second cancel.
        let closing = panel
        panel = nil
        hosting = nil
        closing?.orderOut(nil)
    }

    private func originForPointer(size: NSSize, firstCenterX: CGFloat) -> NSPoint {
        let mouse = NSEvent.mouseLocation
        let x = mouse.x - firstCenterX
        let y = mouse.y - size.height + 40
        return clamped(NSPoint(x: x, y: y), size: size)
    }

    private func clamped(_ origin: NSPoint, size: NSSize) -> NSPoint {
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let visible = screen?.visibleFrame else { return origin }
        var point = origin
        point.x = min(max(point.x, visible.minX + 8), visible.maxX - size.width - 8)
        point.y = min(max(point.y, visible.minY + 8), visible.maxY - size.height - 8)
        return point
    }
}
