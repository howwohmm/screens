import SwiftUI

struct MenuBarView: View {
    var appState: AppState
    var onToggleFrame: () -> Void
    var onShowSettings: () -> Void
    var onShowAbout: () -> Void
    var onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Brand
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("screens")
                        .font(.system(size: 13, weight: .thin))
                        .foregroundStyle(.primary)
                        .kerning(0.8)
                    Text("your monitor. a channel.")
                        .font(.system(size: 10, weight: .light))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider().padding(.horizontal, 8)

            // Status
            HStack(spacing: 8) {
                if appState.isFetching {
                    ProgressView().progressViewStyle(.circular).scaleEffect(0.55)
                    Text("syncing…")
                        .font(.system(size: 11, weight: .light))
                        .foregroundStyle(.secondary)
                } else if appState.orderedBlocks.isEmpty {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text("no channels added")
                        .font(.system(size: 11, weight: .light))
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "photo.stack")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text("\(appState.orderedBlocks.count) blocks · \(appState.channelSlugs.count) channel\(appState.channelSlugs.count == 1 ? "" : "s")")
                        .font(.system(size: 11, weight: .light))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider().padding(.horizontal, 8)

            // Actions
            menuButton(icon: "rectangle.on.rectangle", label: "open frame", shortcut: "⌘⇧A", action: onToggleFrame)
            menuButton(icon: "gearshape",              label: "settings",   shortcut: nil,    action: onShowSettings)
            menuButton(icon: "info.circle",            label: "about",      shortcut: nil,    action: onShowAbout)

            Divider().padding(.horizontal, 8)

            menuButton(icon: "power", label: "quit", shortcut: "⌘Q", action: onQuit)
                .padding(.bottom, 4)
        }
        .frame(width: 240)
        .background(.ultraThinMaterial)
    }

    private func menuButton(icon: String, label: String, shortcut: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .frame(width: 16)
                    .foregroundStyle(.secondary)
                Text(label)
                    .font(.system(size: 13, weight: .light))
                Spacer()
                if let s = shortcut {
                    Text(s)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
