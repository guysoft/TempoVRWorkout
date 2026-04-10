extends StaticBody3D
## =============================================================================
## DUAL MESH CONVEYOR BELT GROUND SYSTEM
## =============================================================================
##
## This script implements smooth infinite scrolling terrain that is compatible
## with Meta SpaceWarp frame prediction. It uses TWO meshes that leapfrog each
## other, teleporting only when fully out of view behind the player.
##
## HOW IT WORKS:
## 1. Two meshes (A and B) both move continuously in +Z direction
## 2. When a mesh goes fully behind the player, it teleports ahead of the other
## 3. Each mesh has its own UV offset (via instance uniform) that increments on teleport
## 4. Result: Smooth motion that SpaceWarp can predict correctly
##
## WHY THIS FIXES SPACEWARP:
## - Old system: mesh snapped back every 0.5 units (visible discontinuity)
## - New system: mesh teleports every ~64 units when fully behind player (invisible)
## - SpaceWarp sees consistent +Z motion vectors, predicts correctly
##
## DEBUG MODE:
## Call set_debug_mode(true) to enable height visualization:
## - Red = peaks, Green = middle, Blue = valleys
## - White grid lines show UV boundaries
## =============================================================================

@export var ground_size: float = 8.0
@export var subdivisions: int = 128  # Match the mesh subdivisions
@export var grid_scale: float = 2.0  # Grid texture repetitions (lower = bigger squares)

# Dual mesh system
var mesh_a: MeshInstance3D
var mesh_b: MeshInstance3D
var uv_offset_a: float = 0.0
var uv_offset_b: float = 0.0  # Set in _ready based on initial position

# Teleport parameters (calculated at runtime)
var teleport_threshold: float  # When mesh.position.z > this, teleport
var teleport_distance: float   # How far to jump back (2 mesh lengths)
var uv_per_teleport: float     # UV increment per teleport
var world_size: float          # Full mesh size in world space

# Subdivision periods (for UV calculation)
var subdivision_period_world: float
var subdivision_period_uv: float

var speed: float = 0.0
var material: ShaderMaterial

# SpaceWarp skip - cached reference to avoid per-frame lookups
# When a mesh teleports, we call skip_space_warp_frame() for a few frames
# to tell the runtime to skip motion-vector extrapolation (which would cause
# flash artifacts from the sudden geometry discontinuity).
# This keeps SpaceWarp globally enabled — unlike the old set_space_warp_enabled()
# toggle which caused a "mountain jump" artifact on re-enable due to stale vectors.
var _space_warp = null  # OpenXRFbSpaceWarpExtension singleton (or null if unavailable)
var _space_warp_checked: bool = false
var _sw_skip_frames: int = 0  # Countdown: frames remaining to call skip_space_warp_frame()

# Debug overlay state — which mesh just teleported this frame (or "" if none)
var last_teleported_mesh: String = ""

# How many frames to call skip_space_warp_frame() after a teleport.
# SpaceWarp uses the previous frame's motion vectors to extrapolate the current
# frame, so we need to skip at least the teleport frame + the next frame.
# Using 3 for safety margin.
const SW_SKIP_FRAME_COUNT: int = 3

# DEBUG: Set true to amplify teleport frequency for testing SpaceWarp artifacts.
# Scales the mesh transforms down so teleports happen 8x more often (~1s instead of ~8s).
# Both meshes tile edge-to-edge at the smaller size — no overlap, no z-fighting.
const DEBUG_AMPLIFY_TELEPORT: bool = false
const DEBUG_AMPLIFY_FACTOR: float = 8.0  # How many times faster to teleport

# DEBUG: Set true to show teleport countdown + perf stats on ScoreCanvas during gameplay.
# Overlay shows: FPS, frame time, draw calls, SpaceWarp state, teleport countdown.
const DEBUG_GROUND_OVERLAY: bool = false

# UV offset wrapping threshold to prevent float precision loss in long sessions.
# Must be a multiple of uv_per_teleport (4.0) to avoid texture discontinuities.
# At UV_WRAP = 1000, triplanar precision is ~0.002 texels — well within acceptable.
const UV_WRAP: float = 1000.0


func _set_mesh_z_scale(mesh: MeshInstance3D, new_z_scale: float):
	## Change only the Z-axis scale of a mesh transform, preserving X and Y.
	var t = mesh.transform
	var z_dir = t.basis.z.normalized()
	mesh.transform.basis.z = z_dir * new_z_scale


