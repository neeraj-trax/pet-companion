# Pet — guide for agents

Read this first. It tells you what the app is, how the code is laid out, what each file owns, how to build and check it without a screen, and what is unfinished. You should not need to read every file to start.

## What it is

A macOS desktop companion (Shimeji-style). A small animated character lives on top of every window, click-through except on its body. Rest the cursor on it and a **ring of app chips** fans out around it (Dock-style magnification); click a chip to launch the app. Drop files, text, links or images on it and they are saved to **Stash**. The Stash chip opens a floating shelf in the current Space, including over full-screen apps, and its files can be dragged straight into another app without opening Finder. When you are busy it shrinks to three-quarter size and strolls along the screen edge (side edges: tucks in and peeks). Music playing in Spotify/Apple Music shows up as a player chip; while you speak on a call, sound bars show on its TV face. No permissions are required except Microphone (asked once, only when a call is already using the mic) and Automation for play/pause (asked once).

Owner: a non-technical designer. Vibe: cozy tiny friend, never a utility widget, never distracting during work.

- Native Swift + AppKit, no Xcode project, no dependencies. `swift build` compiles it.
- Character: a sprite-sheet cloud-headed robot (`Assets/pet-atlas.webp`, personal use only, not in git; see "Assets"). The old vector shark drawing remains as a fallback when the atlas is missing.
- Two agents worked on this in parallel for a while with a file split (see "Ownership"); currently one agent owns everything.

## Build, run, verify

```bash
swift build -c release                 # compile
./build-app.sh                         # compile + self-test + bundle → build/Pet.app
pkill -x Pet; open build/Pet.app       # relaunch
./build-dmg.sh                         # shareable build/Pet.dmg; private atlas excluded
```

Headless checks (there is no screenshot access for agents; use these):

```bash
.build/release/Pet --selftest                          # drives the state machine, prints selftest: OK/FAILED
.build/release/Pet --render-poses build/poses.png      # contact sheet of the character's states
.build/release/Pet --render-ring-live build/ring.png   # ring with magnification, light + dark
.build/release/Pet --render-ring-appear build/a.png    # frames of the ring pop-in
.build/release/Pet --render-ring-corners build/c.png   # ring fitted in screen corners/edges
.build/release/Pet --render-stash build/stash.png      # floating draggable file shelf
.build/release/Pet --render-icon build/icon.png        # app icon
```

Then read the PNG. `build-app.sh` refuses to bundle if the self-test fails. Self-test mode uses an off-screen synthetic pointer so the real mouse cannot interrupt a tested stroll.

Saved data: `~/Library/Application Support/Pet/shortcuts.json` (pinned apps), `~/Library/Application Support/Pet/Stash/` (dropped things), `defaults` domain `in.vellabs.pet` (position, edge, skin, mood, toggles).

## Code map (Sources/Pet)

| File | Owns | Notes |
| --- | --- | --- |
| `main.swift` | entry point, debug CLI flags | `--selftest`, `--render-*` |
| `AppDelegate.swift` | menu-bar fin icon, reopen → "Come here" | tiny |
| `PetWindow.swift` | the transparent always-on-top non-activating panel | `ignoresMouseEvents` is toggled per tick by the controller |
| `PetController.swift` | **the brain**: state machine, hover/drag/poke, edge snapping, hiding, typing detection, menu, self-test | ~1700 lines; sections are marked with `// MARK:` |
| `PetPose.swift` | `PetPose` = everything the drawing gets per frame; `PetGeometry` constants; `Coat` skins | the contract between controller and view |
| `PetView.swift` | draws the character from `PetPose`; drag-and-drop target; pose renderers | visuals agent's file |
| `Sprite.swift` | atlas metadata, playback rules, per-skin recolouring | visuals agent's file |
| `RingPanel.swift` | the app ring: `RingPanel` (window, fitting, show/hide) + `RingView` (drawing, magnification, clicks) + `RingConfig` (all tunable numbers) | |
| `RingLayout.swift` | ring geometry math + `RingPreview` debug renderers | |
| `ManageAppsWindow.swift` | "Manage apps…" window: add / remove / reorder | |
| `ShortcutStore.swift` | pinned app list, JSON | |
| `StashStore.swift` | saving dropped files/images/links/text | files copied off the main thread |
| `StashPanel.swift` | floating Stash shelf, file previews and drag-out | nonactivating; stays over full-screen apps |
| `MusicWatcher.swift` | Spotify / Apple Music now-playing via distributed notifications | |
| `MicWatcher.swift` | "user is speaking" during calls (CoreAudio running-somewhere + AVAudioEngine RMS) | |
| `UI.swift` | shared font/colour helpers | |

## How it works (the essentials)

**Loop.** `PetController.tick()` runs on a Timer whose rate adapts (60 fps while moving, 15 fps idle, 2 s while the displays sleep). Each tick: read the mouse, detect typing (`CGEventSource.secondsSinceLastEventType`, no permission), update hover, update the state machine, update the animation values into `pose`, hand `pose` to the view, tick the ring, apply the screen-edge clip mask. The pet and ring panels join every macOS Space, including full-screen app Spaces; an active-Space notification brings them back to the front after a swipe.

