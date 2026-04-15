extends VBoxContainer

const HEIGHT_MIN = 1.0   # 100 cm
const HEIGHT_MAX = 2.2   # 220 cm
const HEIGHT_STEP = 0.01 # 1 cm

@onready var _height_value_label = $TabContainer/Settings/SettingsContent/HeightButtons/HeightValueLabel
@onready var _height_down_btn = $TabContainer/Settings/SettingsContent/HeightButtons/HeightDownBtn
@onready var _height_up_btn = $TabContainer/Settings/SettingsContent/HeightButtons/HeightUpBtn
@onready var _measure_height_btn = $TabContainer/Settings/SettingsContent/MeasureHeightBtn

var _current_height: float = 1.73


func _ready():
	$TabContainer/Settings/SettingsContent/OnlyPowerBalls.button_pressed = Settings.get_setting("game", "only_power_balls")
	
	# Load saved height
	_current_height = float(Settings.get_setting("game", "player_height", 1.73))
	_update_height_display()
	
	# Connect height button signals (button_down for VR raycast compatibility)
	if _height_down_btn and not _height_down_btn.button_down.is_connected(_on_HeightDown_pressed):
		_height_down_btn.button_down.connect(_on_HeightDown_pressed)
	if _height_up_btn and not _height_up_btn.button_down.is_connected(_on_HeightUp_pressed):
		_height_up_btn.button_down.connect(_on_HeightUp_pressed)
	if _measure_height_btn and not _measure_height_btn.button_down.is_connected(_on_MeasureHeight_pressed):
		_measure_height_btn.button_down.connect(_on_MeasureHeight_pressed)


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


# Height adjustment handlers
func _on_HeightDown_pressed():
	_current_height = max(HEIGHT_MIN, _current_height - HEIGHT_STEP)
	_save_and_update_height()


func _on_HeightUp_pressed():
	_current_height = min(HEIGHT_MAX, _current_height + HEIGHT_STEP)
	_save_and_update_height()


func _on_MeasureHeight_pressed():
	var measured = VRRecenter.get_camera_height()
	if measured > 0:
		# Camera Y is head height - use it directly
		_current_height = clamp(measured, HEIGHT_MIN, HEIGHT_MAX)
		_save_and_update_height()
		print("MainMenuLeft: Measured player height: ", _current_height, "m")
	else:
		# VR camera not available - show feedback on button
		_measure_height_btn.text = "VR headset required"
		get_tree().create_timer(2.0).timeout.connect(func():
			_measure_height_btn.text = "Measure Height (Stand Straight)"
		)
		print("MainMenuLeft: Cannot measure height - VR camera not available")


func _save_and_update_height():
	Settings.set_setting("game", "player_height", _current_height)
	_update_height_display()


func _update_height_display():
	if _height_value_label:
		_height_value_label.text = str(int(round(_current_height * 100))) + " cm"
