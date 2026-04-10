extends Label
## =============================================================================
## DEBUG TELEPORT OVERLAY
## =============================================================================
##
## Shows real-time ground teleport info + performance stats on the ScoreCanvas.
## Only visible when Ground.DEBUG_GROUND_OVERLAY == true.
##
## Display format:
##   FPS: 72 | 11.2ms | DC: 45
##   SW: ON | Teleport: 3... 2... 1...
##   <<TELEPORT A>>          (flashes when a mesh teleports)
##
## Also color-codes:
##   Green  = frame time under budget (< 11.1ms for 90Hz)
##   Yellow = borderline (11.1–13.9ms)
##   Red    = over budget (> 13.9ms = below 72Hz)

# How long to show "<<TELEPORT>>" flash after a teleport event
const TELEPORT_FLASH_DURATION: float = 0.5

# Frame budget thresholds (Quest targets 72Hz minimum, 90Hz ideal)
const FRAME_BUDGET_90HZ_MS: float = 11.1
const FRAME_BUDGET_72HZ_MS: float = 13.9

var _ground = null  # Reference to Ground node
var _teleport_flash_timer: float = 0.0
var _teleport_flash_which: String = ""  # "A", "B", or "AB"
var _prev_mesh_a_z: float = 0.0
var _prev_mesh_b_z: float = 0.0


func _ready():
	# Defer lookup — UICanvas reparents us into the SubViewport,
	# so the scene tree isn't stable until the next frame.
	visible = false
	set_process(false)
	call_deferred("_deferred_init")


func _deferred_init():
	# Find the Ground node via group (set in Ground._ready)
	_ground = get_tree().get_first_node_in_group("ground_debug")
	
	if _ground == null:
		print("DebugTeleportOverlay: Ground node not found in 'ground_debug' group")
		return
	
	# Check the const directly (get() doesn't work on consts in GDScript)
	if not _ground.DEBUG_GROUND_OVERLAY:
		print("DebugTeleportOverlay: DEBUG_GROUND_OVERLAY is false, hiding overlay")
		return
	
	# Enable overlay
	visible = true
	set_process(true)
	print("DebugTeleportOverlay: Overlay enabled, ground found: ", _ground.name)
	
	# Store initial mesh positions for teleport detection fallback
	if _ground.mesh_a:
		_prev_mesh_a_z = _ground.mesh_a.position.z
	if _ground.mesh_b:
		_prev_mesh_b_z = _ground.mesh_b.position.z


func _process(delta: float):
	if _ground == null:
		return
	
	# --- Teleport flash timer ---
	if _teleport_flash_timer > 0.0:
		_teleport_flash_timer -= delta
	
	# Check if Ground flagged a teleport this frame
	if _ground.last_teleported_mesh != "":
		_teleport_flash_which = _ground.last_teleported_mesh
		_teleport_flash_timer = TELEPORT_FLASH_DURATION
	
	# --- Performance metrics ---
	var fps = Engine.get_frames_per_second()
	var frame_time_ms = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var draw_calls = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var triangles = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	
	# Format triangle count (e.g., 12345 -> "12.3K")
	var tri_str: String
	if triangles >= 1000.0:
		tri_str = "%.1fK" % (triangles / 1000.0)
	else:
		tri_str = str(int(triangles))
	
	# --- SpaceWarp state ---
	var sw_text: String
	if _ground._sw_skip_frames > 0:
		sw_text = "SW: SKIP (%d)" % _ground._sw_skip_frames
	elif _ground._space_warp != null:
		sw_text = "SW: ON"
	else:
		sw_text = "SW: N/A"  # Not on Quest / extension not available
	
	# --- Teleport countdown ---
	# Calculate progress of the closest-to-teleporting mesh (0.0 = just teleported, 1.0 = about to)
	var progress_a: float = 0.0
	var progress_b: float = 0.0
	if _ground.teleport_threshold > 0:
		progress_a = _ground.mesh_a.position.z / _ground.teleport_threshold
		progress_b = _ground.mesh_b.position.z / _ground.teleport_threshold
	
	# Use the mesh that's closest to teleporting
	var progress = max(progress_a, progress_b)
	var which_next = "A" if progress_a > progress_b else "B"
	progress = clamp(progress, 0.0, 1.0)
	
	# Map progress to countdown: 3... 2... 1...
	var countdown_text: String
	if progress < 0.33:
		countdown_text = "Teleport %s: 3..." % which_next
	elif progress < 0.66:
		countdown_text = "Teleport %s: 2..." % which_next
	elif progress < 0.90:
		countdown_text = "Teleport %s: 1..." % which_next
	else:
		countdown_text = "Teleport %s: NOW" % which_next
	
	# --- Teleport flash ---
	var flash_text: String = ""
	if _teleport_flash_timer > 0.0:
		flash_text = "\n<< TELEPORT %s >>" % _teleport_flash_which
	
	# --- Build display text ---
	text = "FPS: %d | %.1fms | DC: %d | Tri: %s\n%s | %s%s" % [
		fps, frame_time_ms, draw_calls, tri_str,
		sw_text, countdown_text, flash_text
	]
	
	# --- Color coding based on frame time ---
	if frame_time_ms > FRAME_BUDGET_72HZ_MS:
		add_theme_color_override("font_color", Color.RED)
	elif frame_time_ms > FRAME_BUDGET_90HZ_MS:
		add_theme_color_override("font_color", Color.YELLOW)
	else:
		add_theme_color_override("font_color", Color.GREEN_YELLOW)
