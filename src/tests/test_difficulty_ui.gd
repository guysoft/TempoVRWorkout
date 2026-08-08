extends SceneTree

# Headless verification of the Settings-tab difficulty row.
#
# NOTE: MainMenuLeft.gd references autoloads (Settings/GameVariables/VRRecenter)
# which are not compile-time globals in --headless --script mode, so the menu
# instantiates WITHOUT its script here (known limitation, AGENTS.md section 8).
# This test therefore covers the scene structure only; the handler logic is
# covered by test_difficulty_feedback.gd (Settings round-trip) and manual
# play-testing.
#
# Run with: godot --headless --script res://tests/test_difficulty_ui.gd

var _passed := true


func _init():
	print("\n=== Difficulty UI Tests ===\n")

	var scene = load("res://scenes/MainMenuLeft.tscn")
	if scene == null:
		_check(false, "MainMenuLeft.tscn failed to load")
		_finish()
		return
	var menu = scene.instantiate()
	root.add_child(menu)

	var buttons = {
		"Beginner": menu.get_node_or_null("TabContainer/Settings/SettingsContent/DifficultyButtons/DiffBeginnerBtn"),
		"Advanced": menu.get_node_or_null("TabContainer/Settings/SettingsContent/DifficultyButtons/DiffAdvancedBtn"),
		"Expert": menu.get_node_or_null("TabContainer/Settings/SettingsContent/DifficultyButtons/DiffExpertBtn"),
	}
	for diff in buttons:
		var btn = buttons[diff]
		_check(btn != null and btn.toggle_mode and btn.text == diff, \
			"missing/misconfigured toggle button: " + diff)

	root.remove_child(menu)
	menu.free()
	_finish()


func _finish():
	print("\n=== Test Summary ===")
	if _passed:
		print("✓ ALL DIFFICULTY UI TESTS PASSED")
	else:
		print("✗ SOME TESTS FAILED")
	quit(0 if _passed else 1)


func _check(condition: bool, message: String):
	if condition:
		print("  ✓ PASS")
	else:
		_passed = false
		print("  ✗ FAIL: ", message)
