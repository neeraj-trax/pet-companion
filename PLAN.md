# Shark Pet — implementation plan ("Build now")

Existing anchors (view coords, 170×170): `bodyCenter (85,74)`, `bodyBottom 28`, `bodyTop 120`, fin tip local y `62+8·earPerk` → view `136…144`. Note: the `// 37 / 111 / 131` comments in `PetGeometry` are stale; real values are 28/120/144.

## 1. Geometry + pose fields — `PetPose.swift`

- `PetGeometry`: add `finVisible = 18`, `waterlineLocal = bodyCenter.y + 66 − finVisible = 122` (fin tip pinned at `earPerk 0.5` → local 66 → view 140), `submergeDepth = waterlineLocal − bodyBottom = 94` (replaces the current 98 formula), `periscopeDepth = 96 − bodyBottom = 68` (waterline at view 96: eyes at 106, upper gill tips 92–96 just clear water, mouth at 94–120 hidden), `finHitRect = CGRect(x: 67, y: 122, width: 36, height: 26)`. Window origin while fully under: `y = visibleFrame.minY − 122`; periscope `minY − 96`; standing `minY − 28`.
- `PetPose`: add `finSway`, `wake` (0…1 cruise-speed), `flop` (0…1), `chomp` (0…1), `flipperLift: (l, r)`, `depth`. `Mouth` gains `.chomp`.
- `hitPath`: pass `depth`; when `depth > 0.5` return only the fin triangle inset by −6pt so hover is forgiving.

## 2. State machine — `PetController.swift`

`enum State { idle, wandering, napping, poked, dragging, landing, diving, submerged, periscope, surfacing }` (rename `cruising`→`submerged`). New vars: `depth: CGFloat` (0 standing…1 under; **stop overloading `peek`** for the bottom edge — `peek` stays side-edge only), `diveReason: enum {menu, drag, idle, typing, autopilot, app, shh, fullscreen}`, `cruiseSpeed/targetSpeed`, `legUntil`, `pausing`, `turnUntil`, `periscopeIn`, `periscopeHold`, `lastPeriscope`, `lastSelfSurface`, `surfaceFast`, `openPanelOnLand`, `curiousT`, `curiousAnchor`, `lastCurious`, `keyIdle`, `typingFor`, `frontSince`, `switchTimes: [TimeInterval]`, `mood`, `shhUntil`, `diveApps: Set<String>`, `fullscreenHidden`.

`edgeTarget(.bottom)`: `y = minY − bodyBottom − depth·submergeDepth`. `updatePeek` guard: `if !underwater { depth = approach(depth, 0, 8) }` instead of `peek = 1`. `screensChanged`/`comeHere`/`release` must not reset depth; `comeHere` and menu "Come here" call `surface(fast:false)` first if underwater. `savePosition`: store standing y plus `pet.underwater` flag; `placeInitially` starts in `.submerged` when set (the fin "arrives").

## 3. Diving — `startDive(reason:)`, `updateDive`

Guard: `edge == .bottom && hugEdges && !seam(bottom)` (reuse `nearestEdge` seam probe). Hide panel, `panelCooldownUntil = time+1`. Phases by `stateTime`:
- 0–0.15 s hop: `bob = 8·sin(p·π)`, `tilt → −facing·0.35` (nose down, rate 12).
- 0.15–0.70 s sink: `depth = easeInQuad` 0→1.08 (8pt past fin-hidden), `spawnBubbles(5)` at 0.35 s.
- 0.70–1.40 s nothing (fin hidden). At 1.40 s: `origin.x += facing·60` clamped, `facing = −facing`, `tilt = 0`.
- 1.40–1.90 s fin rises: `depth 1.08→1` ease-out; then `state = .submerged`, start a leg.
From drag (`reason .drag`) skip the hop.

## 4. Fin cruise — `updateSubmerged`

- Legs: `legUntil = time + rand(6…14)`; `targetSpeed = rand(14…18)`, `cruiseSpeed = approach(…, rate 1.2)`. At leg end: `pausing = true` for `rand(2…5)` s (`targetSpeed 0`); then 65 % reverse direction with `turnUntil = time+0.8`, else same way. Walls: reverse and `pausing` 1 s.
- Motion: `o.x += dir·cruiseSpeed·dt`; `o.y = minY − 28 − depth·94`; `depth = 1 + 0.03·sin(t·1.3)` (slow bob so the fin breathes).
- Tail-beat: `tailPhase += dt·(0.8 + 1.6·wake)`; `pose.finSway = 3·sin(tailPhase)·wake`; `pose.wake = cruiseSpeed/18`.
- Lean: `tilt → −dir·0.10·wake` (rate 3); during `turnUntil`: `−dir·0.18`. Set `earPerk → 0.5`.
- Lifetime: `cruiseUntil = time + rand(120…360)`; "stretch" auto-surface only if `mouseStillFor < 3 && time − lastSelfSurface > moodGap` (Shy 600/Normal 300/Chatty 240 s); otherwise wait for the next mouse move. Never surface via `welcomeBack()` — early-return when underwater.
- Frame rate `desiredInterval`: `.submerged` → 1/30 while `cruiseSpeed > 1`, else 1/15.

