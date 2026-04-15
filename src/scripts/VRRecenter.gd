extends Node

# VRRecenter - Manages VR room scale orientation reset and persistence
# Stores position and rotation offset that is applied to XROrigin3D
# Persisted via Settings autoload

const RECENTER_HOLD_TIME := 3.0  # seconds

var _xr_origin: XROrigin3D = null
var _xr_camera: XRCamera3D = null

# Current offset values (applied to XROrigin3D)
var _offset_position := Vector3.ZERO
var _offset_rotation := 0.0  # Y-axis rotation in radians

func _ready():
	# Load saved offset on startup
	load_offset()

func set_xr_nodes(origin: XROrigin3D, camera: XRCamera3D):
	"""Set references to the XR nodes. Called after XR is initialized."""
	_xr_origin = origin
	_xr_camera = camera
	# Apply saved offset once we have the nodes
	apply_offset()

func load_offset():
	"""Load the saved offset from Settings."""
	_offset_position = Settings.get_setting("vr", "recenter_offset_position", Vector3.ZERO)
	_offset_rotation = Settings.get_setting("vr", "recenter_offset_rotation", 0.0)
	print("VRRecenter: Loaded offset - position: ", _offset_position, ", rotation: ", _offset_rotation)

var _save_pending := false  # Debounce flag for saving

func save_offset():
	"""Save the current offset to Settings.
	
	Uses debouncing to avoid excessive file I/O during rapid adjustments.
	"""
	if _save_pending:
		return
	
	_save_pending = true
	call_deferred("_save_offset_deferred")

func _save_offset_deferred():
	"""Actually save the offset (called at end of frame via call_deferred)."""
	_save_pending = false
	Settings.set_setting("vr", "recenter_offset_position", _offset_position)
	Settings.set_setting("vr", "recenter_offset_rotation", _offset_rotation)
	print("VRRecenter: Saved offset - position: ", _offset_position, ", rotation: ", _offset_rotation)

func apply_offset():
	"""Apply the stored offset to the XROrigin3D node.
	
	Uses call_deferred to avoid modifying transforms during active VR frame rendering,
	which can cause Vulkan device loss on Quest when transforms change rapidly.
	"""
	if _xr_origin == null:
		print("VRRecenter: Cannot apply offset - XROrigin3D not set")
		return
	
	# Defer the actual transform modification to end of frame to avoid
	# race conditions with Vulkan rendering (especially in VR with multiple viewports)
	call_deferred("_apply_offset_deferred")

func _apply_offset_deferred():
	"""Actually apply the offset (called at end of frame via call_deferred)."""
	if _xr_origin == null:
		return
	
	# Apply rotation around Y axis
	_xr_origin.rotation.y = _offset_rotation
	
	# Apply position offset
	_xr_origin.position = _offset_position
	
	print("VRRecenter: Applied offset to XROrigin3D")

func recenter():
	"""Recenter the VR space based on current HMD position and orientation.
	
	This calculates the offset needed to make the current HMD forward direction
	become the 'forward' direction in the game world (negative Z).
	
	IMPORTANT: We use the camera's LOCAL transform (relative to XROrigin3D) to get
	the raw HMD tracking data, not global_transform which includes the current offset.
	"""
	if _xr_origin == null or _xr_camera == null:
		print("VRRecenter: Cannot recenter - XR nodes not set")
		return
	
	# Use LOCAL transform to get raw HMD tracking data (not affected by current offset)
	# The camera's transform relative to XROrigin3D is the pure tracking space position
	var camera_local_transform = _xr_camera.transform
	
	# Get the forward direction of the camera (negative Z in camera space)
	var camera_forward = -camera_local_transform.basis.z
	# Project onto XZ plane (ignore vertical component)
	camera_forward.y = 0
	if camera_forward.length_squared() < 0.001:
		print("VRRecenter: Camera looking straight up/down, cannot determine forward")
		return
	camera_forward = camera_forward.normalized()
	
	# Calculate the angle between current forward and world forward (-Z)
	var world_forward = Vector3(0, 0, -1)
	var angle = camera_forward.signed_angle_to(world_forward, Vector3.UP)
	
	# The rotation offset is this angle
	# (we rotate the origin so that the camera's forward becomes world forward)
	_offset_rotation = angle
	
	# Calculate position offset to center on HMD position in tracking space
	# We want the HMD's XZ position to become the origin (0, 0, 0) in game space
	var camera_pos = camera_local_transform.origin
	
	# Apply the rotation to the position offset as well
	var rotated_offset = Vector3(-camera_pos.x, 0, -camera_pos.z).rotated(Vector3.UP, angle)
	_offset_position = rotated_offset
	
	# Apply and save
	apply_offset()
	save_offset()
	
	print("VRRecenter: Recentered - new rotation: ", rad_to_deg(_offset_rotation), " degrees")

