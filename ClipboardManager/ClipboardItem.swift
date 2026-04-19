import Foundation
import AppKit

struct ClipboardItem: Identifiable, Equatable, Codable {
    enum Kind: String, Codable { case text, image }

    let id: UUID
    let kind: Kind
    let text: String?
    let imageData: Data?
    /// Present for images captured from a file (e.g. screenshot filename without extension).
    /// `nil` for plain clipboard images.
    let sourceName: String?
    let createdAt: Date

    static func text(_ value: String) -> ClipboardItem {
        ClipboardItem(id: UUID(), kind: .text, text: value, imageData: nil, sourceName: nil, createdAt: Date())
    }

    static func image(_ data: Data, source: String? = nil) -> ClipboardItem {
        ClipboardItem(id: UUID(), kind: .image, text: nil, imageData: data, sourceName: source, createdAt: Date())
    }

    var isScreenshot: Bool { kind == .image && sourceName != nil }

    var preview: String {
        switch kind {
        case .text:
            let trimmed = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "(empty)" : trimmed
        case .image:
            if sourceName != nil {
                return "Screenshot at \(Self.screenshotTimeFormatter.string(from: createdAt))"
            }
            return "Image"
        }
    }

    private static let screenshotTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .medium
        return f
    }()

    var nsImage: NSImage? {
        guard kind == .image, let data = imageData else { return nil }
        return NSImage(data: data)
    }

    func matches(pasteboard: NSPasteboard) -> Bool {
        switch kind {
        case .text:
            return pasteboard.string(forType: .string) == text
        case .image:
            guard let incoming = pasteboard.data(forType: .tiff) ?? pasteboard.data(forType: .png) else {
                return false
            }
            return incoming == imageData
        }
    }
}
