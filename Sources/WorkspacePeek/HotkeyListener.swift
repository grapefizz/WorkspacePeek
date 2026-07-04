import AppKit
import Carbon

final class HotkeyListener {

    var onTrigger: (() -> Void)?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    func start() {
        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue)

        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon else { return Unmanaged.passRetained(event) }
                let listener = Unmanaged<HotkeyListener>.fromOpaque(refcon).takeUnretainedValue()
                return listener.handle(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let tap else {
            let cfg = WorkspacePeekConfig.current
            print("\(cfg.logging.prefix): could not create event tap - check Accessibility permission")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), src, .commonModes)
        }
    }

    private func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passRetained(event)
        }
        guard type == .keyDown else { return Unmanaged.passRetained(event) }

        let cfg = WorkspacePeekConfig.current.hotkey
        guard let triggerKeyCode = cfg.triggerKeyCode else { return Unmanaged.passRetained(event) }
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags.intersection([.maskAlternate, .maskCommand, .maskControl, .maskShift])

        if keyCode == triggerKeyCode && flags == cfg.modifierFlags {
            DispatchQueue.main.async { self.onTrigger?() }
            return cfg.consumeEvent ? nil : Unmanaged.passRetained(event)
        }
        return Unmanaged.passRetained(event)
    }
}
