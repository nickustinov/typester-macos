import Cocoa
import Carbon.HIToolbox

class HotkeyManager {
    static let shared = HotkeyManager()

    private var hotkeyRef: EventHotKeyRef?

    // Triple-tap tracking
    private var modifierPressTimestamps: [String: [Date]] = [:]
    private let tripleTapWindow: TimeInterval = 0.5
    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?
    private var previousModifierFlags: NSEvent.ModifierFlags = []

    var onHotkeyTriggered: (() -> Void)?

    private init() {
        installCarbonHandler()
        installTripleTapMonitor()
    }

    // MARK: - Carbon hotkeys (works without accessibility permission)

    private func installCarbonHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, _) -> OSStatus in
                var hotkeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotkeyID
                )

                HotkeyManager.shared.handleHotkey()
                return noErr
            },
            1,
            &eventType,
            nil,
            nil
        )
    }

    private func handleHotkey() {
        guard SettingsStore.shared.activationMode == .hotkey else { return }

        DispatchQueue.main.async { [weak self] in
            self?.onHotkeyTriggered?()
        }
    }

    func registerHotkey() {
        unregisterHotkey()

        let keys = SettingsStore.shared.shortcutKeys
        guard !keys.isTripleTap else { return }

        let hotkeyID = EventHotKeyID(signature: OSType(0x5459_5053), id: 1) // "TYPS"

        let modifiers = carbonModifiers(from: NSEvent.ModifierFlags(rawValue: keys.modifiers))

        _ = RegisterEventHotKey(
            UInt32(keys.keyCode),
            modifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )
    }

    func unregisterHotkey() {
        if let ref = hotkeyRef {
            UnregisterEventHotKey(ref)
            hotkeyRef = nil
        }
    }

    private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var modifiers: UInt32 = 0
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        return modifiers
    }

    // MARK: - Triple-tap monitor

    private func installTripleTapMonitor() {
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }

        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        defer { previousModifierFlags = flags }

        // Only count key-down (modifier newly pressed, not released)
        var pressedModifier: String?
        if flags.contains(.option) && !previousModifierFlags.contains(.option) {
            pressedModifier = "option"
        } else if flags.contains(.control) && !previousModifierFlags.contains(.control) {
            pressedModifier = "control"
        } else if flags.contains(.shift) && !previousModifierFlags.contains(.shift) {
            pressedModifier = "shift"
        } else if flags.contains(.command) && !previousModifierFlags.contains(.command) {
            pressedModifier = "command"
        }

        guard let modifier = pressedModifier else { return }

        let now = Date()
        var timestamps = modifierPressTimestamps[modifier] ?? []
        timestamps.append(now)
        timestamps = timestamps.filter { now.timeIntervalSince($0) < tripleTapWindow }
        modifierPressTimestamps[modifier] = timestamps

        if timestamps.count >= 3 {
            modifierPressTimestamps[modifier] = []

            let keys = SettingsStore.shared.shortcutKeys
            if keys.isTripleTap && keys.tapModifier == modifier {
                handleHotkey()
            }
        }
    }

    deinit {
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
