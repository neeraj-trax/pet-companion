# Pet

A tiny desktop companion for your Mac. A cloud-headed robot sits at the edge of your screen,
opens a ring of your favourite apps when you rest the cursor on it, keeps things you drop on it,
and gets out of the way while you work.

## Run it
- Double-click `build/Pet.app` (or drag it to Applications first). A small fin icon appears in the
  menu bar; there is no Dock icon.
- Lost it? Click the menu-bar icon → "Come here", or double-click Pet.app again.
- Right-click the pet → "Open at login" so it comes back after a restart.
- To rebuild after changing code: `./build-app.sh` (needs Xcode or the Command Line Tools).
  On another Mac, right-click → Open the first time (it is signed locally).

## Use it
- **Rest your cursor** on it for half a second → a ring of app chips fans out. The chip under the
  cursor grows like the Dock. Click to launch. The name pops out next to the chip.
- **Manage apps**: right-click → "Manage apps…" to add, remove or reorder (or right-click a chip).
- **Drop** files, images, links or text on it → saved to your Stash. The folder chip in the ring
  opens it (`~/Library/Application Support/Pet/Stash/`). The clipboard chip keeps what you last copied.
- **Music**: when Spotify or Apple Music is playing, a player chip appears first in the ring;
  click it to play/pause (macOS asks once for permission).
- **Move it**: drag it anywhere. Near an edge it tucks into that edge; elsewhere it stays put.
- **Out of the way**: when you type for a while, when you've been in one app for 15 minutes, or
  when you pick "Shh for an hour", it shrinks to half size and strolls along the edge. Move your
  cursor near it and it grows back. Fullscreen apps hide it completely.
- **Click** it to poke. **Double-click** to jump to the app you were using before.
- **Sleep**: 10 seconds without mouse or keyboard and it lies down; any input wakes it.
- **Talks on its screen**: little messages and expressions show on its TV face. During a call,
  sound bars appear while you speak (macOS asks once for microphone access).
- Right-click menu: apps, clipboard, stash, hide, nap, come here, shh, skin, mood, quiet hours,
  dive-while-app, hug edges, hide from screenshots, open at login, quit.

## Permissions
None required. Play/pause asks for Automation access to the music app the first time.

## For developers / agents
See `AGENTS.md` for the code map, how to verify without a screen, and what is unfinished.
The character sprite sheet (`Assets/pet-atlas.webp`) is not in the repository; without it the
app draws a fallback vector character.
