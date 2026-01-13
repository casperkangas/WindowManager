import Carbon
import Cocoa

class KeyHandler {

    static func setupEventTap() -> CFMachPort? {
        // Listen for KeyDown events
        let eventMask = (1 << CGEventType.keyDown.rawValue)

        return CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: myCGEventCallback,
            userInfo: nil
        )
    }
}

// Global C-function callback
func myCGEventCallback(
    proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {

    if type == .keyDown {
        let flags = event.flags
        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))

        // Modifiers
        let isCmd = flags.contains(.maskCommand)
        let isOption = flags.contains(.maskAlternate)
        let isCtrl = flags.contains(.maskControl)

        // Key Codes (Carbon)
        let kLeftArrow = 123
        let kRightArrow = 124
        let kKeyL = 37
        let kKeyR = 15  // 'R' Key

        // We use DispatchQueue.main.async to bridge the gap between this C-function
        // and the @MainActor isolated WindowActions.

        // 1. Maximize: Cmd + Option + L
        if isCmd && isOption && !isCtrl && keyCode == kKeyL {
            DispatchQueue.main.async {
                WindowActions.snapActiveWindow(to: .maximize)
            }
            return nil
        }

        // 2. Snap Left: Cmd + Option + Left Arrow
        if isCmd && isOption && !isCtrl && keyCode == kLeftArrow {
            DispatchQueue.main.async {
                WindowActions.snapActiveWindow(to: .left)
            }
            return nil
        }

        // 3. Snap Right: Cmd + Option + Right Arrow
        if isCmd && isOption && !isCtrl && keyCode == kRightArrow {
            DispatchQueue.main.async {
                WindowActions.snapActiveWindow(to: .right)
            }
            return nil
        }

        // 4. Reset (Center 1/3): Cmd + Option + R
        if isCmd && isOption && !isCtrl && keyCode == kKeyR {
            DispatchQueue.main.async {
                WindowActions.snapActiveWindow(to: .reset)
            }
            return nil
        }

        // 5. Move Next Display: Ctrl + Option + Cmd + Right Arrow
        if isCmd && isOption && isCtrl && keyCode == kRightArrow {
            DispatchQueue.main.async {
                WindowActions.moveActiveWindowToNextScreen()
            }
            return nil
        }
    }

    return Unmanaged.passUnretained(event)
}