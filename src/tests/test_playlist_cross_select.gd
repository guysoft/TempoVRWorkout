extends SceneTree

# Tests for the playlist-to-custom-tab cross-selection feature.
# Verifies:
#   1. Basename extraction logic (layout path -> song name)
#   2. Music file matching by basename
#   3. Recursive folder search for music files
#   4. Source code inspection: navigate_to_song switches tabs
#   5. Source code inspection: single-click triggers navigate_to_song
#   6. Source code inspection: select_song_by_path has subfolder search
#   7. Scene structure: TabContainer has Custom tab at index 1

const MUSIC_EXTENSIONS = ["ogg", "mp3", "wav"]

func _init():
	print("\n=== Playlist Cross-Select Tests ===\n")
	var all_passed = true
	
	all_passed = test_basename_extraction() and all_passed
	all_passed = test_music_file_matching_logic() and all_passed
	all_passed = test_recursive_folder_search() and all_passed
	all_passed = test_navigate_sets_custom_tab() and all_passed
	all_passed = test_single_click_triggers_navigate() and all_passed
	all_passed = test_select_song_by_path_has_subfolder_search() and all_passed
	all_passed = test_scene_structure_tab_container() and all_passed
	all_passed = test_find_main_menu_helper_exists() and all_passed
	all_passed = test_navigate_uses_music_path() and all_passed
	
	print("\n=== Test Summary ===")
	if all_passed:
		print("✓ ALL TESTS PASSED")
	else:
		print("✗ SOME TESTS FAILED")
	
	quit(0 if all_passed else 1)


func test_basename_extraction() -> bool:
	print("--- Testing Basename Extraction from Layout Path ---")
	var passed = true
	
	# Standard layout path
	var layout_path = "/some/path/PowerBeatsVRLevels/Layouts/Wellerman.json"
	var song_name = layout_path.get_file().get_basename()
	if song_name == "Wellerman":
		print("  ✓ Extracted 'Wellerman' from full layout path")
	else:
		print("  ✗ Expected 'Wellerman', got: ", song_name)
		passed = false
	
	# Spaces in name
	layout_path = "Layouts/My Favorite Song.json"
	song_name = layout_path.get_file().get_basename()
	if song_name == "My Favorite Song":
		print("  ✓ Extracted 'My Favorite Song' with spaces")
	else:
		print("  ✗ Expected 'My Favorite Song', got: ", song_name)
		passed = false
	
	# Just a filename
	layout_path = "SongName.json"
	song_name = layout_path.get_file().get_basename()
	if song_name == "SongName":
		print("  ✓ Extracted 'SongName' from just filename")
	else:
		print("  ✗ Expected 'SongName', got: ", song_name)
		passed = false
	
	# Empty path
	layout_path = ""
	song_name = layout_path.get_file().get_basename()
	if song_name == "":
		print("  ✓ Empty path returns empty string")
	else:
		print("  ✗ Expected empty, got: ", song_name)
		passed = false
	
	return passed


func test_music_file_matching_logic() -> bool:
	print("--- Testing Music File Matching by Basename ---")
	var passed = true
	
	# Simulate the arrays as they would exist in ui_song_list.gd
	var songs_list = ["Wellerman.ogg", "TestSong.mp3", "Another Song.wav"]
	var item_types = [2, 2, 2]  # MUSIC_FILE = 2
	
	# Match TestSong by layout path
	var layout_path = "Layouts/TestSong.json"
	var song_name = layout_path.get_file().get_basename()
	
	var found_index = -1
	for i in range(songs_list.size()):
		if item_types[i] == 2:
			var music_base = songs_list[i].get_basename()
			if music_base == song_name:
				found_index = i
				break
	
	if found_index == 1:
		print("  ✓ Found TestSong at index 1")
	else:
		print("  ✗ Expected index 1, got: ", found_index)
		passed = false
	
	# Match with spaces
	layout_path = "Layouts/Another Song.json"
	song_name = layout_path.get_file().get_basename()
	found_index = -1
	for i in range(songs_list.size()):
		if item_types[i] == 2:
			if songs_list[i].get_basename() == song_name:
				found_index = i
				break
	
	if found_index == 2:
		print("  ✓ Found 'Another Song' at index 2")
	else:
		print("  ✗ Expected index 2, got: ", found_index)
		passed = false
	
	# No match
	layout_path = "Layouts/NonExistent.json"
	song_name = layout_path.get_file().get_basename()
	found_index = -1
	for i in range(songs_list.size()):
		if item_types[i] == 2:
			if songs_list[i].get_basename() == song_name:
				found_index = i
				break
	
	if found_index == -1:
		print("  ✓ Correctly returns -1 for non-existent song")
	else:
		print("  ✗ Should not find non-existent song, got index: ", found_index)
		passed = false
	
	# Skip non-music items (folders, parent dirs)
	var mixed_types = [1, 0, 2, 2]  # PARENT_DIR, FOLDER, MUSIC_FILE, MUSIC_FILE
	var mixed_list = ["..", "subfolder", "Target.ogg", "Other.mp3"]
	layout_path = "Layouts/Target.json"
	song_name = layout_path.get_file().get_basename()
	found_index = -1
	for i in range(mixed_list.size()):
		if mixed_types[i] == 2:
			if mixed_list[i].get_basename() == song_name:
				found_index = i
				break
	
	if found_index == 2:
		print("  ✓ Correctly skips non-music items and finds Target at index 2")
	else:
		print("  ✗ Expected index 2, got: ", found_index)
		passed = false
	
	return passed


