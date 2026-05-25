# Stuffie Crossing — Product Plan

> **Implementation note**: Several deliberate departures from this PRD were made during development — including the removal of `CONFLICT_REACTION`, conflicts moving from `Stuffie` to `Level` scope (`ConflictPair`), the Ellie mandatory-escort mechanic, and a 5-level arc replacing the 2-level MVP. See `ARCHITECTURE.md` for the full departures table and the rationale behind each decision.

## Context

An iPad puzzle game for a toddler (target: age 3–4, designed to grow with the child to age 4–6) built in Swift. The core mechanic is a bridge-crossing logic puzzle: a set of stuffed animals ("stuffies") start on one side of a bridge and must all cross to the other side. Only N stuffies can be on the bridge at once, and certain stuffie pairs can't be left alone together on the same bank. The player figures out which stuffies to send, in what order, and who needs to come back. App Store release is a future goal. Art starts as placeholder shapes; real assets come later.

---

## Game Design

### Core Loop
1. Player sees Level Start screen: bridge environment, stuffies on the left bank, a short animated intro showing which pairs conflict
2. Player **drags** stuffies onto the bridge (up to bridge capacity)
3. Player taps "Go" — selected stuffies animate across
4. Game checks: are any conflicting stuffies now alone together on either bank? If yes → gentle animated reaction (stuffies look scared/sad, shake), prompt to try again
5. To send stuffies back, the player drags stuffies from the right bank onto the bridge and presses "Go" (bridge is bidirectional)
6. Repeat until all stuffies are on the right bank → Win celebration
7. Progress to next level

### The "Escort Back" Mechanic
This is the heart of the puzzle. After a crossing, the player will sometimes need to drag a stuffie *back* from the right bank to the left bank (via the bridge) before they can proceed. The bridge supports both directions — crossing direction is inferred from which bank the stuffies originated. For younger players (3–4), a Hint button is available.

### Drag-and-Drop Interaction (technically non-trivial)
- Stuffie "lifts" (scales up slightly) when picked up
- Draggable to the bridge (drop zone highlighted when a stuffie is hovering near it)
- At `touchesEnded`: if dropped in bridge zone → snap to bridge; if dropped anywhere else → snap back to originating bank
- Multi-touch: each stuffie tracks its own initiating touch via UITouch identity — prevents stuffies teleporting when a second finger lands
- During `ANIMATING` state: dragging is locked; stuffies visually "wiggle" if tapped to communicate "wait"
- Tap-to-select remains as a fallback if drag proves too unreliable in toddler testing

### Conflict Communication
Each level starts with a brief "Meet the stuffies" beat: each conflict pair has a short animation showing them reacting (Lion roars, Bunny hides). This teaches rules through story, not text. **This intro must be skippable** (tap anywhere to skip) — a child replaying a level should not be forced to watch it again.

> **Note**: Moved "Meet the stuffies" out of hardest MVP work — keep it simple (a static icon overlay) initially, animate it later.

### Level Design Principles
- **Level 1** (3 stuffies, 1 conflict pair, bridge capacity 2): Gentlest version. Bear, Bunny, Lion. Rule: Lion scares Bunny — can't be left alone. Two valid solution paths keep it from feeling like a dead-end.
- **Level 2** (3 stuffies, 2 conflict pairs, bridge capacity 2): Forces the escort-back insight. Hint should be more guided here — first-time hint auto-triggers rather than waiting for the player to ask.
- **Level 3+**: 4th stuffie, more constraints, possibly lower bridge capacity.
- All rules communicated visually — no text (target audience cannot read). Use conflict icons: a small "X" or animated flash between two stuffie portraits.

---

## Technical Architecture

### Platform & Framework
- **iOS, iPad-first**, locked to **landscape orientation** (set `UISupportedInterfaceOrientations` in Info.plist on Day 1 — bridge layout assumes landscape)
- **Swift + SpriteKit**: right tool for 2D animated characters, scene management, and touch input
- **Minimum iOS**: 16.0
- **Xcode**: Use the "Game" template with SpriteKit
- **Scene scale mode**: `.resizeFill` or `.aspectFit` with explicit safe-area insets — decide before first layout and never change it (affects all coordinate math)
- **Physics**: **Disabled on all nodes** (`physicsBody = nil` by default) — puzzle game does not need physics and it introduces unpredictable behavior

