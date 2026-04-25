# screens — build session log

> built from scratch across two context windows. this doc covers everything: what we built, what broke, how we fixed it, and all major decisions.

---

## what we built

**screens** (originally: arenaframe) — a native macOS menu bar screensaver app powered by the Are.na public API v3.

- **repo:** https://github.com/howwohmm/arenaframe
- **stack:** Swift 5.9, SwiftUI + AppKit, Carbon, CryptoKit, ServiceManagement
- **target:** macOS 14+, arm64
- **license:** MIT

---

## feature list

| feature | detail |
|---|---|
| menu bar app | `NSStatusItem + NSPopover` — reliable, no double-click required |
| global hotkey | `⌘⇧A` via Carbon `RegisterEventHotKey` — no Accessibility permission |
| fullscreen frame | `NSWindow` at `.screenSaver` level — sits above all apps |
| fit modes | contain (letterboxed) · cover (fill + crop) · blur fill (blurred bg + contained image) |
| transitions | instant · crossfade · ken burns (slow pan + zoom) |
| channel management | add by slug or full URL, validates against Are.na API before saving |
| playback order | random · newest first · oldest first |
| quality filter | max upscale multiplier (1×–4×) — skips low-res images on big displays |
| cursor auto-hide | hides after 1s of inactivity, reappears on mouse movement |
| label overlay | never · on hover · always — shows block title + channel · index counter |
| clock overlay | HH:MM in corner, toggleable |
| SHA-256 disk cache | images persist across app restarts via `~/.arenaframe/cache/images/` |
| onboarding flow | 3-step welcome: welcome → add channel → ready |
| settings panel | comprehensive settings for all the above |
| about window | version, github link, support email, MIT license |
| launch at login | `ServiceManagement.SMAppService` |
| keyboard shortcuts | `← →` prev/next · `space` pause/resume · `esc`/`q` close |
| CI | GitHub Actions on `macos-14`, unsigned build on every push/PR |

---

## file structure

```
Sources/ArenaFrame/
├── ArenaFrameApp.swift          — @main entry, NSStatusItem + NSPopover, AppDelegate
├── AppState.swift               — @Observable shared state, UserDefaults, auto-refresh
├── HotkeyManager.swift          — Carbon RegisterEventHotKey (⌘⇧A)
├── Arena/
│   ├── ArenaClient.swift        — actor-based API client, SHA-256 disk cache
│   ├── ArenaModels.swift        — block types, API response decoders
│   └── DisplaySettings.swift   — FitMode, TransitionStyle, LabelVisibility enums
├── Frame/
│   ├── FrameWindowController.swift  — NSWindow at .screenSaver level, cursor hiding
│   └── FrameView.swift              — image renderer: contain/cover/blur fill, ken burns
├── Onboarding/
│   └── OnboardingView.swift     — 3-step welcome flow
├── Settings/
│   └── SettingsView.swift       — comprehensive settings panel with mode cards
├── About/
│   └── AboutView.swift          — version, links, credits
└── MenuBarView.swift            — NSPopover content: brand, status, actions
```

---

## conversation log

### session 1 (context window 1)

**start:** blank Xcode project + idea: Are.na screensaver as a macOS menu bar app

**what happened:**

1. wrote `ArenaModels.swift` — block types, image/text/link variants, API response decoders
2. wrote `ArenaClient.swift` — actor-based API client with SHA-256 disk caching via CryptoKit
3. wrote all remaining files to make the app buildable
4. set up `project.yml` with xcodegen, `Info.plist` with `LSUIElement: true`

---

### session 2 (context window 2, this session)

**start:** app builds but has two critical bugs + major feature gaps

---

#### bug 1: start button did nothing

**symptom:** clicking "start" in the onboarding step 2 didn't close the window or trigger anything visible.

**root cause:** `OnboardingView` is hosted in a raw `NSWindow`. SwiftUI's `@Environment(\.dismiss)` doesn't propagate through `NSWindow` hosts — it only works inside `.sheet`, `.fullScreenCover`, etc.

**fix:**
```swift
onboardBtn("start") {
    appState.hasCompletedOnboarding = true
    appState.fetchAll()
    NSApplication.shared.keyWindow?.close()  // the fix
}
```

