extends CharacterBody3D

# PowerBeatsVR velocity mechanics (Expert difficulty)
# These are SQUARED velocity thresholds for performance
# From PowerBeatsVR GameManager.cs:
#   HIT_SPEED_SQUARED_EXPERT_LOWER = 1.0f  (minimum for any hit)
#   HIT_SPEED_SQUARED_EXPERT_UPPER = 3.0f  (for full impact)
# PowerBalls: velocity is divided by 4 before checking thresholds
const HIT_SPEED_SQUARED_MIN = 1.0       # Minimum for semi-hit
const HIT_SPEED_SQUARED_FULL = 3.0      # For full impact hit

# PowerBeatsVR scoring constants
const SCORE_SEMI = 10       # Partial/semi hit
const SCORE_COMPLETE = 20   # Full impact hit

# Combo system
const MIN_COMBO_FOR_MULTIPLIER = 5  # Need 5+ combo for score multiplier

# Hit level enum (from PowerBeatsVR)
enum HitLevel { TOOLOW, MINIMUMIMPACT, FULLIMPACT }

const BOMB_SCORE_VALUE = 100 
const MAX_COMBO = 99  # Increased max combo for PowerBeatsVR style

# Floating score text scene
var _floating_score_scene = preload("res://scenes/FloatingScore.tscn")

# Payer movement in non-vr mode settings
@export var mouse_sensitivity = 0.03
@export var Invert_Y_Axis = true
@export var Exit_On_Escape = true
@export var Maximum_Y_Look = 45
@export var Accelaration = 5
@export var Maximum_Walk_Speed = 10
@export var Jump_Speed = 2

var in_game = false
var game_node #reference to game node

var _beat_player
var _pause_button_cooldown = false

const GRAVITY = 0 #0.098
#var velocity = Vector3(0,0,0)
var forward_velocity = 0
var Walk_Speed = 0.1

var score = 0:
	set(value):
		score = value
		if score < 0:
			score = 0
		Events.emit_signal("current_score_updated", score)
var combo = 0:
	set(value):
		combo = value
		if combo >= MAX_COMBO:
			combo = MAX_COMBO
		Events.emit_signal("current_combo_updated", combo)

#REFS
@onready var _camera = $XROrigin3D/XRCamera3D


func reset_player():
	self.score = 0
	self.combo = 0
	
	if not _beat_player:
		_beat_player = Global.manager()._beatplayer

# All property setters (song_acceleration, score, energy, combo) are now inline
# with their property definitions above

func _ready():
	# TODO Change this not to the global variable
	# but after checking if vr worked
	
	_beat_player = Global.manager()._beatplayer
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	if not GameVariables.ENABLE_VR:
		forward_velocity = Walk_Speed


func _physics_process(delta):
	
	if not GameVariables.ENABLE_VR and in_game and not get_tree().paused:
		velocity.y -= GRAVITY
		
#		if game_node:
#			if Input.is_key_pressed(KEY_P):
#				game_node.toggle_speed(0.5, 0.1, 5.0, 0.01)
	
	# Camera raycast is ONLY for non-VR mode (for mouse look-and-click)
	# In VR mode, use controller raycasts instead
	if GameVariables.ENABLE_VR:
		# VR mode: always disable camera raycast, use controller raycasts
		$XROrigin3D/XRCamera3D/Feature_UIRayCast.active = false
	else:
		# Non-VR mode: always enable camera raycast for mouse interaction
		$XROrigin3D/XRCamera3D/Feature_UIRayCast.active = true
	
	# Check pause button in physics_process so it works even when game is paused
	# Only check when in_game (during song playback)
	if GameVariables.ENABLE_VR and in_game and not _pause_button_cooldown:
		var left_hand = Global.manager()._left_hand
		if left_hand and left_hand.is_button_just_pressed("ax_button"):
			_pause_button_cooldown = true
			pause_game()
			# Wait a bit before allowing another pause toggle
			await get_tree().create_timer(0.3, true, false, true).timeout
			_pause_button_cooldown = false
	
	if GameVariables.NON_VR_MOVEMENT:
		_handle_non_vr_move_and_slide()
			
func _handle_non_vr_move_and_slide():
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
				Walk_Speed += Accelaration
				if Walk_Speed > Maximum_Walk_Speed:
						Walk_Speed = Maximum_Walk_Speed
				velocity.x = -global_transform.basis.z.x * Walk_Speed
				velocity.z = -global_transform.basis.z.z * Walk_Speed
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
				Walk_Speed += Accelaration
				if Walk_Speed > Maximum_Walk_Speed:
						Walk_Speed = Maximum_Walk_Speed
				velocity.x = global_transform.basis.z.x * Walk_Speed
				velocity.z = global_transform.basis.z.z * Walk_Speed
		if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
				Walk_Speed += Accelaration
				if Walk_Speed > Maximum_Walk_Speed:
						Walk_Speed = Maximum_Walk_Speed
				velocity.x = -global_transform.basis.x.x * Walk_Speed
				velocity.z = -global_transform.basis.x.z * Walk_Speed
				
		if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
				Walk_Speed += Accelaration
				if Walk_Speed > Maximum_Walk_Speed:
						Walk_Speed = Maximum_Walk_Speed
				velocity.x = global_transform.basis.x.x * Walk_Speed
				velocity.z = global_transform.basis.x.z * Walk_Speed
				
		if not(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_RIGHT)):
				velocity.x = 0
				velocity.z = 0
				
		if is_on_floor():
				if Input.is_action_just_pressed("ui_accept"):
						velocity.y = Jump_Speed
		#set_velocity(velocity)
		up_direction = Vector3(0,1,0)
		move_and_slide()
		#velocity = velocity