## 5. Periscope — `startPeriscope`, `updatePeriscope`

Triggers (only from `.submerged`, `time − lastPeriscope > 12`): (a) cursor `|mouse.x − finX| < 200`, `mouse.y < minY+160`, `cursorSpeed < 120` sustained 0.35 s; (b) `periscopeIn` check-in `rand(40…120)` s, Normal/Chatty only, and only if `mouseStillFor < 60`; (c) `appActivated` (Normal/Chatty, ≥60 s apart).
Motion: `depth 1→periscopeDepth/94 = 0.72` over 0.35 s ease-out, `cruiseSpeed 0`; hold `rand(1…2.5)` s with the normal look code (eyes track cursor); force one blink at 0.6 s (`blinkT = 0`); `spawnBubbles(1)` on rise. Exit: `petContains(mouse)` → `surface(fast:true)`; else sink 0.4 s → `.submerged`.

## 6. Surfacing — `surface(fast:openPanel:)`, `updateSurfacing`

`from = origin.y`, `to = minY − 28`, duration fast 0.6 / slow 1.0. Fast curve: `k = p<0.7 ? easeOutCubic(p/0.7)·1.08 : 1.08 − 0.08·easeIn((p−0.7)/0.3)` (8 pt overshoot); slow: plain ease-out. Head-shake `tilt = 0.18·sin(p·π·4)·(1−p)` for p > 0.5, `spawnDroplets(5)` at p 0.5 (glyph "•", light blue, `dy 40…70`, add gravity `dy −= 90·dt` for that glyph in the particle loop), `think("puh", 1.2)`. Startled variant when `cursorSpeed > 900` at trigger: duration 0.4, overshoot 0.2, `think("!")`. Ends → `enterIdle()`, `pulse(−0.12, 0.3)`, `savePosition()`; if `openPanelOnLand && petContains(mouse)` set `hoverDwell = 0.3` so the pill opens next tick.

## 7. Hover / hit / panel — `updateHover`, `petContains`, `petMouseDown/Up`

- `petContains`: underwater → hit test `hitPath(depth:)` (fin only when `depth > 0.5`) **and** `point.y ≥ minY − 2` (already there); screen rect `finHitRectOnScreen = (origin.x+67, minY−2, 36, 28)`. `hitRectOnScreen` returns this rect while underwater so the pill anchors above the fin.
- Pill opens only for a resting cursor: add `NSEvent.pressedMouseButtons == 0` and `cursorSpeed < 60` to the 0.25 s dwell (raise to 0.3 s). Exclude `.diving/.surfacing` from opening; from `.submerged/.periscope` the dwell instead calls `surface(fast:true, openPanel:true)`.
- `petMouseDown` underwater → `surface(fast:true)`, `pressed = true`; `petMouseUp` skips `poke()` if `state == .surfacing`. Drag from the fin works unchanged (clip lifts as `pose.submerged` decays).
- `release()`: if `origin.y + bodyBottom < minY − 10` → clamp x, `edge = .bottom`, `startDive(.drag)`.
- `decideNext`: replace `startCruise` with `startDive(.idle)`, chance by mood (Shy 0.45 / Normal 0.30 / Chatty 0.15).

## 8. Curious — inside `.idle`

Conditions: `60 < dist < 220`, `!overPet`, `cursorSpeed < 30` for 0.8 s, `time − lastCurious > cooldown` (40/20/12 s), not typing. Set `curiousT = 0`, `curiousAnchor = mouse`. Effect: `tilt = −0.14·sign(dx)` (assigned directly, not multiplied by facing), `finSway = 4·sign(dx)`, `flipperLift` on the cursor side → 1 (rate 6). End when `hypot(mouse − anchor) > 40` or 5 s. No thought.

## 9. Chomp — `poke()`, `launch()`, `acceptDrop()`, `PetView.drawFace`

`Mouth.chomp` draws `mh = 4 + 34·(0.15 + 0.85·chomp)`, `widthScale 1.1`, teeth on. `.poked` lasts 0.5 s: `chomp = p<0.18 ? p/0.18 : max(0, 1 − (p−0.18)/0.14)`; at close `sy 0.86` for 0.1 s; bob capped at 3 pt (drop the 14 pt hop). Pokes 2–3 hearts (existing); ≥4: `spinT` 0.45 s with `sx = cos(2π·q)`, `think("@_@")`. Launch: same chomp + `bob 8` + `spawnBubbles(3)` from mouth (local (0,10)). Drop: `dragHover(true)` holds `chomp = 1`; `acceptDrop` closes in 0.12 s, then `sy 1.18 → 0.85` over 0.7 s (tall-then-squat), `think("kept ✓")`. Sparkle glyph "✦" → "○" everywhere.

## 10. Flop nap — `startNap`, `wake`, `PetView`

