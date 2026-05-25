# Architecture Reference — Stuffie Crossing

This document is the living reference for how the game is built. Read it before adding levels, stuffies, or new mechanics. For original design intent see `PRD.md`; for deliberate departures from that design, see the **Departures from PRD** section at the bottom.

---

## System Overview

```
AppDelegate / SceneDelegate
└── GameViewController          — SKView + UIKit overlay wiring
    ├── SKView
    │   └── GameScene (SKScene) — main gameplay
    │       ├── BridgeNode      — bridge visual + drop zone
    │       ├── BankNode ×2     — left/right banks
    │       └── StuffieNode ×N  — sprite + per-stuffie touch tracking
    └── UIKit overlay (transparent UIView)
        └── Go / Undo / Hint / Restart buttons (UIButton)
```

All gameplay buttons live in the **UIKit overlay**, not in SpriteKit. `GameViewController` bridges them to `GameScene` via method calls (`handleGoTapped`, `handleUndoTapped`, etc.).

### Delegate boundaries

```
GameStateManager  ──GameStateDelegate──▶  GameScene
GameScene         ──GameOverlayDelegate──▶ GameViewController
```

- `GameStateDelegate.gameStateDidTransition(to:)` — scene rebuilds visuals after any state change
- `GameOverlayDelegate.gameStateDidChange(canGo:)` — view controller enables/disables Go button

`GameStateManager` never imports UIKit or SpriteKit. `GameScene` never owns state.

---

## State Machine

```
INTRO ──introCompleted()──▶ IDLE
                              │
              stuffieMovedToBridge()
                              │
                              ▼
                          SELECTING ◀──stuffieRemovedFromBridge() (if bridge non-empty)
                              │
                    goTapped() (only if wouldCrossSucceed == true)
                              │
                              ▼
                          ANIMATING
                              │
                    animationCompleted()
                              │
                              ▼
                          CHECKING
                           /     \
              all on right      otherwise
                  bank              │
                    │               ▼
                    ▼             IDLE
                   WIN
```

- **IDLE / SELECTING**: All input enabled. Stuffies can be dragged.
- **ANIMATING**: All input locked. Tapping a stuffie triggers `wiggle()`.
- **CHECKING**: Internal only — evaluates win or returns to IDLE. No UI state.
- **WIN**: Triggers celebration animation, then transitions to `MenuScene`.

> `CONFLICT_REACTION` state from the PRD was **not implemented**. See Departures from PRD.

---

## How Levels Work

### The `Level` struct

```swift
struct Level {
    let id: Int
    let environment: BridgeEnvironment   // .water or .lava (visual theme)
    let bridgeCapacity: Int              // max stuffies allowed on bridge at once
    let stuffies: [Stuffie]             // all stuffies in this level (left bank at start)
    let conflicts: Set<ConflictPair>    // pairs that cannot be left alone together
    let mandatoryEscortId: String?      // stuffie ID that must be on every crossing
    let hintSequence: [[String]]        // hand-authored solution; each entry = one crossing's IDs
    var isUnlocked: Bool                // computed from UserDefaults at launch
}
```

### `ConflictPair`

```swift
struct ConflictPair: Hashable {
    let a: String   // lexicographically smaller ID
    let b: String   // lexicographically larger ID
    init(_ x: String, _ y: String) { a = min(x, y); b = max(x, y) }
    func involves(_ id: String) -> Bool { a == id || b == id }
}
```

Canonical ordering (`a < b`) means `ConflictPair("lion","bunny") == ConflictPair("bunny","lion")`. Use `Set<ConflictPair>` for O(1) lookup. Conflict is **level-scoped** — the same stuffie can have different conflict relationships in different levels.

### Conflict check

A bank triggers a conflict if and only if **exactly 2** stuffies are present and they form a `ConflictPair`. Banks with 0, 1, or 3+ stuffies are always safe.

```swift
private func hasConflict(in bank: [Stuffie]) -> Bool {
    guard bank.count == 2 else { return false }
    return level.conflicts.contains(ConflictPair(bank[0].id, bank[1].id))
}
```

### The Ellie mechanic (`mandatoryEscortId`)

