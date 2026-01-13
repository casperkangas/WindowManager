🖥️ WindowManager for macOS (v0.1)

A lightweight, fast, and of course open-source window manager built purely in Swift. No bloat. No App Store fees. Just productivity.

Welcome to WindowManager, a native macOS utility designed to keep your workspace organized with zero friction. Built for developers and power users who want keyboard-centric control over their windows without the complexity of heavy tiling window managers.


🚀 Features

⚡️ Lightning Fast: Built with native Swift and Apple's Accessibility API. Zero lag.

🔒 Privacy First: Runs locally. No internet connection required. No data collection.

🛠️ Dual Snap: Unique Feature! Automatically snap the window underneath your active window to the opposite side (toggle in Settings).

🖥️ Multi-Monitor Support: Throw windows instantly to your other displays.

🎨 Clean UI: Lives quietly in your menu bar. Includes a built-in interactive guide.

⌨️ Shortcuts / Hotkeys


Master your layout with these simple combinations:

Maximize

Cmd + Opt + L


Snap Left (50%)

Cmd + Opt + ←


Snap Right (50%)

Cmd + Opt + →


Reset (Center 1/3)

Cmd + Opt + R


Move to Next Screen

Ctrl + Opt + Cmd + →


Tip: You can view these anytime by clicking the WM icon in the menu bar and selecting "Show Guide".


📥 Installation

Option 1: The Easy Way (User)

Go to the Releases page.

Download WindowManager.zip.

Unzip and drag WindowManager.app to your Applications folder.

Double-click to run.

Permissions: You will be prompted to grant Accessibility permissions. This is required for the app to move windows.


Option 2: The Developer Way (Build from Source)

Want to tweak the code?

Clone this repo.

Open in VS Code or Terminal.

Run the build script:

./build.sh

To create a distributable .app bundle:

./package.sh


⚠️ Troubleshooting Permissions

If the app is running but hotkeys aren't working, macOS likely has "stale" permissions (common when updating non-App Store apps).

The Fix:

Go to System Settings > Privacy & Security > Accessibility.

Find WindowManager in the list.

DO NOT just toggle the switch. Click the Minus (-) button to delete it completely.

Restart the app.

When prompted, grant permission again.


👨‍💻 Tech Stack

Language: Swift 6

Frameworks: Cocoa, ApplicationServices, Carbon

Architecture: Universal Binary (Apple Silicon & Intel)


©️ Credits

Created by casperkangas (2026).

Open Source / MIT License (Feel free to fork and improve!)
