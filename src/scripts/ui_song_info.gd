extends ReferenceRect

@onready var _song_name_label = $Content/SongNameLabel
@onready var _difficulty_label = $Content/DifficultyLabel
@onready var _highscore_label = $Content/HighscoreLabel
@onready var _date_label = $Content/DateLabel

var _current_map = null

func _ready():
	Events.song_selected.connect(_on_song_selected)
	_clear_display()

func _clear_display():
	_song_name_label.text = "No song selected"
	_difficulty_label.text = ""
	_highscore_label.text = ""
	_date_label.text = ""

func _on_song_selected(map):
	_current_map = map
	if not map:
		_clear_display()
		return
	
	_song_name_label.text = map.get_name()
	var diff = GameVariables.difficulty
	_difficulty_label.text = "Difficulty: " + diff
	
	var song_id = map.get_song_id()
	var hs = HighscoreManager.get_highscore(song_id, diff)
	if hs:
		_highscore_label.text = "Highscore: " + str(hs["score"])
		_date_label.text = "Set on: " + hs["date"]
	else:
		_highscore_label.text = "Highscore: —"
		_date_label.text = ""