func _ready():
	mesh_a = $GroundShapeA
	mesh_b = $GroundShapeB
	
	# Register in group so debug overlay can find us
	add_to_group("ground_debug")
	
	# Get the actual mesh scale from the transform
	var mesh_scale_z = mesh_a.transform.basis.get_scale().z
	
	# DEBUG: Scale meshes down so teleports happen more often.
	# Instead of keeping full-size meshes with a tiny threshold (causing 56-unit overlap
	# and z-fighting), we shrink the meshes so they tile edge-to-edge at the smaller size.
	if DEBUG_AMPLIFY_TELEPORT:
		var new_scale_z = mesh_scale_z / DEBUG_AMPLIFY_FACTOR
		_set_mesh_z_scale(mesh_a, new_scale_z)
		_set_mesh_z_scale(mesh_b, new_scale_z)
		mesh_scale_z = new_scale_z
		print("Ground: DEBUG AMPLIFY ON - mesh Z-scale: %.2f (was %.2f)" % [new_scale_z, new_scale_z * DEBUG_AMPLIFY_FACTOR])
	
	# Calculate world size (mesh local size * scale)
	# All derived values flow from this — amplified mode works automatically
	# because world_size is smaller, so threshold/distance are proportionally smaller.
	world_size = ground_size * mesh_scale_z
	
	# Calculate subdivision periods (kept for UV calculations)
	subdivision_period_world = world_size / float(subdivisions)
	subdivision_period_uv = (1.0 / float(subdivisions)) * grid_scale
	
	# Teleport parameters
	# Threshold: when mesh center is one world_size behind player origin (fully out of view)
	teleport_threshold = world_size
	# Distance: jump back 2 mesh lengths to land ahead of the other mesh
	teleport_distance = world_size * 2.0
	
	# UV: how much UV offset to add per teleport (2 mesh lengths worth)
	uv_per_teleport = (teleport_distance / subdivision_period_world) * subdivision_period_uv
	
	# Initial UV offset for mesh B (one teleport-threshold ahead in UV space)
	var uv_per_segment = (teleport_threshold / subdivision_period_world) * subdivision_period_uv
	uv_offset_b = uv_per_segment
	
	# Get material for non-instance shader parameters
	material = mesh_a.get_surface_override_material(0)
	if material == null:
		material = mesh_a.get_active_material(0)
	
	# Apply initial UV offsets
	mesh_a.set_instance_shader_parameter("uv_offset_z", uv_offset_a)
	mesh_b.set_instance_shader_parameter("uv_offset_z", uv_offset_b)


func _get_space_warp():
	## Lazy-init: get the SpaceWarp extension singleton (Quest only).
	## Returns null on PC or if the extension is not available.
	if not _space_warp_checked:
		_space_warp_checked = true
		# Try the name used in the official sample project first
		_space_warp = Engine.get_singleton("OpenXRFbSpaceWarpExtension")
		if not _space_warp:
			# Try with Wrapper suffix (the actual C++ class name)
			_space_warp = Engine.get_singleton("OpenXRFbSpaceWarpExtensionWrapper")
		if _space_warp:
			print("Ground: SpaceWarp extension found (skip_space_warp_frame on teleport enabled)")
	return _space_warp


func _process(delta: float):
	if speed == 0.0:
		return
	
	# Call skip_space_warp_frame() for each remaining skip frame
	if _sw_skip_frames > 0:
		var sw = _get_space_warp()
		if sw:
			sw.skip_space_warp_frame()
		_sw_skip_frames -= 1
	
	var movement = speed * delta
	
	# Both meshes always move forward (+Z direction, toward player)
	mesh_a.position.z += movement
	mesh_b.position.z += movement
	
	# Teleport when fully behind player (out of view)
	var did_teleport = false
	last_teleported_mesh = ""
	
	if mesh_a.position.z > teleport_threshold:
		mesh_a.position.z -= teleport_distance
		uv_offset_a += uv_per_teleport
		mesh_a.set_instance_shader_parameter("uv_offset_z", uv_offset_a)
		did_teleport = true
		last_teleported_mesh = "A"
	
	if mesh_b.position.z > teleport_threshold:
		mesh_b.position.z -= teleport_distance
		uv_offset_b += uv_per_teleport
		mesh_b.set_instance_shader_parameter("uv_offset_z", uv_offset_b)
		did_teleport = true
		last_teleported_mesh += "B"
	
	# Wrap UV offsets to prevent float precision loss in long play sessions.
	# Both offsets are wrapped together to preserve their relative difference.
	# The noise texture is seamless, so wrapping is invisible.
	if uv_offset_a > UV_WRAP:
		uv_offset_a -= UV_WRAP
		uv_offset_b -= UV_WRAP
		mesh_a.set_instance_shader_parameter("uv_offset_z", uv_offset_a)
		mesh_b.set_instance_shader_parameter("uv_offset_z", uv_offset_b)
	
	if did_teleport:
		# Skip SpaceWarp extrapolation for the next few frames.
		# Call immediately for this frame, then the countdown loop at the top
		# of _process() handles the remaining frames.
		# We set to COUNT-1 because we call skip once right here (this frame).
		_sw_skip_frames = SW_SKIP_FRAME_COUNT - 1
		var sw = _get_space_warp()
		if sw:
			sw.skip_space_warp_frame()