func _unhandled_input(event):
	if not GameVariables.ENABLE_VR:
		
		if event.is_action_pressed("ui_cancel") and in_game:
				pause_game()
		
		if event is InputEventMouseMotion:
			rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
			_camera.rotate_x(deg_to_rad(-event.relative.y * mouse_sensitivity))
			_camera.rotation.x = clamp(_camera.rotation.x, deg_to_rad(-89), deg_to_rad(89))


func handle_hit(body, hand):
	var controller = null
	if hand == "left":
		controller = Global.manager()._left_hand
	else:
		controller = Global.manager()._right_hand
	#print("hit " + hand + " "  + body.name)
	
	if body.is_in_group("note"):
		
		#if it's a bomb
		if body._type == 3:
			$BombSound.play()
			self.score -= BOMB_SCORE_VALUE
			self.combo = 0
			if body.has_method("on_hit"):
				body.on_hit(0, 0, HitLevel.TOOLOW)
			else:
				body.queue_free()
		else:
			velocity = controller.get("velocity")
			var linear_velocity = velocity.length()
			
			# Calculate velocity squared for hit detection (PowerBeatsVR style)
			var velocity_squared = linear_velocity * linear_velocity
			
			# Determine hit level based on velocity squared and ball type
			# PowerBalls require 4x velocity (checked per-ball, not globally)
			var is_power_ball = body._is_power_ball if "_is_power_ball" in body else false
			var hit_level = _calculate_hit_level(velocity_squared, is_power_ball)
			
			#print ("Controller velocity: ", linear_velocity, " squared: ", velocity_squared, " hit_level: ", hit_level, " power_ball: ", is_power_ball)
			
			if hit_level == HitLevel.TOOLOW:
				# Too weak - miss
				self.combo = 0
				if body.has_method("on_hit"):
					body.on_hit(velocity, linear_velocity, hit_level)
				else:
					body.queue_free()
			else:
				# Valid hit - calculate score
				self.combo += 1
				
				# Haptic feedback on successful hit
				if controller:
					controller.simple_rumble(0.5, 0.15)  # Intensity 0.5, duration 0.15s
				
				var base_score = SCORE_SEMI if hit_level == HitLevel.MINIMUMIMPACT else SCORE_COMPLETE
				var score_value = base_score
				
				# Combo multiplier only applies after MIN_COMBO_FOR_MULTIPLIER hits
				if combo >= MIN_COMBO_FOR_MULTIPLIER:
					var multiplier = combo - MIN_COMBO_FOR_MULTIPLIER + 2  # x2 at combo 5, x3 at 6, etc.
					score_value = base_score * multiplier
				
				self.score += score_value
				
				# Spawn floating score text at hit location
				_spawn_floating_score(body.global_position, score_value, hit_level)

				if body.has_method("on_hit"):
					body.on_hit(velocity, linear_velocity, hit_level)
				else:
					body.queue_free()


# Calculate hit level based on velocity squared (PowerBeatsVR Expert difficulty)
# PowerBalls require 4x velocity - this is checked per-ball, not globally
# From PowerBeatsVR GameManager.cs: if (isPowerBall) { velocity /= 4f; }
func _calculate_hit_level(velocity_squared: float, is_power_ball: bool = false) -> int:
	var effective_velocity = velocity_squared
	
	# PowerBalls: divide velocity by 4 (same as multiplying threshold by 4)
	# This matches PowerBeatsVR exactly
	if is_power_ball:
		effective_velocity = velocity_squared / 4.0
	
	# Use normal thresholds for all balls after adjustment
	# Min: 1.0 (1.0 m/s for normal, 2.0 m/s for power)
	# Full: 3.0 (1.73 m/s for normal, 3.46 m/s for power)
	if effective_velocity >= HIT_SPEED_SQUARED_FULL:
		return HitLevel.FULLIMPACT
	elif effective_velocity >= HIT_SPEED_SQUARED_MIN:
		return HitLevel.MINIMUMIMPACT
	else:
		return HitLevel.TOOLOW
		
#			if controller.get_rumble() == 0.0:
#				print("rumble")
#				controller.set_rumble(1.0)

##remaps a value from input range to output range
#func remap_value(value, input_range:Vector2, output_range:Vector2)->float:
#	return (value-input_range.x) / (input_range.y - input_range.x) * (output_range.y - output_range.x) + output_range.x