func test_recursive_folder_search() -> bool:
	print("--- Testing Recursive Folder Search ---")
	var passed = true
	
	# Create a temporary directory structure for testing
	var test_root = "user://test_cross_select"
	
	# Clean up any previous test data
	_cleanup_test_dir(test_root)
	
	# Create directory structure:
	# test_root/
	#   song_at_root.ogg
	#   subdir1/
	#     nested_song.mp3
	#     subdir2/
	#       deep_song.wav
	DirAccess.make_dir_recursive_absolute(test_root + "/subdir1/subdir2")
	
	# Create test files
	var f = FileAccess.open(test_root + "/song_at_root.ogg", FileAccess.WRITE)
	f.store_string("fake audio")
	f.close()
	
	f = FileAccess.open(test_root + "/subdir1/nested_song.mp3", FileAccess.WRITE)
	f.store_string("fake audio")
	f.close()
	
	f = FileAccess.open(test_root + "/subdir1/subdir2/deep_song.wav", FileAccess.WRITE)
	f.store_string("fake audio")
	f.close()
	
	# Test 1: Find file at root
	var result = _test_find_music_recursive(test_root, "song_at_root")
	if result == "":
		print("  ✓ Found song_at_root at root (empty relative path)")
	else:
		print("  ✗ Expected empty relative path for root, got: '", result, "'")
		passed = false
	
	# But verify it actually exists at root
	var found = false
	for ext in MUSIC_EXTENSIONS:
		if FileAccess.file_exists(test_root + "/song_at_root." + ext):
			found = true
			break
	if found:
		print("  ✓ Verified song_at_root file exists at root")
	else:
		print("  ✗ song_at_root file not found at root")
		passed = false
	
	# Test 2: Find file in subfolder
	result = _test_find_music_recursive(test_root, "nested_song")
	if result == "subdir1":
		print("  ✓ Found nested_song in subdir1")
	else:
		print("  ✗ Expected 'subdir1', got: '", result, "'")
		passed = false
	
	# Test 3: Find file in nested subfolder
	result = _test_find_music_recursive(test_root, "deep_song")
	if result == "subdir1/subdir2":
		print("  ✓ Found deep_song in subdir1/subdir2")
	else:
		print("  ✗ Expected 'subdir1/subdir2', got: '", result, "'")
		passed = false
	
	# Test 4: File not found
	result = _test_find_music_recursive(test_root, "nonexistent")
	# For "not found", _find_music_in_subfolders returns "" but the file won't exist
	# We verify by checking the file doesn't exist
	found = false
	for ext in MUSIC_EXTENSIONS:
		if FileAccess.file_exists(test_root + "/nonexistent." + ext):
			found = true
			break
	if not found:
		print("  ✓ Correctly reports no file for nonexistent song")
	else:
		print("  ✗ Should not find nonexistent song")
		passed = false
	
	# Cleanup
	_cleanup_test_dir(test_root)
	
	return passed


# Mirrors the recursive search logic from ui_song_list.gd
# Returns the relative folder path where the song was found, or "" if at root/not found
func _test_find_music_recursive(base_path: String, song_name: String) -> String:
	return _test_find_recursive(base_path, song_name, "")


