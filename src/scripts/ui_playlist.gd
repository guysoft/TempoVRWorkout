extends VBoxContainer

# View modes for the playlist UI
enum ViewMode { PLAYLISTS, SONGS }

@onready var playlist_items = $ListContainer/PlaylistItems
@onready var scroll_up_btn = $ListContainer/ScrollUpBtn
@onready var scroll_down_btn = $ListContainer/ScrollDownBtn
@onready var play_button = $PlayButton
@onready var playlist_label = $HeaderContainer/PlaylistLabel
@onready var back_button = $HeaderContainer/BackButton

var _current_view_mode: ViewMode = ViewMode.PLAYLISTS
var _selected_playlist_index: int = -1
var _selected_playlist = null  # PlaylistData for songs view
var _selected_song_index: int = -1
var _beatplayer = null

func _get_beatplayer():
	if _beatplayer == null:
		var manager = Global.manager()
		if manager:
			_beatplayer = manager._beatplayer
	return _beatplayer

func _ready():
	# Connect button signals using button_down for VR raycast compatibility
	if scroll_up_btn and not scroll_up_btn.button_down.is_connected(_on_scroll_up_pressed):
		scroll_up_btn.button_down.connect(_on_scroll_up_pressed)
	if scroll_down_btn and not scroll_down_btn.button_down.is_connected(_on_scroll_down_pressed):
		scroll_down_btn.button_down.connect(_on_scroll_down_pressed)
	if play_button and not play_button.button_down.is_connected(_on_play_pressed):
		play_button.button_down.connect(_on_play_pressed)
	if back_button and not back_button.button_down.is_connected(_on_back_pressed):
		back_button.button_down.connect(_on_back_pressed)
	if playlist_items:
		if not playlist_items.item_selected.is_connected(_on_item_selected):
			playlist_items.item_selected.connect(_on_item_selected)
		# Connect double-click for entering playlist or navigating to song
		if not playlist_items.item_activated.is_connected(_on_item_activated):
			playlist_items.item_activated.connect(_on_item_activated)
	
	# Connect to scroll changes for button visibility
	if playlist_items:
		var v_scroll = playlist_items.get_v_scroll_bar()
		if v_scroll and not v_scroll.is_connected("value_changed", _on_scroll_changed):
			v_scroll.connect("value_changed", _on_scroll_changed)
	
	# Start in playlists view
	_show_playlists_view()

	# Restore saved playlist state after initial view
	_restore_playlist_state()


func _show_playlists_view():
	"""Switch to showing list of playlists"""
	_current_view_mode = ViewMode.PLAYLISTS
	_selected_playlist = null
	_selected_song_index = -1
	
	Settings.set_setting("ui", "playlist_view_mode", 0)

	# Update UI
	if playlist_label:
		playlist_label.text = "PLAYLISTS"
	if back_button:
		back_button.visible = false
	
	_populate_playlists()
	_update_play_button()


func _show_songs_view(playlist):
	"""Switch to showing songs in a specific playlist"""
	if playlist == null:
		return
	
	_current_view_mode = ViewMode.SONGS
	_selected_playlist = playlist
	_selected_song_index = -1
	
	Settings.set_setting("ui", "playlist_view_mode", 1)

	# Update UI
	if playlist_label:
		playlist_label.text = playlist.name
	if back_button:
		back_button.visible = true
	
	_populate_songs()
	_update_play_button()


func _populate_playlists():
	if not playlist_items:
		return
	
	playlist_items.clear()
	
	var playlists = PlaylistManager.get_playlists()
	
	if playlists.size() == 0:
		playlist_items.add_item("No playlists found")
		playlist_items.set_item_disabled(0, true)
		return
	
	for playlist in playlists:
		var song_count = playlist.entries.size()
		var display_text = playlist.name + " (" + str(song_count) + " songs)"
		
		# Add shuffle indicator
		if playlist.is_shuffle:
			display_text += " [Shuffle]"
		
		playlist_items.add_item(display_text)
	
	# Update scroll button visibility
	call_deferred("_update_scroll_button_visibility")


