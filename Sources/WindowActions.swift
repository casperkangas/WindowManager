import ApplicationServices
import Cocoa

enum WindowSnapDirection {
    case left
    case right
    case maximize
    case reset

    var opposite: WindowSnapDirection? {
        switch self {
        case .left: return .right
        case .right: return .left
        default: return nil
        }
    }
}

struct WindowActions {

    // Explicitly mark this static property as isolated to the MainActor
    @MainActor
    static var enableDualSnap: Bool = false

    // MARK: - Snap / Maximize / Reset

    @MainActor
    static func snapActiveWindow(to direction: WindowSnapDirection) {
        guard let (windowElement, currentScreen) = getActiveWindowAndScreen() else { return }

        // 1. Snap the main active window
        calculateAndApplyRect(window: windowElement, screen: currentScreen, direction: direction)

        // 2. Dual Snap Logic
        if enableDualSnap, let oppositeDirection = direction.opposite {
            if let secondWindow = getSecondFrontmostWindow() {
                calculateAndApplyRect(
                    window: secondWindow, screen: currentScreen, direction: oppositeDirection)
            }
        }
    }

    // MARK: - Core Logic

    @MainActor
    private static func calculateAndApplyRect(
        window: AXUIElement, screen: NSScreen, direction: WindowSnapDirection
    ) {
        let visibleFrame = screen.visibleFrame
        let primaryHeight = NSScreen.screens.first?.frame.height ?? visibleFrame.height
        let standardY = primaryHeight - (visibleFrame.origin.y + visibleFrame.height)

        var newX: CGFloat = 0
        var newY: CGFloat = standardY
        var newWidth: CGFloat = 0
        var newHeight: CGFloat = visibleFrame.height

        switch direction {
        case .maximize:
            newX = visibleFrame.origin.x
            newWidth = visibleFrame.width

        case .left:
            newX = visibleFrame.origin.x
            newWidth = visibleFrame.width / 2

        case .right:
            newX = visibleFrame.origin.x + (visibleFrame.width / 2)
            newWidth = visibleFrame.width / 2

        case .reset:
            let scaleFactor: CGFloat = 1.75
            newWidth = visibleFrame.width / scaleFactor
            newHeight = visibleFrame.height / scaleFactor
            newX = visibleFrame.origin.x + (visibleFrame.width - newWidth) / 2
            let marginY = (visibleFrame.height - newHeight) / 2
            newY = standardY + marginY
        }

        setWindowFrame(window, x: newX, y: newY, width: newWidth, height: newHeight)
    }

    // MARK: - Move to Next Display

    @MainActor
    static func moveActiveWindowToNextScreen() {
        guard let (windowElement, currentScreen) = getActiveWindowAndScreen() else { return }
        let screens = NSScreen.screens

        guard screens.count > 1, let currentIndex = screens.firstIndex(of: currentScreen) else {
            return
        }

        let nextIndex = (currentIndex + 1) % screens.count
        let nextScreen = screens[nextIndex]

        let visibleFrame = nextScreen.visibleFrame
        let primaryHeight = screens.first?.frame.height ?? 0

        let newX = visibleFrame.origin.x
        let newY = primaryHeight - (visibleFrame.origin.y + visibleFrame.height)

        var point = CGPoint(x: newX, y: newY)
        if let posVal = AXValueCreate(.cgPoint, &point) {
            AXUIElementSetAttributeValue(windowElement, kAXPositionAttribute as CFString, posVal)

            if #available(macOS 10.15, *) {
                print("Moved window to screen: \(nextScreen.localizedName)")
            } else {
                print("Moved window to screen index: \(nextIndex)")
            }
        }
    }

    // MARK: - Helpers

    @MainActor
    private static func setWindowFrame(
        _ window: AXUIElement, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat
    ) {
        var point = CGPoint(x: x, y: y)
        var size = CGSize(width: width, height: height)

        if let posVal = AXValueCreate(.cgPoint, &point),
            let sizeVal = AXValueCreate(.cgSize, &size)
        {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posVal)
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeVal)
        }
    }

    @MainActor
    private static func getActiveWindowAndScreen() -> (AXUIElement, NSScreen)? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)

        var focusedWindow: AnyObject?
        if AXUIElementCopyAttributeValue(
            appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow) != .success
        {
            return nil
        }

        let windowElement = focusedWindow as! AXUIElement

        // Determine screen
        var positionValue: AnyObject?
        AXUIElementCopyAttributeValue(
            windowElement, kAXPositionAttribute as CFString, &positionValue)

        var currentPoint = CGPoint.zero
        if let val = positionValue as! AXValue? {
            AXValueGetValue(val, .cgPoint, &currentPoint)
        }

        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0

        for screen in NSScreen.screens {
            let cocoaFrame = screen.frame
            let quartzY = primaryHeight - (cocoaFrame.origin.y + cocoaFrame.height)
            let quartzRect = CGRect(
                x: cocoaFrame.origin.x, y: quartzY, width: cocoaFrame.width,
                height: cocoaFrame.height)

            if quartzRect.contains(currentPoint) {
                return (windowElement, screen)
            }
        }

        return (windowElement, NSScreen.screens[0])
    }

    @MainActor
    private static func getSecondFrontmostWindow() -> AXUIElement? {
        let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly)
        // Get list of windows
        guard
            let infoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as NSArray?
                as? [[String: AnyObject]]
        else { return nil }

        var foundActive = false

        for info in infoList {
            // Check layer 0 (standard application windows)
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
            guard let pid = info[kCGWindowOwnerPID as String] as? Int32 else { continue }

            // Skip ourself
            if pid == ProcessInfo.processInfo.processIdentifier { continue }

            // Logic: The first valid window we find is usually the active one.
            // We want the one AFTER that.
            if !foundActive {
                foundActive = true
                continue
            }

            // If we are here, this is the "next" window
            let appElement = AXUIElementCreateApplication(pid)

            var focusedWindow: AnyObject?
            if AXUIElementCopyAttributeValue(
                appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success
            {
                return (focusedWindow as! AXUIElement)
            }
        }

        return nil
    }
}