func clear_offset():
	"""Clear the offset and reset to default."""
	_offset_position = Vector3.ZERO
	_offset_rotation = 0.0
	apply_offset()
	save_offset()
	print("VRRecenter: Offset cleared")

# Constants for manual adjustment
const POSITION_STEP := 0.05  # 5cm per button press
const ROTATION_STEP := deg_to_rad(5.0)  # 5 degrees per button press

var _is_adjusting := false  # Reentrancy guard

func adjust_position(direction: Vector3):
	"""Adjust position offset by a step in the given direction.
	
	Direction should be normalized. The direction is in world space,
	so Vector3.LEFT moves left, Vector3.FORWARD moves forward, etc.
	The adjustment is applied relative to the current rotation offset.
	"""
	if _is_adjusting:
		return
	_is_adjusting = true
	
	if _xr_origin == null:
		print("VRRecenter: Cannot adjust position - XROrigin3D not set")
		_is_adjusting = false
		return
	
	# Rotate the direction by current offset rotation so movement is relative to player facing
	var rotated_direction = direction.rotated(Vector3.UP, _offset_rotation)
	_offset_position += rotated_direction * POSITION_STEP
	
	apply_offset()
	save_offset()
	
	_is_adjusting = false
	print("VRRecenter: Position adjusted by ", direction, " - new offset: ", _offset_position)

func adjust_rotation(clockwise: bool):
	"""Adjust rotation offset by one step.
	
	clockwise=true rotates view clockwise (player rotates counter-clockwise)
	clockwise=false rotates view counter-clockwise (player rotates clockwise)
	"""
	if _xr_origin == null:
		print("VRRecenter: Cannot adjust rotation - XROrigin3D not set")
		return
	
	if clockwise:
		_offset_rotation -= ROTATION_STEP
	else:
		_offset_rotation += ROTATION_STEP
	
	# Normalize to -PI to PI range
	while _offset_rotation > PI:
		_offset_rotation -= TAU
	while _offset_rotation < -PI:
		_offset_rotation += TAU
	
	apply_offset()
	save_offset()
	print("VRRecenter: Rotation adjusted - new offset: ", rad_to_deg(_offset_rotation), " degrees")

# Getters for UI display
func get_position_offset() -> Vector3:
	return _offset_position

func get_rotation_offset_degrees() -> float:
	return rad_to_deg(_offset_rotation)

func get_camera_height() -> float:
	"""Return the XR camera's current Y position in tracking space (head height in meters).
	Returns -1.0 if camera is not available (e.g., desktop mode without VR)."""
	if _xr_camera == null:
		return -1.0
	# Use LOCAL transform to get raw tracking height (not affected by offset)
	return _xr_camera.transform.origin.y

# Static helper functions for offset calculations (useful for testing)
static func calculate_rotation_offset(camera_forward: Vector3) -> float:
	"""Calculate the Y rotation offset given a camera forward direction."""
	var forward = camera_forward
	forward.y = 0
	if forward.length_squared() < 0.001:
		return 0.0
	forward = forward.normalized()
	
	var world_forward = Vector3(0, 0, -1)
	return forward.signed_angle_to(world_forward, Vector3.UP)

static func calculate_position_offset(camera_position: Vector3, rotation_offset: float) -> Vector3:
	"""Calculate the position offset given camera position and rotation offset."""
	var offset = Vector3(-camera_position.x, 0, -camera_position.z)
	return offset.rotated(Vector3.UP, rotation_offset)
