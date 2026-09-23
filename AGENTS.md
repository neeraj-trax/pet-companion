# Pet — guide for agents

Read this first. It tells you what the app is, how the code is laid out, what each file owns, how to build and check it without a screen, and what is unfinished. You should not need to read every file to start.

## What it is

A macOS desktop companion (Shimeji-style). A small animated character lives on top of every window, click-through except on its body. Rest the cursor on it and a **ring of app chips** fans out around it (Dock-style magnification); click a chip to launch the app. Drop files, text, links or images on it and they are saved to **Stash**. The Stash chip opens a floating shelf in the current Space, including over full-screen apps, and its files can be dragged straight into another app without opening Finder. A click selects an item, double-click or Preview opens Quick Look, and Remove moves only the Stash copy to Trash with Undo until the shelf closes. When you are busy Pet shrinks to three-quarter size and strolls along the screen edge (side edges: tucks in and peeks). Music playing in Spotify/Apple Music shows up as a player chip. Automation permission may be requested for play/pause.

Opening Pet.app again, or choosing **Open Pet home…** from either menu, opens a compact native window with a quiet live preview and only Color, Size (85–115%), and Apps with an Edit Apps shortcut. Changes apply immediately and save automatically. Stash remains available from the menu and ring. Previously saved edge/privacy/login, mood, quiet-hours, and app-specific compact preferences still apply but are not shown in Pet home.

Owner: a non-technical designer. Vibe: cozy tiny friend, never a utility widget, never distracting during work.

- Native Swift + AppKit, no Xcode project, no dependencies. `swift build` compiles it.
- Current character: the blue floppy-eared dog in `Assets/pet-dog-atlas.png` (committed and shareable). The old vector shark remains as a fallback if the PNG is missing. The private robot atlas remains on this Mac but is neither loaded nor shipped.
- Two agents worked on this in parallel for a while with a file split (see "Ownership"); currently one agent owns everything.

## Build, run, verify

```bash
swift build -c release                 # compile
./build-app.sh                         # compile + self-test + bundle → build/Pet.app
pkill -x Pet; rm -rf /Applications/Pet.app
ditto --noextattr --noqtn build/Pet.app /Applications/Pet.app
xattr -cr /Applications/Pet.app
codesign --force --deep --sign - /Applications/Pet.app
open /Applications/Pet.app            # reinstall and relaunch
./build-dmg.sh                         # shareable build/Pet.dmg; dog atlas included
```

Headless checks (there is no screenshot access for agents; use these):

```bash
.build/release/Pet --selftest                          # drives the state machine, prints selftest: OK/FAILED
.build/release/Pet --render-poses build/poses.png      # contact sheet of the character's states
.build/release/Pet --render-ring-live build/ring.png   # ring with magnification, light + dark
.build/release/Pet --render-ring-appear build/a.png    # frames of the ring pop-in
.build/release/Pet --render-ring-corners build/c.png   # ring fitted in screen corners/edges
.build/release/Pet --render-stash build/stash.png      # floating draggable file shelf
PET_STASH_RENDER_SELECTED=1 .build/release/Pet --render-stash build/stash-selected.png # selection controls
.build/release/Pet --render-home build/home.png        # simplified Pet home window
.build/release/Pet --render-icon build/icon.png        # app icon
```

Then read the PNG. `build-app.sh` refuses to bundle if the self-test fails. Self-test mode uses an off-screen synthetic pointer so the real mouse cannot interrupt a tested stroll.

Saved data: `~/Library/Application Support/Pet/shortcuts.json` (pinned apps), `~/Library/Application Support/Pet/Stash/` (dropped things), `defaults` domain `in.vellabs.pet` (position, edge, skin, mood, toggles).

## Code map (Sources/Pet)