func _populate_songs():
	"""Populate the list with songs from the selected playlist"""
	if not playlist_items or _selected_playlist == null:
		return
	
	playlist_items.clear()
	
	if _selected_playlist.entries.size() == 0:
		playlist_items.add_item("No songs in playlist")
		playlist_items.set_item_disabled(0, true)
		return
	
	for i in range(_selected_playlist.entries.size()):
		var song = _selected_playlist.entries[i]
		var display_text = str(i + 1) + ". " + song.name
		
		# Add difficulty indicator
		if song.difficulty != "":
			display_text += " [" + song.difficulty + "]"
		
		playlist_items.add_item(display_text)
		
		# Disable songs without layout
		if song.layout_path == "":
			playlist_items.set_item_disabled(i, true)
			playlist_items.set_item_custom_fg_color(i, Color(0.5, 0.5, 0.5))
			playlist_items.set_item_tooltip(i, "No layout available")
	
	# Update scroll button visibility
	call_deferred("_update_scroll_button_visibility")


func _on_back_pressed():
	"""Return to playlists view"""
	if _current_view_mode == ViewMode.SONGS:
		_show_playlists_view()


func _on_scroll_up_pressed():
	if not playlist_items:
		return
	
	var v_scroll = playlist_items.get_v_scroll_bar()
	if not v_scroll:
		return
	
	var page_size = playlist_items.size.y
	var new_value = max(0, v_scroll.value - page_size)
	v_scroll.value = new_value
	_update_scroll_button_visibility()


func _on_scroll_down_pressed():
	if not playlist_items:
		return
	
	var v_scroll = playlist_items.get_v_scroll_bar()
	if not v_scroll:
		return
	
	var page_size = playlist_items.size.y
	var max_scroll = v_scroll.max_value - v_scroll.page
	var new_value = min(max_scroll, v_scroll.value + page_size)
	v_scroll.value = new_value
	_update_scroll_button_visibility()


func _on_scroll_changed(_value: float):
	_update_scroll_button_visibility()


func _update_scroll_button_visibility():
	if not playlist_items:
		return
	
	var v_scroll = playlist_items.get_v_scroll_bar()
	if not v_scroll:
		if scroll_up_btn:
			scroll_up_btn.visible = false
		if scroll_down_btn:
			scroll_down_btn.visible = false
		return
	
	var content_exceeds_view = v_scroll.max_value > v_scroll.page
	
	if not content_exceeds_view:
		if scroll_up_btn:
			scroll_up_btn.visible = false
		if scroll_down_btn:
			scroll_down_btn.visible = false
		return
	
	if scroll_up_btn:
		scroll_up_btn.visible = v_scroll.value > 0
	
	if scroll_down_btn:
		var max_scroll = v_scroll.max_value - v_scroll.page
		scroll_down_btn.visible = v_scroll.value < max_scroll


func _on_play_pressed():
	"""Handle play button press - behavior depends on view mode"""
	if _current_view_mode == ViewMode.PLAYLISTS:
		# In playlists view, enter the selected playlist
		if _selected_playlist_index >= 0:
			var playlist = PlaylistManager.get_playlist(_selected_playlist_index)
			if playlist:
				_show_songs_view(playlist)
	else:
		# In songs view, start the playlist
		if _selected_playlist == null or _selected_playlist.entries.size() == 0:
			push_warning("Playlist has no songs")
			return
		
		# Start playlist mode and load game
		if not PlaylistManager.start_playlist(_selected_playlist):
			push_warning("Playlist has no valid songs (all missing layouts)")
			return
		
		# Load the game scene
		Global.manager().load_scene(Global.manager().game_path, "game")