When `mandatoryEscortId` is set, `wouldCrossSucceed()` returns false unless the escort stuffie is on the bridge. This makes escort-back **structurally required** — Ellie must physically return to the starting bank to pick up each remaining stuffie. She cannot be left behind.

`wouldCrossSucceed(sourceSide:)` checks (in order):
1. State is `.idle` or `.selecting`
2. Bridge is non-empty
3. Escort is on the bridge (if `mandatoryEscortId` is set)
4. After the simulated crossing, neither bank would have a 2-alone conflict

The Go button is disabled whenever this returns false.

### Hint sequences

Each `hintSequence` entry is an array of stuffie IDs representing one crossing (which stuffies to put on the bridge for that move). The sequence is **hand-authored** — it is not solved algorithmically. Write it by walking through the puzzle move by move and verifying each step is valid with `wouldCrossSucceed`.

Direction is inferred: each move goes in whichever direction the source stuffies came from. Escort-back moves are included as single-ID entries (e.g., `["ellie"]`).

---

## The 5-Level Arc

| Level | Stuffies | Capacity | New conflict(s) | Key mechanic taught |
|-------|----------|----------|-----------------|---------------------|
| 1 | Ellie, Lion, Bunny | 2 | bunny–lion | Escort required every crossing |
| 2 | + Duck | 2 | bunny–duck | Escort-back with a passenger (forced) |
| 3 | + Bear | 2 | lion–bear | Ordering matters; wrong start = 9 moves |
| 4 | Same | 2 | bear–duck | Mid-puzzle forced move emerges |
| 5 | Same | 3 | lion–duck | Grouping mechanic; escort-back forced by new conflict |

All levels share the same 5 stuffies after Level 3. Conflicts are **additive per level** — a conflict introduced in Level 2 persists in all later levels.

---

## How to Add a New Level

1. **`StuffieCrossing/Data/Levels.swift`** — add a new `Level` constant with:
   - A unique `id`
   - `stuffies: [...]` — ordered list for initial left-bank layout
   - `conflicts: [ConflictPair(...), ...]` — all pairs that can't be left alone
   - `mandatoryEscortId` — set to the escort's ID, or `nil` for a free-form level
   - `hintSequence` — walk the puzzle manually and record each crossing
   - `isUnlocked: false` (set to `true` only for Level 1)
2. Update `allLevels()` to include the new level and set its unlock condition.
3. Update `showWinCelebration()` in `GameScene.swift` if the new level is the last one (no "next level" banner).
4. **Tests** — add a hint-path win test in `GameStateManagerTests.swift` following the pattern in the existing level tests. Derive all IDs from `level.hintSequence` and `level.mandatoryEscortId`, not from bare string literals.

---

## How to Add a New Stuffie

1. **`StuffieCrossing/Data/Levels.swift`** — add a `static let` constant:
   ```swift
   static let penguin = Stuffie(id: "penguin", displayName: "Penguin", spriteName: "stuffie_penguin")
   ```
2. **`StuffieCrossing/Nodes/StuffieNode.swift`** — add a case in `placeholderColor(for:)`:
   ```swift
   case "penguin": return SKColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 1)
   ```
   The `default: .gray` case ensures unknown IDs never crash.
3. Add the stuffie to the relevant level's `stuffies:` array.
4. Add any new `ConflictPair` entries to the level's `conflicts:` set.
5. Tests do not need updating if you follow the ID-deriving pattern — hint-path tests use `level.hintSequence` and are correct by construction.

---

## Custom Stuffie IDs (Future-Proofing)

The PRD describes a photo-to-character feature where users photograph a real stuffed animal and it becomes a game character. This means stuffie IDs will eventually be user-generated strings (e.g., `"user_photo_42"`) rather than canonical names like `"lion"`.

**The architecture already supports this:**
- `ConflictPair` uses plain `String` IDs — no enums, no hardcoded assumptions
- `mandatoryEscortId` is a plain `String?`
- `Stuffie.id` is a plain `String`
- `StuffieNode.placeholderColor(for:)` has a `default` case for unknown IDs