| File | Owns | Notes |
| --- | --- | --- |
| `main.swift` | entry point, debug CLI flags | `--selftest`, `--render-*` |
| `AppDelegate.swift` | menu-bar dog icon, reopen → Pet home | tiny |
| `PetWindow.swift` | the transparent always-on-top non-activating panel | `ignoresMouseEvents` is toggled per tick by the controller |
| `PetController.swift` | **the brain**: state machine, hover/drag/poke, edge snapping, hiding, typing detection, menu, self-test | ~1700 lines; sections are marked with `// MARK:` |
| `PetPose.swift` | `PetPose` = everything the drawing gets per frame; `PetGeometry` constants; `Coat` skins | the contract between controller and view |
| `PetView.swift` | draws the character from `PetPose`; drag-and-drop target; pose renderers | visuals agent's file |
| `Sprite.swift` | atlas metadata, playback rules, per-skin recolouring | visuals agent's file |
| `RingPanel.swift` | the app ring: `RingPanel` (window, fitting, show/hide) + `RingView` (drawing, magnification, clicks) + `RingConfig` (all tunable numbers) | |
| `RingLayout.swift` | ring geometry math + `RingPreview` debug renderers | |
| `ManageAppsWindow.swift` | "Manage apps…" window: add / remove / reorder | |
| `PetHomeWindow.swift` | compact Pet home window, live preview, color, size, apps | |
| `ShortcutStore.swift` | pinned app list, JSON | |
| `StashStore.swift` | saving dropped files/images/links/text; moving Stash copies to Trash and restoring them | files copied off the main thread |
| `StashPanel.swift` | floating Stash shelf, selection, preview, drag-out, Remove/Undo | nonactivating; stays over full-screen apps |
| `MusicWatcher.swift` | Spotify / Apple Music now-playing via distributed notifications | |
| `MicWatcher.swift` | dormant microphone reaction code, not instantiated or permissioned | Keep dormant until a future character behavior needs it. |
| `UI.swift` | shared font/colour helpers | |

## How it works (the essentials)

**Loop.** `PetController.tick()` runs on a Timer whose rate adapts (60 fps while moving, 15 fps idle, 2 s while the displays sleep). Each tick: read the mouse, detect typing (`CGEventSource.secondsSinceLastEventType`, no permission), update hover, update the state machine, update the animation values into `pose`, hand `pose` to the view, tick the ring, apply the screen-edge clip mask. The pet and ring panels join every macOS Space, including full-screen app Spaces; an active-Space notification brings them back to the front after a swipe.

**States** (`PetController.State`): `idle, wandering, napping, poked, dragging, landing, shrinking, strolling, growing`. The last three are the "get out of the way" family: it shrinks to 75 % over 0.6 s (`mini` 0→1, applied as squash anchored at the feet), then strolls left/right along its edge with the running sprite rows (legs of 4–10 s, pauses, turns after a stop, never a jump), and grows back when the cursor comes within 200 pt, on hover (ring opens after growing), or when the trigger ends. Side edges use a `peek` value instead (tucked with a sliver showing, brief peeks, out when the cursor is near). `edge` is `.bottom/.top/.left/.right/.free`; `.free` means "stays where dropped" (drops more than 150 pt from any edge). The curled-up nap remains implemented (`pose.napping`) but is not exposed in the simple menus. Idle strolls are frequent: every 4–10 s standing there is a 70 % chance (Normal mood) to shrink and stroll for 40–120 s. Variable names `diveReason`, `cruise*`, `surfaceFrom` are leftovers from the shark's dive; they now describe the stroll.

**Triggers that make it small:** idle chance (mood), steady typing for 60–90 s, 15 min in one app, and app-specific compact rules. Previously saved rules continue to apply; the simplified Pet home does not edit them. The simple menus do not offer manual stroll, Shh, or nap. It never grows back on its own while the mouse is still. Full-screen apps do not hide it; Pet stays visible when the user swipes between Spaces.

**Interactions:** click = poke (jump). Double-click normally switches to the app you used before the current one. The right-click and menu-bar menus can enable Follow cursor; Pet trails beside the pointer at full size, switches sides near screen edges to leave the pointer clear, pauses when hovered or pressed, and double-clicking it turns follow mode off. Dragging it also turns the mode off. Follow mode is stored as `pet.followCursor`, suppresses autonomous strolls and the hover ring while active, and stops in place when disabled. Drop = save to Stash. The Stash ring chip opens a nonactivating shelf; single-click selects, double-click or Preview opens Quick Look, drag sends a file into another app, and Remove moves selected Stash copies to Trash. Undo restores the recent removals until the shelf closes. Item gestures never move the shelf window. Right-click = menu. The old "Keep clipboard" ring chip and menu action were removed because their save-only behavior was unclear and duplicated the drop flow.

