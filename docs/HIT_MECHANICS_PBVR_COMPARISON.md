# Hit Mechanics: PowerBeatsVR vs EnergySource (Godot)

Evidence-backed comparison of how each game decides whether a punch hits a ball.
PBVR evidence comes from the decompiled `Assembly-CSharp.dll` and AssetRipper scene
exports in `/home/guy/workspace/vibe/PunchBeatVR` (read-only reference; originals at
`~/.local/share/Steam/steamapps/common/PowerBeatsVR`).

## How PowerBeatsVR registers a hit

1. **Collision**: the ball prefab has a **trigger SphereCollider, radius 0.307 m**
   (`Scenes/Environments/Generic Environment.unity`: `m_Radius: 0.307, m_IsTrigger: 1`).
   The visible ball mesh is only ~0.25 m radius, so the hitbox is ~23% larger than what
   the player sees. The fist is a small non-trigger sphere, r=0.09 m, with a kinematic
   rigidbody. First `OnTriggerEnter` frame ->
   `CollidableObject.PartTriggerEnter` -> `GameManager.Contact(...)`.
2. **Fist speed**: instantaneous **SteamVR pose velocity** at the contact frame
   (`CollidableHandObject.GetSpeed()` -> `poseAction.velocity`), evaluated as
   `speed.sqrMagnitude`. No averaging/smoothing in game code.
   (`Controller.SPHERE_HIT_THRESHOLD_VELOCITY_SQUARED` exists but is dead code.)
3. **Thresholds** (`GameManager.GetHitLevel`, `GameManager.cs:3079-3107`):
   - Expert: v2 < 1.0 -> TOOLOW (ball bounces off, combo reset);
     1.0 <= v2 < 3.0 -> MINIMUMIMPACT; v2 >= 3.0 -> FULLIMPACT.
   - Beginner/Advanced: v2 < 1.5 -> MINIMUMIMPACT (ball still breaks, scores);
     v2 >= 1.5 -> FULLIMPACT. **TOOLOW is impossible below Expert.**
   - PowerBall: `v2 /= 4` before the check (i.e. needs 2x linear speed).
4. **Swing series** ("3 balls with an arrow"):
   - Detection (`BeatSequence.FindSwing`, `BeatSequence.cs:1000`): balls at beats
     **N, N+1/16 (0.0625), N+1/8 (0.125)** (float tolerance 0.001). Purely timing-based.
     Double swings (2 balls on the first beat) require exactly 2 balls on each following
     beat and are paired left-with-left by X position.
   - The arrow (`setting.swingIndicator`) is **visual only** - punch direction is never
     checked anywhere in `GameManager.Contact`.
   - Swing balls get **bigger hitboxes** (`GameManager.cs:2605-2673`):
     every swing ball `radius *= 1.03`; mid ball additionally
     `ScaleColliderUpDuringFlight(1.1111)`; end ball `ScaleColliderUpDuringFlight(1.1765)`
     (`Hittable.cs:39`). Effective radii: **0.316 / 0.351 / 0.372 m**, while the
     *visuals* shrink (x0.9 mid, x0.85 end). PBVR deliberately makes series balls
     easier to hit because the player sweeps them in one motion.

## How EnergySource registers a hit (before this fix)

1. **Collision**: hammer `Area3D` (layer 2) overlaps note `Area3D` (layer 4) ->
   `player.gd::handle_hit()`. Note hitbox: SphereShape3D **radius 0.225 m**
   (`src/scenes/Note.tscn:14`).
2. **Hand speed**: arithmetic **mean of the last 30 physics frames** of hammer-tip
   (`EndTracker`) position deltas (`src/scripts/controller.gd:226-241`).
   Physics rate follows the HMD refresh rate (`src/scripts/GameManager.gd:481-486`,
   `Engine.physics_ticks_per_second = int(refresh_rate)`, fallback 144), so the
   30-frame window is a **different duration on every headset**:
   72 Hz -> 417 ms, 90 Hz -> 333 ms, 120 Hz -> 250 ms, 144 Hz -> 208 ms.
3. **Thresholds** (`src/scripts/player.gd:246-262`): PBVR **Expert** rules at every
   difficulty: v2 >= 3.0 FULL, v2 >= 1.0 MIN, else TOOLOW (ball turns black, combo = 0).
   PowerBall: v2/4.
4. **No swing detection**: series balls get the stock 0.225 m sphere, no arrow,
   `_cutDirection` hardcoded to 8 ("any") (`src/scripts/PowerBeatsVRMap.gd:301`).
   Streams are logged and skipped (`PowerBeatsVRMap.gd:272-274`).

## Why hits (especially series of 3) felt bad

- **Hitbox area**: 0.225 vs 0.307 m radius = 46% less cross-section area on every ball.
  For swing-end balls: 0.225 vs 0.372 m -> PBVR offers ~2.7x the target area.
- **Velocity dilution**: a punch's fast phase lasts ~50-100 ms (~6-12 frames at 120 Hz);
  the other ~18-24 frames of the 30-frame average are wind-up/follow-through near zero.
  Example at 120 Hz: a 3 m/s jab held for 8 frames amid 22 slow frames averages to
  ~0.8 m/s -> v2 = 0.64 < 1.0 -> TOOLOW. PBVR evaluates the contact frame directly.
- **Series timing**: at 125 BPM the 2nd/3rd balls arrive 30/60 ms after the first
  (~4/~7 physics frames at 120 Hz) - one sweep must carry the hammer through all three.
  PBVR enlarges exactly those targets; we did not.
- **Map composition makes it dominant**: `Matt Gray - Sanxion Loader 2014 Remake
  Preview` Expert contains 750 balls, of which **170 swing series = 510 balls (68%)**,
  284 PowerBalls, 52 Streams. The majority of the map was our worst-case content.
- **Collider/visual desync**: the collider moved in `_physics_process` while the mesh
  followed the audio clock in `_process` (`src/scripts/note.gd`), so the visible ball
  was not exactly where the hitbox was.

## Ruled out as causes

- **Tunneling**: at 120 Hz physics a fast note (~8.3 m/s) moves ~0.07 m/frame and a hard
  swing (~5 m/s tip) ~0.04 m/frame -> worst-case closing ~0.11 m/frame vs ~0.34 m
  combined radii. No continuous collision detection needed.
- **Punch direction**: neither game checks it.
- **Hammer colliders**: ours (capsule r~0.11 + box 0.11x0.23x0.11) are already bigger
  than PBVR's fist (r=0.09).

## The fix (branch `bugfix/better-punch`)

| Change | File | PBVR reference |
|--------|------|----------------|
| Note collider 0.225 -> 0.307 m | `src/scenes/Note.tscn` | Generic Environment.unity |
| Swing detection + per-role collider scale (x1.03 / x1.144 / x1.212) | `src/scripts/PowerBeatsVRMap.gd`, `src/scripts/note.gd` | `BeatSequence.FindSwing`, `GameManager.cs:2605-2673` |
| Contact-moment peak velocity over ~70 ms window (framerate-independent) | `src/scripts/controller.gd`, `src/scripts/player.gd` | `CollidableHandObject.GetSpeed()` |
| Difficulty-aware thresholds (TOOLOW only on Expert) | `src/scripts/player.gd` | `GameManager.GetHitLevel` |
| Collider driven by the same audio clock as the mesh | `src/scripts/note.gd` | PBVR tweens move the whole ball object |