func setup_ground(bpm: float, delay: float, color):
	## Setup the ground with BPM-synced scrolling speed
	## Called by GameManager when a song starts
	
	if mesh_a == null:
		mesh_a = $GroundShapeA
	if mesh_b == null:
		mesh_b = $GroundShapeB
	
	# Update mesh size on both meshes
	mesh_a.mesh.size = Vector2(ground_size, ground_size)
	mesh_b.mesh.size = Vector2(ground_size, ground_size)
	
	# Get material for non-instance parameters
	material = mesh_a.get_surface_override_material(0)
	if material == null:
		material = mesh_a.get_active_material(0)
	if material == null:
		push_warning("Ground: No material found on GroundShapeA")
		return
	
	# Set grid texture scale (controls how many times grid repeats)
	material.set_shader_parameter("uv1_scale", Vector3(grid_scale, grid_scale, grid_scale))
	
	# Set mesh size for triplanar offset calculation
	material.set_shader_parameter("mesh_size_z", ground_size)
	
	# Recalculate parameters based on current settings
	var mesh_scale_z = mesh_a.transform.basis.get_scale().z
	
	# DEBUG: Scale meshes down for amplified teleport testing
	if DEBUG_AMPLIFY_TELEPORT:
		# The mesh may already be scaled from _ready(), so use the original scene scale.
		# Original Z-scale is stored in the scene as 8.0 (see Ground.tscn transform).
		var original_scale_z = 8.0  # From Ground.tscn: Transform3D(8,0,0, 0,0.5,0, 0,0,8, ...)
		var new_scale_z = original_scale_z / DEBUG_AMPLIFY_FACTOR
		_set_mesh_z_scale(mesh_a, new_scale_z)
		_set_mesh_z_scale(mesh_b, new_scale_z)
		mesh_scale_z = new_scale_z
	
	world_size = ground_size * mesh_scale_z
	subdivision_period_world = world_size / float(subdivisions)
	subdivision_period_uv = (1.0 / float(subdivisions)) * grid_scale
	teleport_threshold = world_size
	teleport_distance = world_size * 2.0
	
	uv_per_teleport = (teleport_distance / subdivision_period_world) * subdivision_period_uv
	speed = bpm / 60.0 * ground_size / delay
	
	# Set color
	if color is Color:
		material.set_shader_parameter("albedo", color)
	
	# Reset state for new song
	reset_ground()
	print("Ground: setup_ground() called - bpm=%.1f speed=%.2f threshold=%.1f distance=%.1f" % [bpm, speed, teleport_threshold, teleport_distance])
	# Eagerly init SpaceWarp lookup
	_get_space_warp()


func reset_ground():
	## Reset terrain to initial state (useful when restarting game)
	
	# Reset positions: A at origin, B one threshold-length ahead (-Z direction)
	# threshold == world_size in both normal and amplified modes (meshes tile edge-to-edge)
	if mesh_a:
		mesh_a.position.z = 0.0
	if mesh_b:
		mesh_b.position.z = -teleport_threshold
	
	# Reset UV offsets
	# A starts at 0, B is one teleport-threshold ahead in UV space
	var uv_per_segment = (teleport_threshold / subdivision_period_world) * subdivision_period_uv
	uv_offset_a = 0.0
	uv_offset_b = uv_per_segment
	
	# Apply UV offsets via instance parameters
	if mesh_a:
		mesh_a.set_instance_shader_parameter("uv_offset_z", uv_offset_a)
	if mesh_b:
		mesh_b.set_instance_shader_parameter("uv_offset_z", uv_offset_b)


func set_debug_mode(enabled: bool):
	## Enable/disable debug height coloring
	## Red = peaks, Green = middle, Blue = valleys
	## White grid lines show UV cell boundaries
	if material:
		material.set_shader_parameter("debug_height_colors", enabled)


func set_curved_world(enabled: bool, strength: float = 0.002):
	## Enable/disable curved world effect (horizon hiding)
	## strength: how much to curve (0.001-0.01 typical)
	if material:
		material.set_shader_parameter("enable_curve", enabled)
		material.set_shader_parameter("curve_strength", strength)