**What must stay true:**
- Tests must derive IDs from `level.mandatoryEscortId` and `level.hintSequence[step]`, not from bare string literals like `"ellie"` or `"lion"`. This ensures tests remain valid when custom IDs are introduced.
- Exception: tests that verify a *specific level's design* (e.g., "Level 2 has exactly one valid first move") may reference IDs by name, but should access them via `Levels.level2.stuffies` rather than bare string literals.
- `Levels.swift` static constants remain the source of truth for built-in levels. Custom levels would be constructed the same way.

---

## Testing Strategy

### What unit tests cover (`bash scripts/test.sh`)

Unit tests live in `Tests/StuffieCrossingCoreTests/GameStateManagerTests.swift` and target the `StuffieCrossingCore` SPM package (Foundation-only models — no UIKit/SpriteKit).

Tests verify the **rule engine**, not every valid path. The correct `wouldCrossSucceed` implementation guarantees any sequence of valid moves either reaches `.win` or gets stuck — exhaustive path enumeration is not needed.

**Covered by tests:**
- `ConflictPair` canonical ordering, symmetric equality, `Hashable` set containment, `involves()`
- `wouldCrossSucceed` core rules: empty bridge, missing escort, valid crossing, source-bank conflict, destination-bank conflict
- One hint-path win test per level (canonical reference solution → `.win`)
- Critical blocking cases per level (wrong first moves, forced escort-back scenarios)
- Level 5 capacity-3 enforcement
- State machine transitions: intro → idle, idle → selecting → animating → checking → win/idle
- Undo and restart
- Hint sequence indexing
- Bridge capacity enforcement
- Duplicate stuffie rejection

**Philosophy:** If the hint path reaches `.win` and the critical blocking cases are blocked, the level is correct. Alternative valid paths are guaranteed correct by the rule engine — testing them adds noise without adding confidence.

### What requires manual testing

These cannot be verified by the unit test suite:

- Go button visual state (grays out without escort, lights up with valid grouping)
- Drag-and-drop feel and multi-touch behavior (especially with a toddler's hand)
- Animation timing and visual correctness
- Level 5 bridge rendering with 3 stuffies (no overlap)
- Escort-back flow: dragging Ellie from the right bank back onto the bridge
- Level unlock persistence across app restarts
- Win celebration banner ("Level N Unlocked!" appears for levels 1–4, absent for level 5)

---

## Departures from PRD

The PRD was written before the Ellie escort mechanic and the block-upfront conflict check were designed. These are deliberate departures, not oversights.

| Topic | PRD says | Implementation | Reason |
|-------|----------|---------------|--------|
| Conflict mechanic | React-after: stuffies shake, `CONFLICT_REACTION` state | Block-upfront: Go button disabled for invalid moves | Removes async state complexity; teaches the rule proactively instead of reactively; suits the toddler UX better |
| `CONFLICT_REACTION` state | Exists in state machine | Removed | Superseded by block-upfront; Go button communicates validity without needing a reaction animation |
| Conflicts on `Stuffie` | `let conflicts: Set<String>` on `Stuffie` | `let conflicts: Set<ConflictPair>` on `Level` | Level-scoped conflicts enable the same stuffie to have different relationships per level; also future-proofs for custom stuffie IDs |
| Level 1 stuffies | Bear, Bunny, Lion | Ellie, Lion, Bunny | Ellie is the escort; Bear introduced in Level 3 to avoid overwhelming the tutorial |
| Level 2 | 3 stuffies, 2 conflict pairs | 4 stuffies (Ellie + 3), 7-move classic puzzle | Ellie mechanic enables the real wolf-goat-cabbage; more ambitious but cleaner puzzle |
| MVP level count | 2 levels | 5 levels | Better arc now than patching later; all 5 levels use the same 5 stuffies |
| Mandatory escort | Not mentioned | `mandatoryEscortId` on `Level` | Core mechanic — makes escort-back structurally required, not just suggested |
| `Stuffie.conflicts` field | Present | Removed | Replaced by `Level.conflicts: Set<ConflictPair>` |

**Not yet implemented (carry forward):**
- "Meet the stuffies" intro animation showing conflict pairs (PRD: short animated intro per level)
- Hint auto-trigger on first retry for Level 2 (PRD: "first-time hint auto-triggers")
- Conflict reaction animation — may be added as polish if block-upfront alone isn't clear enough for young players