`startNap`: yawn 0.9 s (`mouth .chomp`, `chomp` ramps 0→0.8→0, `eyeOpen 0.3`), then `pose.flop → 1` (rate 2). Controller: `sx *= 1 + 0.32·flop`, `sy *= 1 − 0.38·flop`. View: fin tip `x += 14·flop, y −= 18·flop`; flippers `lift −= 10·flop`, x scale `1 + 0.15·flop`; feet alpha `1 − flop`; `drawZzz` glyph "○" in bubble colour. Tail twitch: `tailTwitchIn = rand(4…7)` → `tailWag 2.5` for 0.3 s. `wake`: `flop → 0` (rate 6), `pulse(0.14, 0.4)`, `spawnDroplets(3)`.

## 11. Typing-focus dive (no permission)

Per tick: `keyIdle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)` — needs **no** Accessibility/Input Monitoring (unlike `addGlobalMonitorForEvents`). `typing = keyIdle < 3` freezes: skip `decideNext`, thoughts, curious, periscope, wander. `typingFor += dt` while `keyIdle < 3`, reset when `keyIdle > 8`. `typingFor > rand(60…90)` && standing → `startDive(.typing)`. Resurface (slow) when `keyIdle > rand(20…25)` and the mouse moved within 10 s; else on the next move.

## 12. Deep-work autopilot — `appActivated`

Track `frontSince` (reset on bundle change) and `switchTimes` (keep ≤60 s). Standing, `time − frontSince > 900`, `keyIdle > 30`, ≥10 min since last autopilot → `startDive(.autopilot)`. Underwater with reason `.autopilot/.typing` and `switchTimes.count ≥ 3` → `surface(fast:false)` and refresh `recents`.

## 13. Mood dial + quiet — menu, `Keys`

`enum Mood { shy, normal, chatty }` (`pet.mood`, default shy; `pet.firstRun` date; flips to normal after 7 days unless user chose). Table: thought interval 60–120 / 25–70 / 18–40 s; periscope check-in none / 40–120 / 30–60; curious cooldown 40/20/12; self-surface gap 600/300/240. Quiet hours (`pet.quietHours`, default on, 22–08 via `Calendar.component(.hour)`) = Shy + no thoughts + no check-ins. "Shh for an hour": `shhUntil`, dive now, no self-surface/check-ins (fin hover still works). "Dive while <frontmost.localizedName> is in front": toggles bundle id in `pet.diveApps`; `appActivated` dives/surfaces (slow, 2 s later). Rename "Fur colour" → "Skin". Thought library: `["fish?", "hm", "puh", "…", "?", "♪", "○"]`.

## 14. Clipboard snack — `LaunchPanel.swift`

`PanelCell.Kind.clip` (SF "doc.on.clipboard", title "Keep clipboard"), placed before the add cell; `onClip` → `controller.keepClipboard()`: `StashStore.shared.save(from: NSPasteboard.general)` → gulp (step 9) + `flash("kept note")`, or `flash("clipboard is empty")`. Never read `changeCount` or contents before the click.

## 15. Fullscreen dive

Every 2 s: `CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)`; a `kCGWindowLayer == 0` window whose bounds width/height equal `currentScreen.frame` size (±2) → fullscreen (bounds are readable without Screen Recording; only titles are gated). Then `window.orderOut`, `launchPanel.hide()`; on exit `orderFrontRegardless` and return via slow surfacing from `.submerged`. Heuristic: Keynote/games that capture the display are already covered because our window can't show.

## Risks

1. **`ignoresMouseEvents` polling lag**: toggled per tick (≤67 ms at 15 fps); a click faster than that on the fin falls through, and conversely the window's 122 pt below `visibleFrame.minY` sits over the Dock — for one tick after the cursor leaves the fin downward, Dock clicks can be swallowed. Mitigation: force `ignore = true` first thing when `mouse.y < minY`, run 30 fps whenever `overPet`, and don't rely on AppKit's transparent-pixel pass-through.
2. **Auto-hiding Dock**: the fin hit rect at `minY − 2` overlaps the Dock reveal strip; start the rect at `minY + 2` when `visibleFrame.minY == frame.minY`.
3. **`currentScreen` while underwater**: `bodyCenterOnScreen.y = minY − 48` is off every screen → falls back to `NSScreen.main`; on multi-monitor `edgeTarget` then teleports the shark. Resolve the screen from `(origin.x + 85, minY + 5)` or cache the home `NSScreen` on dive.
4. **Edge snapping**: `release()`, `comeHere()`, `screensChanged()` all set `peek = 1`; with `depth` separate they no longer pop the shark up. Also refuse dives where the bottom edge is a seam (body would show on the lower monitor, since clipping is by waterline only).
5. **`bodyCenterOnScreen`-based distance checks** (`desiredInterval`, welcome, look) use the submerged centre; use the fin point while underwater.
6. `secondsSinceLastEventType` and `CGWindowListCopyWindowInfo` work unsandboxed today; verify after any future sandboxing.