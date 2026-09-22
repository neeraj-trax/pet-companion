# Pet

A tiny desktop companion for your Mac. A blue floppy-eared dog sits at the edge of your screen,
opens a ring of your favourite apps when you rest the cursor on it, keeps things you drop on it,
and gets out of the way while you work.

## Run it
- Double-click `build/Pet.app` (or drag it to Applications first). A small Pet icon appears in the
  menu bar; there is no Dock icon.
- Double-click Pet.app to open Pet home. The dog-face menu-bar icon opens the same short menu as right-clicking Pet.
- In Pet home, turn on "Open at login" if you want it after a restart.
- To rebuild after changing code: `./build-app.sh` (needs Xcode or the Command Line Tools).
  On another Mac, right-click → Open the first time (it is signed locally).

## Use it
- **Rest your cursor** on it for half a second → a ring of app chips fans out. The chip under the
  cursor grows like the Dock. Click to launch. The name pops out next to the chip.
- **Manage apps**: open Pet home → "Edit Apps…" to add, remove or reorder (or right-click a chip).
- **Drop** files, images, links or text on it → saved to your Stash. The folder chip in the ring
  opens a floating shelf. Click an item to preview it, or drag it straight into another app.
- **Music**: when Spotify or Apple Music is playing, a player chip appears first in the ring;
  click it to play/pause (macOS asks once for permission).
- **Move it**: drag it anywhere. Near an edge it tucks into that edge; elsewhere it stays put.
- **Out of the way**: when you type for a while or stay in one app for 15 minutes, it shrinks to
  three-quarter size and strolls along the edge.
  Move your cursor near it and it grows back. It stays visible across full-screen app Spaces.
- **Click** it to poke. **Double-click** to jump to the app you were using before.
- **Expressions**: its ears, eyes, face and body poses show how it feels. There is no face screen.
- Right-click menu: Open Pet home, Open Stash, Quit Pet. Skin, size, app choices, and essential
  preferences live in Pet home. “More settings…” holds mood, quiet hours, and app-specific rules.

## Permissions
Automation may be requested for music-app play/pause. Pet does not request microphone access.

## For developers / agents
See `AGENTS.md` for the code map, how to verify without a screen, and what is unfinished.
The shareable dog sprite sheet is `Assets/pet-dog-atlas.png`. Regenerate it and its labelled
preview from `Assets/pet-dog-source.png` with `Tools/prepare-dog-atlas.swift`. Without the atlas,
the app draws a fallback vector character. The old private robot atlas is not loaded or shipped.