func _on_item_selected(index: int):
	"""Handle single click on item"""
	if playlist_items.get_item_count() <= 0:
		return
	
	if _current_view_mode == ViewMode.PLAYLISTS:
		if index < 0 or index >= PlaylistManager.get_playlist_count():
			return
		
		_selected_playlist_index = index
		Settings.set_setting("ui", "playlist_selected_index", index)
		_update_play_button()
		
		# Preview first song in playlist
		var playlist = PlaylistManager.get_playlist(index)
		if playlist and playlist.entries.size() > 0:
			_preview_playlist_song(playlist, 0)
	else:
		# Songs view
		if _selected_playlist == null:
			return
		if index < 0 or index >= _selected_playlist.entries.size():
			return
		
		# Check if song is disabled (no layout)
		var song = _selected_playlist.entries[index]
		if song.layout_path == "":
			return
		
		_selected_song_index = index
		Settings.set_setting("ui", "playlist_selected_song_index", index)
		_update_play_button()
		
		# Preview the selected song
		_preview_playlist_song(_selected_playlist, index)
		
		# Cross-select in the Custom tab so the user can also play it solo
		navigate_to_song(index)


func _on_item_activated(index: int):
	"""Handle double-click on item"""
	if _current_view_mode == ViewMode.PLAYLISTS:
		# Double-click on playlist: enter songs view
		if index >= 0 and index < PlaylistManager.get_playlist_count():
			var playlist = PlaylistManager.get_playlist(index)
			if playlist:
				_show_songs_view(playlist)
	else:
		# Double-click on song: navigate to it in the song list
		if _selected_playlist and index >= 0 and index < _selected_playlist.entries.size():
			var song = _selected_playlist.entries[index]
			if song.layout_path != "":
				navigate_to_song(index)


func _preview_playlist_song(playlist, song_index: int):
	if song_index < 0 or song_index >= playlist.entries.size():
		return
	
	var song = playlist.entries[song_index]
	if song.music_path == "":
		push_warning("No music file found for: " + song.name)
		return
	
	# Play preview audio
	var audio_loader = AudioLoader.new()
	var beatplayer = _get_beatplayer()
	if beatplayer:
		beatplayer.stop_music()
		var stream = audio_loader.loadfile(song.music_path, false)
		if stream:
			beatplayer.stream = stream
			# Try to get BPM from layout if available
			if song.layout_path != "":
				var map = MapFactory.create_map(song.layout_path)
				if map:
					beatplayer.bpm = map.get_bpm()
			beatplayer.play_music()
		else:
			push_warning("Failed to load audio file: " + song.music_path)


func _update_play_button():
	if not play_button:
		return
	
	if _current_view_mode == ViewMode.PLAYLISTS:
		if _selected_playlist_index < 0:
			play_button.disabled = true
			play_button.text = "Select Playlist"
		else:
			var playlist = PlaylistManager.get_playlist(_selected_playlist_index)
			if playlist and playlist.entries.size() > 0:
				play_button.disabled = false
				play_button.text = "View Songs"
			else:
				play_button.disabled = true
				play_button.text = "No Songs"
	else:
		# Songs view
		if _selected_playlist and _selected_playlist.entries.size() > 0:
			play_button.disabled = false
			play_button.text = "Play Playlist"
		else:
			play_button.disabled = true
			play_button.text = "No Songs"


# Get the songs for the currently selected playlist
func get_selected_playlist_songs() -> Array:
	if _selected_playlist == null:
		return []
	return _selected_playlist.entries