---

#### bug 2: black frame — images never rendered

**symptom:** frame opened, was pure black, spinner never went away. Images were downloading (confirmed via cache inspection) but never appeared.

**root cause #1: `AsyncImage` fails silently with `file://` URLs on macOS.**
`AsyncImage` is designed for HTTP URLs. It calls `URLSession` under the hood and `file://` scheme returns silently empty on macOS. Switched to `NSImage(contentsOf:)` which loads local files reliably.

```swift
// before (broken):
AsyncImage(url: localURL) { ... }

// after (works):
let img: NSImage? = localURL.flatMap { NSImage(contentsOf: $0) }
```

**root cause #2: `orderedBlocks` was a computed property using `.shuffled()`.**
Every access to `orderedBlocks` returned a *different array* (shuffle is non-deterministic). `currentBlock?.id` changed on every access, which repeatedly cancelled and restarted `.task(id:)` — the image download never completed before the next cancellation.

**fix:** made `orderedBlocks` a `private(set) var` rebuilt only explicitly:
```swift
func rebuildOrder() {
    let filtered = allBlocks.filter { $0.isRenderable && $0.isHQ(...) }
    switch order {
    case .random:  orderedBlocks = filtered.shuffled()
    case .newest:  orderedBlocks = filtered
    case .oldest:  orderedBlocks = filtered.reversed()
    }
}
```

**root cause #3: `fetchAll()` called inside `show()`.**
`FrameWindowController.show()` was calling `appState.fetchAll()` which reset `currentIndex = 0` and called `rebuildOrder()`, changing `currentBlock?.id` mid-task, cancelling the in-flight download.

**fix:** removed `fetchAll()` from `show()`. Fetch runs once on launch and on auto-refresh only.

---

#### feature: pure black background + cursor auto-hide

- `FrameView`: `Color.black.ignoresSafeArea()` — true black (was grey before)
- `FrameWindowController`: `win.backgroundColor = .black`
- cursor hide: `NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved])` → resets 1s `Timer` → `NSCursor.hide()` on fire
- cursor restore: `showCursor()` called whenever frame closes — cursor is always restored

---

#### feature: fit modes

three modes, toggled via settings:

**contain** — letterboxed, full image visible
```swift
Image(...).resizable().scaledToFit()
```

**cover** — fills frame, crops edges
```swift
Image(...).resizable().scaledToFill().clipped()
```

**blur fill** — blurred version of image as background, contained image on top
```swift
ZStack {
    Image(...).resizable().scaledToFill()
        .blur(radius: 40).opacity(0.45).clipped()
    Image(...).resizable().scaledToFit()
}
```

---

#### feature: transitions

**instant** — no animation, hard cut

**crossfade** — `.opacity` transition with `easeInOut`

**ken burns** — slow pan + zoom using `withAnimation(.linear(duration:))`
```swift
@State private var kbScale: CGFloat = 1.0
@State private var kbAnchor: UnitPoint = .center

func startKenBurns(duration: Double) {
    kbScale = 1.0; kbAnchor = .center
    let scales: [CGFloat] = [1.12, 1.18, 1.22]
    let anchors: [UnitPoint] = [.topLeading, .topTrailing, .bottomLeading, .bottomTrailing, .center]
    withAnimation(.linear(duration: duration)) {
        kbScale = scales.randomElement()!
        kbAnchor = anchors.randomElement()!
    }
}
```

---

#### bug: `transition(for:)` name collision

named the SwiftUI helper `transition(for:)` which collided with SwiftUI's built-in `.transition()` view modifier. renamed to `makeTransition(_:)`.

---

#### feature: replace `MenuBarExtra` with `NSStatusItem + NSPopover`

**problem:** SwiftUI's `MenuBarExtra` with `.menuBarExtraStyle(.window)` is unreliable. First click focuses the window, second click actually hits the button.

**fix:** replaced entirely with `NSStatusItem + NSPopover`:
```swift
@objc private func handleStatusClick(_ sender: Any?) {
    guard let button = statusItem.button else { return }
    if popover.isShown {
        popover.performClose(sender)
    } else {
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        NSApp.activate(ignoringOtherApps: true)
    }
}
```
`makeKey()` + `NSApp.activate()` ensures SwiftUI buttons respond immediately without double-click.

