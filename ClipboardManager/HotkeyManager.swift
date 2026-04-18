import Foundation
import AppKit
import Carbon

final class HotkeyManager {
    var onShowHistory: (() -> Void)?
    var onPasteIndex: ((Int) -> Void)?

    private var handler: EventHandlerRef?
    private var mainHotKey: EventHotKeyRef?
    private var digitHotKeys: [EventHotKeyRef] = []

    private let signature: OSType = 0x434C4250

    func start() {
        installHandler()
        registerDigitHotkeys()
    }

    func setMainHotkeyEnabled(_ enabled: Bool) {
        if enabled {
            guard mainHotKey == nil else { return }
            mainHotKey = register(id: 0,
                                  keyCode: UInt32(kVK_ANSI_V),
                                  modifiers: UInt32(cmdKey | controlKey))
        } else {
            if let ref = mainHotKey {
                UnregisterEventHotKey(ref)
                mainHotKey = nil
            }
        }
    }

    private func registerDigitHotkeys() {
        let digitKeys: [Int] = [
            kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5,
            kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9
        ]
        let modifiers = UInt32(cmdKey | controlKey)
        for (idx, key) in digitKeys.enumerated() {
            if let ref = register(id: UInt32(idx + 1),
                                  keyCode: UInt32(key),
                                  modifiers: modifiers) {
                digitHotKeys.append(ref)
            }
        }
    }

    private func installHandler() {
        guard handler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event = event, let userData = userData else { return noErr }
            var hkID = EventHotKeyID()
            let status = GetEventParameter(event,
                                           EventParamName(kEventParamDirectObject),
                                           EventParamType(typeEventHotKeyID),
                                           nil,
                                           MemoryLayout<EventHotKeyID>.size,
                                           nil,
                                           &hkID)
            if status == noErr {
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                manager.dispatch(id: hkID.id)
            }
            return noErr
        }, 1, &spec, selfPtr, &handler)
    }

    private func register(id: UInt32, keyCode: UInt32, modifiers: UInt32) -> EventHotKeyRef? {
        var ref: EventHotKeyRef?
        let hkID = EventHotKeyID(signature: signature, id: id)
        let status = RegisterEventHotKey(keyCode, modifiers, hkID,
                                         GetApplicationEventTarget(), 0, &ref)
        guard status == noErr else {
            NSLog("HotkeyManager: register id=\(id) failed (status \(status))")
            return nil
        }
        return ref
    }

    private func dispatch(id: UInt32) {
        if id == 0 {
            onShowHistory?()
        } else {
            onPasteIndex?(Int(id) - 1)
        }
    }

    deinit {
        if let ref = mainHotKey { UnregisterEventHotKey(ref) }
        digitHotKeys.forEach { UnregisterEventHotKey($0) }
        if let h = handler { RemoveEventHandler(h) }
    }
}
