import Foundation
import AppKit

/// Watches the user's Desktop (and any configured screenshot location) for
/// new screenshot files saved by macOS. When a new PNG matching the standard
/// screenshot naming pattern appears, its bytes are delivered via
/// `onNewScreenshot`.
final class ScreenshotWatcher {
    /// Called with the screenshot's PNG bytes and its source label
    /// (typically the filename without extension).
    var onNewScreenshot: ((Data, String) -> Void)?

    private var sources: [DispatchSourceFileSystemObject] = []
    private var knownByFolder: [URL: Set<String>] = [:]
    private let fm = FileManager.default

    var isRunning: Bool { !sources.isEmpty }

    func start() {
        guard sources.isEmpty else { return }
        let folders = watchFolders()
        NSLog("ScreenshotWatcher: watching \(folders.count) folder(s): \(folders.map { $0.path })")
        for folder in folders {
            watch(folder)
        }
    }

    func stop() {
        sources.forEach { $0.cancel() }
        sources.removeAll()
        knownByFolder.removeAll()
    }

    private func watchFolders() -> [URL] {
        var folders: [URL] = []
        var seenPaths: Set<String> = []

        if let desktop = fm.urls(for: .desktopDirectory, in: .userDomainMask).first {
            folders.append(desktop)
            seenPaths.insert(desktop.path)
        }

        if let customLoc = screenshotCustomLocation(), !seenPaths.contains(customLoc.path) {
            folders.append(customLoc)
            seenPaths.insert(customLoc.path)
        }

        return folders
    }

    private func screenshotCustomLocation() -> URL? {
        guard let raw = UserDefaults(suiteName: "com.apple.screencapture")?
                .string(forKey: "location"),
              !raw.isEmpty else {
            return nil
        }
        let expanded = (raw as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded, isDirectory: true)
        return fm.fileExists(atPath: url.path) ? url : nil
    }

    private func watch(_ folder: URL) {
        let fd = open(folder.path, O_EVTONLY)
        guard fd >= 0 else {
            NSLog("ScreenshotWatcher: could not open \(folder.path) (errno=\(errno)) — macOS may be denying Desktop access. Check System Settings → Privacy & Security → Files and Folders.")
            return
        }

        let queue = DispatchQueue.global(qos: .utility)
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .rename],
            queue: queue
        )

        knownByFolder[folder] = currentScreenshots(in: folder)

        source.setEventHandler { [weak self] in
            self?.handleFolderChange(folder)
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()
        sources.append(source)
    }

    private func currentScreenshots(in folder: URL) -> Set<String> {
        guard let urls = try? fm.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil
        ) else {
            NSLog("ScreenshotWatcher: could not list \(folder.path)")
            return []
        }
        return Set(urls.filter(Self.looksLikeScreenshot).map { $0.lastPathComponent })
    }

    private static func looksLikeScreenshot(_ url: URL) -> Bool {
        guard url.pathExtension.lowercased() == "png" else { return false }
        let name = url.lastPathComponent
        return name.hasPrefix("Screenshot") || name.hasPrefix("Screen Shot")
    }

    private func handleFolderChange(_ folder: URL) {
        let current = currentScreenshots(in: folder)
        let previous = knownByFolder[folder] ?? []
        let added = current.subtracting(previous)
        knownByFolder[folder] = current

        guard !added.isEmpty else { return }
        NSLog("ScreenshotWatcher: detected \(added.count) new screenshot(s) in \(folder.lastPathComponent)")

        for fileName in added {
            let url = folder.appendingPathComponent(fileName)
            readAndDeliver(url)
        }
    }

    private func readAndDeliver(_ url: URL) {
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.3) { [weak self] in
            do {
                let data = try Data(contentsOf: url)
                let source = url.deletingPathExtension().lastPathComponent
                NSLog("ScreenshotWatcher: captured \(url.lastPathComponent) (\(data.count) bytes)")
                DispatchQueue.main.async { self?.onNewScreenshot?(data, source) }
            } catch {
                NSLog("ScreenshotWatcher: could not read \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
    }

    deinit { stop() }
}
