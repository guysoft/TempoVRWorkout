## Centralized joystick / keyboard navigation for VR and desktop menus.
##
## Attach to a Node child of Player (or GameManager). Call activate() with
## an array of focusable buttons and (optionally) a SubViewport that owns them.
## Call deactivate() when the menu closes.
##
## Focus highlight is DORMANT until the user actually moves the joystick or
## presses an arrow key. This avoids showing unwanted focus visuals on menus
## that live inside SubViewports (UICanvasInteract panels).
##
## In VR: reads right-hand thumbstick (primary) and primary_click.
## On desktop: reads arrow keys and Enter / Space.
## process_mode = ALWAYS so it works during pause.
extends Node

# Set to true for verbose per-frame debug logging
const DEBUG_LOG := false

# Tuning
const DEADZONE := 0.5
const INITIAL_REPEAT_SEC := 0.4
const REPEAT_SEC := 0.15

# Focus style
var _focus_stylebox: StyleBoxFlat

# State
var _buttons: Array[BaseButton] = []
var _focus_index: int = -1
var _active := false       # True when activate() has been called with valid buttons
var _focus_shown := false  # True only after user moves joystick/keyboard (lazy focus)

# Repeat-move timer
var _repeat_timer: float = 0.0
var _move_held := false
var _first_repeat_done := false

# Reference to SubViewport so we can push a fake click for VR buttons
var _viewport: SubViewport = null

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)  # only run when active


## Public API

## Activate navigation over the given buttons.
## The navigator registers the buttons but does NOT show any focus highlight
## until the user actually moves the joystick or presses an arrow key.
## buttons: Array of BaseButton (Button, etc.)
## viewport: Optional SubViewport that contains those buttons (used by UICanvasInteract panels).
## initial_index: Which button to focus first when focus becomes visible (default 0).
func activate(buttons: Array, viewport: SubViewport = null, initial_index: int = 0) -> void:
	deactivate()  # clean up previous session

	_buttons.clear()
	for b in buttons:
		if b is BaseButton and is_instance_valid(b) and b.visible and not b.disabled:
			_buttons.append(b)

	if _buttons.is_empty():
		if DEBUG_LOG:
			print("UIMenuNavigator: activate() called but no valid buttons after filter")
		return

	_viewport = viewport
	_active = true
	_focus_shown = false  # Don't show focus until user interacts
	_focus_index = clampi(initial_index, 0, _buttons.size() - 1)

	# Do NOT set focus_mode or grab_focus here - wait for user input
	set_process(true)
	if DEBUG_LOG:
		print("UIMenuNavigator: activated with ", _buttons.size(), " buttons")


## Deactivate - remove focus styling and stop processing.
func deactivate() -> void:
	if not _active:
		return

	# Remove focus overrides only if we ever showed them
	if _focus_shown:
		for btn in _buttons:
			if is_instance_valid(btn):
				btn.focus_mode = Control.FOCUS_NONE
				btn.remove_theme_stylebox_override("focus")
				btn.release_focus()

	_buttons.clear()
	_focus_index = -1
	_active = false
	_focus_shown = false
	_viewport = null
	_move_held = false
	_first_repeat_done = false
	_repeat_timer = 0.0
	set_process(false)


## Returns true when the navigator is currently managing buttons.
func is_active() -> bool:
	return _active


