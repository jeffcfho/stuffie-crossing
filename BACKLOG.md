# Backlog

Known issues, found during device testing on 2026-09-06 (iPad 6th gen, iPadOS 16.6).
Ordered by severity. None are blocking — the game is playable end to end.

---

## 1. Mixed-direction bridge duplicates a stuffie — *correctness*

> **Fixed** on `fix/mixed-direction-bridge`. Covered by 5 tests in
> `GameStateManagerTests`, verified to fail when the guard is removed.


Dragging a left-bank stuffie and a right-bank stuffie onto the bridge together and
tapping Go duplicates one of them: a second Ellie appears on the right bank.

**Cause.** `GameScene.currentBridgeSourceSide()` takes the source bank of the *first*
stuffie on the bridge and applies it to everyone:

```swift
stateManager.onBridge.compactMap { stuffieNodes[$0.id]?.sourceBankNode?.side }.first ?? .left
```

`GameStateManager.applyBridgeCrossing(from:)` then does, for `.left`:

```swift
leftBank.removeAll { s in crossers.contains { $0.id == s.id } }
rightBank.append(contentsOf: crossers)
```

For a stuffie that was actually on the *right* bank, the removal matches nothing and
the append adds it to `rightBank` where it already is — so it exists twice.

**Not just cosmetic.** The win condition is
`rightBank.count == level.stuffies.count && leftBank.isEmpty`, and that count can now
be inflated by duplicates.

**Fix.** Guard in `stuffieMovedToBridge` — reject a stuffie whose source side differs
from whatever is already on the bridge. The bridge should only ever hold one
direction. Needs a unit test in `GameStateManagerTests`.

---

## 2. Conflict rules vanish after the intro — *UX*

> **Fixed** on `feat/persistent-rules` via `RulesBadgeNode` — a slim strip of the
> conflict pairs pinned along the top for the whole level. Shows conflicts only; the
> escort rule is item 3 and waits for art.


`IntroOverlayNode` shows which pairs conflict, then disappears on tap and never
returns. A 3-year-old cannot re-check the rules mid-puzzle without hitting Restart.

**Fix direction.** Keep a persistent, smaller version of the conflict rows on screen
during play — a corner card or a strip along one edge. The layout already computes
per-pair rows, so the drawing code is reusable; it needs a placement that doesn't
collide with the banks or the UIKit button row along the bottom.

Relates to PRD.md's own acceptance test: *"Hand the iPad to the target child and
observe without coaching — if they need a verbal prompt, the UX has a gap."*

---

## 3. Nothing signals that Ellie must cross every time — *UX*

> **Deliberately deferred until after the art swap (step 10).** This item is really
> two problems, and art only solves one of them:
>
> - *"Which one is special"* — a distinctive Ellie sprite solves this on its own. A
>   grey circle never will. Designing a marker now means throwing it away later.
> - *"Ellie must be on every crossing"* — art cannot solve this. It is a rule, not an
>   identity, and no sprite communicates "mandatory."
>
> So do the art first, then revisit: the remaining work is likely just feedback for
> the tapped-but-disabled Go button, which is much smaller than this entry implies.


The mandatory-escort rule is the core mechanic and is communicated nowhere. It is
enforced silently in `canTapGo(sourceSide:)`, which just leaves Go disabled. A child
sees a dead button and no reason for it.

Ellie is drawn as a circle where everyone else is a rounded square, but nothing
explains what that shape *means*.

**Fix direction.** Some affordance on Ellie herself (a highlight, a marker) plus a
reaction when Go is tapped-but-disabled — right now that tap does nothing at all.

---

## 4. Two-finger drag doesn't work — *input*

Only one stuffie can be dragged at a time.

**Cause.** `UIView.isMultipleTouchEnabled` defaults to `false` and is never set — grep
the project, it appears nowhere. The `SKView` therefore delivers a single touch at a
time. The per-node `activeTouch` tracking in `StuffieNode` is already correct; it just
never receives a second touch.

**Fix.** One line in `GameViewController.configureSKView()`:

```swift
skView.isMultipleTouchEnabled = true
```

Worth doing carefully rather than blindly — enabling it is exactly what the
`activeTouch` guards were written for, but that path has never actually executed, so
it wants real device testing with two fingers.

---

## 5. No sound on the conflict reaction — *polish gap*

`animateConflictReaction()` plays no sound — it is wiggle + "!" puff only. POLISH.md
only ever specified four sounds and the conflict wasn't one of them.

This is arguably the moment that most needs audio feedback for a toddler: it's the
only "you did something wrong" signal in the game. Would need a fifth CC0 clip, added
to the `Sounds` enum in `Constants.swift`.

---

## Verified working on device (2026-09-06)

iPad 6th gen (A10), iPadOS 16.6:

- Audio mixing — background music keeps playing under the game (`.ambient` category)
- Drag latency — fine on A10 hardware
- `crossing.mp3` timing — 0.88 s clip reads as walking against the 0.55 s animation
- All four sounds fire at the right moments


---

## Suggested order of work

Agreed 2026-09-06/07. Items 1 and 2 are done and merged to `main`.

1. ~~Mixed-direction duplicate bug~~ — done
2. ~~Persistent conflict rules~~ — done
3. **Art swap (PRD step 10, see `VISUALS.md`)** — next
4. Escort affordance (item 3 above) — after art, for the reasons given there
5. Two-finger drag (item 4) and conflict sound (item 5) — small and independent,
   can be picked up any time

### Note for whoever picks this up

Two things worth knowing that aren't obvious from the code:

- **Nothing here has been tested on hardware since the sound work.** Items 1 and 2
  were verified by unit tests and on the simulator only. The iPad kept dropping off
  USB (a marginal Lightning cable on an iPad 6th gen). `scripts/test.sh` covers the
  logic; drag feel and layout on a real 1024x768 screen are unverified.
- **The rules strip's layout was checked arithmetically, not visually, at Level 5** —
  its widest case, 5 conflict pairs, ~694pt of ~1024pt. Worth an actual look.
