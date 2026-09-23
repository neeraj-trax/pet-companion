# Pet animation roadmap

The dog should feel responsive as an app launcher and gentle while idle. Review every change at its actual 100–120 pt height, including the transitions between poses. Keep the paws anchored and honour Reduce Motion.

## Current motion inventory

| Motion | Current implementation | Next review |
| --- | --- | --- |
| Idle and blink | Six-frame slow loop, small body squash, separate blink frame | A directional gaze currently takes precedence over the blink frame. |
| Cursor gaze | Five front-facing pose bands; side poses are mirrored; tracking has a 350–430 pt attention range | Direction changes can still jump between atlas cells. Random idle directional glances have been removed. |
| Stroll and Follow cursor walk | Eight frames each way at fixed 120–220 ms durations | The same cycle plays at roughly 30 pt/s stroll speed and at much faster follow speeds, so feet can slide. |
| Ordinary wander | Position moves with a small bob | No walking row is selected, so it can look like sliding. |
| Compact shrink/grow and edge peek | Transform/position animation | Ring access is now independent of finishing growth. Check alignment as the dog changes size. |
| Poke, drag, landing | Jump/walk rows plus squash, tilt and particles | Check entry/exit frames and feet placement. |
| Wave and other action rows | Atlas action rows | Non-walking actions repeat three cycles before returning to idle, regardless of the interaction's length. Routine thought signals now keep the neutral idle face; the waiting row is unused and the sprite path does not draw bubbles. |
| Nap and wake | Curled-up pose, breathing and Zzz | Improve transitions without losing the clear sleeping silhouette. |

The atlas also contains gentle oops, waiting, laptop and celebration rows with no live trigger. The music-disc pose data is not drawn yet.

The supplied source sheet is 1027×1531, so each of its 8×11 source cells is only about 128×139 pixels. The atlas-generation script enlarges each cell to 192×208; this does not create new line detail. Splitting the same artwork into one file per action would ease editing but would not improve sharpness. To improve clarity on Retina screens, redraw or regenerate consistent original frames at two or three times their displayed size, then pack them into an atlas while preserving frame bounds and the shared paw baseline. Avoid enlarging the current source again.

## Next animation pass

1. Render short timed sequences for walking, gaze, blink, poke and nap at app size. Record where a pose pops, a foot slides, or a feature disappears.
2. Tie the walking cycle to distance travelled rather than one fixed clock. Use a continuous phase so speed changes do not jump to another leg position; give ordinary wandering walking frames too.
3. Make gaze and blink coexist, then try a small set of consistent in-between head poses for the sharpest direction changes. Keep the body facing forward and the dog's original line style.
4. Give one-shot actions clear entry, hold and exit points instead of repeating every action three times. Tune each against the actual trigger.
5. During active motion, draw at a steady display cadence; return to low-rate updates when idle. A faster timer alone cannot fill gaps between sprite drawings, so assess any new in-between art at normal size before adding it.

The next UI task after the main motion pass is corner resizing for Stash, with a reflowing grid, a screen-bounded minimum/maximum size and unchanged file drag behaviour.
