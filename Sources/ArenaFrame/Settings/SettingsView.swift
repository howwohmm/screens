import SwiftUI

// MARK: - SettingsView

struct SettingsView: View {
    @Bindable var appState: AppState
    @State private var newSlug: String = ""
    @State private var addError: String? = nil
    @State private var isAdding: Bool = false

    var body: some View {
        ZStack {
            Color(red: 0.09, green: 0.088, blue: 0.084).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    Divider().background(Color.white.opacity(0.07)).padding(.vertical, 24)
                    channelsSection
                    Divider().background(Color.white.opacity(0.07)).padding(.vertical, 24)
                    playbackSection
                    Divider().background(Color.white.opacity(0.07)).padding(.vertical, 24)
                    displaySection
                    Divider().background(Color.white.opacity(0.07)).padding(.vertical, 24)
                    transitionsSection
                    Divider().background(Color.white.opacity(0.07)).padding(.vertical, 24)
                    overlaySection
                    Divider().background(Color.white.opacity(0.07)).padding(.vertical, 24)
                    systemSection
                    Divider().background(Color.white.opacity(0.07)).padding(.vertical, 24)
                    footer
                }
                .padding(32)
            }
        }
        .frame(width: 500, height: 680)
    }

    // MARK: Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("screens")
                    .font(.system(size: 18, weight: .thin))
                    .foregroundStyle(.white)
                    .kerning(1.5)
                Text("settings")
                    .font(.system(size: 11, weight: .light))
                    .foregroundStyle(.white.opacity(0.3))
                    .kerning(0.8)
            }
            Spacer()
            if appState.isFetching {
                HStack(spacing: 6) {
                    ProgressView().progressViewStyle(.circular).scaleEffect(0.55).tint(.white.opacity(0.3))
                    Text("syncing")
                        .font(.system(size: 11, weight: .light))
                        .foregroundStyle(.white.opacity(0.3))
                }
            } else {
                Text("\(appState.orderedBlocks.count) blocks")
                    .font(.system(size: 11, weight: .light))
                    .foregroundStyle(.white.opacity(0.25))
            }
        }
    }

    // MARK: Channels

    private var channelsSection: some View {
        sectionBlock("channels") {
            VStack(spacing: 6) {
                ForEach(appState.channelSlugs, id: \.self) { slug in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color.white.opacity(0.12))
                            .frame(width: 6, height: 6)
                        Text(slug)
                            .font(.system(size: 13, weight: .light))
                            .foregroundStyle(.white.opacity(0.7))
                        Spacer()
                        Button {
                            appState.channelSlugs.removeAll { $0 == slug }
                            if appState.channelSlugs.isEmpty {
                                appState.allBlocks = []
                                appState.rebuildOrder()
                            } else {
                                appState.fetchAll()
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.25))
                                .frame(width: 20, height: 20)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(6)
                }

                // Add row
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        TextField("", text: $newSlug,
                                  prompt: Text("slug or are.na URL").foregroundStyle(.white.opacity(0.18)))
                            .textFieldStyle(.plain)
                            .font(.system(size: 13, weight: .light))
                            .foregroundStyle(.white)
                            .autocorrectionDisabled()
                            .onSubmit { addChannel() }

                        if isAdding {
                            ProgressView().progressViewStyle(.circular).scaleEffect(0.6).tint(.white.opacity(0.35))
                        } else {
                            Button { addChannel() } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white.opacity(0.4))
                                    .frame(width: 22, height: 22)
                            }
                            .buttonStyle(.plain)
                            .disabled(newSlug.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.07))
                    .cornerRadius(6)

                    if let err = addError {
                        Text(err)
                            .font(.system(size: 11, weight: .light))
                            .foregroundStyle(Color(red: 1, green: 0.4, blue: 0.4).opacity(0.8))
                            .padding(.horizontal, 4)
                    }
                }
            }
        }
    }

    // MARK: Playback

    private var playbackSection: some View {
        sectionBlock("playback") {
            VStack(spacing: 14) {
                row("interval") {
                    HStack(spacing: 10) {
                        Slider(value: $appState.intervalSeconds, in: 3...120, step: 1)
                            .tint(.white.opacity(0.4))
                        Text("\(Int(appState.intervalSeconds))s")
                            .font(.system(size: 12, weight: .light).monospacedDigit())
                            .foregroundStyle(.white.opacity(0.4))
                            .frame(width: 34, alignment: .trailing)
                    }
                }

                row("order") {
                    Picker("", selection: $appState.order) {
                        ForEach(BlockOrder.allCases) { o in
                            Text(o.label).tag(o)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 210)
                    .colorScheme(.dark)
                }

            }
        }
    }

    // MARK: Display

    private var displaySection: some View {
        sectionBlock("display") {
            VStack(spacing: 16) {
                // Fit mode cards
                VStack(alignment: .leading, spacing: 8) {
                    Text("fit mode")
                        .font(.system(size: 11, weight: .light))
                        .foregroundStyle(.white.opacity(0.35))
                        .kerning(0.5)
                    HStack(spacing: 8) {
                        ForEach(FitMode.allCases) { mode in
                            fitModeCard(mode)
                        }
                    }
                }
            }
        }
    }

    private func fitModeCard(_ mode: FitMode) -> some View {
        let selected = appState.fitMode == mode
        return Button { appState.fitMode = mode } label: {
            VStack(spacing: 6) {
                fitModeIcon(mode)
                    .frame(height: 36)
                Text(mode.label)
                    .font(.system(size: 11, weight: .light))
                    .foregroundStyle(.white.opacity(selected ? 0.85 : 0.4))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.white.opacity(selected ? 0.1 : 0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(selected ? 0.2 : 0), lineWidth: 1)
            )
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func fitModeIcon(_ mode: FitMode) -> some View {
        switch mode {
        case .contain:
            // Small rect inside frame
            ZStack {
                RoundedRectangle(cornerRadius: 3).stroke(Color.white.opacity(0.2), lineWidth: 1)
                    .frame(width: 38, height: 28)
                RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.25))
                    .frame(width: 24, height: 18)
            }
        case .blurFill:
            ZStack {
                RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.1))
                    .frame(width: 38, height: 28)
                RoundedRectangle(cornerRadius: 3).stroke(Color.white.opacity(0.2), lineWidth: 1)
                    .frame(width: 38, height: 28)
                RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.3))
                    .frame(width: 22, height: 17)
                    .blur(radius: 0.5)
            }
        }
    }

    // MARK: Transitions

    private var transitionsSection: some View {
        sectionBlock("transitions") {
            HStack(spacing: 8) {
                ForEach(TransitionStyle.allCases) { style in
                    transitionCard(style)
                }
            }
        }
    }

    private func transitionCard(_ style: TransitionStyle) -> some View {
        let selected = appState.transitionStyle == style
        return Button { appState.transitionStyle = style } label: {
            VStack(spacing: 5) {
                Text(style.label)
                    .font(.system(size: 12, weight: .light))
                    .foregroundStyle(.white.opacity(selected ? 0.85 : 0.4))
                Text(style.description)
                    .font(.system(size: 10, weight: .light))
                    .foregroundStyle(.white.opacity(selected ? 0.4 : 0.2))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.white.opacity(selected ? 0.09 : 0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(selected ? 0.18 : 0), lineWidth: 1)
            )
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    // MARK: Overlay

    private var overlaySection: some View {
        sectionBlock("overlay") {
            VStack(spacing: 14) {
                row("label") {
                    Picker("", selection: $appState.labelVisibility) {
                        ForEach(LabelVisibility.allCases) { v in
                            Text(v.label).tag(v)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                    .colorScheme(.dark)
                }

                row("clock") {
                    Toggle("", isOn: $appState.showClock)
                        .toggleStyle(.switch)
                        .tint(.white.opacity(0.5))
                        .scaleEffect(0.8)
                        .frame(width: 44, alignment: .trailing)
                }
            }
        }
    }

    // MARK: System

    private var systemSection: some View {
        sectionBlock("system") {
            VStack(spacing: 14) {
                row("launch at login") {
                    Toggle("", isOn: $appState.launchAtLogin)
                        .toggleStyle(.switch)
                        .tint(.white.opacity(0.5))
                        .scaleEffect(0.8)
                        .frame(width: 44, alignment: .trailing)
                }

                row("hotkey") {
                    Text("⌘ ⇧ A")
                        .font(.system(size: 12, weight: .light))
                        .foregroundStyle(.white.opacity(0.35))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(4)
                }

                row("keyboard controls") {
                    VStack(alignment: .trailing, spacing: 3) {
                        keyHint("← →", "prev / next")
                        keyHint("space", "pause")
                        keyHint("esc / q", "close")
                    }
                }
            }
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            Text("screens · made by ohm")
                .font(.system(size: 11, weight: .light))
                .foregroundStyle(.white.opacity(0.15))
            Spacer()
            Button("reset onboarding") {
                appState.hasCompletedOnboarding = false
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .light))
            .foregroundStyle(.white.opacity(0.15))
        }
    }

    // MARK: Building blocks

    private func sectionBlock<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .light))
                .foregroundStyle(.white.opacity(0.3))
                .kerning(1.2)
            content()
        }
    }

    private func row<Content: View>(_ label: String, @ViewBuilder control: () -> Content) -> some View {
        HStack(alignment: .center) {
            Text(label)
                .font(.system(size: 13, weight: .light))
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 120, alignment: .leading)
            control()
        }
    }

    private func keyHint(_ key: String, _ desc: String) -> some View {
        HStack(spacing: 6) {
            Text(key)
                .font(.system(size: 10, weight: .light))
                .foregroundStyle(.white.opacity(0.35))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.06))
                .cornerRadius(3)
            Text(desc)
                .font(.system(size: 10, weight: .light))
                .foregroundStyle(.white.opacity(0.25))
        }
    }

    // MARK: Add channel

    private func addChannel() {
        var s = newSlug.trimmingCharacters(in: .whitespaces)
        if let url = URL(string: s),
           let host = url.host,
           host == "are.na" || host.hasSuffix(".are.na") {
            s = url.pathComponents.last ?? s
        }
        s = s.lowercased()
        guard !s.isEmpty else { return }
        guard !appState.channelSlugs.map({ $0.lowercased() }).contains(s) else { addError = "already added"; return }
        addError = nil
        isAdding = true
        Task {
            do {
                let _ = try await appState.client.validateChannel(slug: s)
                await MainActor.run {
                    appState.channelSlugs.append(s)
                    newSlug  = ""
                    isAdding = false
                    appState.fetchAll()
                }
            } catch let e as ArenaError {
                await MainActor.run { addError = e.errorDescription; isAdding = false }
            } catch {
                await MainActor.run { addError = "couldn't validate"; isAdding = false }
            }
        }
    }
}
