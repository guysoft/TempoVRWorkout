extends Node3D

## Fireworks celebration effect for new highscores.
## Spawns several one-shot GPUParticles3D bursts in a ring around the origin.

const NUM_EMITTERS = 5
const BURST_COLORS = [
	Color(1.0, 0.3, 0.9, 1.0),   # Pink/magenta
	Color(0.3, 1.0, 0.5, 1.0),   # Green
	Color(1.0, 0.85, 0.2, 1.0),  # Gold
	Color(0.3, 0.7, 1.0, 1.0),   # Cyan/blue
	Color(1.0, 0.45, 0.15, 1.0), # Orange
]

var _emitters: Array[GPUParticles3D] = []


func fire():
	"""Trigger all firework bursts."""
	_create_emitters()
	for emitter in _emitters:
		emitter.emitting = true
	# Auto-cleanup after particles finish
	await get_tree().create_timer(3.0).timeout
	queue_free()


func _create_emitters():
	var radius = 0.6
	for i in NUM_EMITTERS:
		var angle = TAU * float(i) / float(NUM_EMITTERS)
		var emitter = GPUParticles3D.new()
		emitter.position = Vector3(cos(angle) * radius, sin(angle) * 0.3, 0)
		emitter.amount = 60
		emitter.lifetime = 1.5
		emitter.one_shot = true
		emitter.explosiveness = 0.95
		emitter.emitting = false

		var mat = ParticleProcessMaterial.new()
		mat.direction = Vector3(0, 1, 0)
		mat.spread = 60.0
		mat.initial_velocity_min = 1.5
		mat.initial_velocity_max = 3.0
		mat.gravity = Vector3(0, -3.0, 0)
		mat.damping_min = 0.5
		mat.damping_max = 1.0
		mat.scale_min = 0.02
		mat.scale_max = 0.06
		mat.color = BURST_COLORS[i % BURST_COLORS.size()]

		emitter.process_material = mat

		# Simple sphere mesh as the particle draw pass
		var mesh = SphereMesh.new()
		mesh.radius = 0.02
		mesh.height = 0.04
		mesh.radial_segments = 4
		mesh.rings = 2
		# Give it an unshaded emissive material so it glows
		var mesh_mat = StandardMaterial3D.new()
		mesh_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh_mat.albedo_color = BURST_COLORS[i % BURST_COLORS.size()]
		mesh.surface_set_material(0, mesh_mat)

		emitter.draw_pass_1 = mesh

		add_child(emitter)
		_emitters.append(emitter)
