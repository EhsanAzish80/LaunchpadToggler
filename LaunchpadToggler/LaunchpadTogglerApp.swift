//
//  LaunchpadTogglerApp.swift
//  LaunchpadToggler
//
//  Created by Ehsan Azish on 21.07.2025.
//

import SwiftUI
import AppKit

@main
struct LaunchpadTogglerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {} // no visible UI
    }
}




class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ note: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let image = NSImage(named: "StatusIconTemplate") {
            image.isTemplate = true // auto-adapts to dark/light mode
            image.size = NSSize(width: 24, height: 24) // explicitly set size
            statusItem.button?.image = image
        }
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "MacOS 18 Launchpad", action: #selector(revertOld), keyEquivalent: "o"))
        menu.addItem(NSMenuItem(title: "MacOS 26 Launchpad",  action: #selector(restoreNew), keyEquivalent: "n"))
        menu.addItem(NSMenuItem(title: "About", action: #selector(showAbout), keyEquivalent: "a"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    // MARK: - Menu Actions
    @objc private func revertOld() {
        runPrivilegedScript("""
            /bin/mkdir -p /Library/Preferences/FeatureFlags/Domain && \
            /usr/bin/defaults write /Library/Preferences/FeatureFlags/Domain/SpotlightUI.plist SpotlightPlus -dict Enabled -bool false
        """)
    }

    @objc private func restoreNew() {
        runPrivilegedScript("""
            /bin/rm /Library/Preferences/FeatureFlags/Domain/SpotlightUI.plist
        """)
    }
    
    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "About Launchpad Toggler"
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        let dateString = formatter.string(from: Date())
        alert.informativeText = "Created by Ehsan Azish\n\(dateString)"
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // MARK: - Helpers
    private func runPrivilegedScript(_ shell: String) {
        print("Attempting to run script: \(shell)")

        let appleScriptCommand = """
        do shell script "\(shell.replacingOccurrences(of: "\"", with: "\\\""))" with prompt "Launchpad Toggler needs your admin password to apply changes." with administrator privileges
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", appleScriptCommand]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                print("Script completed")
                showRestartPrompt()
            } else {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    print("osascript error output: \(output)")
                }
                alert(title: "Command Failed", msg: "Administrator password incorrect or command blocked.")
            }
        } catch {
            alert(title: "Execution Error", msg: error.localizedDescription)
        }
    }

    private func showRestartPrompt() {
        let alert = NSAlert()
        alert.messageText = "Restart Required"
        alert.informativeText = "The changes will take effect after a system restart. Would you like to restart now?"
        alert.addButton(withTitle: "Restart Now")
        alert.addButton(withTitle: "Restart Later")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            requestSystemRestart()
        }
    }
    
    private func requestSystemRestart() {
        let script = """
        do shell script "/sbin/shutdown -r now" with prompt "Launchpad Toggler needs to restart your Mac to apply changes." with administrator privileges
        """
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
        }

        if let error = error {
            alert(title: "Command Failed", msg: error[NSAppleScript.errorMessage] as? String ?? "Unknown error")
        }
    }

    private func alert(title: String, msg: String) {
        let a = NSAlert()
        a.messageText = title
        a.informativeText = msg
        a.addButton(withTitle: "OK")
        a.runModal()
    }

    @objc private func quitApp() { NSApp.terminate(nil) }
}
