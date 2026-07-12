extends SceneTree

var _passed := 0
var _failed := 0

func _init():
	print("\n=== Workout Smoothness Merge Tests ===\n")
	_test_note_scene()
	_test_hammer_collision_masks()
	_test_production_quality_defaults()
	_test_vr_defaults()
	print("\nPassed: ", _passed, " Failed: ", _failed)
	quit(0 if _failed == 0 else 1)

func _pass(message: String):
	_passed += 1
	print("  ✓ ", message)

func _fail(message: String):
	_failed += 1
	print("  ✗ ", message)

func _check(condition: bool, message: String):
	if condition:
		_pass(message)
	else:
		_fail(message)

func _test_note_scene():
	var packed := load("res://scenes/Note.tscn") as PackedScene
	_check(packed != null, "Note scene loads")
	if packed == null:
		return
	var note := packed.instantiate()
	var mesh := note.get_node("MeshInstance3D") as MeshInstance3D
	_check(mesh.mesh.resource_path == "res://models/note/note.obj", "Original note mesh remains active")
	_check(note.visible == false, "Pooled note starts hidden")

	var player := note.get_node("AnimationPlayer") as AnimationPlayer
	var spawn := player.get_animation("spawn")
	var position_track := spawn.find_track(NodePath("MeshInstance3D:position"), Animation.TYPE_VALUE)
	_check(position_track >= 0 and not spawn.track_is_enabled(position_track), "Spawn z-rush track is disabled")
	_check(player.has_animation("despawn"), "Original despawn animation remains available")
	note.free()

func _test_hammer_collision_masks():
	var packed := load("res://scenes/Player.tscn") as PackedScene
	_check(packed != null, "Player scene loads")
	if packed == null:
		return
	var player := packed.instantiate()
	var left := player.get_node("XROrigin3D/LeftHand/Position3D2/Marker3D/Area3D") as Area3D
	var right := player.get_node("XROrigin3D/RightHand/Marker3D/Marker3D/Area3D") as Area3D
	_check(left.collision_mask == 4, "Left hammer scans Notes layer only")
	_check(right.collision_mask == 4, "Right hammer scans Notes layer only")
	player.free()

func _test_production_quality_defaults():
	var quality_script := load("res://scripts/QualitySettings.gd")
	_check(quality_script.debug_particles_enabled, "Particles default enabled")
	_check(quality_script.debug_lighting_enabled, "Lighting defaults enabled")
	_check(quality_script.debug_postprocess_enabled, "Post-processing defaults enabled")
	_check(quality_script.debug_note_explosions_enabled, "Note explosions default enabled")
	_check(quality_script.debug_environment_particles_enabled, "Environment particles default enabled")
	_check(not quality_script.performance_test_mode, "Performance test mode defaults off")

func _test_vr_defaults():
	var variables_script := load("res://scripts/GameVariables.gd")
	var variables = variables_script.new()
	_check(variables.ENABLE_VR, "VR remains enabled")
	variables.free()

	var manager_script := load("res://scripts/GameManager.gd")
	var manager = manager_script.new()
	_check(manager.target_refresh_rate == 120.0, "Quest target refresh defaults to 120 Hz")
	manager.free()
