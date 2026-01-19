extends VBoxContainer


func _ready():
	$TabContainer/Settings/OnlyPowerBalls.button_pressed = Settings.get_setting("game", "only_power_balls")


func _on_OnlyPowerBalls_toggled(button_pressed):
	Settings.set_setting("game", "only_power_balls", button_pressed)
