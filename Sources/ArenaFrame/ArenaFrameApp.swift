import SwiftUI
import AppKit
import ServiceManagement

// MARK: - Entry point
// No MenuBarExtra scene — we use NSStatusItem directly for reliable click handling.

@main
struct ArenaFrameApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        // Empty scene — all UI is driven by AppDelegate
        Settings { EmptyView() }
    }
}

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: State

    let appState = AppState()

    // MARK: UI

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var frameController: FrameWindowController?
    private var settingsWindow: NSWindow?
    private var aboutWindow: NSWindow?

    // MARK: Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        frameController = FrameWindowController(appState: appState)
        appState.startAutoRefresh()
        if !appState.channelSlugs.isEmpty {
            appState.fetchAll()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if !self.appState.hasCompletedOnboarding {
                self.openSettingsPanel()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        frameController = nil
    }

    // MARK: Status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "rectangle.on.rectangle.angled",
                                   accessibilityDescription: "screens")
            button.image?.isTemplate = true
            button.action = #selector(handleStatusClick)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        let menuContent = MenuBarView(
            appState: appState,
            onToggleFrame: { [weak self] in self?.toggleFrame() },
            onShowSettings: { [weak self] in self?.openSettingsPanel() },
            onShowAbout: { [weak self] in self?.openAboutWindow() },
            onQuit: { NSApp.terminate(nil) }
        )

        let controller = NSHostingController(rootView: menuContent)
        controller.view.frame.size = CGSize(width: 240, height: 240)

        popover = NSPopover()
        popover.contentViewController = controller
        popover.contentSize = CGSize(width: 240, height: 240)
        popover.behavior = .transient
        popover.animates = true
    }

    @objc private func handleStatusClick(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // Make the popover window key so all buttons respond immediately
            popover.contentViewController?.view.window?.makeKey()
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: Frame

    func toggleFrame() {
        popover.performClose(nil)
        frameController?.toggle()
    }

    // MARK: Settings / Onboarding

    func openSettingsPanel() {
        popover.performClose(nil)
        if let w = settingsWindow, w.isVisible { w.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }

        let view: AnyView = appState.hasCompletedOnboarding
            ? AnyView(SettingsView(appState: appState))
            : AnyView(OnboardingView(appState: appState))

        let win = makePanel(width: 500, height: appState.hasCompletedOnboarding ? 680 : 460, view: view)
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = win
    }

    // MARK: About

    func openAboutWindow() {
        popover.performClose(nil)
        if let w = aboutWindow, w.isVisible { w.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        let win = makePanel(width: 360, height: 320, view: AnyView(AboutView()))
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        aboutWindow = win
    }

    // MARK: Window factory

    private func makePanel<V: View>(width: CGFloat, height: CGFloat, view: V) -> NSWindow {
        let hosting = NSHostingView(rootView: view)
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.backgroundColor = NSColor(red: 0.09, green: 0.088, blue: 0.084, alpha: 1)
        win.isMovableByWindowBackground = true
        win.contentView = hosting
        win.center()
        win.isReleasedWhenClosed = false
        return win
    }
}
