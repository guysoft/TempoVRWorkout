# PowerBeatsVR Features Not Yet Implemented (Reference for Future Work)

Reverse-engineered details captured so these features can be implemented without
re-decompiling. Source: `/home/guy/workspace/vibe/PunchBeatVR/decompiled_cs/powerbeatsvr/`
(from `PowerBeatsVR_Data/Managed/Assembly-CSharp.dll`).

## 1. Swing arrow visuals (direction indicator on series-start balls)

Our hit-fix branch `bugfix/better-punch` already tags notes with `_swing_role`
(`"start"` / `"mid"` / `"end"`) in `PowerBeatsVRMap.gd`, so arrows are purely cosmetic
work on top of that.

How PBVR renders them (`GameManager.cs:2610-2658`):

- When a ball `IsStartOfSwing()`, instantiate `setting.swingIndicator`
  (`EnvironmentSetting.swingIndicator`, per-environment prefab) as a child of the
  ball's visual parent.
- Direction: `dir = (lastBall.position - firstBall.position).normalized` (2D, x/y of
  the play window). Rotation: `SignedAngle(Vector3.up, dir, Vector3.forward)`.
- Offset from the ball: `(-0.45 * dir.x, -0.45 * dir.y, -0.26)` - slightly behind and
  opposite the swing direction.
- Double swings (`Swing.IsDouble()`) get a paired indicator for the second hand.
- Hidden when the ball is hit via `Hittable.DeactivateSwingIndicator()`
  (`Hittable.cs:72-78`).
- The arrow never affects hit detection - punch direction is not checked.

Godot implementation sketch: instance a small arrow `MeshInstance3D` (or textured
quad) as a child of the note mesh in `note.gd::setup_note()` when
`_swing_role == "start"`, rotate around Z by the angle between Vector2.UP and
`(end_xy - start_xy)`, hide in `on_hit()`. Needs the swing's start/end positions
stored on the note dict (add `_swing_end_pos` alongside `_swing_role`).

## 2. Stream notes (ribbon/stream elements)

Status: logged and skipped in `src/scripts/PowerBeatsVRMap.gd` (`ACTION_STREAM` ->
print "not implemented"). Sanxion Expert contains 52 stream actions, so real maps
lose content.

### Map format (from the layout JSON)

```json
{"position": [-0.2, 0], "action": "Stream", "type": "START", "id": "A",
 "rotation": [0, 0, 0, 1],
 "inHandle": [0.006, 0.006, -0.333], "outHandle": [-0.006, -0.006, 0.333]}
```

- `type`: `START` / `INBETWEEN` / `END` (`StreamAction.CAType`) - anchors of a bezier
  ribbon the player must keep a fist inside.
- `id`: `A` / `B` (`StreamAction.Id`) - two simultaneous streams (left/right).
- `rotation`: quaternion orienting the stream cross-section.
- `inHandle` / `outHandle`: bezier control points relative to the anchor.

### PBVR runtime pieces

- `BeatSequence.RunStreamDetection(beatSequence, ballFlightDuration)`
  (`BeatSequence.cs:848`) chains START -> INBETWEEN* -> END into `Stream` objects
  (`Stream.cs`), stored in `StreamAction.streamInfo` (`BezierListStruct`).
- `StreamElement` (`StreamElement.cs`): pooled moving ribbon segment; reports
  `gameManager.ReportStreamElementMissed()` when it passes unhit; despawn via LeanPool.
- Contact scoring: `GameManager.Contact` handles stream contact separately from balls -
  continuous contact while the fist is inside (haptics/sparks via
  `streamSparksRight/Left.SetContactTime(Time.time)`, `GameManager.cs:3073`), tracked by
  `StreamCounter` / `StreamInfo`; visual effects by `StreamCollectionSparks` and
  `StreamParticleGenerator`.
- Editor constants: `LiveRecorder` uses `HITTABLE_RADIUS=0.25`, `HAND_RADIUS=0.15`.
  The live stream trigger sphere found in `Generic Environment.unity` has radius
  0.163 m (`m_IsTrigger: 1`).

### Godot implementation sketch

- Parse `Stream` actions in `PowerBeatsVRMap.gd::_parse_action` into a separate
  `streams[diff]` list (keep bezier anchors + handles + rotation + id).
- New `Stream.tscn`/`stream.gd`: a chain of small Area3D spheres (or one extruded
  shape) following the bezier path, moving toward the player like notes; score per
  physics frame of overlap with a hand Area rather than per-contact.
- Combo/score policy decision needed: PBVR scores streams continuously, not per-ball.
