class_name HitVelocityTracker
extends RefCounted

# Contact-moment hit velocity: peak per-frame sample over the last WINDOW_SEC
# seconds. PowerBeatsVR evaluates the SteamVR pose velocity at the contact
# frame; the peak over a short window approximates that while staying robust
# to single-frame noise.
#
# The window is time-based (derived from Engine.physics_ticks_per_second),
# never a hardcoded frame count, so hit strictness is identical at any
# current or future physics tick rate (72/90/120/144Hz+).

const WINDOW_SEC = 0.070
const TRACK_LENGTH = 30

var points: Array = []


func add_sample(v: Vector3):
	points.append(v)
	if points.size() > TRACK_LENGTH:
		points.remove_at(0)


func window_frames() -> int:
	return max(2, int(ceil(WINDOW_SEC * Engine.physics_ticks_per_second)))


## Peak per-frame velocity within the window. Returns fallback when empty.
func get_hit_velocity(fallback: Vector3 = Vector3.ZERO) -> Vector3:
	var count = min(window_frames(), points.size())
	if count == 0:
		return fallback
	var best = Vector3.ZERO
	var best_len_sq = -1.0
	for i in range(points.size() - count, points.size()):
		var l = points[i].length_squared()
		if l > best_len_sq:
			best_len_sq = l
			best = points[i]
	return best
