# Plan: Art Style Experimentation

## Context

The game uses colored shape placeholders (rectangles/circles). To evaluate what art style feels right for a toddler audience, we need to:
1. Know exactly what to ask an AI image tool for
2. Be able to drop images into Xcode and immediately see them in-game
3. Iterate on styles before committing to all 5 stuffies

The code already has `stuffie.spriteName` defined (`"stuffie_ellie"` etc.) and `Assets.xcassets` is empty and waiting — the only missing pieces are (a) actual images and (b) a small StuffieNode update to load them.

---

## Technical Requirements

### File format
**PNG with transparent background** — required for irregular shapes (stuffed animals aren't rectangles). No JPEG.

### Sizes to export
| Xcode slot | Resolution | Use |
|------------|-----------|-----|
| @2x | 160 × 160 px | All iPad Retina displays |
| @3x | 240 × 240 px | iPhone Pro (optional for iPad-only, but useful to have) |

Minimum to function: one size at 160×160 px in the @2x slot. Easiest: ask AI for 512×512, then scale down to 240 (@3x) and 160 (@2x) in Preview or Figma.

### Asset catalog naming (must match `stuffie.spriteName` exactly)
```
stuffie_ellie
stuffie_lion
stuffie_bunny
stuffie_duck
stuffie_bear
```
Each becomes a folder in Xcode: `Assets.xcassets/stuffie_ellie.imageset/`

### Design constraints
- **Square canvas** — game places each stuffie in an 80×80 pt square, centered
- **Simple silhouette** — must read clearly at 80pt (about thumbnail size). No fine detail.
- **Stuffed animal, not real animal** — plush toy look: puffy, stitched seams, button eyes
- **Ellie is special** — she's the escort who must be on every crossing. Give her a visual differentiator (crown, bow, badge, star) to reinforce her unique role

---

## Recommended Art Styles to Try

Start with **just Ellie** in each style. Load her into the game and compare before generating all 5.

### Style A — Flat vector cartoon (recommended first try)
Bold outlines, 2–3 flat colors per character, no gradients, white highlight dot on eye. Reads best at small sizes. Most consistent when generating multiple characters.

### Style B — Soft chibi / kawaii
Oversized round head (~60% of image), tiny body, big shiny eyes. Popular in toddler apps. More charming but trickier to get consistent across characters from AI.

### Style C — Plush / felt texture
Looks like actual fabric — visible stitching, slight fuzz. Most on-brand for "stuffies" but fine texture can disappear at 80pt. Worth one test to compare.

---

## AI Prompting Templates

These work in Gemini, ChatGPT (DALL-E), Midjourney, or Adobe Firefly.

### Base prompt
```
A cute [CHARACTER DESCRIPTION] stuffed animal character, [STYLE DESCRIPTOR].
Square format, transparent background, centered with padding around the edges.
Simple chunky design that reads clearly at very small sizes.
Children's app illustration, toddler-friendly, no scary features.
```

### Style descriptors
| Style | Descriptor |
|-------|-----------|
| A – Flat cartoon | `flat vector cartoon style, bold black outline, 2-3 solid colors, no gradients, white highlight on eye` |
| B – Chibi | `chibi kawaii style, round oversized head, big shiny eyes, soft pastel colors, gentle shading` |
| C – Plush | `plush stuffed animal, visible fabric texture and stitching, felt material look, soft toy aesthetic` |

### Character descriptions
| Stuffie | Add to prompt |
|---------|--------------|
| Ellie | `gray elephant stuffed animal, wearing a small gold crown to show she's the leader` |
| Lion | `golden-maned lion stuffed animal, warm amber color` |
| Bunny | `white fluffy bunny stuffed animal, long floppy ears` |
| Duck | `bright orange duck stuffed animal, rounded bill` |
| Bear | `brown teddy bear stuffed animal, classic round ears` |

### Consistency tip
Generate all 5 in one AI chat session. Generate Ellie first, then for each subsequent character say: *"Same art style as the elephant above, but now a [CHARACTER]..."* Most tools maintain visual consistency within a conversation.

---

## Code Change to Integrate Art

One change to `StuffieNode.swift` — try to load a real sprite first, fall back to the colored placeholder shape if no asset exists yet. This lets you add one stuffie's art and test it while others stay as placeholders.

### `StuffieCrossing/Nodes/StuffieNode.swift`

Change `body` from `SKShapeNode` to `SKNode` and add sprite-or-shape logic:

```swift
private let body: SKNode  // was SKShapeNode

init(stuffie: Stuffie, isEscort: Bool = false) {
    self.stuffie = stuffie

    if UIImage(named: stuffie.spriteName) != nil {
        // Real art exists in asset catalog — use it
        let sprite = SKSpriteNode(imageNamed: stuffie.spriteName)
        sprite.size = CGSize(width: StuffieSize.width, height: StuffieSize.height)
        body = sprite
    } else if isEscort {
        // Placeholder: circle for escort
        let shape = SKShapeNode(circleOfRadius: min(StuffieSize.width, StuffieSize.height) / 2)
        shape.fillColor = StuffieNode.placeholderColor(for: stuffie.id)
        shape.strokeColor = shape.fillColor.withAlphaComponent(0.6)
        shape.lineWidth = 2
        body = shape
    } else {
        // Placeholder: rounded rect
        let rect = CGRect(x: -StuffieSize.width/2, y: -StuffieSize.height/2,
                          width: StuffieSize.width, height: StuffieSize.height)
        let shape = SKShapeNode(rect: rect, cornerRadius: 12)
        shape.fillColor = StuffieNode.placeholderColor(for: stuffie.id)
        shape.strokeColor = shape.fillColor.withAlphaComponent(0.6)
        shape.lineWidth = 2
        body = shape
    }
    // physicsBody = nil already default; rest of init unchanged
    super.init()
    addChild(body)
    isUserInteractionEnabled = true
    zPosition = ZPosition.stuffieResting
}
```

`UIImage(named:)` returns nil for missing assets — the correct check. `SKTexture(imageNamed:)` always succeeds (returns a 1×1 placeholder) so it can't be used here.

`wiggle()` still works — it rotates the parent `StuffieNode`, not the body child.

### Adding an imageset in Xcode (no code needed)
1. Click `Assets.xcassets` in Project Navigator
2. Bottom-left `+` → **New Image Set**
3. Name it `stuffie_ellie` (exactly matching the spriteName)
4. Drag the 160×160 PNG into the **2x** slot
5. Build and run — Ellie shows as sprite, others remain as shapes

---

## Experimentation Workflow

1. Prompt the AI for Ellie in Style A → export PNG at 512px
2. Scale to 160×160 (@2x) using Preview (Tools → Adjust Size)
3. Add to `Assets.xcassets` as `stuffie_ellie`
4. Build and run → Ellie is a sprite, others are shapes
5. Play the game — does the style feel right for a toddler?
6. If yes: generate Lion, Bunny, Duck, Bear in the same style, add all 5
7. If no: swap Ellie's asset and try Style B or C

---

## Files to Change

| File | Change |
|------|--------|
| `StuffieCrossing/Nodes/StuffieNode.swift` | Replace body type + creation with sprite-or-shape fallback |
| `StuffieCrossing/Assets.xcassets/` | Add `.imageset` per stuffie as art is ready (done in Xcode, not code) |

No changes to `GameScene`, `Constants`, `Levels`, or `GameStateManager`.

---

## Verification

1. `bash scripts/test.sh` — all 41 tests still pass (logic unchanged)
2. Build and run — Ellie renders as sprite at correct size, others as colored shapes
3. Drag Ellie onto bridge — fits within bridge bounds, no clipping
4. Trigger conflict reaction — wiggle animation still works on sprite node
5. Once all 5 assets added: no placeholder shapes visible anywhere in any level
