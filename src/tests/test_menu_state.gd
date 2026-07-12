extends SceneTree

# Test script for menu state persistence (Settings save/restore).
# Tests the Settings.gd implementation directly by instantiating the script as a
# Node, because autoloads (like Settings) are NOT registered when running via
# `godot --headless --script ...` (other tests such as test_playlist.gd replicate
# autoload logic rather than rely on it for the same reason).
#
# Run with: godot --headless --path src --script res://tests/test_menu_state.gd

const SettingsScript = preload("res://scripts/Settings.gd")

var _tests_passed = 0
var _tests_failed = 0
var _settings_node: Node = null

func _init():
	_settings_node = SettingsScript.new()
	_run_tests()
	_settings_node.queue_free()


func _run_tests():
	print("\n=== Menu State Persistence Tests ===\n")

	test_settings_has_menu_keys()
	test_save_and_restore_tab()
	test_save_and_restore_playlist_state()
	test_save_and_restore_custom_song()
	test_save_and_restore_last_played()
	test_default_values_when_nothing_saved()

	print("\n=== Test Summary ===")
	print("Passed: ", _tests_passed)
	print("Failed: ", _tests_failed)
	if _tests_failed == 0:
		print("✓ ALL TESTS PASSED")
	else:
		print("✗ SOME TESTS FAILED")

	quit(0 if _tests_failed == 0 else 1)


func _pass(name: String):
	_tests_passed += 1
	print("  ✓ ", name)


func _fail(name: String, reason: String = ""):
	_tests_failed += 1
	print("  ✗ ", name, " — ", reason)


func test_settings_has_menu_keys():
	var s = _settings_node
	# Verify the default keys exist in the _settings dict
	var ui = s._settings.get("ui", {})

	if ui.has("song_list_tab"):
		_pass("Settings has ui.song_list_tab")
	else:
		_fail("Settings has ui.song_list_tab", "key missing")

	if ui.has("custom_music_folder"):
		_pass("Settings has ui.custom_music_folder")
	else:
		_fail("Settings has ui.custom_music_folder", "key missing")

	if ui.has("custom_selected_song"):
		_pass("Settings has ui.custom_selected_song")
	else:
		_fail("Settings has ui.custom_selected_song", "key missing")

	if ui.has("playlist_view_mode"):
		_pass("Settings has ui.playlist_view_mode")
	else:
		_fail("Settings has ui.playlist_view_mode", "key missing")

	if ui.has("playlist_selected_index"):
		_pass("Settings has ui.playlist_selected_index")
	else:
		_fail("Settings has ui.playlist_selected_index", "key missing")

	if ui.has("playlist_selected_song_index"):
		_pass("Settings has ui.playlist_selected_song_index")
	else:
		_fail("Settings has ui.playlist_selected_song_index", "key missing")

	if ui.has("last_played_path"):
		_pass("Settings has ui.last_played_path")
	else:
		_fail("Settings has ui.last_played_path", "key missing")

	if ui.has("last_played_difficulty"):
		_pass("Settings has ui.last_played_difficulty")
	else:
		_fail("Settings has ui.last_played_difficulty", "key missing")


func test_save_and_restore_tab():
	# Simulate a saved value by writing directly to the in-memory _settings dict
	# (avoids calling set_setting, which would clobber user://settings.ini).
	# get_setting is the real method under test.
	var s = _settings_node
	s._settings["ui"]["song_list_tab"] = 2
	var restored = s.get_setting("ui", "song_list_tab", 0)
	if restored == 2:
		_pass("Save and restore song_list_tab=2")
	else:
		_fail("Save and restore song_list_tab=2", "got " + str(restored))


func test_save_and_restore_playlist_state():
	var s = _settings_node
	s._settings["ui"]["playlist_view_mode"] = 1
	s._settings["ui"]["playlist_selected_index"] = 3
	s._settings["ui"]["playlist_selected_song_index"] = 5

	var vm = s.get_setting("ui", "playlist_view_mode", 0)
	var pi = s.get_setting("ui", "playlist_selected_index", 0)
	var si = s.get_setting("ui", "playlist_selected_song_index", 0)

	if vm == 1 and pi == 3 and si == 5:
		_pass("Save and restore playlist state (view=1, playlist=3, song=5)")
	else:
		_fail("Save and restore playlist state", "got vm=" + str(vm) + " pi=" + str(pi) + " si=" + str(si))


func test_save_and_restore_custom_song():
	var s = _settings_node
	s._settings["ui"]["custom_music_folder"] = "MyFolder"
	s._settings["ui"]["custom_selected_song"] = "Those Who Squat.ogg"

	var folder = s.get_setting("ui", "custom_music_folder", "")
	var song = s.get_setting("ui", "custom_selected_song", "")

	if folder == "MyFolder" and song == "Those Who Squat.ogg":
		_pass("Save and restore custom song state (folder + song name)")
	else:
		_fail("Save and restore custom song state", "got folder=" + str(folder) + " song=" + str(song))


func test_save_and_restore_last_played():
	var s = _settings_node
	s._settings["ui"]["last_played_path"] = "/some/path/Unity.ogg"
	s._settings["ui"]["last_played_difficulty"] = "Expert"

	var path = s.get_setting("ui", "last_played_path", "")
	var diff = s.get_setting("ui", "last_played_difficulty", "")

	if path == "/some/path/Unity.ogg" and diff == "Expert":
		_pass("Save and restore last_played_path + difficulty")
	else:
		_fail("Save and restore last_played_path + difficulty", "got path=" + str(path) + " diff=" + str(diff))


func test_default_values_when_nothing_saved():
	var s = _settings_node
	# A key that doesn't exist in the _settings dict should return the default arg
	# passed to get_setting. Use a sentinel-named key so we don't pollute _settings.
	var val = s.get_setting("ui", "totally_nonexistent_test_key_12345", "fallback.mp3")
	if val == "fallback.mp3":
		_pass("Default value returned when key not set")
	else:
		_fail("Default value returned when key not set", "got " + str(val))

	# Also verify that a missing *section* returns the default
	var sec_val = s.get_setting("totally_nonexistent_section_12345", "x", 42)
	if sec_val == 42:
		_pass("Default value returned when section not set")
	else:
		_fail("Default value returned when section not set", "got " + str(sec_val))
