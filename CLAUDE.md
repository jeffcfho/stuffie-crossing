# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`stuffie-crossing` is an iPad puzzle game for toddlers (age 3–6) built in Swift + SpriteKit. The core mechanic: stuffed animals must all cross a bridge, with a capacity limit and conflict rules (certain pairs can't be left alone together). Players drag stuffies onto the bridge and tap "Go." The escort-back mechanic (dragging a stuffie back from the far bank) is the heart of the puzzle. Full design in `PRD.md`.

**Status**: Documentation and design complete. No Swift source files exist yet — implementation starts at Build Sequence Step 1 (scaffold).

## Internal Testing Procedure

Run this before any manual testing. It covers everything verifiable without a device or Xcode project:

```bash
bash scripts/test.sh
```

What it runs:
1. **Unit tests** (`swift test`) — exercises `GameStateManager` logic: state transitions, conflict detection, win condition, both Level 1 solution paths, Level 2 solution path, undo, restart, hints, bridge capacity, bidirectional crossing.
2. **Full type-check** (`xcrun swiftc -typecheck`) — verifies all 11 source files against the iOS simulator SDK, including UIKit/SpriteKit files that `swift test` can't reach.

**What's left for manual testing** (only after `scripts/test.sh` passes and Xcode project is set up):
- `xcodebuild` build + iPad simulator boot
- Drag-and-drop feel and multi-touch behavior
- Animation timing and visual correctness
- Win/conflict reaction animations
- Level 2 unlock persisting across restarts

To add new unit tests: `Tests/StuffieCrossingCoreTests/GameStateManagerTests.swift`. The `StuffieCrossingCore` SPM target contains only the Foundation-only model files; UIKit/SpriteKit files are excluded from the package.

## Build & Run

This project requires Xcode with the "Game" (SpriteKit) template. Target: iPad, landscape-only, iOS 16.0+.

```bash
xcodebuild -scheme StuffieCrossing build
xcodebuild -scheme StuffieCrossing -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation)' build
xcodebuild test -scheme StuffieCrossing -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation)'
xcodebuild test -scheme StuffieCrossing -only-testing:StuffieCrossingTests/<TestName> -destination '...'
```

## Architecture

### Scene hierarchy
```
AppDelegate / SceneDelegate
├── MenuScene              — title + Play button
└── GameScene              — main gameplay
    ├── BridgeNode         — visual + animation path
    ├── BankNode (×2)      — left/right banks
    └── StuffieNode        — sprite + per-stuffie touch tracking
```
`GameStateManager` owns the state machine and notifies `GameScene`/nodes via `GameStateDelegate`.

### State machine
```
INTRO → IDLE → SELECTING → ANIMATING → CHECKING → WIN
                                               └→ CONFLICT_REACTION → IDLE
```
- `ANIMATING`: all input locked; stuffies wiggle if tapped
- `CHECKING`: validates conflict rules on both banks after animation completes
- Crossing direction inferred from `sourceBankNode` on each `StuffieNode` — no explicit direction control

### Key invariants — do not violate
- **Physics disabled** on all nodes (`physicsBody = nil`). This is a puzzle game; physics causes unpredictable behavior.
- **UIKit overlay** for all buttons (Go, Undo, Hint, Restart) — transparent `UIView` over `SKView`. Do NOT use `SKNode`s for buttons.
- **Landscape-only** — set `UISupportedInterfaceOrientations` in Info.plist on day 1; all coordinate math assumes it.
- **Scene scale mode** — choose `.resizeFill` or `.aspectFit` once and never change it (affects all layout math).
- **Named constants** for all stuffie sizes and anchor points — no magic numbers. Swapping real art for placeholders should only require changing constants.
- `AVAudioSession.sharedInstance().setCategory(.ambient)` at launch — game must mix with background audio.

### Data model
```swift
struct Stuffie: Identifiable {
    let id: String            // "bear", "bunny", "lion"
    let conflicts: Set<String> // unidirectional — check both directions in GameStateManager
}
struct Level {
    let bridgeCapacity: Int
    let stuffies: [Stuffie]
    let hintSequence: [[String]]  // hand-authored, not solved
    var isUnlocked: Bool          // computed from UserDefaults at launch
}
```
Conflict checks: `a.conflicts.contains(b.id) || b.conflicts.contains(a.id)`.

### Persistence
`UserDefaults` stores completed level IDs. Level 2 unlock depends on this — must exist even in MVP.

## Build Sequence (do not reorder)
1. Scaffold: Xcode project, landscape lock, UIKit overlay skeleton, constants, audio session
2. Data model + state machine (no visuals) — unit-testable
3. Static render: placeholder rectangles in correct positions
4. Drag-and-drop: multi-touch safety, snap-to-bridge, snap-back ← highest-risk mechanic
5. Go button + state machine integration
6. Animations: walk, idle, shake, win celebration
7. Hint system: wire hand-authored sequences to highlight
8. Level 2 + unlock flow
9. Polish: sounds, transitions, skippable intro
10. Art swap: replace placeholder shapes with real sprites

## Dependency Managers

`.gitignore` is configured for SPM, CocoaPods, Carthage, and fastlane.
