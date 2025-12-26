extends Node2D
class_name Building

@export var display_name: String = "Building"
@export var footprint: Vector2i = Vector2i(1, 1)
@export var pop_cap_bonus: int = 0
@export var produces: Dictionary = {}  # e.g. { }
@export var consumes: Dictionary = {}  # e.g. { 

func apply_state(_state) -> void:
	# override per-building if needed
	pass

func get_population_cap_bonus() -> int:
	return pop_cap_bonus

func tick_economy(dt: float) -> Dictionary:
	var delta: Dictionary = {}
	for k in produces.keys():
		delta[k] = (delta.get(k, 0.0) as float) + float(produces[k]) * dt
	for k in consumes.keys():
		delta[k] = (delta.get(k, 0.0) as float) - float(consumes[k]) * dt
	return delta