**States** (`PetController.State`): `idle, wandering, napping, poked, dragging, landing, shrinking, strolling, growing`. The last three are the "get out of the way" family: it shrinks to 75 % over 0.6 s (`mini` 0→1, applied as squash anchored at the feet), then strolls left/right along its edge with the running sprite rows (legs of 4–10 s, pauses, turns after a stop, never a jump), and grows back when the cursor comes within 200 pt, on hover (ring opens after growing), or when the trigger ends. Side edges use a `peek` value instead (tucked with a sliver showing, brief peeks, out when the cursor is near). `edge` is `.bottom/.top/.left/.right/.free`; `.free` means "stays where dropped" (drops more than 150 pt from any edge). Nap: the lie-down sleep exists (`afkSleepEnabled`, `flop` → the view rolls the sprite 90°) but is switched off at the owner's request; only "Nap now" naps. Idle strolls are frequent: every 4–10 s standing there is a 70 % chance (Normal mood) to shrink and stroll for 40–120 s. Variable names `diveReason`, `cruise*`, `surfaceFrom` are leftovers from the shark's dive; they now describe the stroll.

**Triggers that make it small:** idle chance (mood), steady typing for 60–90 s, 15 min in one app, "Shh for an hour", "Dive while <app> is in front". It never grows back on its own while the mouse is still. Full-screen apps do not hide it; Pet stays visible when the user swipes between Spaces.

**Interactions:** click = poke (jump). Double-click = switch to the app you used before the current one. Drop = save to Stash. The Stash ring chip opens a nonactivating shelf; click an item for a Quick Look preview or drag it into any app. Item gestures never move the shelf window. Right-click = menu. The old "Keep clipboard" ring chip and menu action were removed because their save-only behavior was unclear and duplicated the drop flow.

**Expressions:** short texts (`pose.thought`) are drawn on the character's TV face by the view (panel colours sampled from the atlas per skin), not in a bubble. `pose.listening` draws sound bars there while the user speaks. `MicWatcher` only opens the mic while some other app already has it open (a call), measures RMS with an adaptive noise floor, and needs Microphone permission once (`NSMicrophoneUsageDescription` is in Info.plist).

**Hover/click.** The pet window is click-through unless `petContains(mouse)` (hit path from `PetGeometry.hitPath`). Resting the cursor ~0.3 s on the body opens the ring; the ring window is likewise click-through except on chips. `updateHover` owns this; `RingPanel.keepsOpen(for:)` decides when the ring stays open.

**Ring fitting.** `RingPanel.show()` → `bestFit()` searches rotation × arc width × radius so no chip is off-screen or over the pet, then sizes its own window. Magnification is a continuous Dock layout in `RingView.update`.

**Pose contract.** The controller only writes `PetPose` fields (`bob, squashX/Y, tilt, facing, eyeOpen, eyeStyle, look, earPerk, mouth, chomp, smile, flop, blush, thought/thoughtAlpha, particles, walk, listening, music, discAngle, ceiling, coat …`). `submerged`/`waterline` are always 0 now (water era); the screen-edge clipping is a layer mask set by `applyScreenClip()`. The view maps them to sprite rows (see `VISUALS-HANDOFF.md` for the table). Adding a new behaviour usually means: a state or timer in the controller → a pose field → a mapping in the view.

**Mood.** `Mood` (Shy/Normal/Chatty) + quiet hours + Shh scale thought frequency, peeks and hide chance. Defaults: Normal, quiet hours off.

## Ownership (keep this split when two agents work at once)

- Since 2026-09-21 (late) one agent owns everything; the split below is only needed if two agents work at once.
- Functionality agent: everything except `PetView.swift`, `Sprite.swift`, and the drawing-related constants / `hitPath` in `PetPose.swift`.
- Visuals agent: `PetView.swift`, `Sprite.swift`, drawing constants in `PetPose.swift`. It must not rename `PetPose` fields.
- Never build while the other agent is mid-edit; one finishes, builds, then the other starts.
- Briefs: `VISUALS-BRIEF.md` (what the visuals agent was asked), `VISUALS-HANDOFF.md` (what it changed and how sprite rows map to pose fields).

## Assets

`Assets/pet-atlas.webp` is the Codex pet sprite sheet, used for the owner's own desktop only. It is **not committed** (see `.gitignore`); `build-app.sh` copies it into the app bundle when present. Without it the app draws the fallback vector character. `PET_ATLAS=<path>` overrides the location.

`build-dmg.sh` always removes the atlas from the copy placed in `build/Pet.dmg`, then re-signs that shareable copy. The local `build/Pet.app` and `/Applications/Pet.app` can continue using the atlas. A Developer ID Application certificate is not currently installed, so the DMG is ad-hoc signed and recipients may need right-click → Open once.

## Known gaps / ideas not built

- Sprite rows with no trigger yet: `failed`, `running` (laptop), `review`. Wire a pose signal in the controller, then map it in the view.
- Music: the player chip works; the "spinning disc" visual for `pose.music`/`discAngle` is not drawn yet.
- The lying-down nap is the closed-eyes idle frame rotated 90°; a real lying sprite would look better.
- Listening (mic) is untested on a real call in this environment; thresholds are in `MicWatcher.ingest`.
- Recents in the ring are disabled (`RingConfig.maxRecents = 0`) at the owner's request; the code path still works.
- Drops from Chrome/Photos that arrive as file promises are not received (only real files, images, links, text).
- Multi-monitor: edge logic uses the screen under the character; seams between monitors are avoided but not heavily tested.
- Reduce Motion: wander/hop are suppressed; the ring animation is not yet reduced.
- Ideas from `DESIGN.md` still open: size options, accessories, naming the pet, cloud/AI job status, "hold a file over the pet then drop on an app".
- `DESIGN.md` / `PLAN.md` describe the shark-era design; the state names and the hide behaviour come from there.