### Scene Structure
```
AppDelegate / SceneDelegate
├── MenuScene              — Title screen, Play button
├── LevelSelectScene       — Grid of unlocked levels (post-MVP)
└── GameScene              — Main gameplay
    ├── BridgeNode         — Bridge visual + crossing animation path
    ├── BankNode (x2)      — Left and right banks, holds waiting stuffies
    ├── StuffieNode        — Per-stuffie sprite, owns its drag touch tracking
    └── GameStateManager   — Owns state machine, notifies nodes via delegation
```

**Important: UI buttons (Go, Undo, Hint, Restart) live in a UIKit overlay — a transparent `UIView` layered on top of the `SKView`, with `UIButton` or SwiftUI controls.** Do NOT put them in SpriteKit as `SKNode`s. This makes accessibility, tap feedback, and any future UIKit sheet presentations work correctly from the start. This is a standard SpriteKit pattern — do not skip it.

### Data Model
```swift
struct Stuffie: Identifiable {
    let id: String           // "bear", "bunny", "lion"
    let displayName: String
    let spriteName: String
    // Conflicts stored UNIDIRECTIONALLY — if bear conflicts with bunny,
    // only bear.conflicts contains "bunny" (not both). GameStateManager
    // checks both directions: a.conflicts(b) || b.conflicts(a)
    let conflicts: Set<String>
}

struct Level {
    let id: Int
    let environment: BridgeEnvironment
    let bridgeCapacity: Int
    let stuffies: [Stuffie]
    // Hand-authored hint sequence — do NOT use a solver for MVP
    // Each entry is a set of stuffie IDs to send on that move
    let hintSequence: [[String]]
    // Unlocked after completing the previous level (or id == 1)
    var isUnlocked: Bool
}

enum BridgeEnvironment { case water, lava, rope, steel }
```

All stuffie sprite sizes and anchor points are defined as **named constants** (not magic numbers) from Day 1. When real art replaces placeholder rectangles, only constants change — not layout code.

### Game State Machine
Owner: `GameStateManager` (a class, not embedded in `GameScene`). `GameScene` and nodes observe it via a `GameStateDelegate` protocol.

```
INTRO → IDLE → SELECTING → ANIMATING → CHECKING → WIN | CONFLICT_REACTION → IDLE
```
- `IDLE`: Waiting for player input. Stuffies idle-animate. Dragging enabled.
- `SELECTING`: Player has placed ≥1 stuffie on the bridge. Go button activates.
- `ANIMATING`: Stuffies walking across bridge. **All input locked.** Stuffies wiggle if touched.
- `CHECKING`: After animation completes, validate conflict rules on both banks + bridge-empty check.
- `CONFLICT_REACTION`: 1–2s animation showing the problem → back to `IDLE` (stuffies stay where they landed — player must undo or work from here).
- `WIN`: All stuffies on right bank AND bridge is empty. Celebration, then advance.

### Crossing Direction
Crossing direction is inferred from the stuffies' source bank, not from a separate direction control. When a stuffie is dropped on the bridge, it retains a reference to its `sourceBankNode`. At `ANIMATING`, all stuffies on the bridge move toward the **opposite** bank. After animation, they join that bank's node.

### Persistence
Use `UserDefaults` to store completed level IDs. `Level.isUnlocked` is computed from this at launch. Even for MVP with 2 levels, persistence must exist for the Level 2 unlock to work.

### Audio Session
Configure `AVAudioSession.sharedInstance().setCategory(.ambient)` at launch so the game **mixes with** background audio (music the child is listening to) rather than silencing it. This is the correct behavior for a children's app.

### File Structure
```
stuffie-crossing/
├── App/
│   └── GameViewController.swift   — SKView setup, UIKit overlay wiring
├── Scenes/
│   ├── MenuScene.swift
│   └── GameScene.swift
├── Nodes/
│   ├── StuffieNode.swift          — sprite + drag handling
│   ├── BridgeNode.swift
│   └── BankNode.swift
├── Models/
│   ├── Stuffie.swift
│   ├── Level.swift
│   └── GameStateManager.swift     — state machine + delegation
├── Data/
│   └── Levels.swift               — static level definitions + hint sequences
└── Assets.xcassets/
    └── (placeholder colored squares per stuffie, real art swapped in later)
```

