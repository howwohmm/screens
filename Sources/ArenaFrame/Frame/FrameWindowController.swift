import AppKit
import SwiftUI

// MARK: - FrameWindowController

final class FrameWindowController: NSWindowController {
    private let appState: AppState
    private var hotkeyManager: HotkeyManager?

    // Cursor state
    private var cursorTimer: Timer?
    private var cursorHidden = false

    // Event monitors — stored so we can remove them on deinit
    private var eventMonitors: [Any] = []

    init(appState: AppState) {
        self.appState = appState

        let screen = NSScreen.main ?? NSScreen.screens[0]
        let win = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        win.level = .screenSaver
        win.backgroundColor = .black
        win.isOpaque = true
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        win.ignoresMouseEvents = false
        win.acceptsMouseMovedEvents = true
        win.isReleasedWhenClosed = false

        let hostingView = NSHostingView(rootView: FrameView(appState: appState))
        win.contentView = hostingView

        super.init(window: win)

        setupKeyBindings(win)
        setupCursorHiding(win)
        registerHotkey()
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit {
        eventMonitors.forEach { NSEvent.removeMonitor($0) }
    }

    // MARK: Show / Hide

    var isVisible: Bool { window?.isVisible ?? false }

    func show() {
        guard let win = window else { return }
        win.alphaValue = 0
        win.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            win.animator().alphaValue = 1
        }
        appState.startSlideshow { [weak self] in
            self?.window?.contentView?.needsDisplay = true
        }
        resetCursorTimer()
    }

    func hide() {
        guard let win = window, win.isVisible else { return }
        showCursor()
        cursorTimer?.invalidate()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            win.animator().alphaValue = 0
        } completionHandler: {
            win.orderOut(nil)
        }
        appState.stopSlideshow()
    }

    func toggle() { isVisible ? hide() : show() }

    // MARK: Cursor hiding

    private func setupCursorHiding(_ win: NSWindow) {
        let monitor = NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved, .mouseEntered, .leftMouseDragged]
        ) { [weak self] event in
            if self?.window?.isVisible == true {
                self?.resetCursorTimer()
            }
            return event
        }
        if let monitor { eventMonitors.append(monitor) }
    }

    private func resetCursorTimer() {
        cursorTimer?.invalidate()
        showCursor()
        guard window?.isVisible == true else { return }
        cursorTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            guard self?.window?.isVisible == true else { return }
            self?.hideCursor()
        }
    }

    private func hideCursor() {
        guard !cursorHidden else { return }
        NSCursor.hide()
        cursorHidden = true
    }

    private func showCursor() {
        guard cursorHidden else { return }
        NSCursor.unhide()
        cursorHidden = false
    }

    // MARK: Keyboard

    private func setupKeyBindings(_ win: NSWindow) {
        let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.window?.isVisible == true else { return event }
            switch event.keyCode {
            case 53:  self.hide()                  // ESC
            case 123: self.appState.retreat()      // ←
            case 124: self.appState.advance()      // →
            case 49:  self.appState.togglePause()  // SPACE
            case 12:  self.hide()                  // Q
            default:  return event
            }
            return nil
        }
        if let monitor { eventMonitors.append(monitor) }
    }

    // MARK: Hotkey (⌘⇧A)

    private func registerHotkey() {
        let hk = HotkeyManager { [weak self] in self?.toggle() }
        hk.register()
        self.hotkeyManager = hk
    }
}
