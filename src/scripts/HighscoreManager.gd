extends Node

## Manages per-song, per-difficulty highscores.
## Stores data in user://saves/highscores.json as a flat dictionary:
##   { "bs:SongName:Expert": { "score": 12500, "date": "2026-04-14T12:30:00" }, ... }
##
## Song ID formats:
##   Beat Saber:    "bs:<songName>"   (from info.dat _songName field)
##   PowerBeatsVR:  "pbvr:<layout_basename>"  (from layout JSON filename)

const SAVE_DIR = "user://saves/"
const HIGHSCORE_FILE = "user://saves/highscores.json"

var _data: Dictionary = {}


func _ready():
	_ensure_save_dir()
	load_data()


func _ensure_save_dir():
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_absolute(SAVE_DIR)


## Returns the highscore entry for a song+difficulty, or empty dict if none.
## Example return: { "score": 12500, "date": "2026-04-14T12:30:00" }
func get_highscore(song_id: String, difficulty: String) -> Dictionary:
	var key = _make_key(song_id, difficulty)
	if _data.has(key):
		return _data[key]
	return {}


## Returns just the highscore value (int), or 0 if none set.
func get_highscore_value(song_id: String, difficulty: String) -> int:
	var entry = get_highscore(song_id, difficulty)
	if entry.has("score"):
		return int(entry["score"])
	return 0


## Attempts to set a new highscore. Only saves if score > current best.
## Returns true if this was a new record.
func set_highscore(song_id: String, difficulty: String, score: int) -> bool:
	var key = _make_key(song_id, difficulty)
	var current_best = get_highscore_value(song_id, difficulty)

	if score > current_best:
		_data[key] = {
			"score": score,
			"date": _get_datetime_string()
		}
		save_data()
		print("HighscoreManager: New highscore! ", key, " = ", score)
		return true

	return false


## Builds the storage key from song_id and difficulty.
func _make_key(song_id: String, difficulty: String) -> String:
	return song_id + ":" + difficulty


## Returns current date/time as an ISO 8601 string.
func _get_datetime_string() -> String:
	var dt = Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02dT%02d:%02d:%02d" % [
		dt["year"], dt["month"], dt["day"],
		dt["hour"], dt["minute"], dt["second"]
	]


## Persists highscores to disk.
func save_data():
	var file = FileAccess.open(HIGHSCORE_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_data, "\t"))
		file.close()
	else:
		push_error("HighscoreManager: Failed to save highscores to " + HIGHSCORE_FILE)


## Loads highscores from disk.
func load_data():
	if not FileAccess.file_exists(HIGHSCORE_FILE):
		_data = {}
		return

	var file = FileAccess.open(HIGHSCORE_FILE, FileAccess.READ)
	if file:
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			_data = json.data
		else:
			push_error("HighscoreManager: Failed to parse highscores JSON")
			_data = {}
		file.close()
	else:
		_data = {}
