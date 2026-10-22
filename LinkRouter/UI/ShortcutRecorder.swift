import AppKit
import Carbon.HIToolbox
import SwiftUI

struct ShortcutRecorder: NSViewRepresentable {
    var combo: KeyCombo?
    var onChange: (KeyCombo?) -> Bool

    func makeCoordinator() -> Coordinator { Coordinator(onChange: onChange) }

    func makeNSView(context: Context) -> ShortcutRecorderButton {
        let button = ShortcutRecorderButton()
        button.coordinator = context.coordinator
        button.combo = combo
        button.refreshTitle()
        return button
    }

    func updateNSView(_ button: ShortcutRecorderButton, context: Context) {
        context.coordinator.onChange = onChange
        button.coordinator = context.coordinator
        button.combo = combo
        button.refreshTitle()
    }

    final class Coordinator {
        var onChange: (KeyCombo?) -> Bool
        init(onChange: @escaping (KeyCombo?) -> Bool) { self.onChange = onChange }
    }
}

final class ShortcutRecorderButton: NSButton {
    var combo: KeyCombo?
    weak var coordinator: ShortcutRecorder.Coordinator?
    private var recording = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        bezelStyle = .rounded
        setButtonType(.momentaryPushIn)
        focusRingType = .default
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        recording = true
        refreshTitle()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        guard recording else { super.keyDown(with: event); return }
        if event.keyCode == UInt16(kVK_Escape) {
            recording = false
            refreshTitle()
            return
        }
        if event.keyCode == UInt16(kVK_Delete) || event.keyCode == UInt16(kVK_ForwardDelete) {
            if coordinator?.onChange(nil) == true { combo = nil }
            recording = false
            refreshTitle()
            return
        }
        let modifiers = KeyCombo.carbonModifiers(for: event.modifierFlags)
        let candidate = KeyCombo(keyCode: UInt32(event.keyCode), carbonModifiers: modifiers)
        guard candidate.hasRequiredModifier else { NSSound.beep(); return }
        if coordinator?.onChange(candidate) == true {
            combo = candidate
            recording = false
            refreshTitle()
        } else {
            NSSound.beep()
        }
    }

    func refreshTitle() {
        guard !recording else {
            title = String(localized: "Type shortcut…")
            return
        }
        title = combo?.displayString ?? String(localized: "Record Shortcut")
    }
}
