# Visuals handoff — for the functionality agent

Written 2026-09-21 by the visuals agent. Read this before touching anything that references `Coat`, `PetGeometry`, or the drawing code.

## The big change: the character is now a sprite, not the vector shark

The user replaced the shark with the blue cloud-headed terminal robot (sprite sheet). Files:

- `Assets/pet-atlas.webp` — the atlas (1536×2288, 8 columns × 11 rows of 192×208 cells). `build-app.sh` now copies it into `Pet.app/Contents/Resources/`. When run from `.build/release/Pet` it is found via `../../Assets/`. `PET_ATLAS=<path>` overrides.
- `Sources/Pet/Sprite.swift` — **new.** Atlas metadata, the playback rules from `gpt-pet-exact-animation-spec.md` (nine timed rows; every non-idle state plays 3 fast cycles then the slow 6.6 s idle loop; 16 directional gaze poses on rows 9–10; reduced-motion = first frame), and per-skin recolouring.
- `Sources/Pet/PetView.swift` — draws the sprite when the atlas loads; the vector shark code is still there as a fallback if the file is missing.
- `Sources/Pet/PetPose.swift` — `Coat` and `PetGeometry` changed (details below).

**Nothing in `PetPose` was renamed.** The controller's contract is unchanged; the view *infers* which sprite row to play from the fields you already set:

| Pose signal (set by the controller) | Sprite row |
| --- | --- |
| `mouth == .surprised` (dragging) | `running-right` if `facing == 1`, else `running-left` |
| `mouth == .chomp` and `flop < 0.5` (poke, drop hover) | `jumping` |
| `mouth == .happy` (pill open, welcome) | `waving` |
| `thoughtAlpha > 0.5` | `waiting` |
| `eyeStyle == .closed` or `flop > 0.5` (nap) | idle closed-eyes frame, static, with the Zzz |
| `look` magnitude > 0.5 while idle | gaze pose for that direction |
| anything else | `idle` |

`bob`, `squashX/Y`, `tilt`, `submerged`/`waterline`, `ceiling`, `zzz`, `thought`, `particles` all still apply. `facing` no longer mirrors the drawing (the atlas has its own left/right rows). Unused rows that have no trigger yet: `failed`, `running` (laptop), `review`. If you want them, add a signal in `PetPose` and tell me; I'll map it.

## Skins (`Coat`) — what changed

`Coat` is still `String, CaseIterable`, still persisted under the same key (`pet.coat`), still built into the menu by your `for coat in Coat.allCases` loop. Changes:

1. **New case `sand`**, listed first. Raw value `"sand"`. The user picked it, so the saved default was set with `defaults write in.vellabs.pet pet.coat sand`. If no value is saved your code still falls back to `.hojiro`; consider falling back to `.sand` instead.
2. **Titles are now two-colour names** (body + glyph accent):

   | Case | Old title | New title |
   | --- | --- | --- |
   | `sand` | — | Sand + orange |
   | `hojiro` | Hojiro blue | Original blue |
   | `deep` | Deep sea | Navy + cyan |
   | `sakura` | Sakura | Coral + mint |
   | `mint` | Mint | Forest + amber |
   | `charcoal` | Charcoal | Charcoal + amber |

3. **New property `spriteTones`** → `(body: SpriteTone, accent: SpriteTone, screenHue: CGFloat)?`. `nil` for `hojiro` (untouched original art). `SpriteTone` is a new small struct `{hue, sat, val}`: absolute hue in degrees plus multipliers on the original saturation and value. `SpriteAtlas.image(for:)` recolours the atlas by region (outlines untouched, cyan glyphs → accent, white chest glyph → pale accent, dark face panel → `screenHue`, everything else → body) and caches one image per skin. First use of a skin costs ~100 ms on the main thread.
4. `body` / `shade` colours per coat were updated to match the new names. They are only used for the waterline ripples, particles, and the vector fallback. `outline` / `features` unchanged.
5. Removed: the temporary `spriteHueShift` / `spriteSaturation` / `spriteBrightness` properties that existed for about ten minutes this morning. Nothing outside `PetPose.swift` used them.

Nothing in `PetController.pickCoat` needs to change. If you show a colour swatch anywhere, use `coat.body` for the body and `coat.spriteTones?.accent` for the accent.

## Geometry constants — what changed

| Constant | Old | New | Why |
| --- | --- | --- | --- |
| `bodyCenter` | (85, 74) | (85, 74) | **unchanged on purpose** — your grab/drop-below-edge thresholds hang off it (raising it made the self-test's "released near the bottom" case dive) |
| `bodyHalfWidth` | 40 | 51 | robot is 102 pt wide |
| `bodyHalfHeight` | 46 | 46 | unchanged; `bodyBottom` stays 28, `bodyTop` stays 120 |
| `earHeight` | 24 | 28 | the cloud head reaches `earTop` = 148 |
| `hitRect` | (41, 24, 88, 120) | (30, 24, 110, 128) | |
| `submergeDepth` | 94 | 88 | ~32 pt of cloud shows when "only the fin" is out |
| `periscopeFraction` | 68/94 | 46/88 | face screen just above the water |
| `spriteScale`, `spriteCellOrigin` | — | new | sprite placement; feet on `bodyBottom` |

`hitPath()` now returns a rounded rect covering the whole robot when the atlas is present (shark silhouette otherwise). `bodyTopNow` is unchanged (120); the view adds `earHeight` itself when placing the Zzz and thought bubble. Particles you spawn at `bodyTopNow` start inside the cloud head, which looks fine, but `bodyTopNow + earHeight` would put them on top of it.

`./build-app.sh` self-test: **OK** with these values. `RingLayout` / `RingPanel` still use `bodyCenter.y - 34` and `+ 34` offsets tuned for the shark; they may want re-tuning for the taller character, that's yours.

## How to check visuals

```bash
swift build -c release && .build/release/Pet --render-poses build/poses.png
```

The sheet shows one frame per state, the waterline poses, nap, thought, and every skin. `--render-icon` renders the waving frame.

## Note on the artwork

`pet-atlas.webp` is OpenAI's Codex pet sprite sheet, copied from the user's Codex folder. Fine for the user's own desktop; do not ship it.
