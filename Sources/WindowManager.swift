import ApplicationServices
import Cocoa
import Foundation

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

    // --- UPDATE CONFIGURATION ---
    let repoOwner = "casperkangas"
    let repoName = "WindMan"

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

        // Listen for wake to refresh hotkeys
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        NSApp.setActivationPolicy(.accessory)
        print("WindMan active.")

        // Optional: Check for updates silently on launch
        checkForUpdates(isUserInitiated: false)
    }

    @objc func handleWake() {
        print("🌅 Mac woke up. Temporarily disabling hotkeys to unblock input...")

        // 1. IMPROVEMENT: Immediately cut the connection so native keys (Cmd+Space) work instantly.
        // If we don't do this, the system waits for WindMan to "wake up" before processing keys.
        if let eventTap = KeyHandler.eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }

        // 2. Wait 1 second for the system to settle, then rebuild the connection cleanly.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.setupHotkeys()
        }
    }

    func setupHotkeys() {
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

        // Settings Submenu
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
            NSMenuItem(
                title: "Check for Updates...", action: #selector(checkForUpdatesMenuAction),
                keyEquivalent: ""))
        menu.addItem(
            NSMenuItem(title: "Show Guide", action: #selector(showGuide), keyEquivalent: "g"))
        menu.addItem(NSMenuItem.separator())

        let creditItem = NSMenuItem(title: "© casperkangas 2026", action: nil, keyEquivalent: "")
        creditItem.isEnabled = false
        menu.addItem(creditItem)

        menu.addItem(NSMenuItem.separator())

        let restartItem = NSMenuItem(
            title: "Restart", action: #selector(restartApp), keyEquivalent: "r")
        restartItem.keyEquivalentModifierMask = .command
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

    @objc func restartApp() {
        let url = Bundle.main.bundleURL
        let path: String
        if url.pathExtension == "app" {
            path = url.path
        } else {
            path = Bundle.main.executablePath ?? url.path
        }
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

    // --- UPDATE LOGIC ---

    @objc func checkForUpdatesMenuAction() {
        checkForUpdates(isUserInitiated: true)
    }

    func checkForUpdates(isUserInitiated: Bool) {
        // 1. Get Current Version from Info.plist
        let currentVer =
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"

        // 2. Prepare GitHub API URL
        let urlString = "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest"
        guard let url = URL(string: urlString) else { return }

        print("Checking for updates... Current: \(currentVer)")

        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                if isUserInitiated {
                    DispatchQueue.main.async {
                        let alert = NSAlert()
                        alert.messageText = "Check Failed"
                        alert.informativeText = "Could not connect to GitHub."
                        alert.runModal()
                    }
                }
                return
            }

            do {
                // 3. Parse JSON
                let release = try JSONDecoder().decode(GitHubRelease.self, from: data)

                // 4. Compare Versions
                // Remove 'v' prefix if present (e.g. v1.0.1 -> 1.0.1)
                let cleanTag = release.tag_name.replacingOccurrences(of: "v", with: "")

                // Simple string comparison (works for 1.0.0 vs 1.0.1, but ideally use a semantic version comparator)
                if cleanTag.compare(currentVer, options: .numeric) == .orderedDescending {

                    // Update Available!
                    DispatchQueue.main.async {
                        let alert = NSAlert()
                        alert.messageText = "New Version Available!"
                        alert.informativeText =
                            "WindMan \(release.tag_name) is out.\n\nCurrent: \(currentVer)\nNew: \(cleanTag)"
                        alert.addButton(withTitle: "Download")
                        alert.addButton(withTitle: "Cancel")

                        let response = alert.runModal()
                        if response == .alertFirstButtonReturn {
                            if let link = URL(string: release.html_url) {
                                NSWorkspace.shared.open(link)
                            }
                        }
                    }
                } else {
                    // No Update
                    if isUserInitiated {
                        DispatchQueue.main.async {
                            let alert = NSAlert()
                            alert.messageText = "You're up to date!"
                            alert.informativeText = "WindMan \(currentVer) is the latest version."
                            alert.runModal()
                        }
                    }
                }
            } catch {
                print("JSON Error: \(error)")
            }
        }
        task.resume()
    }
}

// Data model for GitHub API response
struct GitHubRelease: Codable {
    let tag_name: String
    let html_url: String
}