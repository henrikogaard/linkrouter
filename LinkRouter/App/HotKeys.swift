import AppKit
import Carbon.HIToolbox
import SwiftUI

enum ShortcutAction: String, Codable, CaseIterable, Identifiable {
    case openClipboardLink
    case sendCurrentPage

    var id: String { rawValue }

    var title: String {
        switch self {
        case .openClipboardLink: String(localized: "Open Clipboard Link")
        case .sendCurrentPage: String(localized: "Open Current Page in Another Browser")
        }
    }
}

struct KeyCombo: Codable, Equatable {
    var keyCode: UInt32
    var carbonModifiers: UInt32

    var displayString: String {
        var result = ""
        if carbonModifiers & UInt32(controlKey) != 0 { result += "⌃" }
        if carbonModifiers & UInt32(optionKey) != 0 { result += "⌥" }
        if carbonModifiers & UInt32(shiftKey) != 0 { result += "⇧" }
        if carbonModifiers & UInt32(cmdKey) != 0 { result += "⌘" }
        return result + Self.keyName(keyCode)
    }

    var hasRequiredModifier: Bool {
        carbonModifiers & UInt32(controlKey | optionKey | cmdKey) != 0
    }

    var keyboardShortcut: KeyboardShortcut? {
        let key: KeyEquivalent
        if let letter = Self.letters[Int(keyCode)] {
            key = KeyEquivalent(Character(letter.lowercased()))
        } else if let functionKey = Self.functionKeys[Int(keyCode)],
                  let number = Int(functionKey.dropFirst()) {
            key = KeyEquivalent(Character(UnicodeScalar(0xF703 + number)!))
        } else {
            switch keyCode {
            case UInt32(kVK_LeftArrow): key = .leftArrow
            case UInt32(kVK_RightArrow): key = .rightArrow
            case UInt32(kVK_UpArrow): key = .upArrow
            case UInt32(kVK_DownArrow): key = .downArrow
            case UInt32(kVK_Return): key = .return
            case UInt32(kVK_Tab): key = .tab
            case UInt32(kVK_Space): key = .space
            default: return nil
            }
        }
        var modifiers: SwiftUI.EventModifiers = []
        if carbonModifiers & UInt32(controlKey) != 0 { modifiers.insert(.control) }
        if carbonModifiers & UInt32(optionKey) != 0 { modifiers.insert(.option) }
        if carbonModifiers & UInt32(shiftKey) != 0 { modifiers.insert(.shift) }
        if carbonModifiers & UInt32(cmdKey) != 0 { modifiers.insert(.command) }
        return KeyboardShortcut(key, modifiers: modifiers)
    }

    static func carbonModifiers(for flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.control) { result |= UInt32(controlKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        return result
    }

    private static let letters: [Int: String] = [
        kVK_ANSI_A: "A", kVK_ANSI_S: "S", kVK_ANSI_D: "D", kVK_ANSI_F: "F",
        kVK_ANSI_H: "H", kVK_ANSI_G: "G", kVK_ANSI_Z: "Z", kVK_ANSI_X: "X",
        kVK_ANSI_C: "C", kVK_ANSI_V: "V", kVK_ANSI_B: "B", kVK_ANSI_Q: "Q",
        kVK_ANSI_W: "W", kVK_ANSI_E: "E", kVK_ANSI_R: "R", kVK_ANSI_Y: "Y",
        kVK_ANSI_T: "T", kVK_ANSI_O: "O", kVK_ANSI_U: "U", kVK_ANSI_I: "I",
        kVK_ANSI_P: "P", kVK_ANSI_L: "L", kVK_ANSI_J: "J", kVK_ANSI_K: "K",
        kVK_ANSI_N: "N", kVK_ANSI_M: "M"
    ]
    private static let functionKeys: [Int: String] = [
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4",
        kVK_F5: "F5", kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8",
        kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
        kVK_F13: "F13", kVK_F14: "F14", kVK_F15: "F15", kVK_F16: "F16",
        kVK_F17: "F17", kVK_F18: "F18", kVK_F19: "F19", kVK_F20: "F20"
    ]

    private static func keyName(_ code: UInt32) -> String {
        if let letter = letters[Int(code)] { return letter }
        if let functionKey = functionKeys[Int(code)] { return functionKey }
        return switch code {
        case UInt32(kVK_LeftArrow): "←"
        case UInt32(kVK_RightArrow): "→"
        case UInt32(kVK_UpArrow): "↑"
        case UInt32(kVK_DownArrow): "↓"
        case UInt32(kVK_Return): "↩"
        case UInt32(kVK_Tab): "⇥"
        case UInt32(kVK_Space): "Space"
        case UInt32(kVK_Escape): "Esc"
        case UInt32(kVK_Delete): "⌫"
        case UInt32(kVK_ForwardDelete): "⌦"
        default: "Key \(code)"
        }
    }
}

@MainActor
final class HotKeys {
    private struct Registration {
        let combo: KeyCombo
        let reference: EventHotKeyRef
    }

    private let onAction: (ShortcutAction) -> Void
    private var eventHandler: EventHandlerRef?
    private var registrations: [ShortcutAction: Registration] = [:]
    private var actionIDs: [UInt32: ShortcutAction] = [:]

    init(onAction: @escaping (ShortcutAction) -> Void) {
        self.onAction = onAction
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        _ = InstallEventHandler(
            GetApplicationEventTarget(),
            globalHotKeyHandler,
            1,
            &type,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
    }

    func configure(_ combos: [ShortcutAction: KeyCombo]) {
        for action in ShortcutAction.allCases {
            if let combo = combos[action] { _ = set(combo, for: action) }
            else { clear(action) }
        }
    }

    func set(_ combo: KeyCombo, for action: ShortcutAction) -> Bool {
        guard combo.hasRequiredModifier else { return false }
        if registrations.contains(where: { $0.key != action && $0.value.combo == combo }) { return false }
        if registrations[action]?.combo == combo { return true }

        let id = UInt32(ShortcutAction.allCases.firstIndex(of: action)! + 1)
        var reference: EventHotKeyRef?
        let status = RegisterEventHotKey(
            combo.keyCode,
            combo.carbonModifiers,
            EventHotKeyID(signature: OSType(0x4C52484B), id: id),
            GetApplicationEventTarget(),
            0,
            &reference
        )
        guard status == noErr, let reference else { return false }
        if let old = registrations.removeValue(forKey: action) {
            UnregisterEventHotKey(old.reference)
        }
        registrations[action] = Registration(combo: combo, reference: reference)
        actionIDs[id] = action
        return true
    }

    func clear(_ action: ShortcutAction) {
        guard let registration = registrations.removeValue(forKey: action) else { return }
        UnregisterEventHotKey(registration.reference)
    }

    fileprivate func trigger(_ id: UInt32) {
        if let action = actionIDs[id] { onAction(action) }
    }

    deinit {
        for registration in registrations.values { UnregisterEventHotKey(registration.reference) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }
}

private let globalHotKeyHandler: EventHandlerProcPtr = { _, event, userData in
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr else { return status }
    let manager = Unmanaged<HotKeys>.fromOpaque(userData).takeUnretainedValue()
    let id = hotKeyID.id
    Task { @MainActor in manager.trigger(id) }
    return noErr
}
