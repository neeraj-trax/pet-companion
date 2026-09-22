# Shark Pet — states & behaviours

> Historical shark-era concept, not current Pet behavior. See `README.md` and `AGENTS.md` for the blue dog app.

A chibi great-white (Hojiro plush style) on your screen edge. The bottom edge is the waterline: most of the time you see only a fin. It comes out when you come to it and gets out of the way while you work.

## 1. The state machine

| State | What you see | Enters when | Leaves when |
|---|---|---|---|
| **Submerged (fin cruise)** | Only the dorsal fin and a sliver of blue back above the bottom edge. Drifts at 14–18 pt/s with a slow tail-beat, fin leaning into turns, faint ripple. Cruises 6–14 s, pauses, turns lazily. Lasts 2–6 min. | "Go for a swim", dragging it below the bottom edge, Shy mood, typing/deep-work autopilot, a fullscreen app. | Cursor slows near the fin (via Periscope), hover/click on the fin, a file dragged over it, or a stretch every 4–10 min — never while your mouse is still. |
| **Periscope** | Fin stops; only eyes, top of head and upper gill lines rise above the edge. Looks at the cursor 1–2.5 s, blinks once, sinks with a tiny ripple. | Cursor slows within ~200 px of the fin; a random check-in every 40–120 s while hidden; a new app comes to the front. | After 1–2.5 s: cursor onto it → Surfacing; away → sinks. |
| **Surfacing** | Body pops up over 0.6 s with a small overshoot, head-shake, droplets, a "puh" bubble. A fast-approaching cursor gets a startled pop. | From Submerged or Periscope. | Lands in Standing. |
| **Diving** | Small hop, nose-down tilt, sinks in 0.55 s with bubbles. 0.7 s of nothing, then the fin rises to the side, facing the other way. | Any trigger into Submerged. | Fin cruise begins. |
| **Standing / idle** | Tall pill body on two little feet, breathing, blinking, a rare thought bubble, short wanders. | After Surfacing, landing, waking, or any reaction. | Picks a nap, wander or dive; or you interact. |
| **Curious** | Head tilts ~8° toward the cursor, fin leans the same way, one flipper lifts. Silent. | Cursor pauses within 220 px (not on it) for 0.8 s; at most once per 20 s. | Cursor moves >40 px, or after 5 s. |
| **Chomp (poke)** | Big black mouth snaps open showing the zig-zag teeth, clacks shut with a squash. 2–3 pokes add hearts; 4+ spins once and goes dizzy. | Click. | 0.3–0.7 s later. |
| **Napping (flopped)** | A yawn showing every tooth, then it melts into the plush's lying-flat pose: wide and low, fin drooping, flippers spread, eyes shut, tail twitch every 4–7 s, zzz rising as bubbles. | Away 150 s+, "Nap now", or a small chance after 2 min awake. | Timer, poke, hover or drop: inflates with a wobble, shakes off droplets. |
| **Peeking (side edges)** | Behind the edge with snout and one eye out. One time in four only the tail fin sticks 16 px in, twitching every 2–4 s. | Seated on a left or right edge. | Cursor within 220 px, hover, or drag: slides out with a guilty turn. |
| **Dragging** | Dangles from the cursor, swinging, fin flat. | Press and move. | Release: glides to the nearest edge with a squash landing. Released below the bottom edge → Diving. |
| **Launching an app** | Chomps upward at the icon with an 8 px hop, bubbles from the mouth. | Click an icon in the hover pill. | 0.5 s later. |
| **Gulp (drop)** | Mouth hangs open while a drag hovers, snaps shut on drop, tall-then-squat gulp, "kept" thought. | Text, link, image or file dropped on it. | 0.7 s later. |

## 2. Build now

1. **Fin cruise polish** — the hidden state you asked for. The base exists; add tail-beat, lean, pauses, longer cruises and slow-vs-fast surfacing. You will see this state most.
2. **Periscope + Curious** — the two "small thinking states". Cheap, and the crocodile-eyes peek is the shark's signature.
3. **Dive and surface beats** — hop, sink, bubbles; head-shake and droplets on the way up. Makes hiding physical.
4. **Typing-focus dive** — freezes while you type, dives after 60–90 s of steady typing, resurfaces 20–25 s after you stop. No permission. The most respectful thing a desk pet can do.
5. **Deep-work autopilot** — for mouse-heavy work: 15 min in one app and it goes under; three app switches in a minute and it comes back, exactly when the launcher helps.
6. **Chomp reactions** — the mouth is the character. Replaces the cat hop on poke, launch and drop.
7. **Flop nap with yawn** — the plush's lying-flat pose, seen several times a day.
8. **Mood dial (Shy / Normal / Chatty)** plus quiet hours, "Shh for an hour" and "Dive while [current app] is in front". One knob that tunes everything.
9. **Clipboard snack** — a "keep clipboard" cell inside the hover pill; click and the shark gulps it into the Stash. Reads nothing until you click.
10. **Fullscreen dive** — gone completely during Keynote, video or games. Essential for trust.

Quick wins: pill opens only for a resting cursor, "Fur colour" → "Skin", shark thought library ("fish?", "hm", "puh"), sparkles → bubbles, breathing gills, reef-wall tail peek.

## 3. Later

- Ping-pong partner riding the fin ("app you keep switching to", Chatty only)
- Hold a file over the shark, drop it on an app ("open with")
- Clip chips row in the pill
- Display-change manners: remember each monitor setup, dive here / surface there
- Accessories (beanie with a fin hole, scarf, glasses, bow)
- Name your shark; first-run "the fin arrives"; fin menu-bar icon
- Size: Pup / Regular / Big
- Reduce Motion, Increase Contrast, Low Power Mode (before any public release)
- Night dimming and slower evenings (no nudges)
- Still water = offline; startle flinch (rate-limited); breach (menu, drop-on-fin, third poke only)
- Under-the-Dock cruise; top-edge tank float; seasonal touches

## 4. Dropped and why

- **"Keep this link?" pop-up, Downloads courier, ping-pong bubble** — things that appear on their own are notifications in a costume; Downloads also needs a system folder prompt.
- **Peckish "fish?", bored knee-drumming, 23:30 "bed?", Monday coffee, 90-min stretch** — nags and Tamagotchi guilt; tapping is exactly the corner-of-the-eye motion to avoid.
- **Scent trail** — a fin creeping toward your cursor where the Dock lives; Periscope covers it.
- **Battery "plug me?"** — macOS already says so.
- **Drive eject, sounds** — utility widgets with a fin on them; a noisy office pet is the wrong instinct.
- **Feeding unlocks** — hiding skins behind 30 drops hides the customization you asked for.

## 5. Defaults that keep it calm

- Clicks pass through everywhere except the body; hidden, only the fin is clickable, so it never blocks the Dock.
- The pill opens only when the cursor rests on it (~0.3 s, no button held, no drag) and closes when you leave.
- Zero notifications, badges or sound. No permissions of any kind.
- Thought bubbles at most every 25–70 s, never while typing; app suggestions live inside the pill, not in bubbles.
- Any key in the last 3 s: it freezes. Steady typing or 15 min in one app: it dives. It never surfaces by itself while your mouse is still, and never more than once per 4–10 min.
- Mood ships as **Shy** for the first week; quiet hours 22:00–08:00 on by default; "Shh for an hour" one click away.
- Fullscreen means fully gone.
- Curious at most once per 20 s; periscope check-ins only while hidden; every reaction under 0.7 s.
