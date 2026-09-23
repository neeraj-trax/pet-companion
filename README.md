# Pet

A tiny desktop companion for your Mac. A blue floppy-eared dog sits at the edge of your screen,
opens a ring of your favourite apps when you rest the cursor on it, keeps things you drop on it,
and gets out of the way while you work.

## Install and open
- Open `build/Pet.dmg`, drag Pet.app into Applications, then open it. On another Mac, macOS may
  require right-click → Open the first time because the shareable app is signed locally.
- The dog-face icon appears in the menu bar; there is no Dock icon. Open Pet.app again to show
  Pet home. The menu-bar icon and right-clicking Pet both open the same short menu.
- Pet home keeps the everyday choices together: color, size and app selection.
- To rebuild on this Mac, use `./build-app.sh`, then follow `START-HERE.md` to reinstall. Use
  `./build-dmg.sh` to refresh the shareable disk image. Both require Xcode or Command Line Tools.

## Use it
- **Rest your cursor** on it for half a second → a ring of app chips fans out. The chip under the
  cursor grows like the Dock. Click to launch. The name pops out next to the chip.
- **Manage apps**: open Pet home → "Edit Apps…" to add, remove or reorder (or right-click a chip).
- **Drop** files, images, links or text on Pet → saved as copies in Stash. Open the floating shelf
  from the ring or menu; it stays over full-screen apps without opening Finder. Drag an item into
  another app, or click to select and use **Preview** (double-click also previews).
- **Remove from Stash**: select one or more items and click **Remove**. Only the Stash copies move
  to Trash; the originals stay where they were. **Undo** remains available until you close the shelf.
- **Music**: when Spotify or Apple Music is playing, a player chip appears first in the ring;
  click it to play/pause (macOS asks once for permission).
- **Move it**: drag it anywhere. Near an edge it tucks into that edge; elsewhere it stays put.
- **Out of the way**: when you type for a while or stay in one app for 15 minutes, it shrinks to
  three-quarter size and strolls along the edge.
  Move your cursor near it and it grows back. It stays visible across full-screen app Spaces.
- **Follow cursor**: choose it from Pet's right-click or menu-bar menu. Pet trails beside the
  pointer at its normal size, looks toward it when still, and changes sides near screen edges
  without repeatedly flipping. It pauses when you hover over it. Double-click Pet to stop following;
  you can also choose **Stop following** from the menu. Dragging Pet also turns follow mode off.
  The app ring stays closed until follow mode ends.
- **Click** it to poke. When follow mode is off, **double-click** to jump to the app you were using before.
- **Expressions**: its ears, eyes, face and body poses show how it feels. There is no face screen.
- Right-click menu: Open Pet home, Open Stash, Follow cursor/Stop following, Quit Pet.

## Permissions
Automation may be requested for music-app play/pause. Pet does not request microphone access.

## For developers / agents
See `AGENTS.md` for the code map, how to verify without a screen, and what is unfinished.
The shareable dog sprite sheet is `Assets/pet-dog-atlas.png`. Regenerate it and its labelled
preview from `Assets/pet-dog-source.png` with `Tools/prepare-dog-atlas.swift`. Without the atlas,
the app draws a fallback vector character. The old private robot atlas is not loaded or shipped.