**Pet home/settings.** The menu bar menu and Pet's right-click menu contain “Open Pet home…”, “Open Stash”, a Follow cursor toggle, and “Quit Pet”. Reopening Pet.app also opens home. Pet home contains only color, size, and app choices beside a plain live preview. `PetHomeWindowController` calls the public setting methods on `PetController`, so the desktop character updates live. The size setting is stored as `pet.displayScale`; valid values are clamped to 0.85–1.15 and scale around the feet so Pet stays on the same screen edge. Hit-testing, ring placement and edge fitting use the scaled silhouette too. The home window returns focus to the previously active app when it closes.

**Expressions:** The dog uses its own face and body poses; no text or sound bars are painted over the face. `pose.thoughtAlpha` selects the waiting row. The microphone watcher is not instantiated and Pet does not request microphone permission. `pose.napping` selects the curled-up dog frame immediately; `eyeStyle`/`eyeOpen` still blink the standing dog in Pet home and idle. The menu-bar icon is a dog face, and the empty Stash/focus menu labels use dog-appropriate language.

**Hover/click.** The pet window is click-through unless `petContains(mouse)` (hit path from `PetGeometry.hitPath`). Resting the cursor ~0.3 s on the body opens the ring; the ring window is likewise click-through except on chips. `updateHover` owns this; `RingPanel.keepsOpen(for:)` decides when the ring stays open.

**Ring fitting.** `RingPanel.show()` → `bestFit()` searches rotation × arc width × radius so no chip is off-screen or over the pet, then sizes its own window. Magnification is a continuous Dock layout in `RingView.update`.

**Pose contract.** The controller only writes `PetPose` fields (`bob, squashX/Y, tilt, facing, eyeOpen, eyeStyle, look, earPerk, mouth, chomp, smile, flop, blush, thought/thoughtAlpha, particles, walk, listening, music, discAngle, ceiling, coat …`). `submerged`/`waterline` are always 0 now (water era); the screen-edge clipping is a layer mask set by `applyScreenClip()`. The view maps them to dog sprite rows (see `VISUALS-HANDOFF.md` for the table). Adding a new behaviour usually means: a state or timer in the controller → a pose field → a mapping in the view.

**Mood.** `Mood` (Shy/Normal/Chatty) + quiet hours + Shh scale thought frequency, peeks and hide chance. Defaults: Normal, quiet hours off.

## Ownership (keep this split when two agents work at once)

- Since 2026-09-21 (late) one agent owns everything; the split below is only needed if two agents work at once.
- Functionality agent: everything except `PetView.swift`, `Sprite.swift`, and the drawing-related constants / `hitPath` in `PetPose.swift`.
- Visuals agent: `PetView.swift`, `Sprite.swift`, drawing constants in `PetPose.swift`. It must not rename `PetPose` fields.
- Never build while the other agent is mid-edit; one finishes, builds, then the other starts.
- Briefs: `VISUALS-BRIEF.md` (what the visuals agent was asked), `VISUALS-HANDOFF.md` (what it changed and how sprite rows map to pose fields).

## Assets

`Assets/pet-dog-source.png` is the supplied grid sheet. `Tools/prepare-dog-atlas.swift` cleans and normalizes it into transparent `Assets/pet-dog-atlas.png` (1536×2288, 8×11 cells of 192×208) and a separate labelled `Assets/pet-dog-atlas-preview.png`. All used cells have paws/soles about 30 px above their bottoms. `build-app.sh` bundles only the unlabelled dog PNG; `build-dmg.sh` keeps it in the shareable app. `PET_ATLAS=<path>` can override the atlas for testing. The old `Assets/pet-atlas.webp` remains private and ignored by Git, and no default loader path points to it. A Developer ID Application certificate is not currently installed, so the DMG is ad-hoc signed and recipients may need right-click → Open once.