# Spawn floating score text at the hit position
# Shows green for perfect hits (FULLIMPACT), white for partial hits (MINIMUMIMPACT)
func _spawn_floating_score(hit_position: Vector3, score_value: int, hit_level: int):
	var floating = _floating_score_scene.instantiate()
	get_tree().root.add_child(floating)
	floating.show_score(hit_position, score_value, hit_level == HitLevel.FULLIMPACT)

#SIGNAL CALLBACKS

func _on_left_hand_body_entered(body):
	handle_hit(body, "left")


func _on_right_hand_body_entered(body):
	handle_hit(body, "right")


#func _on_Area_body_exited_left(body):
#	handle_hit(body, "left")
#
#
#func _on_Area_body_exited_right(body):
#	handle_hit(body, "right")


func _on_Area_area_entered_right(area):
	handle_hit(area, "right")


func _on_Area_area_entered_left(area):
	handle_hit(area, "left")


func _on_LeftHand_button_pressed(button):
	button_pressed(button, "left")

func _on_RightHand_button_pressed(button):
	button_pressed(button, "right")

func _on_LeftHand_button_release(button):
	button_released(button, "left")

func _on_RightHand_button_release(button):
	button_released(button, "right")


var last_position
const PAUSE_MENU_DISTANCE = 2.0  # Distance in meters in front of camera

func pause_game():
	if not game_node or not is_instance_valid(game_node):
		return
	
	var pause_menu = game_node.get_node_or_null("PauseMenu")
	if not pause_menu:
		return
	
	var pause_state = get_tree().paused
	get_tree().paused = !pause_state

	var pause_btns = pause_menu.get_node("SubViewport/PauseContainer/PauseBtns").get_children()
	var skip_btn = pause_menu.get_node_or_null("SubViewport/PauseContainer/SkipBtn")
	var is_playlist_mode = PlaylistManager.is_playlist_mode()
	
	if get_tree().paused:
		if _beat_player:
			_beat_player.stream_paused = true
		
		# Position pause menu 2m in front of camera, facing the player
		# var camera_transform = _camera.global_transform
		# var menu_position = camera_transform.origin - camera_transform.basis.z * PAUSE_MENU_DISTANCE
		# pause_menu.global_transform.origin = menu_position
		
		# Make the menu face the camera
		# pause_menu.look_at(camera_transform.origin, Vector3.UP)
		
		pause_menu.get_node("UnpauseSound").play()
		pause_menu.visible = true
		pause_menu.disable_collision = false
		for btn in pause_btns:
			btn.disabled = false
		# Skip button is separate from PauseBtns - only visible in playlist mode
		if skip_btn:
			skip_btn.visible = is_playlist_mode
			skip_btn.disabled = not is_playlist_mode
	else:
		if _beat_player:
			_beat_player.stream_paused = false
		pause_menu.get_node("PauseSound").play()
		pause_menu.visible = false
		pause_menu.disable_collision = true
		for btn in pause_btns:
			btn.disabled = true
		if skip_btn:
			skip_btn.disabled = true
	

func button_pressed(button, hand):
	pass
#	var hand_object = null
#	if hand=="left":
#		hand_object = Global.manager()._left_hand
#	elif hand=="right":
#		hand_object = Global.manager()._right_hand
#
	#hand_object._buttons_just_pressed[button] = !hand_object._buttons_just_pressed[button]
	
#	hand_object._buttons_just_pressed[button] = 1
#	hand_object._buttons_pressed[button] = 1
	
	#hand_object.check_button(button,1)

func button_released(button,hand):
	pass
#	var hand_object = null
#	if hand=="left":
#		hand_object = Global.manager()._left_hand
#	elif hand=="right":
#		hand_object = Global.manager()._right_hand
#
#	hand_object.check_button(button,0)
	
#	hand_object._buttons_just_released[button] = 1
#	hand_object._buttons_pressed[button] = 0


func _on_HeadArea_area_entered(area):
	if area.is_in_group("obstacle"):
		$BombSound.play()
		self.combo = 0
		self.score -= 500


func _on_ResumeBtn_pressed():
	if game_node:
		var pause_menu = game_node.get_node_or_null("PauseMenu")
		if pause_menu:
			pause_menu.get_node("PauseSound").play()
	pause_game()

func _on_MenuBtn_pressed():
	if game_node:
		var pause_menu = game_node.get_node_or_null("PauseMenu")
		if pause_menu:
			pause_menu.get_node("PauseSound").play()
	pause_game()
	reset_player()
	await get_tree().create_timer(0.1).timeout
	Global.manager().load_scene(Global.manager().menu_path,"menu")

func _on_RestartBtn_pressed():
	if game_node:
		var pause_menu = game_node.get_node_or_null("PauseMenu")
		if pause_menu:
			pause_menu.get_node("PauseSound").play()
	reset_player()
	pause_game()
	await get_tree().create_timer(0.1).timeout
	Global.manager().load_scene(Global.manager().game_path,"game")