---

#### bug: xcodegen overwrites Info.plist

xcodegen regenerates `Info.plist` on every `xcodegen generate` run, erasing custom keys (`LSUIElement`, `NSAppTransportSecurity`, etc.).

**fix:** moved all custom keys to `info.properties` in `project.yml`:
```yaml
info:
  path: Info.plist
  properties:
    CFBundleName: screens
    LSUIElement: true
    NSAppTransportSecurity:
      NSAllowsArbitraryLoads: true
```

---

#### professional open-source setup

- `LICENSE` — MIT, © 2026 ohm. (mishraom.work@gmail.com)
- `README.md` — badges, feature list, install instructions, usage table, settings table, architecture tree, v2 roadmap
- `.github/workflows/build.yml` — GitHub Actions CI on `macos-14`, unsigned `xcodebuild` release build
- `.github/ISSUE_TEMPLATE/bug_report.md` — structured bug report template
- `.github/ISSUE_TEMPLATE/feature_request.md` — feature request template
- `.github/FUNDING.yml` — `custom: ["https://ohm.quest"]`
- `AboutView.swift` — version from Bundle, GitHub + support + Are.na links
- `dist/screens.dmg` — packaged via `create-dmg`, 407KB

---

#### GitHub push

```bash
gh repo create arenaframe --public --source . --remote origin --push
```
repo live at: https://github.com/howwohmm/arenaframe

---

#### rename: arenaframe → screens

user suggested "screens" ("are.na screens kaisa rahega?" = "how would are.na screens be?")

changed across:
- `project.yml` — `CFBundleName`, `CFBundleDisplayName`, `PRODUCT_BUNDLE_IDENTIFIER` (→ `quest.ohm.screens`), `PRODUCT_NAME`
- `ArenaFrameApp.swift` — status item `accessibilityDescription`
- `MenuBarView.swift` — brand name
- `OnboardingView.swift` — welcome title, ready step copy
- `AboutView.swift` — app name display, fixed GitHub link (`ohmdreams` → `howwohmm`)
- `README.md` — title, DMG filename
- rebuilt: `screens.app`, `dist/screens.dmg`

---

## key decisions

| decision | reasoning |
|---|---|
| `NSStatusItem + NSPopover` over `MenuBarExtra` | SwiftUI's MenuBarExtra is unreliable — buttons need double-click to register. NSStatusItem + makeKey() is battle-tested. |
| `NSImage(contentsOf:)` over `AsyncImage` | AsyncImage silently fails with file:// URLs on macOS. NSImage is the right tool for local disk images. |
| `orderedBlocks` as stored var, not computed | Computed `.shuffled()` reshuffles on every access. `.task(id: currentBlock?.id)` depends on stable IDs — computed property breaks this entirely. |
| No `fetchAll()` in `show()` | Fetching on show resets state mid-task, cancelling in-flight downloads. Fetch runs once at launch + on timer. |
| xcodegen `info.properties` for plist keys | Only way to add custom Info.plist keys without xcodegen wiping them on regenerate. |
| Carbon `RegisterEventHotKey` | Only reliable way to get a global hotkey on macOS without Accessibility permission. |
| SHA-256 cache keys | CryptoKit is built into macOS SDK, no dependencies. SHA-256 of the image URL = stable, collision-resistant filename. |
| NSWindow at `.screenSaver` level | Sits above all apps including full-screen — the correct layer for a screensaver replacement. |

---

## v2 roadmap

- [ ] OAuth for private channels
- [ ] layout modes (2-up, 4-grid, polaroid wall)
- [ ] color palette extraction → animated gradient background
- [ ] per-channel weighting
- [ ] multi-monitor support
- [ ] ambient mode (auto-dim for always-on displays)
- [ ] `H` to hide block, `S` to star
- [ ] open on are.na (`⌘↵`)
- [ ] Sparkle auto-updates
- [ ] notarization

---

*built by ohm. · mishraom.work@gmail.com · ohm.quest*
