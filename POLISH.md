# Plan: Polish — Sounds, Transitions, and Level Intro

## Context

The core game loop is complete across all 5 levels. This step adds three experiential layers before art:

1. **Sounds** — feedback for bridge drops, crossings, and win celebration
2. **Scene transitions** — push-slide between Menu and Game
3. **Level intro overlay** — "Meet the stuffies" conflict card shown at the start of each level, skippable

The `INTRO` state already exists in the state machine but immediately calls `introCompleted()` (a pass-through). The audio session (`.ambient`) is already configured at launch. Both are ready to be wired.

---

## 1. Sound Effects

### Sounds to source

Source from **freesound.org** — filter for **CC0** (no attribution required). Short files only.

| File | Trigger | Character | Target duration |
|------|---------|-----------|----------------|
| `crossing.mp3` | ANIMATING state begins (stuffies start walking) | Soft shuffle or light whoosh | 1–2 s |
| `plop.mp3` | Stuffie snaps onto bridge (drag success) | Soft landing thump or toy click | < 0.5 s |
| `snapback.mp3` | Stuffie snaps back to bank (drag miss) | Light boing or rubber snap | < 0.5 s |
| `win.mp3` | WIN state entered | Cheerful chime or fanfare | 2–3 s |

**CC0** means the creator has waived all copyright — use freely in any app, no attribution needed. Avoid **CC BY** (requires crediting the author in-app). Verify the license badge on each page before downloading.

Prefer **mono** files under 100 KB each. `.mp3` or `.caf` both work; `.caf` avoids iOS resampling overhead but `.mp3` is easier to source.

### Candidate sounds — open each link, hit play to audition, download the one you like

#### `crossing.mp3` — stuffies start walking across the bridge (plays once per Go tap, 1–2 s)

