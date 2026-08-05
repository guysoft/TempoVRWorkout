extends SceneTree

# Tests for the bugfix/better-punch hit mechanics:
# - PowerBeatsVR swing series detection (ported from BeatSequence.FindSwing)
# - Swing collider scaling factors
# - Difficulty-aware hit levels (PBVR GameManager.GetHitLevel parity)
# - Contact-moment peak velocity window (framerate-independent)
#
# Run with: godot --headless --script res://tests/test_swing_detection.gd

const PowerBeatsVRMapScript = preload("res://scripts/PowerBeatsVRMap.gd")
const HitRulesScript = preload("res://scripts/HitRules.gd")
const HitVelocityTrackerScript = preload("res://scripts/HitVelocityTracker.gd")

var _map: PowerBeatsVRMap


func _init():
	print("\n=== Hit Mechanics Tests ===\n")
	var all_passed = true

	all_passed = test_single_swing() and all_passed
	all_passed = test_double_swing_pairs_by_x() and all_passed
	all_passed = test_incomplete_swing_not_tagged() and all_passed
	all_passed = test_bombs_excluded() and all_passed
	all_passed = test_cross_beat_boundary() and all_passed
	all_passed = test_swing_collider_scales() and all_passed
	all_passed = test_hit_levels_expert() and all_passed
	all_passed = test_hit_levels_casual_never_toolow() and all_passed
	all_passed = test_hit_levels_power_ball() and all_passed
	all_passed = test_hit_velocity_peak_and_window() and all_passed

	print("\n=== Test Summary ===")
	if all_passed:
		print("✓ ALL HIT MECHANICS TESTS PASSED")
	else:
		print("✗ SOME TESTS FAILED")

	quit(0 if all_passed else 1)


func _make_map() -> PowerBeatsVRMap:
	# Bogus path: JSON load fails gracefully, we populate notes directly
	var map = PowerBeatsVRMapScript.new("res://tests/__nonexistent__.json")
	map.notes["Expert"] = {}
	return map


func _add_ball(beat_no: int, time: float, x: float, type: int = 0) -> Dictionary:
	var note = {"x": x, "y": 1.0, "_time": time, "_type": type, "offset": 0.0}
	if not _map.notes["Expert"].has(beat_no):
		_map.notes["Expert"][beat_no] = []
	_map.notes["Expert"][beat_no].append(note)
	return note


func _roles(notes: Array) -> Array:
	var r = []
	for n in notes:
		r.append(n.get("_swing_role", "<missing>"))
	return r


func test_single_swing() -> bool:
	print("--- Single swing (3 balls at T, T+1/16, T+1/8) ---")
	_map = _make_map()
	var a = _add_ball(10, 10.0, -0.3)
	var b = _add_ball(10, 10.0625, 0.0)
	var c = _add_ball(10, 10.125, 0.3)
	var count = _map._run_swing_detection("Expert")
	var ok = count == 1 and a["_swing_role"] == "start" \
		and b["_swing_role"] == "mid" and c["_swing_role"] == "end"
	_assert(ok, "roles=%s count=%d (expected [start,mid,end] count=1)" % [_roles([a, b, c]), count])
	return ok


func test_double_swing_pairs_by_x() -> bool:
	print("--- Double swing (2 balls per beat, paired left/right by X) ---")
	_map = _make_map()
	var start_l = _add_ball(20, 20.0, -0.4)
	var start_r = _add_ball(20, 20.0, 0.4)
	var mid_l = _add_ball(20, 20.0625, -0.2)
	var mid_r = _add_ball(20, 20.0625, 0.2)
	var end_l = _add_ball(20, 20.125, -0.1)
	var end_r = _add_ball(20, 20.125, 0.1)
	var count = _map._run_swing_detection("Expert")
	var all = [start_l, start_r, mid_l, mid_r, end_l, end_r]
	var ok = count == 2 \
		and start_l["_swing_role"] == "start" and start_r["_swing_role"] == "start" \
		and mid_l["_swing_role"] == "mid" and mid_r["_swing_role"] == "mid" \
		and end_l["_swing_role"] == "end" and end_r["_swing_role"] == "end"
	_assert(ok, "roles=%s count=%d (expected all tagged, count=2)" % [_roles(all), count])
	return ok


func test_incomplete_swing_not_tagged() -> bool:
	print("--- Incomplete swing (missing T+1/8 ball) ---")
	_map = _make_map()
	var a = _add_ball(30, 30.0, -0.3)
	var b = _add_ball(30, 30.0625, 0.0)
	var count = _map._run_swing_detection("Expert")
	var ok = count == 0 and a["_swing_role"] == "" and b["_swing_role"] == ""
	_assert(ok, "roles=%s count=%d (expected untagged, count=0)" % [_roles([a, b]), count])
	return ok


func test_bombs_excluded() -> bool:
	print("--- Bombs are not hittables for swing detection ---")
	_map = _make_map()
	var ball = _add_ball(40, 40.0, -0.3)
	var bomb = _add_ball(40, 40.0625, 0.0, 3)  # _type 3 = bomb
	var ball2 = _add_ball(40, 40.125, 0.3)
	var count = _map._run_swing_detection("Expert")
	var ok = count == 0 and ball["_swing_role"] == "" and ball2["_swing_role"] == "" \
		and bomb.get("_swing_role", "") == ""
	_assert(ok, "count=%d (expected 0, bomb must not complete a swing)" % count)
	return ok