## Per-frame logic
func _process(delta: float) -> void:
	if not _active or _buttons.is_empty():
		return

	# Prune dead / hidden / disabled buttons
	_prune_buttons()
	if _buttons.is_empty():
		if DEBUG_LOG:
			print("UIMenuNavigator: all buttons pruned, deactivating")
		deactivate()
		return

	# Read input direction
	var move_dir := 0  # -1 = prev, +1 = next

	# VR thumbstick (right hand)
	if GameVariables.ENABLE_VR:
		var rh = Global.manager()._right_hand if Global.manager() else null
		if rh and is_instance_valid(rh) and rh is XRController3D:
			var stick: Vector2 = rh.get_vector2("primary")
			# Horizontal has priority (left/right layout), then vertical
			if abs(stick.x) > DEADZONE:
				move_dir = 1 if stick.x > 0 else -1
			elif abs(stick.y) > DEADZONE:
				# Y is inverted: push up = -Y in Godot XR
				move_dir = -1 if stick.y < -DEADZONE else 1

	# Desktop arrow keys (always checked, allows keyboard even in VR for sim)
	if move_dir == 0:
		if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_DOWN):
			move_dir = 1
		elif Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_UP):
			move_dir = -1

	# If user moved joystick/keys and focus isn't shown yet, wake up focus
	if move_dir != 0 and not _focus_shown:
		_show_focus()

	# Only process movement and confirm when focus is visible
	if _focus_shown:
		# Repeat logic
		if move_dir != 0:
			if not _move_held:
				# First press - move immediately
				_move_focus(move_dir)
				_move_held = true
				_first_repeat_done = false
				_repeat_timer = 0.0
			else:
				_repeat_timer += delta
				var threshold = INITIAL_REPEAT_SEC if not _first_repeat_done else REPEAT_SEC
				if _repeat_timer >= threshold:
					_move_focus(move_dir)
					_repeat_timer = 0.0
					_first_repeat_done = true
		else:
			_move_held = false
			_first_repeat_done = false
			_repeat_timer = 0.0

		# Confirm (select)
		var confirm := false

		# VR: primary_click (thumbstick press) only.
		# Trigger is reserved for raycast pointing — using it here too would
		# cause double-activation when both systems are active.
		if GameVariables.ENABLE_VR:
			var rh = Global.manager()._right_hand if Global.manager() else null
			if rh and is_instance_valid(rh) and rh is XRController3D:
				if rh.is_button_just_pressed("primary_click"):
					confirm = true

		# Desktop: Enter or Space
		if not confirm:
			if Input.is_action_just_pressed("ui_accept"):
				confirm = true

		if confirm and _focus_index >= 0 and _focus_index < _buttons.size():
			var btn = _buttons[_focus_index]
			if is_instance_valid(btn) and not btn.disabled:
				# Emit button_down which is what our VR buttons listen to
				btn.button_down.emit()


## Helpers

## Show focus highlight on buttons - called lazily on first joystick/keyboard input.
func _show_focus() -> void:
	if _focus_shown or _buttons.is_empty():
		return
	_focus_shown = true

	# Build the focus outline style on first use
	if not _focus_stylebox:
		_focus_stylebox = StyleBoxFlat.new()
		_focus_stylebox.bg_color = Color(1, 1, 1, 0.08)
		_focus_stylebox.border_color = Color(0.3, 0.8, 1.0, 1.0)  # bright cyan
		_focus_stylebox.border_width_left = 4
		_focus_stylebox.border_width_right = 4
		_focus_stylebox.border_width_top = 4
		_focus_stylebox.border_width_bottom = 4
		_focus_stylebox.corner_radius_top_left = 8
		_focus_stylebox.corner_radius_top_right = 8
		_focus_stylebox.corner_radius_bottom_left = 8
		_focus_stylebox.corner_radius_bottom_right = 8

	# Apply focus style and enable focus on all managed buttons
	for btn in _buttons:
		if is_instance_valid(btn):
			btn.focus_mode = Control.FOCUS_ALL
			btn.add_theme_stylebox_override("focus", _focus_stylebox)

	# Grab focus on the current button
	if _focus_index >= 0 and _focus_index < _buttons.size():
		var btn = _buttons[_focus_index]
		if is_instance_valid(btn):
			btn.grab_focus()


func _move_focus(direction: int) -> void:
	if _buttons.is_empty():
		return

	_focus_index = wrapi(_focus_index + direction, 0, _buttons.size())

	# Grab focus on the new button
	if _focus_index >= 0 and _focus_index < _buttons.size():
		var btn = _buttons[_focus_index]
		if is_instance_valid(btn):
			btn.grab_focus()


func _prune_buttons() -> void:
	var i := _buttons.size() - 1
	while i >= 0:
		var btn = _buttons[i]
		if not is_instance_valid(btn) or not btn.visible or btn.disabled:
			_buttons.remove_at(i)
			if _focus_index >= _buttons.size():
				_focus_index = _buttons.size() - 1
		i -= 1