# Navigate to the Custom tab in the song list and select a specific song.
# This is called when a user single-clicks a song in the playlist songs view,
# allowing them to also play the song solo via the normal Start button.
func navigate_to_song(song_index: int):
	if _selected_playlist == null:
		return
	if song_index < 0 or song_index >= _selected_playlist.entries.size():
		return
	
	var song = _selected_playlist.entries[song_index]
	if song.layout_path == "":
		return
	
	# Set game variables - use music_path for PowerBeatsVR songs (what Custom tab expects)
	if song.music_path != "":
		GameVariables.path = song.music_path
	else:
		GameVariables.path = song.layout_path
	GameVariables.difficulty = song.difficulty
	
	# Find the song list UI panel.
	# The playlist is under MainMenu/UICanvasInteract4/SubViewport/UI_Playlist
	# The song list is under MainMenu/UICanvasInteract2/SubViewport/UI_SongList
	# Walk up from this node to MainMenu, then down to the song list.
	var main_menu = _find_main_menu()
	if main_menu == null:
		print("navigate_to_song: Could not find MainMenu node")
		return
	
	# Find UICanvasInteract2 which contains the song list
	var song_list_canvas = main_menu.get_node_or_null("UICanvasInteract2")
	if song_list_canvas == null:
		print("navigate_to_song: Could not find UICanvasInteract2")
		return
	
	# Get the SubViewport's child (the UI_SongList VBoxContainer)
	var subviewport = song_list_canvas.get_node_or_null("SubViewport")
	if subviewport == null or subviewport.get_child_count() == 0:
		print("navigate_to_song: Could not find SubViewport or it has no children")
		return
	
	var song_list_root = subviewport.get_child(0)  # UI_SongList (VBoxContainer)
	
	# Find the TabContainer and switch to the Custom tab (index 1)
	var tab_container = song_list_root.get_node_or_null("TabContainer")
	if tab_container and tab_container is TabContainer:
		tab_container.current_tab = 1  # Switch to "Custom" tab
	
	# Find the Custom tab instance (second child of TabContainer)
	var custom_tab = null
	if tab_container:
		for i in range(tab_container.get_child_count()):
			var child = tab_container.get_child(i)
			if child.has_method("select_song_by_path") and child.get("tab") == "Custom":
				custom_tab = child
				break
	
	if custom_tab:
		custom_tab.select_song_by_path(song.layout_path)
	else:
		print("navigate_to_song: Could not find Custom tab with select_song_by_path")
	
	print("Navigate to song: ", song.name, " at ", song.layout_path)


# Find the MainMenu node by walking up the scene tree from this node.
func _find_main_menu() -> Node:
	# Walk up through parents to find MainMenu
	var node = self
	while node != null:
		if node.name == "MainMenu":
			return node
		node = node.get_parent()
	
	# Fallback: try the known runtime path
	var main_menu = get_tree().root.get_node_or_null("GameManager/ScenesHolder/MainMenu")
	if main_menu:
		return main_menu
	
	# Second fallback: group-based lookup
	return get_tree().get_first_node_in_group("main_menu")


# Get current view mode
func get_view_mode() -> ViewMode:
	return _current_view_mode


# Restore saved playlist state (view mode, selected playlist, selected song)
func _restore_playlist_state():
	var saved_view_mode = Settings.get_setting("ui", "playlist_view_mode", 0)
	var saved_playlist_index = Settings.get_setting("ui", "playlist_selected_index", 0)
	var saved_song_index = Settings.get_setting("ui", "playlist_selected_song_index", 0)

	if saved_view_mode == 1 and saved_playlist_index is int and saved_playlist_index >= 0:
		# Was in songs view — navigate to the saved playlist
		if saved_playlist_index < PlaylistManager.get_playlist_count():
			var playlist = PlaylistManager.get_playlist(saved_playlist_index)
			if playlist and playlist.entries.size() > 0:
				_show_songs_view(playlist)
				# Select the saved song if valid
				if saved_song_index is int and saved_song_index >= 0 and saved_song_index < playlist.entries.size():
					var song = playlist.entries[saved_song_index]
					if song.layout_path != "":
						playlist_items.select(saved_song_index)
						_on_item_selected(saved_song_index)
					else:
						# Saved song no longer available, select first valid
						_select_first_valid_song()
				else:
					_select_first_valid_song()
				return
		# Playlist no longer exists, stay in playlists view
	elif saved_playlist_index is int and saved_playlist_index >= 0:
		# Was in playlists view — select the saved playlist
		if saved_playlist_index < PlaylistManager.get_playlist_count():
			playlist_items.select(saved_playlist_index)
			_on_item_selected(saved_playlist_index)


func _select_first_valid_song():
	"""Select the first non-disabled song in the current playlist"""
	if _selected_playlist == null:
		return
	for i in range(_selected_playlist.entries.size()):
		var song = _selected_playlist.entries[i]
		if song.layout_path != "":
			playlist_items.select(i)
			_on_item_selected(i)
			return