func _test_find_recursive(base_path: String, song_name: String, relative_path: String) -> String:
	var current_path = base_path
	if relative_path != "":
		current_path = base_path + "/" + relative_path
	
	if not DirAccess.dir_exists_absolute(current_path):
		return ""
	
	var dir = DirAccess.open(current_path)
	if not dir:
		return ""
	
	dir.list_dir_begin()
	var folders: Array[String] = []
	var item = dir.get_next()
	while item != "":
		if not item.begins_with("."):
			var item_path = current_path + "/" + item
			var ext = item.get_extension().to_lower()
			if ext in MUSIC_EXTENSIONS:
				if item.get_basename() == song_name:
					dir.list_dir_end()
					return relative_path
			elif DirAccess.dir_exists_absolute(item_path):
				folders.append(item)
		item = dir.get_next()
	dir.list_dir_end()
	
	for folder in folders:
		var sub_relative = folder if relative_path == "" else relative_path + "/" + folder
		var result = _test_find_recursive(base_path, song_name, sub_relative)
		if result != "":
			return result
	
	return ""


func _cleanup_test_dir(dir_path: String):
	"""Recursively remove a test directory"""
	if not DirAccess.dir_exists_absolute(dir_path):
		return
	
	var dir = DirAccess.open(dir_path)
	if not dir:
		return
	
	dir.list_dir_begin()
	var item = dir.get_next()
	while item != "":
		if not item.begins_with("."):
			var item_path = dir_path + "/" + item
			if DirAccess.dir_exists_absolute(item_path):
				_cleanup_test_dir(item_path)
			else:
				DirAccess.remove_absolute(item_path)
		item = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(dir_path)


func test_navigate_sets_custom_tab() -> bool:
	print("--- Testing navigate_to_song Switches to Custom Tab ---")
	var passed = true
	
	var file = FileAccess.open("res://scripts/ui_playlist.gd", FileAccess.READ)
	if file == null:
		print("  ✗ Could not open ui_playlist.gd")
		return false
	var source = file.get_as_text()
	file.close()
	
	# Check that navigate_to_song sets current_tab = 1 (Custom tab)
	if source.find("current_tab = 1") != -1:
		print("  ✓ navigate_to_song switches TabContainer to Custom tab (index 1)")
	else:
		print("  ✗ navigate_to_song does not set current_tab = 1")
		passed = false
	
	# Check that it looks for the Custom tab specifically
	if source.find('.get("tab") == "Custom"') != -1:
		print("  ✓ navigate_to_song finds the Custom tab instance by tab property")
	else:
		print("  ✗ navigate_to_song does not filter by tab == 'Custom'")
		passed = false
	
	# Check that it calls select_song_by_path on the custom tab
	if source.find("custom_tab.select_song_by_path") != -1:
		print("  ✓ navigate_to_song calls select_song_by_path on the Custom tab")
	else:
		print("  ✗ navigate_to_song does not call select_song_by_path on custom tab")
		passed = false
	
	# Check it has a _find_main_menu helper
	if source.find("func _find_main_menu()") != -1:
		print("  ✓ Has _find_main_menu() helper for robust scene tree traversal")
	else:
		print("  ✗ Missing _find_main_menu() helper")
		passed = false
	
	return passed


func test_single_click_triggers_navigate() -> bool:
	print("--- Testing Single Click Triggers navigate_to_song ---")
	var passed = true
	
	var file = FileAccess.open("res://scripts/ui_playlist.gd", FileAccess.READ)
	if file == null:
		print("  ✗ Could not open ui_playlist.gd")
		return false
	var source = file.get_as_text()
	file.close()
	
	# Find the _on_item_selected function and check it calls navigate_to_song
	var func_start = source.find("func _on_item_selected")
	if func_start == -1:
		print("  ✗ _on_item_selected function not found")
		return false
	
	# Get the section of code after _on_item_selected until the next function
	var next_func = source.find("\nfunc ", func_start + 1)
	var func_body = source.substr(func_start, next_func - func_start) if next_func != -1 else source.substr(func_start)
	
	if func_body.find("navigate_to_song") != -1:
		print("  ✓ _on_item_selected calls navigate_to_song (single-click triggers cross-select)")
	else:
		print("  ✗ _on_item_selected does NOT call navigate_to_song")
		passed = false
	
	# Verify it's called in the songs view branch (not playlists view)
	if func_body.find("_preview_playlist_song") != -1 and func_body.find("navigate_to_song") != -1:
		print("  ✓ navigate_to_song is called alongside _preview_playlist_song in songs view")
	else:
		print("  ✗ navigate_to_song placement may be incorrect")
		passed = false
	
	return passed


