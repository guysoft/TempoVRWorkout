extends Node3D

# Floating score text that appears at hit location and drifts away
# Green for full/perfect hits (FULLIMPACT), white for partial hits (MINIMUMIMPACT)
# Matches PowerBeatsVR behavior

@onready var _label: Label3D = $Label3D

# Object pool reference (set by Game.gd when using pooling)
var _pool: ObjectPool = null
var _tween: Tween = null

# Animation constants (matching PowerBeatsVR)
const ANIMATION_DURATION = 1.0  # seconds
const DRIFT_UP = 0.5  # Y drift (slightly up for visibility)
const DRIFT_BACKWARD = -2.0  # Z drift (opposite of note direction, so player can see)
const SCALE_START = Vector3(0.5, 0.5, 0.5)
const SCALE_END = Vector3.ZERO

# Colors
const COLOR_PERFECT = Color.GREEN
const COLOR_PARTIAL = Color.WHITE

## Reset all state for pool reuse.
func reset_for_pool():
	visible = false
	if _tween and _tween.is_valid():
		_tween.kill()
		_tween = null
	if _label:
		_label.position = Vector3.ZERO
		_label.scale = SCALE_START
		_label.modulate.a = 1.0

func show_score(position: Vector3, score: int, is_perfect: bool):
	# Position at hit location
	global_position = position
	visible = true
	
	# Reset label position for reuse
	_label.position = Vector3.ZERO
	
	# Set text and color
	_label.text = str(score)
	_label.modulate = COLOR_PERFECT if is_perfect else COLOR_PARTIAL
	
	# Start scaled down
	_label.scale = SCALE_START
	
	# Calculate end position (drift up and backward so player can see)
	var end_pos = _label.position + Vector3(
		randf_range(-0.3, 0.3),  # slight random X offset
		DRIFT_UP,
		DRIFT_BACKWARD
	)
	
	# Kill any existing tween from previous use
	if _tween and _tween.is_valid():
		_tween.kill()
	
	# Create animation tween
	_tween = create_tween().set_parallel(true)
	
	# Scale up quickly, then down
	_tween.tween_property(_label, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Position drift
	_tween.tween_property(_label, "position", end_pos, ANIMATION_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Fade out alpha
	_tween.tween_property(_label, "modulate:a", 0.0, ANIMATION_DURATION)
	
	# Scale down after initial pop (delayed)
	_tween.tween_property(_label, "scale", SCALE_END, 0.5).set_delay(ANIMATION_DURATION - 0.5)
	
	# Release to pool when done
	_tween.chain().tween_callback(_release_to_pool)

## Release back to pool instead of queue_free
func _release_to_pool():
	visible = false
	if _pool:
		_pool.release(self)
	else:
		queue_free()
