import AppKit
import Foundation
import Whisper2Core

final class MenuBarController: NSObject {
    private(set) var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var eventMonitor: Any?
    private var isRecording = false
    private let previewVC = LivePreviewViewController()
    private let recorder = StubRecorder()

    private let settingsStore = SettingsStore()
    private let historyStore = HistoryStore()

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            if let img = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Whisper2") {
                img.isTemplate = true
                button.image = img
            } else {
                button.title = "W2"
            }
            button.action = #selector(statusItemClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        popover.contentViewController = previewVC
        popover.behavior = .transient
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showMenu()
        } else {
            toggleRecording()
        }
    }

    private func showMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: isRecording ? "Stop" : "Start", action: #selector(menuToggleRecording), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "History", action: #selector(openHistory), keyEquivalent: "h"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
        statusItem.button?.performClick(nil) // show the menu
        statusItem.menu = nil
    }

    @objc private func menuToggleRecording() { toggleRecording() }

    private func toggleRecording() {
        guard let button = statusItem.button else { return }
        if isRecording {
            isRecording = false
            recorder.stop()
            popover.performClose(nil)
            // Save a fake record for now to exercise storage
            let text = previewVC.currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                let cleaned = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                let record = TranscriptionRecord(rawText: text, cleanedText: cleaned, audioFilePath: nil)
                try? historyStore.append(record)
                previewVC.reset()
            }
        } else {
            isRecording = true
            recorder.start { [weak self] preview in
                self?.previewVC.update(text: preview)
            }
            if !popover.isShown {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
            }
        }
    }

    @objc private func openSettings() {
        SettingsWindowController(settingsStore: settingsStore).show()
    }

    @objc private func openHistory() {
        HistoryWindowController(historyStore: historyStore).show()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

// Stub recorder to simulate live preview output.
final class StubRecorder {
    private var timer: Timer?
    private var words = [
        "hello", "world", "swift", "menu", "bar", "app",
        "dictation", "transcribe", "preview", "testing", "skeleton"
    ]
    private var current = ""

    func start(update: @escaping (String) -> Void) {
        current.removeAll(keepingCapacity: true)
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if let w = self.words.randomElement() {
                self.current += (self.current.isEmpty ? "" : " ") + w
                update(self.current)
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
