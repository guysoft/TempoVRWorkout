extends SceneTree

# Tests for the difficulty option + hit feedback words:
# - Settings persists "game"/"difficulty" (round-trip through user://settings.ini)
# - Settings defaults include difficulty = "Expert"
# - NoteFeedback maps TOOLOW -> ui_weak.png, fly-past MISS -> ui_miss.png,
#   FULLIMPACT -> ui_perfect.png
# - note.gd / NoteFeedback.gd agree on the HIT_LEVEL_MISS pseudo-level
#
# Run with: godot --headless --script res://tests/test_difficulty_feedback.gd

const SettingsScript = preload("res://scripts/Settings.gd")
const NoteFeedbackScript = preload("res://scripts/NoteFeedback.gd")

var _passed := true


func _init():
	print("\n=== Difficulty + Feedback Tests ===\n")

	_test_settings_default()
	_test_settings_roundtrip()
	_test_feedback_textures()
	_test_miss_level_contract()

	print("\n=== Test Summary ===")
	if _passed:
		print("✓ ALL DIFFICULTY/FEEDBACK TESTS PASSED")
	else:
		print("✗ SOME TESTS FAILED")
	quit(0 if _passed else 1)


func _test_settings_default():
	print("--- Settings defaults include difficulty=Expert ---")
	var s = SettingsScript.new()  # not in tree: no disk access, pure defaults
	_check(s.get_setting("game", "difficulty") == "Expert", \
		"default difficulty should be Expert, got %s" % s.get_setting("game", "difficulty"))
	s.free()


func _test_settings_roundtrip():
	print("--- Settings difficulty round-trips through disk ---")
	var s = SettingsScript.new()
	s.load_settings()  # merge the real settings.ini so set_setting writes it back intact
	var original = s.get_setting("game", "difficulty", "Expert")

	s.set_setting("game", "difficulty", "Beginner")
	var s2 = SettingsScript.new()
	s2.load_settings()
	_check(s2.get_setting("game", "difficulty") == "Beginner", \
		"expected Beginner after reload, got %s" % s2.get_setting("game", "difficulty"))

	s2.set_setting("game", "difficulty", original)  # restore the player's setting
	s.free()
	s2.free()


func _test_feedback_textures():
	print("--- NoteFeedback: TOOLOW->WEAK, MISS->MISS, FULL->PERFECT ---")
	var scene = load("res://scenes/NoteFeedback.tscn")
	if scene == null:
		_check(false, "NoteFeedback.tscn failed to load")
		return
	var weak_tex = load("res://effects/ui_weak.png")
	var miss_tex = load("res://effects/ui_miss.png")
	var perfect_tex = load("res://effects/ui_perfect.png")

	var cases = [
		[0, weak_tex, "TOOLOW"],      # NoteFeedback.HIT_LEVEL_TOOLOW
		[-1, miss_tex, "MISS"],       # NoteFeedback.HIT_LEVEL_MISS
		[2, perfect_tex, "FULLIMPACT"],
	]
	for c in cases:
		var fb = scene.instantiate()
		root.add_child(fb)
		fb.show_feedback(Vector3.ZERO, c[0])  # coroutine; mapping happens before its await
		var mat = fb.get_node("MeshInstance3D").get_surface_override_material(0)
		_check(mat != null and mat.albedo_texture == c[1], \
			"%s should show %s" % [c[2], c[1].resource_path if c[1] else "<null>"])
		root.remove_child(fb)
		fb.free()


func _test_miss_level_contract():
	print("--- note.gd and NoteFeedback.gd agree on HIT_LEVEL_MISS ---")
	_check(Obstacle.HIT_LEVEL_MISS == -1 and Obstacle.HIT_LEVEL_MISS == NoteFeedbackScript.HIT_LEVEL_MISS, \
		"HIT_LEVEL_MISS mismatch: note.gd=%s NoteFeedback=%s" % [Obstacle.HIT_LEVEL_MISS, NoteFeedbackScript.HIT_LEVEL_MISS])


func _check(condition: bool, message: String):
	if condition:
		print("  ✓ PASS")
	else:
		_passed = false
		print("  ✗ FAIL: ", message)
