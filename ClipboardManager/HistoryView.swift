import SwiftUI
import AppKit

struct HistoryView: View {
    @EnvironmentObject var store: ClipboardStore
    @EnvironmentObject var panelState: PanelState

    let onSelect: (ClipboardItem) -> Void
    let onDelete: (ClipboardItem) -> Void

    @FocusState private var searchFocused: Bool

    private var filtered: [ClipboardItem] {
        if panelState.query.isEmpty { return store.items }
        return store.items.filter {
            ($0.text ?? "").localizedCaseInsensitiveContains(panelState.query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 6)

            if filtered.isEmpty {
                emptyState
            } else {
                list
            }

            footer
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(.ultraThinMaterial)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 0.5)
                }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
        }
        .onChange(of: panelState.showToken) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                searchFocused = true
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                searchFocused = true
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 13, weight: .medium))
            TextField("Search clipboard", text: $panelState.query)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .focused($searchFocused)
                .onChange(of: panelState.query) { _ in
                    panelState.selectedIndex = 0
                }
            if !panelState.query.isEmpty {
                Button {
                    panelState.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 34, weight: .light))
                .foregroundColor(.secondary.opacity(0.6))
            Text(panelState.query.isEmpty ? "No clipboard history yet" : "No matches")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            if panelState.query.isEmpty {
                Text("Copy something to get started")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }

    private var indexedItems: [IndexedClip] {
        filtered.enumerated().map { IndexedClip(index: $0.offset, item: $0.element) }
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(indexedItems) { entry in
                        HistoryRow(
                            item: entry.item,
                            shortcutIndex: entry.index < 9 ? entry.index + 1 : nil,
                            isSelected: panelState.selectedIndex == entry.index,
                            onClick: { onSelect(entry.item) },
                            onDelete: { onDelete(entry.item) }
                        )
                        .id(entry.item.id)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
            }
            .onChange(of: panelState.selectedIndex) { newIndex in
                guard newIndex >= 0, newIndex < filtered.count else { return }
                let targetId = filtered[newIndex].id
                withAnimation(.easeInOut(duration: 0.1)) {
                    proxy.scrollTo(targetId, anchor: .center)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            hintKey("↑↓", label: "select")
            hintKey("↵", label: "paste")
            hintKey("esc", label: "close")
            Spacer()
            Button {
                store.clear()
            } label: {
                Text("Clear")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private func hintKey(_ key: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(.primary.opacity(0.7))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.primary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }
}

struct IndexedClip: Identifiable {
    let index: Int
    let item: ClipboardItem
    var id: UUID { item.id }
}

struct HistoryRow: View {
    let item: ClipboardItem
    let shortcutIndex: Int?
    let isSelected: Bool
    let onClick: () -> Void
    let onDelete: () -> Void

    @State private var hovered = false

    var body: some View {
        HStack(spacing: 11) {
            iconView
            contentView
            Spacer(minLength: 8)
            if let n = shortcutIndex {
                Text("⌃⌘\(n)")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        isSelected
                        ? Color.white.opacity(0.22)
                        : Color.primary.opacity(0.08)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
            if hovered {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .foregroundColor(isSelected ? .white : .primary)
        .contentShape(Rectangle())
        .onHover { hovered = $0 }
        .onTapGesture { onClick() }
    }

    @ViewBuilder
    private var background: some View {
        if isSelected {
            Color.accentColor
        } else if hovered {
            Color.primary.opacity(0.06)
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if item.kind == .image, let img = item.nsImage {
            Image(nsImage: img)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 30, height: 30)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                }
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(
                        isSelected
                        ? Color.white.opacity(0.2)
                        : Color.primary.opacity(0.07)
                    )
                Image(systemName: item.kind == .text ? "doc.text" : "photo")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isSelected ? .white : .secondary)
            }
            .frame(width: 30, height: 30)
        }
    }

    private var contentView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.preview)
                .lineLimit(2)
                .font(.system(size: 13))
                .truncationMode(.tail)
            Text(relativeTime(item.createdAt))
                .font(.system(size: 10))
                .foregroundColor(isSelected ? .white.opacity(0.75) : .secondary.opacity(0.85))
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct SettingsView: View {
    @EnvironmentObject var store: ClipboardStore
    @EnvironmentObject var settings: AppSettings

    private var noTriggerEnabled: Bool {
        !settings.doubleTapEnabled && !settings.hotkeyEnabled
    }

    var body: some View {
        Form {
            Section("Triggers") {
                Toggle("Double-tap Command key", isOn: $settings.doubleTapEnabled)
                if settings.doubleTapEnabled {
                    Picker("Side", selection: $settings.doubleTapSide) {
                        ForEach(ModifierSide.allCases) { side in
                            Text(side.label).tag(side)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack(spacing: 10) {
                        Text("Speed")
                            .frame(width: 50, alignment: .leading)
                        Slider(value: $settings.doubleTapWindowMs, in: 200...500, step: 10)
                        Text("\(Int(settings.doubleTapWindowMs))ms")
                            .font(.system(.caption, design: .monospaced))
                            .frame(width: 50, alignment: .trailing)
                            .foregroundColor(.secondary)
                    }
                    Text("Tap \(settings.doubleTapSide.label.lowercased())-⌘ twice within \(Int(settings.doubleTapWindowMs))ms to open the panel.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Toggle("⌃⌘V hotkey", isOn: $settings.hotkeyEnabled)

                if noTriggerEnabled {
                    Label("No triggers enabled — you can still open the panel from the menu bar icon.",
                          systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            Section("Quick paste") {
                Text("⌃⌘1 through ⌃⌘9 paste the Nth most recent item instantly (always on).")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }

            Section("Permissions") {
                if PermissionHelper.isAccessibilityTrusted {
                    Label("Accessibility access granted", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Label("Accessibility access required", systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Button("Open System Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            }

            Section("History") {
                Text("\(store.items.count) items stored (max 50)")
                    .foregroundColor(.secondary)
                Button("Clear history") { store.clear() }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 560)
    }
}
