extends Node

signal fuel_changed(value: float)
signal rations_changed(value: float)

var is_time_running: bool = false

# Backing storage
var _fuel: float = 100.0
var _rations: float = 100.0

# Public properties that emit signals when changed
var fuel: float:
	get:
		return _fuel
	set(value):
		_fuel = clamp(value, 0.0, 9999.0)
		fuel_changed.emit(_fuel)

var rations: float:
	get:
		return _rations
	set(value):
		_rations = clamp(value, 0.0, 9999.0)
		rations_changed.emit(_rations)

func _ready() -> void:
	Timekeeper.tick.connect(_on_tick) # hook Timekeeper's signal to our handler


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("quick_save"):
		quick_save()
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("quick_load"):
		quick_load()
		get_viewport().set_input_as_handled()


func _on_tick(step: float) -> void:
	if !is_time_running: return
	# ~0.2 fuel/sec and ~0.1 rations/sec (tweak later)
	fuel -= 0.2 * step * 10.0
	rations -= 0.1 * step * 10.0


# --------------------------
# Save/Load System
# --------------------------

## Save the entire game state to a JSON file
func save_game(save_path: String = "user://savegame.json") -> bool:
	var save_data: Dictionary = {
		"version": "1.0.0",
		"timestamp": Time.get_datetime_string_from_system(),
		"game_state": {
			"fuel": _fuel,
			"rations": _rations,
			"is_time_running": is_time_running
		},
		"progression": {}
	}

	# Integrate ProgressionManager data
	if ProgressionManager != null:
		save_data["progression"] = ProgressionManager.save_all_to_dict()

	else:
		push_warning("GameState.save_game: ProgressionManager not available")

	# Convert to JSON
	var json_string: String = JSON.stringify(save_data, "\t")

	# Write to file
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("GameState.save_game: Failed to open file '%s' for writing. Error: %s" % [save_path, FileAccess.get_open_error()])
		return false

	file.store_string(json_string)
	file.close()


	return true


## Load the entire game state from a JSON file
func load_game(save_path: String = "user://savegame.json") -> bool:
	# Check if file exists
	if not FileAccess.file_exists(save_path):
		push_error("GameState.load_game: Save file '%s' does not exist" % save_path)
		return false

	# Read file
	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		push_error("GameState.load_game: Failed to open file '%s' for reading. Error: %s" % [save_path, FileAccess.get_open_error()])
		return false

	var json_string: String = file.get_as_text()
	file.close()

	# Parse JSON
	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_string)
	if parse_result != OK:
		push_error("GameState.load_game: JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return false

	var save_data: Dictionary = json.data
	if not save_data is Dictionary:
		push_error("GameState.load_game: Invalid save data format")
		return false

	# Load game state
	if save_data.has("game_state"):
		var gs: Dictionary = save_data["game_state"]
		_fuel = gs.get("fuel", 100.0)
		_rations = gs.get("rations", 100.0)
		is_time_running = gs.get("is_time_running", false)

		# Emit signals to update UI
		fuel_changed.emit(_fuel)
		rations_changed.emit(_rations)

	# Load progression data
	if save_data.has("progression") and ProgressionManager != null:
		ProgressionManager.load_all_from_dict(save_data["progression"])
	elif ProgressionManager == null:
		push_warning("GameState.load_game: ProgressionManager not available, skipping progression data")


	return true


## Quick save to default slot
func quick_save() -> bool:
	return save_game("user://quicksave.json")


## Quick load from default slot
func quick_load() -> bool:
	return load_game("user://quicksave.json")
