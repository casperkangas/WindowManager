import Carbon
import Cocoa

@MainActor
class KeyHandler {

    // Explicitly isolated to MainActor to satisfy Swift 6 concurrency requirements
    @MainActor static var eventTap: CFMachPort?

    static func setupEventTap() -> CFMachPort? {
        let eventMask = (1 << CGEventType.keyDown.rawValue)

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: myCGEventCallback,
            userInfo: nil
        )

        return eventTap
    }
}

// Global C-function callback remains non-isolated as required by CoreGraphics
func myCGEventCallback(
    proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {

    // --- SLEEP/WAKE RESILIENCE ---
    // Accessing KeyHandler.eventTap from a non-isolated context requires bridging to the MainActor
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        print("⚠️ Event Tap was disabled by system. Re-enabling...")

        DispatchQueue.main.async {
            // Re-enabling the tap on the main thread to safely access the actor-isolated property
            if let tap = KeyHandler.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
        }
        return Unmanaged.passUnretained(event)
    }

    if type == .keyDown {
        let flags = event.flags
        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))

        let isCmd = flags.contains(.maskCommand)
        let isOption = flags.contains(.maskAlternate)
        let isCtrl = flags.contains(.maskControl)

        let kLeftArrow = 123
        let kRightArrow = 124
        let kKeyL = 37
        let kKeyR = 15

        // Asynchronous bridging to MainActor logic in WindowActions
        if isCmd && isOption && !isCtrl && keyCode == kKeyL {
            DispatchQueue.main.async { WindowActions.snapActiveWindow(to: .maximize) }
            return nil
        }

        if isCmd && isOption && !isCtrl && keyCode == kLeftArrow {
            DispatchQueue.main.async { WindowActions.snapActiveWindow(to: .left) }
            return nil
        }

        if isCmd && isOption && !isCtrl && keyCode == kRightArrow {
            DispatchQueue.main.async { WindowActions.snapActiveWindow(to: .right) }
            return nil
        }

        if isCmd && isOption && !isCtrl && keyCode == kKeyR {
            DispatchQueue.main.async { WindowActions.snapActiveWindow(to: .reset) }
            return nil
        }

        if isCmd && isOption && isCtrl && keyCode == kRightArrow {
            DispatchQueue.main.async { WindowActions.moveActiveWindowToNextScreen() }
            return nil
        }
    }

    return Unmanaged.passUnretained(event)
}