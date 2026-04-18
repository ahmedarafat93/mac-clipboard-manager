import AppKit
import SwiftUI
import Combine

final class PanelState: ObservableObject {
    @Published var selectedIndex: Int = 0
    @Published var query: String = ""
    @Published var showToken: UUID = UUID()
}

final class FloatingPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        level = .floating
        isMovableByWindowBackground = true
        isReleasedWhenClosed = false
        animationBehavior = .utilityWindow
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override var acceptsFirstResponder: Bool { true }
}

final class ClipboardPanelController {
    private let store: ClipboardStore
    let state = PanelState()
    private var panel: FloatingPanel?
    private var localKeyMonitor: Any?
    private var globalClickMonitor: Any?

    init(store: ClipboardStore) {
        self.store = store
    }

    var isVisible: Bool { panel?.isVisible == true }

    func toggle(near point: NSPoint?) {
        if isVisible { hide() } else { show(near: point) }
    }

    func show(near origin: NSPoint?) {
        let panel = ensurePanel()
        state.selectedIndex = 0
        state.query = ""
        state.showToken = UUID()
        position(panel, near: origin)
        panel.makeKeyAndOrderFront(nil)
        installMonitors()
    }

    func hide(pasteSelection: Bool = false) {
        let item = pasteSelection ? selectedItem() : nil
        panel?.orderOut(nil)
        removeMonitors()
        if let item = item {
            store.copy(item)
            Paster.pasteToFrontmostApp()
        }
    }

    private func selectedItem() -> ClipboardItem? {
        let list = filteredItems()
        guard state.selectedIndex >= 0, state.selectedIndex < list.count else { return nil }
        return list[state.selectedIndex]
    }

    private func filteredItems() -> [ClipboardItem] {
        if state.query.isEmpty { return store.items }
        return store.items.filter {
            ($0.text ?? "").localizedCaseInsensitiveContains(state.query)
        }
    }

    private func ensurePanel() -> FloatingPanel {
        if let p = panel { return p }
        let size = NSSize(width: 360, height: 440)
        let root = HistoryView(
            onSelect: { [weak self] item in
                guard let self = self else { return }
                self.panel?.orderOut(nil)
                self.removeMonitors()
                self.store.copy(item)
                Paster.pasteToFrontmostApp()
            },
            onDelete: { [weak self] item in self?.store.delete(item) }
        )
        .environmentObject(store)
        .environmentObject(state)

        let host = NSHostingView(rootView: root)
        host.frame = NSRect(origin: .zero, size: size)

        let p = FloatingPanel(contentRect: NSRect(origin: .zero, size: size))
        p.contentView = host
        panel = p
        return p
    }

    private func position(_ panel: NSPanel, near origin: NSPoint?) {
        let size = panel.frame.size
        let screen = NSScreen.screens.first(where: { $0.frame.contains(origin ?? .zero) })
            ?? NSScreen.main
            ?? NSScreen.screens.first!
        let visible = screen.visibleFrame

        let desired: NSPoint
        if let o = origin {
            desired = NSPoint(x: o.x - 20, y: o.y - size.height - 8)
        } else {
            desired = NSPoint(x: visible.midX - size.width / 2,
                              y: visible.midY - size.height / 2)
        }
        let clamped = NSPoint(
            x: min(max(desired.x, visible.minX + 8), visible.maxX - size.width - 8),
            y: min(max(desired.y, visible.minY + 8), visible.maxY - size.height - 8)
        )
        panel.setFrameOrigin(clamped)
    }

    private func installMonitors() {
        if localKeyMonitor == nil {
            localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                self?.handleLocalKey(event) ?? event
            }
        }
        if globalClickMonitor == nil {
            globalClickMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown]
            ) { [weak self] _ in
                self?.hide()
            }
        }
    }

    private func removeMonitors() {
        if let m = localKeyMonitor { NSEvent.removeMonitor(m); localKeyMonitor = nil }
        if let m = globalClickMonitor { NSEvent.removeMonitor(m); globalClickMonitor = nil }
    }

    private func handleLocalKey(_ event: NSEvent) -> NSEvent? {
        guard isVisible else { return event }
        let count = filteredItems().count
        switch event.keyCode {
        case 126:
            state.selectedIndex = max(0, state.selectedIndex - 1)
            return nil
        case 125:
            state.selectedIndex = min(max(0, count - 1), state.selectedIndex + 1)
            return nil
        case 36, 76:
            hide(pasteSelection: true)
            return nil
        case 53:
            hide()
            return nil
        default:
            return event
        }
    }
}
