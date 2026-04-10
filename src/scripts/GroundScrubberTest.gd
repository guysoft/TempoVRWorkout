extends Node3D
## =============================================================================
## GROUND SCRUBBER TEST
## =============================================================================
##
## Interactive test scene for debugging ground teleport transitions.
## A slider controls the "scroll position" deterministically — no animation,
## no timing issues. Scrub back and forth across teleport boundaries to see
## exactly what changes visually.
##
## CONTROLS:
##   Slider        - Drag to scrub through scroll positions
##   Right-click   - Hold + drag to orbit camera
##   Scroll wheel  - Zoom in/out
##   D             - Toggle debug height colors
##   SPACE         - Toggle auto-play (animates slider at game speed)
##   R             - Reset to position 0
##   A             - Toggle amplified vs normal teleport spacing
##   LEFT/RIGHT    - Nudge slider by one step (fine control)
## =============================================================================

var ground: Node = null
var camera: Camera3D = null

# UI elements
var slider: HSlider = null
var info_label: Label = null

# Camera orbit state
var _orbiting: bool = false
var _orbit_yaw: float = 0.0
var _orbit_pitch: float = -0.5  # Start looking slightly down
var _orbit_distance: float = 20.0
var _orbit_target: Vector3 = Vector3(0, 0, -16)  # Look at center of terrain

# Auto-play state
var _auto_playing: bool = false
var _auto_speed: float = 8.0  # World units per second (matches game BPM speed)

# Teleport mode
var _amplified: bool = false

# Ground parameters (computed from Ground.gd values)
var ground_size: float = 8.0
var mesh_scale_z: float = 8.0
var _original_mesh_scale_z: float = 8.0  # Stored to restore when toggling amplified off
var world_size: float = 64.0
var subdivisions: int = 128
var grid_scale: float = 2.0

const AMPLIFY_FACTOR: float = 8.0  # How much to shrink meshes in amplified mode

# Derived values — set by _compute_teleport_params()
var teleport_threshold: float
var teleport_distance: float
var uv_per_teleport: float
var subdivision_period_world: float
var subdivision_period_uv: float

# Slider range covers this many teleport cycles
const NUM_TELEPORT_CYCLES: int = 8
const SLIDER_STEP: float = 0.05  # World units per slider step


func _ready():
	ground = $Ground
	camera = $Camera3D
	
	if not ground:
		push_error("GroundScrubberTest: No Ground node found!")
		return
	
	# Read actual values from Ground node
	ground_size = ground.ground_size
	subdivisions = ground.subdivisions
	grid_scale = ground.grid_scale
	var mesh_a = ground.get_node("GroundShapeA")
	var mesh_b = ground.get_node("GroundShapeB")
	
	# Store original mesh Z-scale BEFORE setup_ground() potentially changes it
	# (Ground.gd may apply its own DEBUG_AMPLIFY_TELEPORT scaling)
	if mesh_a:
		_original_mesh_scale_z = mesh_a.transform.basis.get_scale().z
	
	# Setup ground but with speed=0 (we control position manually)
	ground.setup_ground(120.0, 1.0, Color.CHOCOLATE)
	ground.speed = 0.0
	
	# Restore original mesh scale — the scrubber manages its own amplification
	if mesh_a and mesh_b:
		_set_mesh_z_scale(mesh_a, _original_mesh_scale_z)
		_set_mesh_z_scale(mesh_b, _original_mesh_scale_z)
	mesh_scale_z = _original_mesh_scale_z
	world_size = ground_size * mesh_scale_z
	
	# Compute teleport parameters
	_compute_teleport_params()
	
	# Build UI
	_build_ui()
	
	# Apply initial position
	_apply_scroll_position(0.0)
	
	# Update camera
	_update_camera()
	
	print("GroundScrubberTest ready!")
	print("  Controls: Slider=scrub, RightClick+drag=orbit, Scroll=zoom")
	print("  D=debug, SPACE=auto-play, R=reset, A=toggle amplified")
	print("  LEFT/RIGHT=nudge slider")


func _set_mesh_z_scale(mesh: MeshInstance3D, new_z_scale: float):
	## Change only the Z-axis scale of a mesh transform, preserving X and Y.
	var t = mesh.transform
	var z_dir = t.basis.z.normalized()
	mesh.transform.basis.z = z_dir * new_z_scale


func _compute_teleport_params():
	if not ground:
		return
	
	var mesh_a = ground.get_node("GroundShapeA")
	var mesh_b = ground.get_node("GroundShapeB")
	
	# Scale meshes based on amplified mode
	if _amplified:
		mesh_scale_z = _original_mesh_scale_z / AMPLIFY_FACTOR
	else:
		mesh_scale_z = _original_mesh_scale_z
	
	if mesh_a and mesh_b:
		_set_mesh_z_scale(mesh_a, mesh_scale_z)
		_set_mesh_z_scale(mesh_b, mesh_scale_z)
	
	# Recompute world_size from the (potentially scaled) mesh
	world_size = ground_size * mesh_scale_z
	
	# All derived values flow from world_size — same formula for both modes
	subdivision_period_world = world_size / float(subdivisions)
	subdivision_period_uv = (1.0 / float(subdivisions)) * grid_scale
	teleport_threshold = world_size
	teleport_distance = world_size * 2.0
	uv_per_teleport = (teleport_distance / subdivision_period_world) * subdivision_period_uv
	
	# Update slider range
	if slider:
		var max_distance = teleport_distance * NUM_TELEPORT_CYCLES
		slider.max_value = max_distance
		slider.step = SLIDER_STEP


