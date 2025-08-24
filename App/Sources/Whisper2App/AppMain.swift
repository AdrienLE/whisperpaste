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
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        menuBar = MenuBarController()
        menuBar.setup()
    }
}
