import SwiftUI
import AppKit
import Combine

@main
struct ClipboardManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appDelegate.clipboardStore)
                .environmentObject(appDelegate.settings)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let clipboardStore = ClipboardStore()
    let settings = AppSettings()
    private(set) var panelController: ClipboardPanelController!
    private var hotkeyManager: HotkeyManager!
    private var doubleTapDetector: DoubleTapDetector!
    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        clipboardStore.startMonitoring()
        panelController = ClipboardPanelController(store: clipboardStore)
        setupStatusItem()

        hotkeyManager = HotkeyManager()
        hotkeyManager.onShowHistory = { [weak self] in self?.showPanelAtCursor() }
        hotkeyManager.onPasteIndex = { [weak self] index in self?.pasteItem(at: index) }
        hotkeyManager.start()

        doubleTapDetector = DoubleTapDetector()
        doubleTapDetector.onDoubleTap = { [weak self] in self?.showPanelAtCursor() }

        applySettings()
        observeSettings()

        PermissionHelper.requestAccessibilityIfNeeded()
    }

    private func applySettings() {
        hotkeyManager.setMainHotkeyEnabled(settings.hotkeyEnabled)

        doubleTapDetector.side = settings.doubleTapSide
        doubleTapDetector.windowSeconds = settings.doubleTapWindowMs / 1000.0
        if settings.doubleTapEnabled {
            if !doubleTapDetector.isRunning { doubleTapDetector.start() }
        } else {
            if doubleTapDetector.isRunning { doubleTapDetector.stop() }
        }
    }

    private func observeSettings() {
        settings.$doubleTapEnabled.dropFirst()
            .sink { [weak self] _ in self?.applySettings() }
            .store(in: &cancellables)
        settings.$doubleTapSide.dropFirst()
            .sink { [weak self] _ in self?.applySettings() }
            .store(in: &cancellables)
        settings.$doubleTapWindowMs.dropFirst()
            .sink { [weak self] _ in self?.applySettings() }
            .store(in: &cancellables)
        settings.$hotkeyEnabled.dropFirst()
            .sink { [weak self] _ in self?.applySettings() }
            .store(in: &cancellables)
    }

    private func showPanelAtCursor() {
        DispatchQueue.main.async { [weak self] in
            self?.panelController.toggle(near: NSEvent.mouseLocation)
        }
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard",
                                   accessibilityDescription: "Clipboard Manager")
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseDown, .rightMouseDown])
        }
        statusItem = item
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseDown {
            showStatusMenu()
        } else {
            panelController.toggle(near: statusItemAnchor())
        }
    }

    private func statusItemAnchor() -> NSPoint? {
        guard let button = statusItem?.button,
              let window = button.window else { return nil }
        let frame = window.frame
        return NSPoint(x: frame.maxX, y: frame.minY)
    }

    private func showStatusMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Open clipboard history",
                     action: #selector(openFromMenu),
                     keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…",
                     action: #selector(openSettings),
                     keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit ClipboardManager",
                     action: #selector(NSApplication.terminate(_:)),
                     keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func openFromMenu() {
        panelController.show(near: statusItemAnchor())
    }

    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        if #available(macOS 14, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }

    private func pasteItem(at index: Int) {
        let items = clipboardStore.items
        guard index < items.count else { return }
        clipboardStore.copy(items[index])
        Paster.pasteToFrontmostApp()
    }
}