func _build_ui():
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)
	
	# --- Slider at bottom ---
	var slider_container = VBoxContainer.new()
	slider_container.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	slider_container.offset_top = -80
	slider_container.offset_bottom = -10
	slider_container.offset_left = 20
	slider_container.offset_right = -20
	canvas.add_child(slider_container)
	
	# Slider label
	var slider_label = Label.new()
	slider_label.text = "Scroll Position"
	slider_label.add_theme_font_size_override("font_size", 18)
	slider_label.add_theme_color_override("font_color", Color.WHITE)
	slider_container.add_child(slider_label)
	
	# The slider itself
	slider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = teleport_distance * NUM_TELEPORT_CYCLES
	slider.step = SLIDER_STEP
	slider.value = 0.0
	slider.custom_minimum_size.y = 32
	slider.value_changed.connect(_on_slider_changed)
	slider_container.add_child(slider)
	
	# --- Info label (top-left) ---
	info_label = Label.new()
	info_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	info_label.offset_left = 10
	info_label.offset_top = 10
	info_label.add_theme_font_size_override("font_size", 20)
	info_label.add_theme_color_override("font_color", Color.WHITE)
	
	# Semi-transparent background
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.6)
	bg.content_margin_left = 8
	bg.content_margin_right = 8
	bg.content_margin_top = 4
	bg.content_margin_bottom = 4
	bg.corner_radius_top_left = 4
	bg.corner_radius_top_right = 4
	bg.corner_radius_bottom_left = 4
	bg.corner_radius_bottom_right = 4
	info_label.add_theme_stylebox_override("normal", bg)
	canvas.add_child(info_label)
	
	# --- Instructions (top-right) ---
	var help_label = Label.new()
	help_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	help_label.offset_right = -10
	help_label.offset_left = -300
	help_label.offset_top = 10
	help_label.add_theme_font_size_override("font_size", 14)
	help_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	help_label.text = "RightClick+Drag: Orbit\nScroll: Zoom\nD: Debug colors\nSPACE: Auto-play\nA: Amplified mode\nR: Reset\nLEFT/RIGHT: Nudge"
	
	var help_bg = StyleBoxFlat.new()
	help_bg.bg_color = Color(0, 0, 0, 0.4)
	help_bg.content_margin_left = 8
	help_bg.content_margin_right = 8
	help_bg.content_margin_top = 4
	help_bg.content_margin_bottom = 4
	help_label.add_theme_stylebox_override("normal", help_bg)
	canvas.add_child(help_label)


func _on_slider_changed(value: float):
	_apply_scroll_position(value)


