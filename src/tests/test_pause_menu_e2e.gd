## End-to-end test for pause menu visibility, positioning, and raycast.
##
## This script is attached to a Timer node added to the Game scene at runtime.
## It auto-triggers pause after a short delay, then validates:
##   1. Pause menu is visible and properly positioned
##   2. Pause menu quad faces the camera (not mirrored)
##   3. Raycast can hit the pause menu collision shape
##   4. Buttons are accessible
##
## Usage: Set GameManager.debug_start_scene = "GameTest" and attach this via
## DebugController or run via editor script.
##
## Since this runs inside the game, it prints results to the output log.
## Check output with get_godot_errors or logcat.
extends Node

var _frame_count := 0
var _test_phase := 0  # 0=wait, 1=pause, 2=validate, 3=done
var _results: Array[String] = []
var _all_passed := true

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("=== PauseMenu E2E Test: Starting ===")

func _process(_delta):
	_frame_count += 1
	
	match _test_phase:
		0:  # Wait for game to settle (60 frames ~ 1 second)
			if _frame_count >= 60:
				_test_phase = 1
		1:  # Trigger pause
			_trigger_pause()
			_test_phase = 2
			_frame_count = 0
		2:  # Wait 10 frames for pause to take effect, then validate
			if _frame_count >= 10:
				_validate_pause_menu()
				_test_phase = 3
		3:  # Done
			_print_results()
			set_process(false)

func _trigger_pause():
	print("E2E: Triggering pause...")
	var player = Global.manager()._player
	if not player:
		_fail("Cannot trigger pause: player is null")
		_test_phase = 3
		return
	player.pause_game()

func _validate_pause_menu():
	print("E2E: Validating pause menu...")
	
	# Check game is actually paused
	_check("Game is paused", get_tree().paused)
	
	var player = Global.manager()._player
	var game_node = player.game_node if player else null
	if not game_node:
		_fail("game_node is null")
		return
	
	var pause_menu = game_node.get_node_or_null("PauseMenu")
	if not pause_menu:
		_fail("PauseMenu node not found")
		return
	
	# Test 1: Pause menu is visible
	_check("PauseMenu.visible is true", pause_menu.visible)
	_check("PauseMenu.is_visible_in_tree()", pause_menu.is_visible_in_tree())
	
	# Test 2: Collision is enabled
	_check("disable_collision is false", not pause_menu.disable_collision)
	
	var ui_area = pause_menu.get_node_or_null("UIArea")
	if ui_area:
		var collision_shape = ui_area.get_node_or_null("UICollisionShape")
		if collision_shape:
			_check("UICollisionShape not disabled", not collision_shape.disabled)
		else:
			_fail("UICollisionShape not found")
	else:
		_fail("UIArea not found")
	
	# Test 3: Menu position — should be roughly PAUSE_MENU_DISTANCE in front of camera
	var camera = Global.manager()._player._camera
	if camera:
		var cam_pos = camera.global_transform.origin
		var menu_pos = pause_menu.global_transform.origin
		var distance = cam_pos.distance_to(menu_pos)
		var expected_dist = 3.0  # PAUSE_MENU_DISTANCE
		_check("Menu distance from camera ~3m (got %.2f)" % distance,
			distance > expected_dist - 0.5 and distance < expected_dist + 0.5)
		
		# Test 4: Menu faces camera — the menu's +Z should point toward camera
		# (dot product of menu's +Z basis vector with direction-to-camera should be positive)
		var menu_forward = pause_menu.global_transform.basis.z.normalized()
		var dir_to_camera = (cam_pos - menu_pos).normalized()
		var dot = menu_forward.dot(dir_to_camera)
		_check("Menu +Z faces camera (dot=%.3f, want > 0)" % dot, dot > 0)
		print("E2E: menu_basis.z = ", pause_menu.global_transform.basis.z)
		print("E2E: dir_to_camera = ", dir_to_camera)
		print("E2E: dot = ", dot)
	else:
		_fail("Camera not found")
	
	# Test 5: Menu scale preserved (should be 2.5 from PauseMenu.tscn)
	var scale = pause_menu.scale
	_check("Menu scale preserved (~2.5, got %s)" % str(scale),
		absf(scale.x - 2.5) < 0.1 and absf(scale.y - 2.5) < 0.1)
	
	# Test 6: Buttons are enabled
	var pause_btns_container = pause_menu.get_node_or_null("SubViewport/PauseContainer/PauseBtns")
	if pause_btns_container:
		var btns = pause_btns_container.get_children()
		_check("Has 3 pause buttons", btns.size() == 3)
		for btn in btns:
			if btn is Button:
				_check("Button '%s' not disabled" % btn.text, not btn.disabled)
	else:
		_fail("PauseBtns container not found")
	
	# Test 7: SubViewport has content
	var viewport = pause_menu.get_node_or_null("SubViewport")
	if viewport:
		_check("SubViewport size > 0", viewport.size.x > 0 and viewport.size.y > 0)
		_check("SubViewport update mode is ALWAYS",
			viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS)
	else:
		_fail("SubViewport not found")
	
	# Test 8: UIMeshInstance has material with viewport texture
	var mesh_inst = pause_menu.get_node_or_null("UIArea/UIMeshInstance")
	if mesh_inst:
		var mat = mesh_inst.get_surface_override_material(0)
		_check("UIMeshInstance has material", mat != null)
		if mat and mat is StandardMaterial3D:
			_check("Material has albedo_texture", mat.albedo_texture != null)
	else:
		_fail("UIMeshInstance not found")
	
	# Test 9: Raycast physics check — cast a ray from camera toward pause menu
	# and verify it hits the UIArea collision shape
	if camera and ui_area:
		var space_state = camera.get_world_3d().direct_space_state
		if space_state:
			var cam_pos2 = camera.global_transform.origin
			var menu_center = pause_menu.global_transform.origin
			var ray_params = PhysicsRayQueryParameters3D.new()
			ray_params.from = cam_pos2
			ray_params.to = menu_center
			ray_params.collision_mask = 16  # Same mask as Feature_UIRayCast
			var result = space_state.intersect_ray(ray_params)
			if result.is_empty():
				_fail("Raycast from camera to menu center: NO HIT (collision layer 16)")
				print("E2E: Ray from ", cam_pos2, " to ", menu_center)
				# Debug: check if UIArea is in correct collision layer
				print("E2E: UIArea collision_layer = ", ui_area.collision_layer)
				print("E2E: UIArea collision_mask = ", ui_area.collision_mask)
			else:
				_check("Raycast hits pause menu UIArea",
					result.collider == ui_area or result.collider.get_parent() == ui_area)
				print("E2E: Ray hit collider: ", result.collider, " at ", result.position)
		else:
			_fail("Cannot get physics space state")

func _check(description: String, passed: bool):
	if passed:
		_results.append("  ✓ " + description)
	else:
		_results.append("  ✗ " + description)
		_all_passed = false

func _fail(message: String):
	_results.append("  ✗ " + message)
	_all_passed = false

func _print_results():
	print("\n=== PauseMenu E2E Test Results ===")
	for r in _results:
		print(r)
	print("")
	if _all_passed:
		print("✓ ALL PAUSE MENU TESTS PASSED")
	else:
		print("✗ SOME PAUSE MENU TESTS FAILED")
	print("=== End PauseMenu E2E Test ===\n")
