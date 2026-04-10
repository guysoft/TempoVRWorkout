extends Node

var _events: Array = []
var _session_start_time: int = 0
var _active: bool = false
var _file_path: String = ""
var _flush_interval: float = 10.0
var _flush_timer: float = 0.0
var _frame_sample_interval: float = 1.0
var _frame_sample_timer: float = 0.0
var _last_process_ms: float = 0.0
var _last_physics_ms: float = 0.0

func _ready():
	set_process(false)
	set_physics_process(false)

func start_session():
	if not GameVariables.DEBUG_LOGGING:
		return
	_events.clear()
	_session_start_time = Time.get_ticks_msec()
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-")
	var dir_path = "user://debug_logs"
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	_file_path = dir_path + "/session_" + timestamp + ".json"
	_active = true
	_flush_timer = 0.0
	_frame_sample_timer = 0.0
	set_process(true)
	set_physics_process(true)
	_append({"type": "session_start",
		"physics_hz": Engine.physics_ticks_per_second,
		"fps": Engine.get_frames_per_second()})

func end_session():
	if not _active:
		return
	_append({"type": "session_end",
		"fps": Engine.get_frames_per_second(),
		"total_events": _events.size()})
	_flush_to_disk()
	_active = false
	set_process(false)
	set_physics_process(false)

func log_hit(hand: String, note_pos: Vector3, _ctrl_velocity: Vector3,
		velocity_squared: float, hit_level: int):
	if not _active:
		return
	_append({"type": "hit", "t": _elapsed_ms(), "hand": hand,
		"note_pos": _v3(note_pos), "vel_sq": velocity_squared,
		"hit_level": hit_level, "fps": Engine.get_frames_per_second()})

func log_miss(note_pos: Vector3, note_speed: float):
	if not _active:
		return
	_append({"type": "miss", "t": _elapsed_ms(),
		"note_pos": _v3(note_pos), "speed": note_speed,
		"fps": Engine.get_frames_per_second()})

func log_user_mark(left_ctrl_pos: Vector3, right_ctrl_pos: Vector3,
		left_vel: Vector3, right_vel: Vector3):
	if not _active:
		return
	_append({"type": "user_mark", "t": _elapsed_ms(),
		"fps": Engine.get_frames_per_second(),
		"physics_hz": Engine.physics_ticks_per_second,
		"l_pos": _v3(left_ctrl_pos), "r_pos": _v3(right_ctrl_pos),
		"l_vel": _v3(left_vel), "r_vel": _v3(right_vel)})

func log_frame_sample():
	if not _active:
		return
	_append({"type": "frame", "t": _elapsed_ms(),
		"fps": Engine.get_frames_per_second(),
		"process_ms": _last_process_ms,
		"physics_ms": _last_physics_ms})

func _process(delta):
	_last_process_ms = delta * 1000.0
	_frame_sample_timer += delta
	if _frame_sample_timer >= _frame_sample_interval:
		_frame_sample_timer -= _frame_sample_interval
		log_frame_sample()
	_flush_timer += delta
	if _flush_timer >= _flush_interval:
		_flush_timer -= _flush_interval
		_flush_to_disk()

func _physics_process(delta):
	_last_physics_ms = delta * 1000.0

func _elapsed_ms() -> int:
	return Time.get_ticks_msec() - _session_start_time

func _v3(v: Vector3) -> Array:
	return [snapped(v.x, 0.001), snapped(v.y, 0.001), snapped(v.z, 0.001)]

func _append(event: Dictionary):
	_events.append(event)

func _flush_to_disk():
	if _events.is_empty():
		return
	var file = FileAccess.open(_file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_events, "\t"))
		file.close()
