extends SceneTree

# Tests for PowerBeatsVR swing series detection (ported from BeatSequence.FindSwing)
# and swing collider scaling.
#
# Run with: godot --headless --script res://tests/test_swing_detection.gd

const PowerBeatsVRMapScript = preload("res://scripts/PowerBeatsVRMap.gd")

var _map: PowerBeatsVRMap


func _init():
	print("\n=== Swing Detection Tests ===\n")
	var all_passed = true

	all_passed = test_single_swing() and all_passed
	all_passed = test_double_swing_pairs_by_x() and all_passed
	all_passed = test_incomplete_swing_not_tagged() and all_passed
	all_passed = test_bombs_excluded() and all_passed
	all_passed = test_cross_beat_boundary() and all_passed
	all_passed = test_swing_collider_scales() and all_passed

	print("\n=== Test Summary ===")
	if all_passed:
		print("✓ ALL SWING DETECTION TESTS PASSED")
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


func _assert(condition: bool, message: String):
	if condition:
		print("  ✓ PASS")
	else:
		print("  ✗ FAIL: ", message)
