import AppKit
import Foundation
import Whisper2Core

@main
final class AppMain: NSObject, NSApplicationDelegate {
    private var menuBar: MenuBarController!

    static func main() {
        let app = NSApplication.shared
        let delegate = AppMain()
        app.delegate = delegate
        buildMainMenu()
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        menuBar = MenuBarController()
        menuBar.setup()
    }

    private static func buildMainMenu() {
        // Provide a minimal menu with Edit items so Cmd+C/V work in accessory mode
        let mainMenu = NSMenu()
        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        NSApp.mainMenu = mainMenu
    }
}
