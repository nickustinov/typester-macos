import Cocoa

class FnKeyMonitor {
    static let shared = FnKeyMonitor()

    var onFnPressed: (() -> Void)?
    var onFnReleased: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isFnDown = false
    private var isActivated = false
    private var activationTimer: DispatchWorkItem?
    private let activationDelay: TimeInterval = 0.05

    private init() {}

    func start() {
        guard eventTap == nil else { return }

        let eventMask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { _, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<FnKeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
                return monitor.handleEvent(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("[FnKeyMonitor] Failed to create event tap - check Accessibility permissions")
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
        isFnDown = false
        isActivated = false
    }

    private func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .flagsChanged else {
            return Unmanaged.passUnretained(event)
        }

        let modifiers = NSEvent.ModifierFlags(rawValue: UInt(event.flags.rawValue))
        let fnNowDown = modifiers.contains(.function)

        if fnNowDown && !isFnDown {
            Debug.log("Fn key DOWN detected")
            isFnDown = true
            activationTimer?.cancel()
            let timer = DispatchWorkItem { [weak self] in
                guard let self = self, self.isFnDown else {
                    Debug.log("Fn activation cancelled (key released before delay)")
                    return
                }
                Debug.log("Fn ACTIVATED after \(self.activationDelay)s delay -> calling onFnPressed")
                self.isActivated = true
                self.onFnPressed?()
            }
            activationTimer = timer
            DispatchQueue.main.asyncAfter(deadline: .now() + activationDelay, execute: timer)
        } else if !fnNowDown && isFnDown {
            Debug.log("Fn key UP detected, isActivated=\(isActivated)")
            isFnDown = false
            activationTimer?.cancel()
            activationTimer = nil
            if isActivated {
                isActivated = false
                DispatchQueue.main.async { [weak self] in
                    Debug.log("Fn DEACTIVATED -> calling onFnReleased")
                    self?.onFnReleased?()
                }
            }
        }

        return Unmanaged.passUnretained(event)
    }
}
