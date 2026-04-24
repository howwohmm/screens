# arenaframe

**your monitor. a channel.**

A minimal macOS screensaver that turns any display into a living window into your [Are.na](https://are.na) collections. Built with the public Are.na v3 API. Free and open source.

![arenaframe screenshot](docs/screenshot.png)

---

## features

- displays any public Are.na channel fullscreen
- fit modes: contain, cover, blur fill
- transitions: crossfade, ken burns, instant
- quality filter — skips low-res images on large displays
- cursor auto-hides after 1 second
- label overlay (on hover / always / never)
- minimal clock overlay
- launch at login
- global hotkey: `⌘⇧A`

## install

1. download `arenaframe.dmg` from [releases](../../releases)
2. drag `arenaframe` → Applications
3. right-click → Open on first launch (ad-hoc signed, no notarization yet)

## usage

```
⌘⇧A       open / close frame
← →        prev / next block
space       pause / resume
esc / q    close
```

Click the menu bar icon → settings to add channels and configure.

## build from source

requires macOS 14+, Xcode 15+, [xcodegen](https://github.com/yonaskolb/XcodeGen)

```bash
git clone https://github.com/ohmdreams/arenaframe
cd arenaframe
xcodegen generate
open ArenaFrame.xcodeproj
```

## built with

- [Are.na public API v3](https://dev.are.na) — no auth required for public channels
- SwiftUI + AppKit
- Carbon (global hotkey, no Accessibility permission needed)
- CryptoKit (SHA256 disk cache)

## v2 roadmap

- OAuth for private channels
- multiple layout modes (2-up, grid, polaroid wall)
- color palette extraction → animated gradient bg
- per-channel weighting
- multi-monitor support (different channel per display)
- ambient mode (auto-dim for always-on screens)

## license

MIT — see [LICENSE](LICENSE)

## by

[ohm.](https://ohm.quest) · [x.com/ohmdreams](https://x.com/ohmdreams) · mishraom.work@gmail.com
