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
| 2 | Walk right | `pose.walk > 0` |
| 3 | Walk left | `pose.walk < 0` |
| 4 | Wave | Happy/pill-open pose; frame 2 is the app icon |
| 5 | Jump | Poke/drop-hover pose |
| 6 | Gentle oops | Not triggered by the controller yet; frame 3 is used for curled-up nap |
| 7 | Waiting | Unused; routine thought signals keep the neutral idle pose |
| 8 | Laptop | Not triggered yet |
| 9 | Celebration | Not triggered yet |
| 10–11 | Sixteen supplied rotation views | Only the forward-facing cells V1–V3 are used for cursor tracking; back and full-profile views remain in the atlas but are not selected by pointer direction |

All non-walking triggered rows play three fast cycles then return to slow idle. Walk loops while `pose.walk` is nonzero. The sprite does not mirror; left and right walking have separate rows. Nap draws the actual curled-up frame without rotating the dog. While dragging, `pose.held` fixes the front-facing idle frame, draws a small collar beneath the face, and pivots the whole sprite at `PetGeometry.collarPoint`, which the controller attaches to the cursor after a short pickup transition. The paws swing below the closed-hand cursor instead of walking in mid-air. The controller supplies a restrained struggle and a short fall-and-settle on release; Reduce Motion suppresses both. Routine idle thought signals no longer select the repeated waiting row; the sprite path does not currently draw a thought bubble. No robot face-screen overlays or sound bars are drawn.

`pose.look.x` is a world-space direction. `SpriteAtlas.lookView` selects a front-facing pose from waiting F3–F4 (pointer above) or gaze V1–V3 (beside/below), mirroring the left/right turns as needed. Only the mirrored vector fallback converts the x direction to body-local coordinates. The pose renderer includes eight labelled pointer directions and uses the same selection and mirroring path as the live dog.

## Geometry and colour

- `PetGeometry.spriteScale = 0.82` makes the idle dog about 108 pt tall. The atlas cell is centred on `bodyCenter.x` and anchored so its sole at top-down pixel 177 sits on `bodyBottom = 28`.
- The dog fits x 11…180 within each cell. `hitRect` and `hitPath` cover its ears, tail and paws; nap has a lower, wider hit path. `earTop` is 167 pt for edge fitting.
- The corner dog bed draws the closed-eye pose from row 6, column 2 (one-based) inside a small native cushion. The original on-screen nap uses row 6, column 3; the bed uses the more legible closed-eye frame.
- `Coat.spriteTone` changes only blue fur pixels. Black eyes, nose, mouth and outline, plus the grey laptop, retain their original colours. `.hojiro` is the original blue and the other saved skin keys remain valid.

Verify with `swift build -c release`, `.build/release/Pet --selftest`, `./build-app.sh`, `--render-poses`, `--render-icon`, and `--render-ring-live`. Inspect the pose sheet at one-third scale to see the character around 100–120 px tall. Check the labelled atlas separately for paw completeness and limb count.
