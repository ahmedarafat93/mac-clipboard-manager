import Foundation
import AppKit
import Combine

final class ClipboardStore: ObservableObject {
    @Published private(set) var items: [ClipboardItem] = []

    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int = 0
    private var timer: Timer?
    private let maxItems = 50
    private let storageURL: URL
    private var suppressNext = false

    init() {
        let fm = FileManager.default
        let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ClipboardManager", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        storageURL = dir.appendingPathComponent("history.json")
        load()
    }

    func startMonitoring() {
        lastChangeCount = pasteboard.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.checkPasteboard()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func checkPasteboard() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        if suppressNext {
            suppressNext = false
            return
        }

        if let str = pasteboard.string(forType: .string), !str.isEmpty {
            insert(.text(str))
            return
        }
        if let data = pasteboard.data(forType: .tiff) ?? pasteboard.data(forType: .png) {
            insert(.image(data))
        }
    }

    private func insert(_ item: ClipboardItem) {
        if let top = items.first, sameContent(top, item) {
            return
        }
        var next = items.filter { !sameContent($0, item) }
        next.insert(item, at: 0)
        if next.count > maxItems {
            next = Array(next.prefix(maxItems))
        }
        items = next
        save()
    }

    private func sameContent(_ a: ClipboardItem, _ b: ClipboardItem) -> Bool {
        a.kind == b.kind && a.text == b.text && a.imageData == b.imageData
    }

    func copy(_ item: ClipboardItem) {
        suppressNext = true
        pasteboard.clearContents()
        switch item.kind {
        case .text:
            if let t = item.text { pasteboard.setString(t, forType: .string) }
        case .image:
            if let data = item.imageData {
                pasteboard.setData(data, forType: .tiff)
            }
        }
        lastChangeCount = pasteboard.changeCount
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            var next = items
            next.remove(at: idx)
            next.insert(item, at: 0)
            items = next
            save()
        }
    }

    func delete(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    func clear() {
        items.removeAll()
        save()
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            NSLog("ClipboardStore save error: \(error)")
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([ClipboardItem].self, from: data) else {
            return
        }
        items = decoded
    }
}
