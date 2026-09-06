# Sounds

Four CC0 sound effects, referenced by the `Sounds` enum in `App/Constants.swift`.
The filenames are fixed.

| File | Trigger | Source (freesound.org) | License | Length |
|------|---------|------------------------|---------|--------|
| `crossing.mp3` | Go tapped, stuffies start walking | [316923](https://freesound.org/people/Rudmer_Rotteveel/sounds/316923/) — Rudmer_Rotteveel | CC0 | 0.88 s |
| `plop.mp3` | Stuffie lands on the bridge | [569679](https://freesound.org/people/marokki/sounds/569679/) — marokki | CC0 | 0.21 s |
| `snapback.mp3` | Stuffie returns to its bank | [368175](https://freesound.org/people/Jofae/sounds/368175/) — Jofae | CC0 | 0.60 s |
| `win.mp3` | Level complete | [607207](https://freesound.org/people/Fupicat/sounds/607207/) — Fupicat | CC0 | 2.37 s |

All four are CC0 (public domain), verified against each sound page at download time —
no attribution required. **The three `win.mp3` candidates originally listed in
`POLISH.md` were CC BY, not CC0**, and were replaced with the Fupicat set.

## How these files were produced

Downloaded from freesound's public `-hq.mp3` preview (128 kbps) rather than the
original master, which requires a login. Fine for short SFX; re-pull at full quality
later if it ever matters.

Each was then trimmed to match the animation it accompanies, downmixed to mono, and
re-encoded at 128 kbps:

```bash
ffmpeg -i in.mp3 -t <dur> -af "afade=t=out:st=<start>:d=<fade>" -ac 1 -b:a 128k out.mp3
```

| File | `-t` | fade start | fade | Why |
|------|------|-----------|------|-----|
| `crossing.mp3` | 0.85 | 0.60 | 0.25 | the walk animation is only 0.55 s — the 2.95 s original ran well past it and overlapped the conflict reaction |
| `snapback.mp3` | 0.55 | 0.40 | 0.15 | snap-back move is 0.20 s |
| `plop.mp3` | — | — | — | already 0.216 s; mono downmix only |
| `win.mp3` | — | — | — | natively 2.37 s; mono downmix only |

**If you retime an animation, retime its sound.** The durations above are matched to
`GameScene`, not chosen for their own sake.

### Trim vs. pick-shorter

Prefer a clip that is natively the right length. Trimming is safe for transients
(`plop`, `snapback`) and for repetitive textures (`crossing` is footsteps — cutting
after two steps is inaudible), but it damages anything *composed*: a musical phrase
cut short reads as broken audio, not as a short sound.

`win` is the composed case, so it is **not** trimmed. The first pick — Fupicat
WinGrandPiano 521643 — was 3.81 s and had to be cut to 3.03 s, which clipped the
resolution of the flourish. Fupicat's win pack is uniformly 3.81 s, so "Congrats"
(607207, 2.37 s) was chosen instead: it fits the ~3.2 s celebration window as-is.

## Swapping a sound

Drop a replacement in under the same filename — xcodegen bundles everything under
`StuffieCrossing/`, so no project changes are needed. Verify the CC0 badge first;
CC BY requires in-app attribution.
