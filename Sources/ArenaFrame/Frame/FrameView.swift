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
    private let clockTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

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
    }

    // MARK: Visual content

    @ViewBuilder
    private func visualContent(img: NSImage) -> some View {
        switch appState.fitMode {
        case .contain:
            Image(nsImage: img)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scaleEffect(kbScale, anchor: kbAnchor)

        case .cover:
            Image(nsImage: img)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .scaleEffect(kbScale, anchor: kbAnchor)

        case .blurFill:
            ZStack {
                // Blurred background fill
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .blur(radius: 40)
                    .overlay(Color.black.opacity(0.45))
                    .clipped()

                // Sharp contained image on top
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .scaleEffect(kbScale, anchor: kbAnchor)
            }
        }
    }

    // MARK: Text content

    private func textContent(text: String) -> some View {
        ScrollView {
            Text(text)
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
            if showOverlay || appState.labelVisibility == .always {
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
        guard appState.transitionStyle == .kenBurns else {
            kbScale = 1.0; kbAnchor = .center; return
        }
        // Random start anchor and direction
        let anchors: [UnitPoint] = [.topLeading, .top, .topTrailing,
                                     .leading, .center, .trailing,
                                     .bottomLeading, .bottom, .bottomTrailing]
        kbScale = 1.0
        kbAnchor = anchors.randomElement() ?? .center
        withAnimation(.linear(duration: max(duration, 5))) {
            kbScale = 1.10
            // Drift toward the opposite region
            kbAnchor = anchors.randomElement() ?? .center
        }
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
