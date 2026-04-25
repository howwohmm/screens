import SwiftUI
import AppKit

// MARK: - FrameView

struct FrameView: View {
    var appState: AppState

    // Display state
    @State private var displayedBlock: ArenaBlock? = nil
    @State private var displayedImage: NSImage? = nil

    // Ken Burns animation state
    @State private var kbScale: CGFloat = 1.0
    @State private var kbAnchor: UnitPoint = .center

    // Overlay
    @State private var showOverlay: Bool = false
    @State private var clockString: String = ""
    private let clockTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let block = displayedBlock, let img = displayedImage, block.isVisual {
                visualContent(img: img)
                    .id(block.id)
                    .transition(makeTransition(appState.transitionStyle))
            } else if let block = displayedBlock, block.isText, let text = block.textContent {
                textContent(text: text)
                    .id(block.id)
                    .transition(makeTransition(appState.transitionStyle))
            } else {
                loadingView
            }

            // Overlay layer
            overlayLayer
        }
        .task(id: appState.currentBlock?.id) {
            await loadCurrentBlock()
        }
        .onHover { hovering in
            guard appState.labelVisibility == .onHover else { return }
            withAnimation(.easeInOut(duration: 0.2)) { showOverlay = hovering }
        }
        .onReceive(clockTimer) { _ in
            clockString = currentTimeString()
        }
        .onAppear {
            clockString = currentTimeString()
            showOverlay = (appState.labelVisibility == .always)
        }
        .onChange(of: appState.labelVisibility) { _, new in
            showOverlay = (new == .always)
        }
        .onChange(of: appState.transitionStyle) { _, new in
            // When user switches transition style from settings, update KB state
            // immediately on the current slide rather than waiting for next advance.
            if new == .kenBurns {
                startKenBurns(duration: appState.intervalSeconds)
            } else {
                cancelKenBurns()
            }
        }
        .onChange(of: appState.fitMode) { _, _ in
            // Fit mode change — snap scale back so the new mode starts clean.
            cancelKenBurns()
        }
    }

    // MARK: Visual content

    @ViewBuilder
    private func visualContent(img: NSImage) -> some View {
        switch appState.fitMode {

        case .contain:
            // No scaleEffect here — Ken Burns on a letterboxed image zooms into
            // the black bars, not the image. Contain shows the full image cleanly.
            Image(nsImage: img)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .cover:
            // scaleEffect BEFORE clipped — zoom happens inside the frame boundary.
            // Old order (clipped → scaleEffect) caused black edges during Ken Burns.
            Image(nsImage: img)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scaleEffect(kbScale, anchor: kbAnchor)
                .clipped()

        case .blurFill:
            ZStack {
                // Ken Burns on the blurred background — fills frame, no black bars
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .scaleEffect(kbScale, anchor: kbAnchor)
                    .blur(radius: 40)
                    .overlay(Color.black.opacity(0.4))
                    .clipped()

                // Contained image on top — crisp and static
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: Text content

    private func textContent(text: String) -> some View {
        let attributed = (try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(text)

        return ScrollView {
            Text(attributed)
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(.white.opacity(0.82))
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .padding(80)
        }
        .frame(maxWidth: 720)
    }

    // MARK: Loading view

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white.opacity(0.3))
            Text(appState.isFetching ? "fetching…" : "loading…")
                .font(.system(size: 12, weight: .light))
                .foregroundStyle(.white.opacity(0.25))
        }
    }

    // MARK: Overlay

    @ViewBuilder
    private var overlayLayer: some View {
        VStack {
            // Clock (top-right)
            if appState.showClock {
                HStack {
                    Spacer()
                    Text(clockString)
                        .font(.system(size: 13, weight: .thin).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.45))
                        .padding(.top, 20)
                        .padding(.trailing, 28)
                }
            }

            Spacer()

            // Info bar (bottom)
            if showOverlay {
                infoBar
                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
            }
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var infoBar: some View {
        if let block = displayedBlock {
            HStack(spacing: 16) {
                Text(block.displayLabel)
                    .font(.system(size: 12, weight: .light))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(1)
                Spacer()
                if appState.isPaused {
                    Text("paused")
                        .font(.system(size: 11, weight: .light))
                        .foregroundStyle(.white.opacity(0.3))
                }
                Text("\(appState.currentIndex + 1) / \(appState.orderedBlocks.count)")
                    .font(.system(size: 11, weight: .light).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial.opacity(0.5))
        }
    }

    // MARK: Transition

    private func makeTransition(_ style: TransitionStyle) -> AnyTransition {
        switch style {
        case .instant:              return .identity
        case .crossfade, .kenBurns: return .opacity.animation(.easeInOut(duration: 0.5))
        }
    }

    // MARK: Ken Burns

    private func startKenBurns(duration: Double) {
        // Cancel any in-flight KB animation before starting a new one.
        var cancel = Transaction()
        cancel.disablesAnimations = true
        withTransaction(cancel) {
            kbScale = 1.0
            kbAnchor = .center
        }

        guard appState.transitionStyle == .kenBurns else { return }

        let anchors: [UnitPoint] = [.topLeading, .top, .topTrailing,
                                     .leading, .center, .trailing,
                                     .bottomLeading, .bottom, .bottomTrailing]
        // Set a fixed anchor — the zoom toward that corner creates the drift.
        // Never animate kbAnchor: moving the scale anchor mid-animation causes
        // the image to lurch (the pivot point changes while scale is non-1).
        kbAnchor = anchors.randomElement() ?? .center

        withAnimation(.linear(duration: max(duration, 5))) {
            kbScale = 1.08
        }
    }

    private func cancelKenBurns() {
        var cancel = Transaction()
        cancel.disablesAnimations = true
        withTransaction(cancel) { kbScale = 1.0 }
    }

    // MARK: Load block

    private func loadCurrentBlock() async {
        guard let block = appState.currentBlock else { return }

        if block.isText {
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.4)) {
                    displayedBlock = block
                    displayedImage = nil
                }
            }
            return
        }

        guard block.isVisual else { return }

        let localURL = await appState.client.localImageURL(for: block)
        guard !Task.isCancelled else { return }

        let img: NSImage? = localURL.flatMap { NSImage(contentsOf: $0) }
        guard !Task.isCancelled else { return }

        // If the image failed to load (bad file, download error), keep showing
        // the current slide — the slideshow timer will move on naturally.
        guard let img else { return }

        await MainActor.run {
            let dur: Double = appState.transitionStyle == .instant ? 0 : 0.5
            withAnimation(.easeInOut(duration: dur)) {
                displayedBlock = block
                displayedImage = img
            }
            startKenBurns(duration: appState.intervalSeconds)
        }
    }

    // MARK: Helpers

    private func currentTimeString() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: Date())
    }
}
