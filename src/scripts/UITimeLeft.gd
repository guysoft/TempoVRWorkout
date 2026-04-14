extends VBoxContainer

var time: float = 0.0
var song_length: float = 0.0

@onready var _remaining_label: Label = $RemainingLabel
@onready var _elapsed_label: Label = $ElapsedLabel

func _ready():
	format_time()
	set_process(false)
	Events.connect("song_begin", Callable(self, "_on_song_begin"))
	Events.connect("song_end", Callable(self, "_on_song_end"))

func _on_song_begin():
	set_process(true)

func _on_song_end():
	set_process(false)

func _process(delta):
	var d = delta * (1.0 / Engine.time_scale)
	time = time + d
	format_time()

func _format_mmss(total_seconds: float) -> String:
	var t = max(0.0, total_seconds)
	var minutes = int(t / 60.0)
	var seconds = int(t) % 60
	return "%02d:%02d" % [minutes, seconds]

func format_time():
	# Remaining time (countdown)
	var remaining = max(0.0, song_length - time)
	_remaining_label.text = "-" + _format_mmss(remaining)

	# Elapsed time
	_elapsed_label.text = _format_mmss(time)
