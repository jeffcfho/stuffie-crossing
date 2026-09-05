# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`stuffie-crossing` is an iPad puzzle game for toddlers (age 3–6) built in Swift + SpriteKit. The core mechanic: stuffed animals must all cross a bridge, with a capacity limit and conflict rules (certain pairs can't be left alone together). Players drag stuffies onto the bridge and tap "Go." One stuffie — Ellie — is a **mandatory escort** who must be on every crossing, which forces the escort-back mechanic that is the heart of the puzzle. Full design in `PRD.md`; art direction in `VISUALS.md`; the current polish pass in `POLISH.md`.

**Status**: Playable. All 5 levels implemented and verified on simulator and iPad. Placeholder shapes, not art. Build Sequence steps 1–8 are done; step 9 (polish) is partly done — see `POLISH.md`.

## Internal Testing Procedure

Run this before any manual testing. It covers everything verifiable without a device:

```bash
bash scripts/test.sh
```

Four steps, each gating the next:
1. **Unit tests** (`swift test`) — 41 tests over `GameStateManager`: state transitions, conflict detection, escort enforcement, win condition, per-level solution paths, undo, restart, hints, bridge capacity, bidirectional crossing.
2. **Full type-check** (`xcrun swiftc -typecheck`) — verifies every source file against the iOS simulator SDK, including the UIKit/SpriteKit files `swift test` can't reach. **Add new files to `SWIFT_FILES` in `scripts/test.sh`** or they escape this gate.
3. **Project generation** (`xcodegen`) — regenerates `StuffieCrossing.xcodeproj` from `project.yml`. Skipped with a warning if xcodegen isn't installed (`brew install xcodegen`).
4. **Compile check** (`xcodebuild`) — full app build for the simulator.

**What's left for manual testing** (only after `scripts/test.sh` passes):
- Drag-and-drop feel and multi-touch behavior
- Animation timing and visual correctness
- Win/conflict reaction animations
- Level unlock persisting across restarts

To add unit tests: `Tests/StuffieCrossingCoreTests/GameStateManagerTests.swift`. The `StuffieCrossingCore` SPM target contains only the Foundation-only model files; UIKit/SpriteKit files are excluded from the package, which is why step 2 exists.

## Build & Run

The Xcode project is **generated, not hand-edited** — change `project.yml` and re-run `xcodegen`. Target: iPad, landscape-only, iOS 16.0+.

```bash
xcodegen --spec project.yml           # after adding/removing any file
xcodebuild -scheme StuffieCrossing build
xcodebuild -scheme StuffieCrossing -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation)' build
```

Because `project.yml` declares `sources: - path: StuffieCrossing`, any file added under that directory is picked up automatically — including sound and art assets. No per-file project surgery.

## Architecture

### Scene hierarchy
```
AppDelegate / SceneDelegate
├── MenuScene              — title + level list (locked levels greyed out)
└── GameScene              — main gameplay
    ├── BridgeNode         — visual + animation path
    ├── BankNode (×2)      — left/right banks
    ├── StuffieNode        — sprite + per-stuffie touch tracking
    └── IntroOverlayNode   — "meet the stuffies" conflict card, tap to dismiss
```
`GameStateManager` owns the state machine and notifies `GameScene`/nodes via `GameStateDelegate`. A second protocol, `GameOverlayDelegate`, drives the UIKit button state (currently just Go's enabled-ness).

### State machine
```
INTRO → IDLE → SELECTING → ANIMATING → CHECKING → WIN
                                               └→ CONFLICT_REACTION → IDLE
```
- `INTRO`: `IntroOverlayNode` is showing; dismissing it calls `introCompleted()`
- `ANIMATING`: all input locked; stuffies wiggle if tapped
- `CHECKING`: validates conflict rules on both banks after animation completes
- `CONFLICT_REACTION`: wiggle + "!" puff, then the last move is rolled back via the undo snapshot
- Crossing direction inferred from `sourceBankNode` on each `StuffieNode` — no explicit direction control

**INTRO has a wrinkle**: `state` is *initialized* to `.intro`, so `didSet` never fires for it and `gameStateDidTransition(to: .intro)` is **not** called on load. `GameScene.didMove` shows the overlay directly. Restart *does* transition back to `.intro`, and that path goes through the delegate. Both routes call `showIntroOverlay()`, which clears any existing overlay first so Restart can't stack two.

### Key invariants — do not violate
- **Physics disabled** on all nodes (`physicsBody = nil`). This is a puzzle game; physics causes unpredictable behavior.
- **UIKit overlay** for all buttons (Go, Undo, Hint, Restart) — transparent `PassthroughView` over `SKView` that only intercepts touches landing on a button. Do NOT use `SKNode`s for buttons.
- **Landscape-only** — `UISupportedInterfaceOrientations` is set in `project.yml`; all coordinate math assumes it.
- **Scene scale mode** is `.resizeFill` everywhere — never change it (affects all layout math).
- **Named constants** for all sizes, z-positions, and sound filenames — see `App/Constants.swift`. Swapping real art for placeholders should only require changing constants.
- `AVAudioSession.sharedInstance().setCategory(.ambient)` at launch — game must mix with background audio.
- **`SKAction.playSoundFileNamed` traps on a missing file.** Always go through `GameScene.playSound(_:)`, which checks the bundle first and caches the result. This is what lets the game run silently while sound assets are still being sourced.

### Data model
```swift
struct Stuffie: Identifiable {
    let id: String            // "ellie", "lion", "bunny", "duck", "bear"
    let displayName: String
    let spriteName: String    // art not yet wired — placeholder shapes are drawn from id
}

struct ConflictPair: Hashable {
    let a: String             // canonically ordered: a < b, so lookup is order-independent
    let b: String
}

struct Level {
    let id: Int
    let environment: BridgeEnvironment   // .water, .lava, .rope, .steel
    let bridgeCapacity: Int
    let stuffies: [Stuffie]
    let conflicts: Set<ConflictPair>
    let mandatoryEscortId: String?       // "ellie" on every level
    let hintSequence: [[String]]         // hand-authored, not solved
    var isUnlocked: Bool                 // computed from UserDefaults at launch
}
```

Conflicts live on `Level`, not `Stuffie` — the same pair can conflict in one level and not another. `ConflictPair.init` sorts its two ids, so `Set.contains(ConflictPair(x, y))` is a single order-independent lookup; there is no both-directions check to remember.

A conflict only fires when a bank holds **exactly two** stuffies (`conflictingPairIds(in:)`). Three or more on a bank is always safe — that's a deliberate design rule, not an oversight.

The escort is enforced in `canTapGo(sourceSide:)`, which disables Go unless the escort is on the bridge. Conflicts are *not* pre-checked there — they're allowed to happen and handled reactively via `CONFLICT_REACTION`, so the child sees why the move was wrong.

### Persistence
`UserDefaults` stores completed level IDs under `completedLevelIds`; level N+1 unlocks when N is complete. A `devMode` flag unlocks everything, toggled from a `#if DEBUG` control on the menu alongside "Reset Progress".

## Build Sequence
Steps 1–8 are complete. Remaining:

9. **Polish** — sounds, transitions, skippable intro. Intro overlay and transitions are done; the four `.mp3` files still need sourcing. See `POLISH.md`.
10. **Art swap** — replace placeholder shapes with real sprites. See `VISUALS.md`.

## Dependency Managers

`.gitignore` is configured for SPM, CocoaPods, Carthage, and fastlane.
