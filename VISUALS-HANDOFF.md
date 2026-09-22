# Visuals handoff

Current character: the blue floppy-eared dog. This replaces the private robot atlas. Read `AGENTS.md` for the app's general code map.

## Art and build

- `Assets/pet-dog-source.png` is the supplied 1027×1531 grid sheet. It has blue generation guides and is not loaded by Pet.
- `Tools/prepare-dog-atlas.swift` removes the guides, retains complete paws, and normalizes all 73 used frames into `Assets/pet-dog-atlas.png` (1536×2288, 8 columns × 11 rows, 192×208 cells). Soles sit about 30 px above each cell bottom. The output is transparent and unlabelled.
- `Assets/pet-dog-atlas-preview.png` is the separate labelled review sheet. Regenerate both outputs with `swift Tools/prepare-dog-atlas.swift Assets/pet-dog-source.png Assets/pet-dog-atlas.png Assets/pet-dog-atlas-preview.png`.
- `build-app.sh` bundles only `pet-dog-atlas.png`. `build-dmg.sh` includes it in the shareable disk image. The old `Assets/pet-atlas.webp` is ignored by Git, not loaded, and never shipped.

## Sprite mapping

| Row (one-based) | Artwork | Trigger |
| --- | --- | --- |
| 1 | Idle, including blink | Default |
| 2 | Walk right | `pose.walk > 0`, or right-facing drag |
| 3 | Walk left | `pose.walk < 0`, or left-facing drag |
| 4 | Wave | Happy/pill-open pose; frame 2 is the app icon |
| 5 | Jump | Poke/drop-hover pose |
| 6 | Gentle oops | Not triggered by the controller yet; frame 3 is used for curled-up nap |
| 7 | Waiting | `pose.thoughtAlpha > 0.5` |
| 8 | Laptop | Not triggered yet |
| 9 | Celebration | Not triggered yet |
| 10–11 | Sixteen real gaze views | Idle look direction through `SpriteAtlas.lookFrame`; the source cells are not ordered by angle, so the function maps sectors to views |

All non-walking triggered rows play three fast cycles then return to slow idle. Walk loops while `pose.walk` is nonzero. The sprite does not mirror; left and right walking have separate rows. Nap draws the actual curled-up frame without rotating the dog. No robot face-screen overlays or sound bars are drawn.

## Geometry and colour

- `PetGeometry.spriteScale = 0.82` makes the idle dog about 108 pt tall. The atlas cell is centred on `bodyCenter.x` and anchored so its sole at top-down pixel 177 sits on `bodyBottom = 28`.
- The dog fits x 11…180 within each cell. `hitRect` and `hitPath` cover its ears, tail and paws; nap has a lower, wider hit path. `earTop` is 167 pt for edge fitting.
- `Coat.spriteTone` changes only blue fur pixels. Black eyes, nose, mouth and outline, plus the grey laptop, retain their original colours. `.hojiro` is the original blue and the other saved skin keys remain valid.

Verify with `swift build -c release`, `.build/release/Pet --selftest`, `./build-app.sh`, `--render-poses`, `--render-icon`, and `--render-ring-live`. Inspect the pose sheet at one-third scale to see the character around 100–120 px tall. Check the labelled atlas separately for paw completeness and limb count.
