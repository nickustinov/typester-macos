import Cocoa

class PressKeyMonitor {
    static let shared = PressKeyMonitor()

    var onKeyPressed: (() -> Void)?
    var onKeyReleased: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isKeyDown = false
    private var isActivated = false
    private var usedAsModifier = false
    private var activationTimer: DispatchWorkItem?
    private let activationDelay: TimeInterval = 0.05

    private init() {}

    private var needsKeyDownMonitoring: Bool {
        switch SettingsStore.shared.pressToSpeakKey {
        case .fn:
            return false
        case .leftCommand, .rightCommand, .leftOption, .rightOption:
            return true
        }
    }

    func start() {
        guard eventTap == nil else { return }

        var eventMask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue)
        // Monitor keyDown events to detect when the configured key is used as a modifier
        // (e.g. Cmd+C), so we don't treat it as press-to-speak
        eventMask |= (1 << CGEventType.keyDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { _, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<PressKeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
                return monitor.handleEvent(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("[PressKeyMonitor] Failed to create event tap - check Accessibility permissions")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        }

        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        activationTimer?.cancel()
        activationTimer = nil

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }

        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }

        eventTap = nil
        runLoopSource = nil
        isKeyDown = false
        isActivated = false
        usedAsModifier = false
    }

    private func isConfiguredKeyDown(event: CGEvent) -> Bool {
        let configuredKey = SettingsStore.shared.pressToSpeakKey
        let rawFlags = event.flags.rawValue

        switch configuredKey {
        case .fn:
            let modifiers = NSEvent.ModifierFlags(rawValue: UInt(rawFlags))
            return modifiers.contains(.function)
        case .leftCommand:
            return rawFlags & 0x00000008 != 0
        case .rightCommand:
            return rawFlags & 0x00000010 != 0
        case .leftOption:
            return rawFlags & 0x00000020 != 0
        case .rightOption:
            return rawFlags & 0x00000040 != 0
        }
    }

    private func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        // If another key is pressed while our key is held, it's being used as a modifier
        if type == .keyDown && isKeyDown && needsKeyDownMonitoring {
            Debug.log("Key pressed while modifier held — treating as modifier combo, cancelling activation")
            usedAsModifier = true
            activationTimer?.cancel()
            activationTimer = nil
            if isActivated {
                isActivated = false
                DispatchQueue.main.async { [weak self] in
                    self?.onKeyReleased?()
                }
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .flagsChanged else {
            return Unmanaged.passUnretained(event)
        }

        let keyName = SettingsStore.shared.pressToSpeakKey.displayName
        let keyNowDown = isConfiguredKeyDown(event: event)

        if keyNowDown && !isKeyDown {
            Debug.log("\(keyName) key DOWN detected")
            isKeyDown = true
            usedAsModifier = false
            activationTimer?.cancel()
            let timer = DispatchWorkItem { [weak self] in
                guard let self = self, self.isKeyDown, !self.usedAsModifier else {
                    Debug.log("\(keyName) activation cancelled")
                    return
                }
                Debug.log("\(keyName) ACTIVATED after \(self.activationDelay)s delay -> calling onKeyPressed")
                self.isActivated = true
                self.onKeyPressed?()
            }
            activationTimer = timer
            DispatchQueue.main.asyncAfter(deadline: .now() + activationDelay, execute: timer)
        } else if !keyNowDown && isKeyDown {
            Debug.log("\(keyName) key UP detected, isActivated=\(isActivated), usedAsModifier=\(usedAsModifier)")
            isKeyDown = false
            activationTimer?.cancel()
            activationTimer = nil
            if isActivated && !usedAsModifier {
                isActivated = false
                DispatchQueue.main.async { [weak self] in
                    Debug.log("\(keyName) DEACTIVATED -> calling onKeyReleased")
                    self?.onKeyReleased?()
                }
            }
            isActivated = false
            usedAsModifier = false
        }

        return Unmanaged.passUnretained(event)
    }
}