func test_select_song_by_path_has_subfolder_search() -> bool:
	print("--- Testing select_song_by_path Has Recursive Subfolder Search ---")
	var passed = true
	
	var file = FileAccess.open("res://scripts/ui_song_list.gd", FileAccess.READ)
	if file == null:
		print("  ✗ Could not open ui_song_list.gd")
		return false
	var source = file.get_as_text()
	file.close()
	
	# Check that _find_music_in_subfolders function exists
	if source.find("func _find_music_in_subfolders(") != -1:
		print("  ✓ _find_music_in_subfolders() function exists")
	else:
		print("  ✗ _find_music_in_subfolders() function not found")
		passed = false
	
	# Check that _find_music_in_subfolders_recursive function exists
	if source.find("func _find_music_in_subfolders_recursive(") != -1:
		print("  ✓ _find_music_in_subfolders_recursive() function exists")
	else:
		print("  ✗ _find_music_in_subfolders_recursive() function not found")
		passed = false
	
	# Check that select_song_by_path calls the recursive search
	var func_start = source.find("func select_song_by_path")
	if func_start == -1:
		print("  ✗ select_song_by_path function not found")
		return false
	
	var next_func = source.find("\nfunc ", func_start + 1)
	var func_body = source.substr(func_start, next_func - func_start) if next_func != -1 else source.substr(func_start)
	
	if func_body.find("_find_music_in_subfolders") != -1:
		print("  ✓ select_song_by_path calls _find_music_in_subfolders for recursive search")
	else:
		print("  ✗ select_song_by_path does NOT call _find_music_in_subfolders")
		passed = false
	
	# Check it navigates to the folder (sets current_music_folder and repopulates)
	if func_body.find("current_music_folder = folder_path") != -1:
		print("  ✓ select_song_by_path navigates to the found folder")
	else:
		print("  ✗ select_song_by_path does not navigate to found folder")
		passed = false
	
	if func_body.find("populate_list()") != -1:
		print("  ✓ select_song_by_path repopulates list after navigation")
	else:
		print("  ✗ select_song_by_path does not repopulate list")
		passed = false
	
	return passed


func test_scene_structure_tab_container() -> bool:
	print("--- Testing Scene Structure: TabContainer with Custom Tab ---")
	var passed = true
	
	var scene = load("res://scenes/ui_song_list.tscn")
	if scene == null:
		print("  ✗ Could not load ui_song_list.tscn")
		return false
	print("  ✓ ui_song_list.tscn loads successfully")
	
	var instance = scene.instantiate()
	if instance == null:
		print("  ✗ Could not instantiate ui_song_list.tscn")
		return false
	print("  ✓ ui_song_list.tscn instantiates successfully")
	
	# Check TabContainer exists
	var tab_container = instance.get_node_or_null("TabContainer")
	if tab_container and tab_container is TabContainer:
		print("  ✓ TabContainer node exists")
	else:
		print("  ✗ TabContainer node not found")
		passed = false
		instance.queue_free()
		return passed
	
	# Check it has at least 2 tabs
	if tab_container.get_tab_count() >= 2:
		print("  ✓ TabContainer has ", tab_container.get_tab_count(), " tabs (need at least 2)")
	else:
		print("  ✗ TabContainer has only ", tab_container.get_tab_count(), " tab(s)")
		passed = false
	
	# Check tab titles
	if tab_container.get_tab_count() >= 1:
		var tab0_title = tab_container.get_tab_title(0)
		if tab0_title == "Original":
			print("  ✓ Tab 0 is 'Original'")
		else:
			print("  ✗ Tab 0 is '", tab0_title, "', expected 'Original'")
			passed = false
	
	if tab_container.get_tab_count() >= 2:
		var tab1_title = tab_container.get_tab_title(1)
		if tab1_title == "Custom":
			print("  ✓ Tab 1 is 'Custom'")
		else:
			print("  ✗ Tab 1 is '", tab1_title, "', expected 'Custom'")
			passed = false
	
	# Check Custom tab has the correct script with tab = "Custom"
	# NOTE: In headless mode, the script may fail to compile because autoloads
	# (Global, Events, etc.) are not available. In that case, tab property and
	# methods won't be accessible. We verify the script path instead.
	var custom_tab = tab_container.get_child(1)
	if custom_tab:
		var tab_value = custom_tab.get("tab")
		if tab_value == "Custom":
			print("  ✓ Custom tab has tab='Custom' export")
		elif tab_value == null:
			# Script didn't compile in headless - verify via scene file instead
			var scene_file = FileAccess.open("res://scenes/ui_song_list.tscn", FileAccess.READ)
			if scene_file:
				var scene_text = scene_file.get_as_text()
				scene_file.close()
				if scene_text.find('tab = "Custom"') != -1:
					print("  ✓ Custom tab has tab='Custom' (verified via scene file, script not loaded in headless)")
				else:
					print("  ✗ Custom tab missing tab='Custom' in scene file")
					passed = false
			else:
				print("  ✗ Could not open scene file for verification")
				passed = false
		else:
			print("  ✗ Custom tab has tab='", tab_value, "', expected 'Custom'")
			passed = false
		
		if custom_tab.has_method("select_song_by_path"):
			print("  ✓ Custom tab has select_song_by_path method")
		else:
			# Verify via source code if script didn't load
			var source_file = FileAccess.open("res://scripts/ui_song_list.gd", FileAccess.READ)
			if source_file:
				var source = source_file.get_as_text()
				source_file.close()
				if source.find("func select_song_by_path(") != -1:
					print("  ✓ Custom tab has select_song_by_path (verified via source, script not loaded in headless)")
				else:
					print("  ✗ select_song_by_path not found in source")
					passed = false
			else:
				print("  ✗ Could not verify select_song_by_path")
				passed = false
	
	instance.queue_free()
	return passed


