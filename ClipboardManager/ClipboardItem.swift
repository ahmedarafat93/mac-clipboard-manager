import Foundation
import AppKit

struct ClipboardItem: Identifiable, Equatable, Codable {
    enum Kind: String, Codable { case text, image }

    let id: UUID
    let kind: Kind
    let text: String?
    let imageData: Data?
    let createdAt: Date

    static func text(_ value: String) -> ClipboardItem {
        ClipboardItem(id: UUID(), kind: .text, text: value, imageData: nil, createdAt: Date())
    }

    static func image(_ data: Data) -> ClipboardItem {
        ClipboardItem(id: UUID(), kind: .image, text: nil, imageData: data, createdAt: Date())
    }

    var preview: String {
        switch kind {
        case .text:
            let trimmed = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "(empty)" : trimmed
        case .image:
            return "Image"
        }
    }

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
