# Shark Pet — Visual brief (for the visuals agent)

You own how the shark looks and moves. Another agent owns behaviour, windows, hover/drag logic, the app pill, stash, menus. Do not touch those. Read this whole file, then `Sources/Pet/PetView.swift` and `Sources/Pet/PetPose.swift`.

## Project
- Folder: `/Users/passwordis1234/Documents/claude max experiment/PET`
- Native macOS app, Swift + AppKit, no Xcode project. Everything is drawn with Core Graphics in `PetView.draw(_:)`. No sprites, no image assets.
- Build: `swift build -c release`. Bundle + launch: `./build-app.sh && open build/Pet.app` (kill the old one first: `pkill -x Pet`).
- Preview without a screen: `.build/release/Pet --render-poses build/poses.png` draws a contact sheet of 8 poses (standing, happy, chomp, nap, submerged, periscope, dragging, curious). Use it after every change and look at it.
- `.build/release/Pet --render-icon out.png` renders the app icon from the same drawing code.

## The target look
Reference sheet: `/private/tmp/claude-501/-Users-passwordis1234-Documents-claude-max-experiment/81e8a293-2b7e-4ff6-a22a-131a1430b208/images/3.webp` (chibi shark, 8 poses) and the extra notes at
`/Users/passwordis1234/Documents/Codex/2026-09-21/want-to-create-a-pet-for/outputs/shark-animation-direction.md`.

Canonical character (one design, used in every state, mirrored as a whole when it turns):
- Soft steel-blue body, cream muzzle + belly, dark navy outline of one consistent weight (~2.2pt at the current 170pt canvas). Solid colours, no textures or tiny highlights that vanish at desktop size.
- Compact pear/egg body, rounded head, gentle three-quarter view. Base is two subtle rounded body lobes, not separate shoes.
- Small dot eyes; at rest a tiny friendly mouth with two little fangs. The big toothy mouth is only for chomp and strong reactions.
- One dorsal fin, two short flippers, and a two-lobed shark tail attached to the lower back through a short thick tail stock. The tail must never look like it sprouts from a flipper or floats beside the body.
- Must still read at ~64pt tall. Current pet is ~92pt body height in a 170×170 canvas; keep the size.
- Skins (`Coat` enum in PetPose.swift): Hojiro blue, Deep sea, Sakura, Mint, Charcoal. Keep all working; only the fills change.

## What the drawing code gets from the controller (do not rename)
`PetPose` (PetPose.swift) is the whole input to drawing. Fields the controller drives every frame:
- `bob` (vertical offset), `squashX/squashY` (anchored at the feet), `tilt` (radians, applied to the whole body), `facing` (1 right / -1 left, mirrors the whole character).
- `eyeOpen` 0…1, `eyeStyle` (.open/.happy/.closed), `look` (-1…1, where the pupils point).
- `earPerk` 0…1 (fin/flipper energy: 1 = perked/lifted, 0 = drooped), `finSway` (fin lean during swimming), `tailPhase` (radians, sway), `tailWag` (amplitude multiplier), `wake` 0…1 (cruise speed).
- `mouth` (.neutral/.happy/.surprised/.sleepy/.chomp), `chomp` 0…1 (mouth opening for .chomp), `smile` 0…1 (neutral→happy blend), `blush` 0…1.
- `flop` 0…1 (1 = the nap pose: low, wide, relaxed).
- `shadow` 0…1 (ground shadow), `submerged` 0…1 + `waterline` (view-space y of the screen edge; nothing may be drawn below it while submerged; draw ripples on it), `ceiling` (nothing above it).
- `zzz`, `thought` + `thoughtAlpha` (bubble text), `particles` (glyphs "○" bubbles, "•" droplets, "♥" hearts, "✦" sparkles), `time`, `coat`.

Geometry constants in `PetGeometry` are used by hit-testing and window placement: `bodyCenter (85,74)`, `bodyHalfWidth 40`, `bodyHalfHeight 46`, `earHeight 24` (fin above the head), `bodyBottom 28`, `bodyTop 120`, `earTop 144`, `submergeDepth 94`, `periscopeFraction`. If you change the silhouette, keep `bodyBottom` as the ground contact and keep the fin tip near y≈140 so "only the fin shows" still works, or update `hitPath()` in the same file to match your new shape. Tell the functionality agent if any constant changes.

## States to make look right (all driven by the fields above)
Idle (breathing, blink, tail sway) · Happy (pill open / poke, flippers up) · Chomp (poke: mouth snaps) · Nap (flop: low, wide, eyes closed, small mouth, slow breathing) · Submerged (fin only above waterline + ripples) · Periscope (eyes and top of head above waterline) · Dragged (tilt from velocity, surprised mouth, flippers/tail trail) · Curious (small lean, one flipper lifts) · Turn (whole-character mirror, brief squash).

## Rules
- Only edit `PetView.swift` (drawing) and, if needed, the constants/`hitPath` in `PetPose.swift`. Don't edit `PetController.swift`, `LaunchPanel.swift`, `StashStore.swift`, `PetWindow.swift`, `AppDelegate.swift`, `main.swift`.
- Keep `IconRenderer.render`, `renderPoses`, `renderPill` working (they're in PetView.swift).
- No new dependencies, no image files. Vector only.
- After changes: build, render the pose sheet, look at it, fix, repeat. Then `./build-app.sh` (it runs a self-test) and relaunch.
- Report what changed and paste the pose sheet path.
