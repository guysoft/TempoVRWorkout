extends Node3D
## =============================================================================
## GROUND ALIGNMENT TEST
## =============================================================================
##
## Test scene script for debugging dual-mesh ground vertex alignment.
## Instances Ground.tscn and runs it with debug coloring enabled.
##
## CONTROLS:
##   D - Toggle debug height coloring (red=peak, green=mid, blue=valley)
##   SPACE - Toggle ground movement on/off
##   UP/DOWN - Adjust speed
##   R - Reset ground to initial state
## =============================================================================

var ground: Node = null
var is_moving: bool = true
var test_speed: float = 8.0  # A reasonable BPM-like speed


func _ready():
	ground = $Ground
	if ground:
		# Setup with test values: 120 BPM, delay=1.0, debug color
		ground.setup_ground(120.0, 1.0, Color.CHOCOLATE)
		# Don't force debug mode - let detector control it (press D to toggle)
		print("GroundAlignmentTest: Ground setup complete (press D to toggle debug)")
		print("  Controls: D=debug, SPACE=pause, UP/DOWN=speed, R=reset")
	else:
		push_error("GroundAlignmentTest: No Ground node found!")


func _input(event):
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
				is_moving = not is_moving
				if ground:
					if is_moving:
						ground.speed = test_speed
					else:
						ground.speed = 0.0
				print("Moving: ", is_moving)
			KEY_UP:
				test_speed += 2.0
				if is_moving and ground:
					ground.speed = test_speed
				print("Speed: ", test_speed)
			KEY_DOWN:
				test_speed = max(0.0, test_speed - 2.0)
				if is_moving and ground:
					ground.speed = test_speed
				print("Speed: ", test_speed)
			KEY_R:
				if ground:
					ground.reset_ground()
					print("Ground reset")