The project is in a synced Documents folder, which can add Finder/file-provider attributes that invalidate a signature there. `build-dmg.sh` stages the shareable copy under `/private/tmp`, clears attributes, signs it, and verifies its signature before packaging. Use `ditto --noextattr --noqtn` and re-sign when installing in `/Applications`. A snapshot request from a sandboxed shell may not reach the running app; retry the `--snapshot` command with local process permissions and check the output file's modification time.

On 2026-09-23 the dog stability pass verified `swift build -c release`, self-test, pose/ring/corner/Stash/icon renders, app bundling, DMG checksum, installed signature, and a fresh running-app snapshot. Blink remains a standing pose, nap starts curled up, the menu-bar icon depicts the dog, and old shark wording is gone from the live menu. An earlier push was rejected because ownership of the private remote was unverified. The owner subsequently confirmed `https://github.com/neeraj-trax/pet-companion.git` as the intended destination and explicitly authorized pushing; `main` was pushed successfully through `6e27bbc`.

The subsequent interface pass shortened both the menu-bar and right-click menus to Pet home, Stash, and Quit. Pet home now shows only skin, app ring, size, Stash, and three essentials (edge hugging, screenshot privacy, login startup); an unobtrusive “More settings…” menu keeps mood, quiet hours, and saved app-specific compact rules editable. The 2026-09-23 build passed self-test, pose/ring renders, installed signature, live UI inspection, running-app snapshot, and the refreshed DMG checksum.

The next code/UI pass fixed Pet home's return-focus tracking when an already-open window is brought forward and removed unused handlers left by the menu simplification. The Stash shelf now has readable file tiles, selection, explicit Preview and Remove actions, and inline Undo. `StashStore.removeFromStash` only accepts direct children of the Stash folder and uses macOS Trash; a temporary hidden-file check exercised remove and restore and verified that a file outside Stash cannot be removed, without touching user items. The debug Stash renderer accepts `PET_STASH_RENDER_SELECTED=1` to show the selected state. Final release build and self-test passed; pose, ring, icon, default Stash, and selected Stash renders were inspected. The DMG checksum, bundled dog atlas, installed app signature, and fresh running-app snapshot were verified.

The following home simplification removed the extra switches, More settings menu, and Stash button from Pet home, leaving only Color, Size, and Apps beside a plain live preview. Their stored preference values and underlying behavior were kept. `--render-home` provides a headless window render. The release build, self-test, pose/ring/Stash/home renders, refreshed DMG checksum, installed signature, fresh snapshot, and live window inspection passed.

The cursor-follow pass added a persisted Follow cursor toggle to the right-click and menu-bar menus. While enabled, Pet stays full-size, trails at a clear offset, changes sides near screen edges, pauses when hovered or pressed, and keeps the ring closed. Double-clicking or dragging Pet disables the mode; normal double-click app switching remains when follow is off. The expanded self-test covers movement, screen-edge clearance, hover pause, double-click off, and drag off. Release build, renders, DMG checksum, installed signature, and fresh snapshot passed. A live menu selection enabled the mode and the running snapshot confirmed movement; direct GUI automation could not reliably click the moving transparent window, so the OS-level double-click gesture remains for the owner to try. The installed app was left with follow mode off.

## Known gaps / ideas not built

- Sprite rows with no trigger yet: gentle oops, laptop, celebration. Wire a pose signal in the controller, then map it in the view.
- Music: the player chip works; the "spinning disc" visual for `pose.music`/`discAngle` is not drawn yet.
- Nap uses the sheet's own closed-eyes lying pose.
- Recents in the ring are disabled (`RingConfig.maxRecents = 0`) at the owner's request; the code path still works.
- Drops from Chrome/Photos that arrive as file promises are not received (only real files, images, links, text).
- Multi-monitor: edge logic uses the screen under the character; seams between monitors are avoided but not heavily tested.
- Reduce Motion: wander/hop are suppressed; the ring animation is not yet reduced.
- Ideas from `DESIGN.md` still open: accessories, naming the pet, cloud/AI job status, "hold a file over the pet then drop on an app".
- `DESIGN.md` / `PLAN.md` describe the shark-era design; the state names and the hide behaviour come from there.
