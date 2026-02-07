extends Node

## Reads version from version.txt (injected at build time by CI).
## Falls back to "dev" when running from editor or if file is missing.

var _version: String = "dev"


func _ready() -> void:
	var path := "res://version.txt"
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f:
			_version = f.get_line().strip_edges()
			f.close()


func get_version() -> String:
	return _version