func test_cross_beat_boundary() -> bool:
	print("--- Swing crossing an integer beat boundary ---")
	_map = _make_map()
	var a = _add_ball(50, 50.9375, -0.3)
	var b = _add_ball(51, 51.0, 0.0)
	var c = _add_ball(51, 51.0625, 0.3)
	var count = _map._run_swing_detection("Expert")
	var ok = count == 1 and a["_swing_role"] == "start" \
		and b["_swing_role"] == "mid" and c["_swing_role"] == "end"
	_assert(ok, "roles=%s count=%d (expected [start,mid,end] count=1)" % [_roles([a, b, c]), count])
	return ok


func test_swing_collider_scales() -> bool:
	print("--- Collider scale factors match PBVR (x1.03 / x1.1444 / x1.2118) ---")
	var scales = Obstacle.SWING_COLLIDER_SCALE
	var ok = is_equal_approx(scales["start"], 1.03) \
		and is_equal_approx(scales["mid"], 1.03 * 1.1111112) \
		and is_equal_approx(scales["end"], 1.03 * 1.1764705) \
		and scales.get("", 1.0) == 1.0
	_assert(ok, "scales=%s" % scales)
	return ok


func test_hit_levels_expert() -> bool:
	print("--- Hit levels: Expert rules (TOOLOW < 1.0 <= MIN < 3.0 <= FULL) ---")
	var HL = HitRulesScript.HitLevel
	var ok = HitRulesScript.calculate_hit_level(0.5, "Expert") == HL.TOOLOW \
		and HitRulesScript.calculate_hit_level(1.0, "Expert") == HL.MINIMUMIMPACT \
		and HitRulesScript.calculate_hit_level(2.9, "Expert") == HL.MINIMUMIMPACT \
		and HitRulesScript.calculate_hit_level(3.0, "Expert") == HL.FULLIMPACT \
		and HitRulesScript.calculate_hit_level(0.5, "ExpertPlus") == HL.TOOLOW \
		and HitRulesScript.calculate_hit_level(0.5, null) == HL.TOOLOW
	_assert(ok, "Expert thresholds wrong")
	return ok


func test_hit_levels_casual_never_toolow() -> bool:
	print("--- Hit levels: Beginner..Advanced never return TOOLOW (PBVR parity) ---")
	var HL = HitRulesScript.HitLevel
	var ok = true
	for diff in HitRulesScript.CASUAL_DIFFICULTIES:
		# Near-zero speed must still break the ball (MINIMUMIMPACT, not TOOLOW)
		if HitRulesScript.calculate_hit_level(0.01, diff) != HL.MINIMUMIMPACT:
			ok = false
			print("  ✗ %s: v2=0.01 expected MINIMUMIMPACT" % diff)
		if HitRulesScript.calculate_hit_level(1.5, diff) != HL.FULLIMPACT:
			ok = false
			print("  ✗ %s: v2=1.5 expected FULLIMPACT" % diff)
	_assert(ok, "casual difficulties must never return TOOLOW")
	return ok


func test_hit_levels_power_ball() -> bool:
	print("--- Hit levels: PowerBall divides v2 by 4 ---")
	var HL = HitRulesScript.HitLevel
	var ok = HitRulesScript.calculate_hit_level(3.9, "Expert", true) == HL.TOOLOW \
		and HitRulesScript.calculate_hit_level(4.0, "Expert", true) == HL.MINIMUMIMPACT \
		and HitRulesScript.calculate_hit_level(12.0, "Expert", true) == HL.FULLIMPACT
	_assert(ok, "PowerBall thresholds wrong")
	return ok


func test_hit_velocity_peak_and_window() -> bool:
	print("--- get_hit_velocity: peak over ~70ms, window scales with tick rate ---")
	var tracker = HitVelocityTrackerScript.new()
	var saved_rate = Engine.physics_ticks_per_second
	var ok = true

	# 30 samples of slow motion; an old 5 m/s peak at index 10 and a recent
	# 2 m/s peak whose inclusion depends on the window size
	for i in range(30):
		tracker.add_sample(Vector3(0.1, 0, 0))
	tracker.points[10] = Vector3(5, 0, 0)   # 20+ frames ago: outside every window
	tracker.points[22] = Vector3(2, 0, 0)   # 8 frames ago: inside 120Hz window only

	Engine.physics_ticks_per_second = 120  # window = ceil(0.07*120) = 9 -> idx 21..29
	var v120 = tracker.get_hit_velocity()
	if v120 != Vector3(2, 0, 0):
		ok = false
		print("  ✗ 120Hz: expected (2,0,0), got ", v120)

	Engine.physics_ticks_per_second = 72  # window = ceil(0.07*72) = 6 -> idx 24..29
	var v72 = tracker.get_hit_velocity()
	if v72 != Vector3(0.1, 0, 0):
		ok = false
		print("  ✗ 72Hz: expected (0.1,0,0), got ", v72)

	Engine.physics_ticks_per_second = 144  # window = ceil(0.07*144) = 11 -> idx 19..29
	var v144 = tracker.get_hit_velocity()
	if v144 != Vector3(2, 0, 0):
		ok = false
		print("  ✗ 144Hz: expected (2,0,0), got ", v144)

	# Empty history falls back to the provided velocity
	var empty_tracker = HitVelocityTrackerScript.new()
	if empty_tracker.get_hit_velocity(Vector3(0.5, 0, 0)) != Vector3(0.5, 0, 0):
		ok = false
		print("  ✗ empty history should fall back to the provided velocity")

	Engine.physics_ticks_per_second = saved_rate
	_assert(ok, "hit velocity window/peak wrong")
	return ok


func _assert(condition: bool, message: String):
	if condition:
		print("  ✓ PASS")
	else:
		print("  ✗ FAIL: ", message)