---

## MVP Scope

### In MVP
- [ ] Xcode project setup: SpriteKit template, landscape-only, UIKit overlay pattern established
- [ ] 3 stuffie characters as colored rounded rectangles (Bear=brown, Bunny=white, Lion=yellow) — sizes as named constants
- [ ] 2 levels (Level 1: 1 conflict pair; Level 2: 2 conflict pairs with hand-authored hint sequences)
- [ ] 1 bridge environment (water)
- [ ] Drag-and-drop interaction with multi-touch safety
- [ ] Full state machine (INTRO → WIN)
- [ ] Bidirectional crossing
- [ ] Hint system using hand-authored sequences (not a solver)
- [ ] Undo and Restart buttons (UIKit overlay)
- [ ] Win celebration (bounce animation + sound)
- [ ] Conflict reaction animation (shake)
- [ ] Skippable level intro showing conflict pairs (static icons for MVP)
- [ ] `UserDefaults` persistence for level completion

### Post-MVP (ordered by value)
1. Real stuffie art (texture swap — no layout changes needed if constants are in place)
2. Additional levels (5–10 total)
3. Additional bridge environments (lava, rope, steel)
4. Level select screen
5. Animated "Meet the stuffies" intro (replace static icons)
6. Sound design (ambient environment audio, crossing sounds)
7. Expanded stuffie roster
8. **Photo-to-character feature**: user photographs real stuffed animal → game sprite (requires its own spike)

### Out of Scope (for now)
- iPhone support
- iCloud sync
- Multiplayer
- App Store submission (until MVP is validated by actual child testing)

---

## Photo-to-Character (Research Note)

Feasible options:
- **Core ML + style transfer**: On-device, no API cost, private. Vision framework removes background → ML model stylizes. Requires training or pre-trained model.
- **Third-party AI API**: Easier to build but requires API key, internet, and COPPA-compliant privacy policy.
- **Hybrid**: Background removal on-device (Vision is good at this) + cloud stylization.

Spike this separately after gameplay is proven.

---

## Legal / Distribution Note

If this app ever collects **any** data (crash logs, analytics) and is distributed to children under 13, COPPA (US) and equivalent regulations apply. This requires a privacy policy before App Store submission. Plan for this before any beta distribution. For TestFlight-only family use, not an issue.

---

## Build Sequence

**Correct order — do not skip steps or reorder:**

1. **Scaffold**: Xcode project, SpriteKit template, landscape lock, UIKit overlay skeleton, named size constants, audio session config
2. **Data model + state machine, no visuals**: `Stuffie`, `Level`, `GameStateManager` with state transitions. Unit-testable. Wire up `Levels.swift` with Level 1 and Level 2 data and hint sequences.
3. **Static render**: Place placeholder rectangles in correct positions. No interaction. Verify layout on iPad simulator.
4. **Drag-and-drop**: `StuffieNode` drag handling with multi-touch safety. Snap-to-bridge and snap-back. Test on a real device with a child's hand if possible — this is the highest-risk mechanic.
5. **Go button + state machine integration**: Pressing Go triggers `ANIMATING` → `CHECKING` → `WIN | CONFLICT_REACTION`. Log state transitions.
6. **Animations**: Walk across bridge, idle bounce, conflict shake, win celebration.
7. **Hint system**: Wire hand-authored sequences to hint button highlight.
8. **Level 2 + unlock flow**: Test difficulty curve. Auto-trigger hint on first retry.
9. **Polish**: Sounds, screen transitions, skippable level intro.
10. **Art swap**: Replace placeholder shapes with real sprites (when ready).

---

## Verification
- Run on iPad simulator (iPad Pro 12.9" or iPad Air 5th gen)
- Test all Level 1 solution paths manually
- Test all illegal combinations produce correct conflict reactions in both crossing directions
- Verify Level 2 unlock persists across app restarts
- **Real test**: Hand the iPad to the target child and observe without coaching — if they need a verbal prompt, the UX has a gap
