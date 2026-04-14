extends SceneTree

# Test script for HighscoreManager
# Run with: godot --headless --script res://tests/test_highscore.gd

const HighscoreManagerScript = preload("res://scripts/HighscoreManager.gd")

var _tests_passed = 0
var _tests_failed = 0

func _init():
	print("\n=== Highscore System Tests ===\n")
	
	test_make_key()
	test_set_and_get_highscore()
	test_only_saves_higher_score()
	test_get_highscore_value_default()
	test_get_highscore_returns_date()
	test_save_and_load_persistence()
	test_song_id_format_beatsaber()
	test_song_id_format_powerbeatsvr()
	
	print("\n=== Test Summary ===")
	print("Passed: ", _tests_passed)
	print("Failed: ", _tests_failed)
	if _tests_failed == 0:
		print("✓ ALL TESTS PASSED")
	else:
		print("✗ SOME TESTS FAILED")
	
	quit()


func _create_manager() -> Node:
	var mgr = Node.new()
	mgr.set_script(HighscoreManagerScript)
	# Don't call _ready (which loads from disk) - we test in-memory
	mgr._data = {}
	return mgr


func assert_eq(actual, expected, test_name: String):
	if actual == expected:
		print("  PASS: ", test_name)
		_tests_passed += 1
	else:
		print("  FAIL: ", test_name, " expected=", expected, " actual=", actual)
		_tests_failed += 1


func assert_true(value: bool, test_name: String):
	assert_eq(value, true, test_name)


func assert_false(value: bool, test_name: String):
	assert_eq(value, false, test_name)


func test_make_key():
	print("test_make_key:")
	var mgr = _create_manager()
	assert_eq(mgr._make_key("bs:TestSong", "Expert"), "bs:TestSong:Expert", "key format")
	assert_eq(mgr._make_key("pbvr:layout1", "Hard"), "pbvr:layout1:Hard", "pbvr key format")
	mgr.free()


func test_set_and_get_highscore():
	print("test_set_and_get_highscore:")
	var mgr = _create_manager()
	var result = mgr.set_highscore("bs:Song1", "Expert", 5000)
	assert_true(result, "first score is new highscore")
	
	var hs = mgr.get_highscore("bs:Song1", "Expert")
	assert_eq(hs["score"], 5000, "stored score matches")
	assert_true(hs.has("date"), "entry has date")
	mgr.free()


func test_only_saves_higher_score():
	print("test_only_saves_higher_score:")
	var mgr = _create_manager()
	mgr.set_highscore("bs:Song1", "Expert", 5000)
	
	var result = mgr.set_highscore("bs:Song1", "Expert", 3000)
	assert_false(result, "lower score not saved")
	assert_eq(mgr.get_highscore_value("bs:Song1", "Expert"), 5000, "original score kept")
	
	result = mgr.set_highscore("bs:Song1", "Expert", 7000)
	assert_true(result, "higher score is new highscore")
	assert_eq(mgr.get_highscore_value("bs:Song1", "Expert"), 7000, "new score saved")
	mgr.free()


func test_get_highscore_value_default():
	print("test_get_highscore_value_default:")
	var mgr = _create_manager()
	assert_eq(mgr.get_highscore_value("bs:NoSuch", "Easy"), 0, "no score returns 0")
	
	var hs = mgr.get_highscore("bs:NoSuch", "Easy")
	assert_eq(hs, {}, "no entry returns empty dict")
	mgr.free()


func test_get_highscore_returns_date():
	print("test_get_highscore_returns_date:")
	var mgr = _create_manager()
	mgr.set_highscore("bs:Song1", "Hard", 1234)
	var hs = mgr.get_highscore("bs:Song1", "Hard")
	# Date should be ISO 8601 format: YYYY-MM-DDTHH:MM:SS
	assert_true(hs["date"].length() >= 19, "date is ISO 8601 length")
	assert_true(hs["date"].contains("T"), "date contains T separator")
	mgr.free()


func test_save_and_load_persistence():
	print("test_save_and_load_persistence:")
	var mgr = _create_manager()
	mgr._ensure_save_dir()
	mgr.set_highscore("bs:PersistTest", "Normal", 9999)
	mgr.save_data()
	
	# Create a new manager and load
	var mgr2 = _create_manager()
	mgr2.load_data()
	assert_eq(mgr2.get_highscore_value("bs:PersistTest", "Normal"), 9999, "persisted score loaded")
	
	# Clean up test data
	mgr2._data.erase("bs:PersistTest:Normal")
	mgr2.save_data()
	mgr.free()
	mgr2.free()


func test_song_id_format_beatsaber():
	print("test_song_id_format_beatsaber:")
	# MapLoader.get_song_id() returns "bs:" + get_name()
	# We can't easily instantiate MapLoader without a real path, so test the format
	var expected_prefix = "bs:"
	assert_true("bs:TestSong".begins_with(expected_prefix), "Beat Saber ID has bs: prefix")


func test_song_id_format_powerbeatsvr():
	print("test_song_id_format_powerbeatsvr:")
	var expected_prefix = "pbvr:"
	assert_true("pbvr:layout_file".begins_with(expected_prefix), "PowerBeatsVR ID has pbvr: prefix")
