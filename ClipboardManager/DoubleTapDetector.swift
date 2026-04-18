import Foundation
import AppKit

final class DoubleTapDetector {
    var onDoubleTap: (() -> Void)?
    var side: ModifierSide = .right {
        didSet { reset() }
    }
    var windowSeconds: TimeInterval = 0.3

    private var monitor: Any?
    private var lastReleaseTime: TimeInterval = 0
    private var wasDown = false
    private var didCombo = false

    // Device-dependent modifier flag bits (IOKit/hidsystem/IOLLEvent.h)
    private let leftCmdMask: UInt = 0x08
    private let rightCmdMask: UInt = 0x10

    // Virtual keycodes
    private let leftCmdKeyCode: UInt16 = 55   // kVK_Command
    private let rightCmdKeyCode: UInt16 = 54  // kVK_RightCommand

    var isRunning: Bool { monitor != nil }

    func start() {
        guard monitor == nil else { return }
        reset()
        monitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.flagsChanged, .keyDown]
        ) { [weak self] event in
            self?.handle(event)
        }
    }

    func stop() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
        reset()
    }

    private func reset() {
        lastReleaseTime = 0
        wasDown = false
        didCombo = false
    }

    private func handle(_ event: NSEvent) {
        if event.type == .keyDown {
            if wasDown { didCombo = true }
            lastReleaseTime = 0
            return
        }

        let keyCode = event.keyCode
        let matchesTargetKey: Bool
        switch side {
        case .right: matchesTargetKey = (keyCode == rightCmdKeyCode)
        case .left: matchesTargetKey = (keyCode == leftCmdKeyCode)
        case .either: matchesTargetKey = (keyCode == rightCmdKeyCode || keyCode == leftCmdKeyCode)
        }

        if !matchesTargetKey {
            if wasDown { didCombo = true }
            return
        }

        let targetMask: UInt
        switch side {
        case .right: targetMask = rightCmdMask
        case .left: targetMask = leftCmdMask
        case .either: targetMask = rightCmdMask | leftCmdMask
        }
        let isDownNow = (event.modifierFlags.rawValue & targetMask) != 0

        if isDownNow && !wasDown {
            let now = event.timestamp
            if lastReleaseTime > 0, (now - lastReleaseTime) < windowSeconds {
                DispatchQueue.main.async { [weak self] in self?.onDoubleTap?() }
                lastReleaseTime = 0
            }
            wasDown = true
            didCombo = false
        } else if !isDownNow && wasDown {
            lastReleaseTime = didCombo ? 0 : event.timestamp
            wasDown = false
        }
    }

    deinit { stop() }
}
