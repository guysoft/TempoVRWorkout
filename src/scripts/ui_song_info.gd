extends ReferenceRect

@onready var _song_name_label = $Content/SongNameLabel
@onready var _difficulty_label = $Content/DifficultyLabel
@onready var _highscore_label = $Content/HighscoreLabel
@onready var _date_label = $Content/DateLabel
@onready var _beginner_btn = $Content/DifficultyButtons/BeginnerBtn
@onready var _advanced_btn = $Content/DifficultyButtons/AdvancedBtn
@onready var _expert_btn = $Content/DifficultyButtons/ExpertBtn

const DIFFICULTIES = ["Beginner", "Advanced", "Expert"]

var _current_map = null

func _ready():
	Events.song_selected.connect(_on_song_selected)

	# Connect difficulty buttons (use button_down for VR raycast compatibility)
	if _beginner_btn and not _beginner_btn.button_down.is_connected(_on_beginner_pressed):
		_beginner_btn.button_down.connect(_on_beginner_pressed)
	if _advanced_btn and not _advanced_btn.button_down.is_connected(_on_advanced_pressed):
		_advanced_btn.button_down.connect(_on_advanced_pressed)
	if _expert_btn and not _expert_btn.button_down.is_connected(_on_expert_pressed):
		_expert_btn.button_down.connect(_on_expert_pressed)

	_clear_display()

func _clear_display():
	_song_name_label.text = "No song selected"
	_difficulty_label.text = ""
	_highscore_label.text = ""
	_date_label.text = ""
	# Disable all buttons when no song selected
	for btn in [_beginner_btn, _advanced_btn, _expert_btn]:
		if btn:
			btn.disabled = true
			btn.modulate = Color(0.5, 0.5, 0.5)

func _on_song_selected(map):
	_current_map = map
	if not map:
		_clear_display()
		return
	
	_song_name_label.text = map.get_name()
	_refresh_difficulty_display()

func _refresh_difficulty_display():
	if not _current_map:
		return
	var diff = GameVariables.difficulty
	_difficulty_label.text = "Difficulty: " + str(diff)
	
	# Enable buttons for available difficulties, disable others
	var available = _current_map.get_available_difficulties()
	var btn_map = {"Beginner": _beginner_btn, "Advanced": _advanced_btn, "Expert": _expert_btn}
	for diff_name in DIFFICULTIES:
		var btn = btn_map[diff_name]
		if btn:
			var is_available = diff_name in available
			btn.disabled = not is_available
			# Highlight active difficulty with bright text + border, dim others
			if diff_name == diff and is_available:
				btn.modulate = Color(1, 1, 1)
				_set_button_selected(btn, true)
			else:
				btn.modulate = Color(0.7, 0.7, 0.7) if is_available else Color(0.4, 0.4, 0.4)
				_set_button_selected(btn, false)

	# Refresh highscore for current difficulty
	var song_id = _current_map.get_song_id()
	var hs = HighscoreManager.get_highscore(song_id, diff)
	if hs:
		_highscore_label.text = "Highscore: " + str(hs["score"])
		_date_label.text = "Set on: " + hs["date"]
	else:
		_highscore_label.text = "Highscore: —"
		_date_label.text = ""

func _set_button_selected(btn: Button, selected: bool):
	if selected:
		btn.add_theme_color_override("font_color", Color(1, 1, 1))
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.254902, 0.603922, 0.882353, 0.35)
		style.border_color = Color(0.254902, 0.603922, 0.882353, 1)
		style.set_border_width_all(3)
		style.set_corner_radius_all(8)
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)
	else:
		btn.remove_theme_color_override("font_color")
		btn.remove_theme_stylebox_override("normal")
		btn.remove_theme_stylebox_override("hover")
		btn.remove_theme_stylebox_override("pressed")

func _on_difficulty_selected(diff_name):
	if not _current_map:
		return
	var available = _current_map.get_available_difficulties()
	if diff_name not in available:
		return
	GameVariables.difficulty = diff_name
	Settings.set_setting("game", "difficulty", diff_name)
	_refresh_difficulty_display()

func _on_beginner_pressed():
	_on_difficulty_selected("Beginner")

func _on_advanced_pressed():
	_on_difficulty_selected("Advanced")

func _on_expert_pressed():
	_on_difficulty_selected("Expert")