func _apply_scroll_position(total_distance: float):
	## Core function: given a total scroll distance, compute and apply
	## both mesh positions and UV offsets deterministically.
	##
	## This replicates the exact same math that Ground.gd._process() does
	## over time, but computed from a single input value.
	
	if not ground:
		return
	
	var mesh_a = ground.get_node("GroundShapeA")
	var mesh_b = ground.get_node("GroundShapeB")
	if not mesh_a or not mesh_b:
		return
	
	# --- Mesh A ---
	# Mesh A starts at z=0 and moves in +Z.
	# First teleport happens when it reaches z=teleport_threshold (at d=threshold).
	# After teleporting, it's at z=threshold - distance = -threshold.
	# Then every teleport_distance units after that.
	var meshA_teleports: int = 0
	var meshA_z: float = total_distance
	
	if total_distance >= teleport_threshold:
		# First teleport at d=threshold, then every distance after
		meshA_teleports = 1 + int((total_distance - teleport_threshold) / teleport_distance)
		# Position after teleports: original position minus all teleport jumps
		meshA_z = total_distance - meshA_teleports * teleport_distance
	
	var uv_offset_a = meshA_teleports * uv_per_teleport
	
	# --- Mesh B ---
	# Mesh B starts at z=-teleport_threshold and also moves in +Z.
	# Its first teleport is at d=2*threshold (when it reaches +threshold from -threshold).
	var meshB_raw_z: float = -teleport_threshold + total_distance
	var meshB_teleports: int = 0
	
	if meshB_raw_z >= teleport_threshold:
		meshB_teleports = 1 + int((meshB_raw_z - teleport_threshold) / teleport_distance)
		meshB_raw_z = meshB_raw_z - meshB_teleports * teleport_distance
	
	var meshB_z: float = meshB_raw_z
	
	# Mesh B's initial UV offset (one segment ahead)
	var uv_per_segment = (teleport_threshold / subdivision_period_world) * subdivision_period_uv
	var uv_offset_b = uv_per_segment + meshB_teleports * uv_per_teleport
	
	# --- Apply positions ---
	mesh_a.position.z = meshA_z
	mesh_b.position.z = meshB_z
	
	# --- Apply UV offsets ---
	mesh_a.set_instance_shader_parameter("uv_offset_z", uv_offset_a)
	mesh_b.set_instance_shader_parameter("uv_offset_z", uv_offset_b)
	
	# --- Detect teleport boundary proximity ---
	# Check if we're near a teleport boundary for either mesh
	var near_teleport_a = false
	var near_teleport_b = false
	var boundary_margin = 0.3  # World units
	
	# Mesh A teleport boundaries: at d=threshold, then every distance after
	if total_distance >= teleport_threshold - boundary_margin:
		var dist_past_first = total_distance - teleport_threshold
		if dist_past_first < boundary_margin:
			near_teleport_a = true
		elif dist_past_first > 0:
			var remainder = fmod(dist_past_first, teleport_distance)
			if remainder < boundary_margin or (teleport_distance - remainder) < boundary_margin:
				near_teleport_a = true
	
	# Mesh B teleport boundaries: at d=2*threshold, then every distance after
	var meshB_first_teleport = 2.0 * teleport_threshold
	if total_distance >= meshB_first_teleport - boundary_margin:
		var dist_past_first_b = total_distance - meshB_first_teleport
		if dist_past_first_b < boundary_margin:
			near_teleport_b = true
		elif dist_past_first_b > 0:
			var remainder = fmod(dist_past_first_b, teleport_distance)
			if remainder < boundary_margin or (teleport_distance - remainder) < boundary_margin:
				near_teleport_b = true
	
	# --- Update info label ---
	if info_label:
		var mode_str = "AMPLIFIED" if _amplified else "NORMAL"
		var text = "Mode: %s  |  Threshold: %.1f  Distance: %.1f\n" % [mode_str, teleport_threshold, teleport_distance]
		text += "Scroll: %.2f / %.1f\n" % [total_distance, slider.max_value if slider else 0.0]
		text += "\n"
		text += "MeshA: z=%.3f  uv=%.4f  teleports=%d" % [meshA_z, uv_offset_a, meshA_teleports]
		if near_teleport_a:
			text += "  <<< TELEPORT >>>"
		text += "\n"
		text += "MeshB: z=%.3f  uv=%.4f  teleports=%d" % [meshB_z, uv_offset_b, meshB_teleports]
		if near_teleport_b:
			text += "  <<< TELEPORT >>>"
		info_label.text = text


func _process(delta: float):
	# Auto-play: animate the slider
	if _auto_playing and slider:
		slider.value += _auto_speed * delta
		if slider.value >= slider.max_value:
			slider.value = 0.0


func _input(event: InputEvent):
	# --- Keyboard controls ---
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_D:
				if ground:
					var mat = ground.material
					if mat:
						var current = mat.get_shader_parameter("debug_height_colors")
						ground.set_debug_mode(not current)
						print("Debug mode: ", not current)
			KEY_SPACE:
				_auto_playing = not _auto_playing
				print("Auto-play: ", _auto_playing)
			KEY_R:
				if slider:
					slider.value = 0.0
				_apply_scroll_position(0.0)
				print("Reset to 0")
			KEY_A:
				_amplified = not _amplified
				_compute_teleport_params()
				# Reset slider since the range changed dramatically
				if slider:
					slider.value = 0.0
				_apply_scroll_position(0.0)
				print("Amplified: ", _amplified, " (world_size=%.1f, threshold=%.1f)" % [world_size, teleport_threshold])
			KEY_LEFT:
				if slider:
					slider.value = max(0.0, slider.value - SLIDER_STEP)
			KEY_RIGHT:
				if slider:
					slider.value = min(slider.max_value, slider.value + SLIDER_STEP)
	
	# --- Camera orbit (right-click + drag) ---
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_orbiting = event.pressed
			if _orbiting:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		
		# Zoom with scroll wheel
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_orbit_distance = max(5.0, _orbit_distance - 2.0)
			_update_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_orbit_distance = min(80.0, _orbit_distance + 2.0)
			_update_camera()
	
	if event is InputEventMouseMotion and _orbiting:
		_orbit_yaw -= event.relative.x * 0.005
		_orbit_pitch = clamp(_orbit_pitch - event.relative.y * 0.005, -1.4, -0.1)
		_update_camera()


func _update_camera():
	if not camera:
		return
	
	# Compute camera position on a sphere around the target
	var x = _orbit_distance * cos(_orbit_pitch) * sin(_orbit_yaw)
	var y = _orbit_distance * sin(-_orbit_pitch)  # Negate because pitch is negative for looking down
	var z = _orbit_distance * cos(_orbit_pitch) * cos(_orbit_yaw)
	
	camera.position = _orbit_target + Vector3(x, y, z)
	camera.look_at(_orbit_target, Vector3.UP)