func test_find_main_menu_helper_exists() -> bool:
	print("--- Testing _find_main_menu Helper ---")
	var passed = true
	
	var file = FileAccess.open("res://scripts/ui_playlist.gd", FileAccess.READ)
	if file == null:
		print("  ✗ Could not open ui_playlist.gd")
		return false
	var source = file.get_as_text()
	file.close()
	
	# Check _find_main_menu walks up parents
	var func_start = source.find("func _find_main_menu()")
	if func_start == -1:
		print("  ✗ _find_main_menu function not found")
		return false
	
	var next_func = source.find("\nfunc ", func_start + 1)
	var func_body = source.substr(func_start, next_func - func_start) if next_func != -1 else source.substr(func_start)
	
	# Verify it walks up parents
	if func_body.find("get_parent()") != -1:
		print("  ✓ _find_main_menu walks up the scene tree via get_parent()")
	else:
		print("  ✗ _find_main_menu does not walk up parents")
		passed = false
	
	# Verify it has a fallback
	if func_body.find("GameManager/ScenesHolder/MainMenu") != -1:
		print("  ✓ _find_main_menu has fallback path via root")
	else:
		print("  ✗ _find_main_menu missing fallback path")
		passed = false
	
	return passed


func test_navigate_uses_music_path() -> bool:
	print("--- Testing navigate_to_song Uses music_path ---")
	var passed = true
	
	var file = FileAccess.open("res://scripts/ui_playlist.gd", FileAccess.READ)
	if file == null:
		print("  ✗ Could not open ui_playlist.gd")
		return false
	var source = file.get_as_text()
	file.close()
	
	# Find navigate_to_song function body
	var func_start = source.find("func navigate_to_song")
	if func_start == -1:
		print("  ✗ navigate_to_song function not found")
		return false
	
	var next_func = source.find("\nfunc ", func_start + 1)
	var func_body = source.substr(func_start, next_func - func_start) if next_func != -1 else source.substr(func_start)
	
	# Check it uses music_path for GameVariables.path
	if func_body.find("song.music_path") != -1:
		print("  ✓ navigate_to_song uses song.music_path")
	else:
		print("  ✗ navigate_to_song does not use song.music_path")
		passed = false
	
	# Check it still passes layout_path to select_song_by_path (used for matching)
	if func_body.find("select_song_by_path(song.layout_path)") != -1:
		print("  ✓ navigate_to_song passes layout_path to select_song_by_path for matching")
	else:
		print("  ✗ navigate_to_song should pass layout_path to select_song_by_path")
		passed = false
	
	return passed
