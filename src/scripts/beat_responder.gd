extends Node

class_name BeatResponder

@export var materials = [] # (Array,ShaderMaterial) — static materials (walls, etc.)
@export var params: Dictionary
@export var lerp_value: float = 0.5
@export var disabled :=false
@export var set_value: float = 10.0
@export var response_frequency: float = 1.0
@export var min_average_freq: float = 0.015;

#Refs
@onready var _beat_player = Global.manager()._beatplayer
@onready var _bus = AudioServer.get_bus_effect_instance(0,0)


var last_beat = 0

# Materials registered at runtime by note.gd (via register_note_materials).
# Combined with the static `materials` export array in _process / _on_beat_detected.
var _note_materials: Array[ShaderMaterial] = []


func _ready():
	if disabled:
		return
	if not materials and _note_materials.is_empty():
		set_process(false)
		return
	
	if _beat_player:
		_beat_player.connect("beat", Callable(self, "_on_beat_detected"))
		_beat_player.connect("reset", Callable(self, "_on_beatplayer_reset"))


## Register note materials so BeatResponder animates their shader params (e.g. min_displace).
## Called by note.gd:setup_note(). Deduplicates so safe to call on every note spawn.
func register_note_materials(mats: Array) -> void:
	for mat in mats:
		if mat is ShaderMaterial and not _note_materials.has(mat):
			_note_materials.append(mat)
	if not _note_materials.is_empty() or not materials.is_empty():
		set_process(true)


func _get_all_materials() -> Array:
	var all = materials.duplicate()
	all.append_array(_note_materials)
	return all


func _process(delta):
	if not disabled:
		for material in _get_all_materials():
			for key in params.keys():
				if material.get_shader_parameter(key) != null:
					var current_value = material.get_shader_parameter(key)
					# Godot 4: lerp requires all arguments to be same type (float)
					material.set_shader_parameter(key, lerpf(float(current_value), float(set_value), lerp_value * delta))


func _on_beat_detected(beat):
	var mag = _bus.get_magnitude_for_frequency_range(0,20000,1).length()
	if GameVariables.DEBUG_LOGGING:
		print(mag)
	if not disabled and mag>min_average_freq:
		if beat>=last_beat + response_frequency:
			for material in _get_all_materials():
				for key in params.keys():
					if material.get_shader_parameter(key) != null:
						#print (key, " ", params[key])
						material.set_shader_parameter(key, params[key])
			last_beat = beat

func _on_beatplayer_reset(beat):
	last_beat=beat