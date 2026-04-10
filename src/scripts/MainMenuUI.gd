extends MarginContainer

@export var start_scene: String

var start_pressed := false
var quit_pressed := false

func _ready():
	start_pressed = false
	# Connect button_down (not pressed) for VR raycast compatibility
	var start_btn = $VBoxContainer2/VBoxContainer/Start
	var quit_btn = $VBoxContainer2/VBoxContainer/Quit
	if start_btn and not start_btn.button_down.is_connected(_on_start_button_pressed):
		start_btn.button_down.connect(_on_start_button_pressed)
	if quit_btn and not quit_btn.button_down.is_connected(_on_quit_button_pressed):
		quit_btn.button_down.connect(_on_quit_button_pressed)
	
	# Activate joystick/keyboard navigation on main menu buttons
	call_deferred("_activate_navigator")
	# Deactivate navigator when this scene is freed (prevents stale button refs)
	tree_exiting.connect(_deactivate_navigator)

func _input(event):
	if Input.is_key_pressed(KEY_ESCAPE):
		_on_quit_button_pressed()

func _activate_navigator():
	var manager = Global.manager()
	if not manager or not manager._player:
		return
	var nav = manager._player._navigator
	if not nav:
		return
	
	var buttons: Array = []
	var start_btn = $VBoxContainer2/VBoxContainer/Start
	var quit_btn = $VBoxContainer2/VBoxContainer/Quit
	if start_btn:
		buttons.append(start_btn)
	if quit_btn:
		buttons.append(quit_btn)
	
	# Find the SubViewport this UI lives in (parent of our root Control in UICanvasInteract)
	var vp: SubViewport = null
	var parent = get_parent()
	while parent:
		if parent is SubViewport:
			vp = parent
			break
		parent = parent.get_parent()
	
	nav.activate(buttons, vp)

func _deactivate_navigator():
	var manager = Global.manager()
	if not manager or not manager._player:
		return
	var nav = manager._player._navigator
	if nav:
		nav.deactivate()


func _on_start_button_pressed():
	if start_pressed:
		return
	$AcceptSound.play()
	start_pressed = true
	Global.manager().load_scene(Global.manager().game_path,"game")

func _on_quit_button_pressed():
	$BackSound.play()
	var animation = Global.manager()._transition.get_node("AnimationPlayer") as AnimationPlayer
	animation.play("fade")
	await animation.animation_finished
	get_tree().quit()
