extends VBoxContainer


func _ready():
	$TabContainer/Settings/SettingsContent/OnlyPowerBalls.button_pressed = Settings.get_setting("game", "only_power_balls")


func _on_OnlyPowerBalls_toggled(button_pressed):
	Settings.set_setting("game", "only_power_balls", button_pressed)


# Position adjustment handlers
# Note: Axes are swapped due to coordinate system - X acts as Z and vice versa
func _on_LeftBtn_pressed():
	VRRecenter.adjust_position(Vector3.FORWARD)  # FORWARD acts as left in our setup


func _on_RightBtn_pressed():
	VRRecenter.adjust_position(Vector3.BACK)  # BACK acts as right in our setup


func _on_FwdBtn_pressed():
	VRRecenter.adjust_position(Vector3.LEFT)  # LEFT acts as forward in our setup


func _on_BackBtn_pressed():
	VRRecenter.adjust_position(Vector3.RIGHT)  # RIGHT acts as back in our setup


# Rotation adjustment handlers
func _on_RotateCCWBtn_pressed():
	VRRecenter.adjust_rotation(false)  # Counter-clockwise


func _on_RotateCWBtn_pressed():
	VRRecenter.adjust_rotation(true)  # Clockwise


# Reset handler
func _on_ResetBtn_pressed():
	VRRecenter.clear_offset()


# Recenter handler (same as holding B+Y)
func _on_RecenterBtn_pressed():
	VRRecenter.recenter()
