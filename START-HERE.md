# Start here (new agent)

Project folder: `/Users/passwordis1234/Documents/claude max experiment/PET`
Git: https://github.com/neeraj-trax/pet-companion (private, branch `main`, clean as of the last commit)

1. Read `AGENTS.md` in this folder first. It has the code map, how the app works, how to verify without a screen, and the list of what is unfinished. Do not read every source file before starting.
2. Read `VISUALS-HANDOFF.md` only if you are touching the drawing (`PetView.swift`, `Sprite.swift`).
3. The character art `Assets/pet-atlas.webp` is on this Mac but not in git. Without it the app falls back to a vector character; do not commit the atlas.

## Build and run

```bash
cd "/Users/passwordis1234/Documents/claude max experiment/PET"
swift build -c release          # compile
./build-app.sh                  # compile + self-test + bundle → build/Pet.app
pkill -x Pet
rm -rf /Applications/Pet.app && cp -R build/Pet.app /Applications/Pet.app && open /Applications/Pet.app
```

The installed copy the owner uses is `/Applications/Pet.app`, so always reinstall it after a build.

## Verify without a screen (no screenshot access)

```bash
.build/release/Pet --selftest                         # state machine; must print selftest: OK
.build/release/Pet --render-poses build/poses.png     # every character state
.build/release/Pet --render-ring-live build/ring.png  # ring + magnification, light and dark
.build/release/Pet --render-ring-corners build/c.png  # ring fitted in corners and edges
.build/release/Pet --snapshot                         # ask the RUNNING app to dump what it draws + its state
```

Then open the PNG and look at it. `--snapshot` writes `$TMPDIR/pet-debug/view.png` and `state.txt`; it is the fastest way to debug "I can't see it" reports.

## House rules

- Owner is a non-technical designer. Reply in short plain sentences and end with a next step.
- Vibe: a cozy tiny friend, never a utility widget, never distracting during work.
- After each round: rebuild, reinstall to `/Applications`, relaunch, then `git add -A && git commit && git push`.
- Keep `AGENTS.md` up to date when behaviour changes. That file is the contract for the next agent.
- If two agents work at once, keep the ownership split in `AGENTS.md` (one owns the drawing files, the other everything else) and never build while the other is mid-edit.
