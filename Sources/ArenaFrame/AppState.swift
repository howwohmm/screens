import Foundation
import AppKit
import ServiceManagement

// MARK: - AppState

@Observable
final class AppState {

    // MARK: Persisted — channels

    var channelSlugs: [String] {
        didSet { UserDefaults.standard.set(channelSlugs, forKey: "channelSlugs") }
    }

    // MARK: Persisted — playback

    var intervalSeconds: Double {
        didSet { UserDefaults.standard.set(intervalSeconds, forKey: "intervalSeconds") }
    }
    var order: BlockOrder {
        didSet { UserDefaults.standard.set(order.rawValue, forKey: "order"); rebuildOrder() }
    }

    // MARK: Persisted — display

    var fitMode: FitMode {
        didSet { UserDefaults.standard.set(fitMode.rawValue, forKey: "fitMode") }
    }
    var transitionStyle: TransitionStyle {
        didSet { UserDefaults.standard.set(transitionStyle.rawValue, forKey: "transitionStyle") }
    }
    var labelVisibility: LabelVisibility {
        didSet { UserDefaults.standard.set(labelVisibility.rawValue, forKey: "labelVisibility") }
    }
    var maxUpscale: Double {
        didSet { UserDefaults.standard.set(maxUpscale, forKey: "maxUpscale"); rebuildOrder() }
    }
    var showClock: Bool {
        didSet { UserDefaults.standard.set(showClock, forKey: "showClock") }
    }

    // MARK: Persisted — system

    var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }
    var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
            applyLaunchAtLogin()
        }
    }

    // MARK: Runtime state

    var allBlocks: [ArenaBlock] = []
    var currentIndex: Int = 0
    var isFetching: Bool = false
    var isPaused: Bool = false

    /// Stable ordered list — rebuilt when allBlocks / order / maxUpscale change.
    private(set) var orderedBlocks: [ArenaBlock] = []

    var currentBlock: ArenaBlock? {
        guard !orderedBlocks.isEmpty else { return nil }
        return orderedBlocks[currentIndex % orderedBlocks.count]
    }

    // MARK: Services

    private(set) var client: ArenaClient
    private var refreshTask: Task<Void, Never>?
    private var advanceTask: Task<Void, Never>?

    // MARK: Init

    init() {
        let d = UserDefaults.standard
        self.channelSlugs      = d.stringArray(forKey: "channelSlugs") ?? []
        self.intervalSeconds   = d.double(forKey: "intervalSeconds").nonZeroOr(15)
        self.order             = BlockOrder(rawValue: d.string(forKey: "order") ?? "")  ?? .random
        self.fitMode           = FitMode(rawValue: d.string(forKey: "fitMode") ?? "")  ?? .contain
        self.transitionStyle   = TransitionStyle(rawValue: d.string(forKey: "transitionStyle") ?? "") ?? .crossfade
        self.labelVisibility   = LabelVisibility(rawValue: d.string(forKey: "labelVisibility") ?? "") ?? .onHover
        self.maxUpscale        = d.double(forKey: "maxUpscale").nonZeroOr(2.0)
        self.showClock         = d.bool(forKey: "showClock")
        self.hasCompletedOnboarding = d.bool(forKey: "hasCompletedOnboarding")
        self.launchAtLogin     = d.bool(forKey: "launchAtLogin")
        self.client = ArenaClient()
    }

    // MARK: Ordered list

    func rebuildOrder() {
        let screen = NSScreen.main
        let sw = screen?.frame.width  ?? 2560
        let sh = screen?.frame.height ?? 1440
        let filtered = allBlocks.filter {
            $0.isRenderable && $0.isHQ(screenW: sw, screenH: sh, maxUpscale: maxUpscale)
        }
        switch order {
        case .random:  orderedBlocks = filtered.shuffled()
        case .newest:  orderedBlocks = filtered
        case .oldest:  orderedBlocks = filtered.reversed()
        }
        if !orderedBlocks.isEmpty {
            currentIndex = currentIndex % orderedBlocks.count
        } else {
            currentIndex = 0
        }
    }

    // MARK: Fetch

    func fetchAll() {
        guard !channelSlugs.isEmpty else { return }
        guard !isFetching else { return }
        isFetching = true
        Task { @MainActor in
            let blocks = await client.fetchAllChannels(slugs: channelSlugs)
            if !blocks.isEmpty || self.allBlocks.isEmpty {
                let wasEmpty = self.orderedBlocks.isEmpty
                self.allBlocks = blocks
                if wasEmpty { self.currentIndex = 0 }
                self.rebuildOrder()
            }
            self.isFetching = false
        }
    }

    func startAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(600))
                if !Task.isCancelled { fetchAll() }
            }
        }
    }

    func stopAutoRefresh() { refreshTask?.cancel() }

    // MARK: Playback

    func startSlideshow(onAdvance: @escaping () -> Void) {
        advanceTask?.cancel()
        advanceTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(intervalSeconds))
                guard !Task.isCancelled, !isPaused else { continue }
                self.advance()
                onAdvance()
            }
        }
    }

    func stopSlideshow() { advanceTask?.cancel() }

    func advance() {
        guard !orderedBlocks.isEmpty else { return }
        currentIndex = (currentIndex + 1) % orderedBlocks.count
    }

    func retreat() {
        guard !orderedBlocks.isEmpty else { return }
        currentIndex = (currentIndex - 1 + orderedBlocks.count) % orderedBlocks.count
    }

    func togglePause() { isPaused.toggle() }

    // MARK: Launch at login

    private func applyLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Silently fail — user may need to grant permission
        }
    }
}

private extension Double {
    func nonZeroOr(_ fallback: Double) -> Double { self == 0 ? fallback : self }
}