| Option | Notes |
|--------|-------|
| [Footsteps, Indoor, Soft — BurghRecords](https://freesound.org/people/BurghRecords/sounds/386929/) | Soft indoor steps, gentle not clompy — verify license is CC0 not CC BY |
| [Footsteps Running Away Fading 1 — Rudmer_Rotteveel](https://freesound.org/people/Rudmer_Rotteveel/sounds/316923/) | Short run of steps with natural fade, good for a quick crossing |
| [Footsteps marble NYC Interior — simong1006](https://freesound.org/people/simong1006/sounds/544602/) | Shuffle character — could feel like little toy feet pattering |

#### `plop.mp3` — stuffie snaps onto bridge after a successful drag (< 0.5 s)

| Option | Notes |
|--------|-------|
| ["Plop!" — Breviceps](https://freesound.org/people/Breviceps/sounds/447910/) | Named exactly right; Breviceps is a prolific CC0 contributor |
| [Wooden Thud (Mono) — Breviceps](https://freesound.org/people/Breviceps/sounds/449955/) | Same uploader, slightly harder landing — good if you want more weight |
| ["Plop Effect" — marokki](https://freesound.org/people/marokki/sounds/569679/) | Mouth-made plop — rounder and more playful, fits the stuffie aesthetic best |

#### `snapback.mp3` — stuffie bounces back to its bank after a missed drag (< 0.5 s)

| Option | Notes |
|--------|-------|
| [Cartoon Boing — reelworldstudio](https://freesound.org/people/reelworldstudio/sounds/161122/) | Classic cartoon spring — universally readable as "nope, try again" |
| [Bouncy Sound — Jofae](https://freesound.org/people/Jofae/sounds/368175/) | Softer bounce, less cartoonish — gentler for a 3-year-old |
| [Boing 2 — magnuswaker](https://freesound.org/people/magnuswaker/sounds/540790/) | Jaw harp boing — warmer/organic, more handmade feel |

#### `win.mp3` — all stuffies reach the far bank, level complete (2–3 s)

| Option | Notes |
|--------|-------|
| [Success Jingle — JustInvoke](https://freesound.org/people/JustInvoke/sounds/446111/) | Described as "sparkly and positive" — good energy without being loud |
| [Jingle Achievement — LittleRobotSoundFactory](https://freesound.org/people/LittleRobotSoundFactory/sounds/270404/) | Orchestral, uplifting — feels like a real reward moment; prolific CC0 contributor |
| [success.wav — grunz](https://freesound.org/people/grunz/sounds/109662/) | Simple abstract game-success tone — understated, not overwhelming |

### Asset location

```
StuffieCrossing/
└── Sounds/
    ├── crossing.mp3
    ├── plop.mp3
    ├── snapback.mp3
    └── win.mp3
```

Add `Sounds/` to the Xcode project as a **folder reference** (blue folder icon, not a group) so all files inside are bundled automatically without adding them one by one.

### Integration

`SKAction.playSoundFileNamed` handles everything — no `AVAudioPlayer` needed.

```swift
// GameScene.swift — private helper
private func playSound(_ name: String) {
    run(SKAction.playSoundFileNamed(name, waitForCompletion: false))
}
```

Call sites in `GameScene`:

```swift
// In animateStuffiesCrossing() — when ANIMATING begins
playSound("crossing.mp3")

// In handleStuffieDroppedOnBridge(_:) — snap confirmed
playSound("plop.mp3")

// In snapStuffieBackToBank(_:) — drag miss or drag away from bridge
playSound("snapback.mp3")

// In gameStateDidTransition(to: .win)
playSound("win.mp3")
```

No `SoundManager` class — `GameScene` owns all playback. The sounds follow the state machine; nothing in `GameStateManager` or the UIKit overlay needs to change.

---

## 2. Scene Transitions

Push direction reinforces spatial orientation: the game is "to the right" of the menu; later levels are "to the right" of earlier ones.

| Transition | Direction | Duration |
|------------|-----------|----------|
| Menu → Game (Play tapped) | Push left — game slides in from right | 0.35 s |
| Win → Next level | Push left — next level slides in from right | 0.40 s |
| Win → Menu (Level 5, or back button) | Push right — menu slides back in from left | 0.35 s |

```swift
// MenuScene.swift — presenting GameScene
let transition = SKTransition.push(with: .left, duration: 0.35)
view?.presentScene(gameScene, transition: transition)

// GameScene.swift — showWinCelebration(), advancing to next level
let transition = SKTransition.push(with: .left, duration: 0.40)
view?.presentScene(nextScene, transition: transition)

// GameScene.swift — returning to menu (Level 5 complete or back button)
let transition = SKTransition.push(with: .right, duration: 0.35)
view?.presentScene(menuScene, transition: transition)
```

No changes to `GameStateManager` — transitions are a view-layer concern owned entirely by the scenes.

---

## 3. Level Intro Overlay

### Design

A full-screen overlay appears when the level loads (INTRO state). It shows which stuffie pairs conflict — purely visual, no text — and dims the game behind it to make it unmissable. Tap anywhere to dismiss and begin play.

```
┌─────────────────────────────────────────────┐
│                                             │
│  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │  ← dim backdrop (alpha 0.72)
│  ░░                                     ░░  │
│  ░░  ╔═══════════════════════════════╗  ░░  │
│  ░░  ║                               ║  ░░  │
│  ░░  ║   [Ellie○]   ✕   [Lion□]     ║  ░░  │  ← one row per conflict pair
│  ░░  ║   [Bunny□]   ✕   [Duck□]     ║  ░░  │
│  ░░  ║                               ║  ░░  │
│  ░░  ║       ▶  tap to play          ║  ░░  │  ← pulsing
│  ░░  ║                               ║  ░░  │
│  ░░  ╚═══════════════════════════════╝  ░░  │
│  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │
└─────────────────────────────────────────────┘
```

- **Backdrop**: full-scene `SKSpriteNode(.black)`, alpha 0.72
- **Card**: `SKShapeNode` white rounded rect, corner radius 24, height expands per conflict count
- **Portraits**: mini versions of the stuffie's placeholder shape (48 × 48 pt), same colors as in-game
- **Conflict marker**: red `✕` `SKLabelNode` between each pair
- **Dismiss**: any touch on the overlay → fade out 0.2 s → call `introCompleted()`

### New file: `IntroOverlayNode.swift`

```swift
// StuffieCrossing/Nodes/IntroOverlayNode.swift

import SpriteKit

final class IntroOverlayNode: SKNode {
    var onDismiss: (() -> Void)?

    init(level: Level, sceneSize: CGSize) {
        super.init()
        isUserInteractionEnabled = true
        buildLayout(level: level, sceneSize: sceneSize)
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    private func buildLayout(level: Level, sceneSize: CGSize) {
        let backdrop = SKSpriteNode(color: .black, size: sceneSize)
        backdrop.alpha = 0.72
        backdrop.position = .zero
        addChild(backdrop)

        let pairs = Array(level.conflicts).sorted { $0.a < $1.a }
        let rowHeight: CGFloat = 80
        let cardHeight = CGFloat(pairs.count) * rowHeight + 100
        let cardSize = CGSize(width: 480, height: cardHeight)

        let card = SKShapeNode(rectOf: cardSize, cornerRadius: 24)
        card.fillColor = .white
        card.strokeColor = .clear
        card.position = .zero
        addChild(card)

        let totalHeight = CGFloat(pairs.count - 1) * rowHeight
        for (i, pair) in pairs.enumerated() {
            let y = totalHeight / 2 - CGFloat(i) * rowHeight + 24
            addConflictRow(pair: pair, level: level, y: y)
        }

        let tapLabel = SKLabelNode(text: "▶  tap to play")
        tapLabel.fontName = "AvenirNext-Medium"
        tapLabel.fontSize = 18
        tapLabel.fontColor = SKColor(white: 0.45, alpha: 1)
        tapLabel.verticalAlignmentMode = .center
        tapLabel.position = CGPoint(x: 0, y: -(cardSize.height / 2) + 36)
        addChild(tapLabel)

        let pulse = SKAction.repeatForever(.sequence([
            .fadeAlpha(to: 0.3, duration: 0.8),
            .fadeAlpha(to: 1.0, duration: 0.8)
        ]))
        tapLabel.run(pulse)
    }

    private func addConflictRow(pair: ConflictPair, level: Level, y: CGFloat) {
        let stuffieA = level.stuffies.first { $0.id == pair.a }
        let stuffieB = level.stuffies.first { $0.id == pair.b }
        let gap: CGFloat = 72

        if let a = stuffieA {
            let node = miniPortrait(for: a, isEscort: a.id == level.mandatoryEscortId)
            node.position = CGPoint(x: -gap, y: y)
            addChild(node)
        }

        let x = SKLabelNode(text: "✕")
        x.fontSize = 32
        x.fontColor = .red
        x.verticalAlignmentMode = .center
        x.position = CGPoint(x: 0, y: y)
        addChild(x)

        if let b = stuffieB {
            let node = miniPortrait(for: b, isEscort: b.id == level.mandatoryEscortId)
            node.position = CGPoint(x: gap, y: y)
            addChild(node)
        }
    }

    private func miniPortrait(for stuffie: Stuffie, isEscort: Bool) -> SKNode {
        let size: CGFloat = 48
        let color = StuffieNode.placeholderColor(for: stuffie.id)
        if isEscort {
            let shape = SKShapeNode(circleOfRadius: size / 2)
            shape.fillColor = color
            shape.strokeColor = color.withAlphaComponent(0.6)
            shape.lineWidth = 2
            return shape
        } else {
            let rect = CGRect(x: -size/2, y: -size/2, width: size, height: size)
            let shape = SKShapeNode(rect: rect, cornerRadius: 8)
            shape.fillColor = color
            shape.strokeColor = color.withAlphaComponent(0.6)
            shape.lineWidth = 2
            return shape
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        dismiss()
    }

    func dismiss() {
        isUserInteractionEnabled = false
        run(.sequence([
            .fadeOut(withDuration: 0.2),
            .run { [weak self] in self?.onDismiss?(); self?.removeFromParent() }
        ]))
    }
}
```

> **Access note**: `StuffieNode.placeholderColor(for:)` is currently a `private static func`. Change it to `internal static func` (remove `private`) so `IntroOverlayNode` can call it. No other callers are affected.

### Wiring in `GameScene.swift`

In `gameStateDidTransition(to:)`, replace the INTRO pass-through with overlay creation:

```swift
case .intro:
    let overlay = IntroOverlayNode(level: currentLevel, sceneSize: size)
    overlay.position = CGPoint(x: size.width / 2, y: size.height / 2)
    overlay.zPosition = ZPosition.overlay
    overlay.onDismiss = { [weak self] in
        self?.gameStateManager.introCompleted()
    }
    addChild(overlay)
```

Add `overlay: CGFloat = 100` to the `ZPosition` constants in `Constants.swift`.

---

## Files to Change

| File | Change |
|------|--------|
| `StuffieCrossing/Sounds/` | New folder — add 4 `.mp3` files |
| `StuffieCrossing/Nodes/IntroOverlayNode.swift` | New file |
| `StuffieCrossing/Nodes/StuffieNode.swift` | `placeholderColor(for:)` — remove `private` keyword |
| `StuffieCrossing/Scenes/GameScene.swift` | Handle `.intro` state; add `playSound()`; use push transitions |
| `StuffieCrossing/Scenes/MenuScene.swift` | Use push transition when presenting GameScene |
| `StuffieCrossing/App/Constants.swift` | Add `ZPosition.overlay = 100` |
| `StuffieCrossing.xcodeproj/project.pbxproj` | Add `IntroOverlayNode.swift`; add Sounds folder reference |

---

## Verification

1. `bash scripts/test.sh` — all tests still pass (no model changes)
2. **Level 1 intro**: overlay appears showing Bunny–Lion pair → tap dismisses with fade → play begins
3. **Level 5 intro**: all 5 conflict pairs visible; card expands to fit; still tap-to-dismiss
4. **Replay a level**: intro still appears (correct — child can tap it away immediately)
5. **Sounds**: bridge drop plays `plop`; crossing plays on Go; snap-back plays `snapback`; win level plays `win`
6. **Transitions**: Menu → Level 1 pushes left; Level 1 win → Level 2 pushes left; Level 5 win → Menu pushes right
7. **Audio mix**: playing music on iPad before launching — game sounds layer on top, music continues
