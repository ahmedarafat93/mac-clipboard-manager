import Foundation
import Combine

enum ModifierSide: String, CaseIterable, Identifiable {
    case right, left, either
    var id: String { rawValue }
    var label: String {
        switch self {
        case .right: return "Right"
        case .left: return "Left"
        case .either: return "Either"
        }
    }
}

final class AppSettings: ObservableObject {
    @Published var doubleTapEnabled: Bool {
        didSet { store.set(doubleTapEnabled, forKey: Keys.doubleTapEnabled) }
    }
    @Published var doubleTapSide: ModifierSide {
        didSet { store.set(doubleTapSide.rawValue, forKey: Keys.doubleTapSide) }
    }
    @Published var doubleTapWindowMs: Double {
        didSet { store.set(doubleTapWindowMs, forKey: Keys.doubleTapWindowMs) }
    }
    @Published var hotkeyEnabled: Bool {
        didSet { store.set(hotkeyEnabled, forKey: Keys.hotkeyEnabled) }
    }

    private let store: UserDefaults
    private enum Keys {
        static let doubleTapEnabled = "doubleTapEnabled"
        static let doubleTapSide = "doubleTapSide"
        static let doubleTapWindowMs = "doubleTapWindowMs"
        static let hotkeyEnabled = "hotkeyEnabled"
    }

    init(store: UserDefaults = .standard) {
        self.store = store
        store.register(defaults: [
            Keys.doubleTapEnabled: true,
            Keys.doubleTapSide: ModifierSide.right.rawValue,
            Keys.doubleTapWindowMs: 300.0,
            Keys.hotkeyEnabled: true
        ])
        self.doubleTapEnabled = store.bool(forKey: Keys.doubleTapEnabled)
        self.doubleTapSide = ModifierSide(rawValue: store.string(forKey: Keys.doubleTapSide) ?? "") ?? .right
        self.doubleTapWindowMs = store.double(forKey: Keys.doubleTapWindowMs)
        self.hotkeyEnabled = store.bool(forKey: Keys.hotkeyEnabled)
    }
}
