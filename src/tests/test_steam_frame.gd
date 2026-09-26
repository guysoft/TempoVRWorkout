extends SceneTree

# Headless verification of Steam Frame (Linux arm64) support.
#
# Checks two things:
#   1. export_presets.cfg contains a "Steam Frame Arm64" Linux preset that
#      targets the arm64 architecture and matches the x86_64 Linux preset's
#      resource filters.
#   2. openxr_action_map.tres contains the Valve Steam Frame controller
#      interaction profile and binds the actions the game actually reads.
#
# Run with: godot --headless --script res://tests/test_steam_frame.gd

const PRESET_NAME := "Steam Frame Arm64"
const PROFILE_PATH := "/interaction_profiles/valve/frame_controller_valve"
const EXPORT_PATH := "build/linux-arm64/TempoVR.arm64"

# Actions the game/XR Tools consume (grep confirmed these are used in scripts/).
const REQUIRED_ACTIONS := [
	"trigger", "trigger_click", "trigger_touch",
	"grip", "grip_click",
	"primary", "primary_click", "primary_touch",
	"menu_button",
	"ax_button", "ax_touch", "by_button", "by_touch",
	"default_pose", "aim_pose", "grip_pose", "palm_pose",
	"haptic",
]

var _passed := true


func _init():
	print("\n=== Steam Frame Tests ===\n")
	_test_export_preset()
	_test_action_map()
	_finish()


func _test_export_preset():
	print("-- export_presets.cfg --")
	var cfg := ConfigFile.new()
	var err := cfg.load("res://export_presets.cfg")
	_check(err == OK, "export_presets.cfg failed to load (err %d)" % err)
	if err != OK:
		return

	var sections := cfg.get_sections()
	var preset_section := ""
	for section in sections:
		if section.begins_with("preset.") and cfg.get_value(section, "name", "") == PRESET_NAME:
			preset_section = section
			break

	_check(preset_section != "", "no preset named '%s'" % PRESET_NAME)
	if preset_section == "":
		return

	var options := preset_section + ".options"
	_check(cfg.get_value(preset_section, "platform", "") == "Linux", "preset platform is not Linux")
	_check(cfg.get_value(preset_section, "export_path", "") == EXPORT_PATH,
		"preset export_path is '%s', expected '%s'" % [cfg.get_value(preset_section, "export_path", ""), EXPORT_PATH])
	_check(cfg.get_value(options, "binary_format/architecture", "") == "arm64",
		"preset architecture is not arm64")
	_check(cfg.get_value(options, "binary_format/embed_pck", false) == true, "embed_pck is not enabled")

	# Same resource filters as the x86_64 Linux preset so both builds ship the same content.
	var filters := ""
	for section in sections:
		if section.begins_with("preset.") and cfg.get_value(section, "name", "") == "Linux":
			_check(cfg.get_value(section, "include_filter", "") == cfg.get_value(preset_section, "include_filter", ""),
				"include_filter differs from the x86_64 Linux preset")
			_check(cfg.get_value(section, "exclude_filter", "") == cfg.get_value(preset_section, "exclude_filter", ""),
				"exclude_filter differs from the x86_64 Linux preset")
			filters = section
	_check(filters != "", "could not find the x86_64 Linux preset for comparison")


func _test_action_map():
	print("-- openxr_action_map.tres --")
	var map = load("res://openxr_action_map.tres")
	_check(map != null, "action map failed to load")
	if map == null:
		return

	var profile = null
	for candidate in map.interaction_profiles:
		if candidate.interaction_profile_path == PROFILE_PATH:
			profile = candidate
			break
	_check(profile != null, "Steam Frame interaction profile '%s' not found" % PROFILE_PATH)
	if profile == null:
		return

	var bound_actions := {}
	for binding in profile.bindings:
		if binding.action != null:
			bound_actions[binding.action.resource_name] = true

	for action_name in REQUIRED_ACTIONS:
		_check(bound_actions.has(action_name), "Steam Frame profile does not bind action '%s'" % action_name)


func _finish():
	print("\n=== Test Summary ===")
	if _passed:
		print("✓ ALL STEAM FRAME TESTS PASSED")
	else:
		print("✗ SOME TESTS FAILED")
	quit(0 if _passed else 1)


func _check(condition: bool, message: String):
	if condition:
		print("  ✓ PASS")
	else:
		_passed = false
		print("  ✗ FAIL: ", message)
