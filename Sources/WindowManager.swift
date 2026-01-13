import ApplicationServices
import Cocoa

@main
struct WindMan {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {

    var statusItem: NSStatusItem!
    var infoWindow: NSWindow!
    var runLoopSource: CFRunLoopSource?

    let kDualSnapKey = "DualSnapEnabled"

    func applicationDidFinishLaunching(_ notification: Notification) {
        checkPermissions()

        let dualSnapState = UserDefaults.standard.bool(forKey: kDualSnapKey)
        WindowActions.enableDualSnap = dualSnapState

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "WM"
        }

        setupMenu()
        setupHotkeys()
        createInfoWindow()

        // --- RESILIENCE LOGIC ---
        // Listen for when the computer wakes up from sleep
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        NSApp.setActivationPolicy(.accessory)
        print("WindMan v1.0 active and sleep-aware.")
    }

    @objc func handleWake() {
        print("🌅 Mac woke up. Refreshing hotkey tap...")
        // Wait 1 second for the system to settle before re-enabling
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.setupHotkeys()
        }
    }

    func setupHotkeys() {
        // Remove old source if it exists to prevent duplicates
        if let oldSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), oldSource, .commonModes)
        }

        guard let eventTap = KeyHandler.setupEventTap() else {
            print("❌ Failed to create event tap.")
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    func checkPermissions() {
        let options = ["AXTrustedCheckOptionPrompt" as CFString: true]
        if !AXIsProcessTrustedWithOptions(options as CFDictionary) {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permissions Needed"
            alert.informativeText =
                "To move windows, WindMan needs Accessibility permissions. Please check System Settings."
            alert.runModal()
        }
    }

    func setupMenu() {
        let menu = NSMenu()
        let settingsMenu = NSMenu()
        let dualSnapItem = NSMenuItem(
            title: "Snap Both Windows (Dual Snap)", action: #selector(toggleDualSnap(_:)),
            keyEquivalent: "")
        dualSnapItem.state = WindowActions.enableDualSnap ? .on : .off
        settingsMenu.addItem(dualSnapItem)

        let settingsItem = NSMenuItem(title: "Settings", action: nil, keyEquivalent: "")
        settingsItem.submenu = settingsMenu

        menu.addItem(settingsItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            NSMenuItem(title: "Show Guide", action: #selector(showGuide), keyEquivalent: "g"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "© casperkangas 2026", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        // New Restart Option
        let restartItem = NSMenuItem(
            title: "Restart", action: #selector(restartApp), keyEquivalent: "r")
        restartItem.keyEquivalentModifierMask = .command  // Cmd + R (only works when menu is open)
        menu.addItem(restartItem)

        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc func toggleDualSnap(_ sender: NSMenuItem) {
        WindowActions.enableDualSnap.toggle()
        sender.state = WindowActions.enableDualSnap ? .on : .off
        UserDefaults.standard.set(WindowActions.enableDualSnap, forKey: kDualSnapKey)
    }

    @objc func showGuide() {
        infoWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // --- APP LIFECYCLE ---

    @objc func restartApp() {
        // Determine valid path to relaunch
        let url = Bundle.main.bundleURL
        let path: String

        if url.pathExtension == "app" {
            // Running as a packaged .app bundle
            path = url.path
        } else {
            // Running as raw debug binary (bundleURL points to the folder, so use executablePath)
            path = Bundle.main.executablePath ?? url.path
        }

        // -n forces a new instance, ensuring it re-opens correctly
        let script = "sleep 0.5; open -n '\(path)'"

        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", script]
        task.launch()

        NSApp.terminate(nil)
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    func createInfoWindow() {
        let windowSize = NSRect(x: 0, y: 0, width: 350, height: 320)
        infoWindow = NSWindow(
            contentRect: windowSize, styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false)
        infoWindow.title = "WindMan Guide"
        infoWindow.center()
        infoWindow.isReleasedWhenClosed = false

        let scrollView = NSScrollView(frame: infoWindow.contentView!.bounds)
        scrollView.hasVerticalScroller = true
        scrollView.autoresizingMask = [.width, .height]

        let content = NSTextView(frame: scrollView.bounds)
        content.string = """
            Active Hotkeys:

            Cmd + Opt + L : Maximize
            Cmd + Opt + R : Reset (1/3)
            Cmd + Opt + ← / → : Snap Half
            Ctrl + Opt + Cmd + → : Next Display
            """
        content.isEditable = false
        content.font = NSFont.systemFont(ofSize: 14)
        content.textContainerInset = NSSize(width: 10, height: 10)

        scrollView.documentView = content
        infoWindow.contentView?.addSubview(scrollView)
    }
}