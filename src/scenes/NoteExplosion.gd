extends Node3D

var vel: Vector3 = Vector3.ZERO

# Object pool reference (set by Game.gd when using pooling)
var _pool: ObjectPool = null

func setup_effect(position:Vector3, speed:float):
	var mat = $Sparks.process_material as ParticleProcessMaterial
	mat.gravity = Vector3(0,2.0,0)
	global_transform.origin = position
	vel = Vector3(0,0,speed);
	visible = true
	set_physics_process(true)
	$Sparks.emitting=true
	$CenterSpark.emitting = true
	await get_tree().create_timer(2.0).timeout
	_release_to_pool()

## Reset all state for pool reuse.
func reset_for_pool():
	vel = Vector3.ZERO
	$Sparks.emitting = false
	$CenterSpark.emitting = false
	set_physics_process(false)
	visible = false

## Release back to pool instead of queue_free
func _release_to_pool():
	visible = false
	set_physics_process(false)
	$Sparks.emitting = false
	$CenterSpark.emitting = false
	if _pool:
		_pool.release(self)
	else:
		queue_free()

func _physics_process(delta):
	translate(vel*delta)
