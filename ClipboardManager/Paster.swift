import Foundation
import AppKit
import Carbon

enum Paster {
    static func pasteToFrontmostApp() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            let src = CGEventSource(stateID: .combinedSessionState)
            let vKey: CGKeyCode = CGKeyCode(kVK_ANSI_V)

            let down = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: true)
            down?.flags = .maskCommand
            let up = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: false)
            up?.flags = .maskCommand

            let tap = CGEventTapLocation.cghidEventTap
            down?.post(tap: tap)
            up?.post(tap: tap)
        }
    }
}

enum PermissionHelper {
    static func requestAccessibilityIfNeeded() {
        let opts: [String: Any] = [
            "AXTrustedCheckOptionPrompt" as String: true
        ]
        _ = AXIsProcessTrustedWithOptions(opts as CFDictionary)
    }

    static var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }
}
