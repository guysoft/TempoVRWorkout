## Generic object pool for reusing scene instances.
##
## Pre-allocates instances at creation, hands them out via acquire(),
## and reclaims them via release(). Objects stay in the scene tree
## (hidden and physics-disabled) — Vulkan pipeline compilation occurs
## at add_child() time during _init(), eliminating the per-frame
## compilation storm that happens with runtime instantiation.

class_name ObjectPool
extends RefCounted

var _scene: PackedScene
var _parent: Node          # Node to add pool children under
var _pool: Array = []      # Free (available) instances
var _active: Array = []    # Currently in-use instances
var _pool_name: String

## Create a pool of [param size] instances of [param scene], parented to [param parent_node].
## Each instance is added hidden and with physics disabled.
func _init(scene: PackedScene, parent_node: Node, size: int, pool_name: String = ""):
	_scene = scene
	_parent = parent_node
	_pool_name = pool_name if pool_name != "" else "ObjectPool"
	
	for i in range(size):
		var instance = _scene.instantiate()
		_parent.add_child(instance)
		_hide_instance(instance)
		_pool.append(instance)
	
	if GameVariables.DEBUG_LOGGING:
		print("%s: Pre-allocated %d instances" % [_pool_name, size])

## Grab a free instance from the pool. Returns null if pool is exhausted.
func acquire() -> Node:
	if _pool.size() == 0:
		# Pool exhausted — instantiate a new one (fallback, shouldn't happen often)
		if GameVariables.DEBUG_LOGGING:
			push_warning("%s: Pool exhausted, allocating extra instance" % _pool_name)
		var instance = _scene.instantiate()
		_parent.add_child(instance)
		_active.append(instance)
		return instance
	
	var instance = _pool.pop_back()
	_active.append(instance)
	return instance

## Return an instance to the pool. Caller must reset visual/physics state first.
func release(instance: Node) -> void:
	if instance == null:
		return
	var idx = _active.find(instance)
	if idx >= 0:
		_active.remove_at(idx)
	_hide_instance(instance)
	_pool.append(instance)

## How many instances are currently available.
func available() -> int:
	return _pool.size()

## How many instances are currently in use.
func active_count() -> int:
	return _active.size()

## Release ALL active instances back to the pool (e.g. on scene cleanup).
func release_all() -> void:
	for instance in _active.duplicate():
		release(instance)

## Free all instances (pool + active). Call when the pool itself is being destroyed.
func destroy() -> void:
	for instance in _active:
		if is_instance_valid(instance):
			instance.queue_free()
	for instance in _pool:
		if is_instance_valid(instance):
			instance.queue_free()
	_active.clear()
	_pool.clear()

func _hide_instance(instance: Node) -> void:
	if instance is Node3D:
		instance.visible = false
	instance.set_physics_process(false)
	instance.set_process(false)
