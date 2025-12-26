extends Control
class_name EncounterUI

## Emitted when combat concludes (win, loss, or retreat)
signal combat_ended(attacker: Node2D, defender: Node2D, winner: Node2D)
## Emitted when exit button is pressed
signal exit_pressed()

@onready var combat_label: Label = $Panel/VBoxContainer/CombatLabel
@onready var attack_button: Button = $Panel/VBoxContainer/AttackButton
@onready var exit_button: Button = $Panel/VBoxContainer/ExitButton

var _attacker: Node2D = null
var _defender: Node2D = null
var _combat_active: bool = false
var _tick_counter: int = 0
const TICKS_PER_COMBAT_ROUND: int = 5

func _ready() -> void:
	hide()
	if attack_button != null:
		attack_button.pressed.connect(_on_attack_pressed)
	if exit_button != null:
		exit_button.pressed.connect(_on_exit_pressed)

## Opens the encounter UI for manual combat
func open_encounter(attacker: Node2D, defender: Node2D) -> void:
	_attacker = attacker
	_defender = defender
	_combat_active = false
	_tick_counter = 0

	if _defender != null and _defender.get("_is_paused") != null:
		_defender.set("_is_paused", true)

	# Reset UI state for new encounter
	if attack_button != null:
		attack_button.disabled = false
		attack_button.text = "Attack"
		if attack_button.pressed.is_connected(_on_retreat_pressed):
			attack_button.pressed.disconnect(_on_retreat_pressed)
		if not attack_button.pressed.is_connected(_on_attack_pressed):
			attack_button.pressed.connect(_on_attack_pressed)
	if combat_label != null:
		combat_label.text = "Encounter!"

	visible = true
	modulate = Color.WHITE
	z_index = 100

## Closes the encounter UI
func close_ui() -> void:
	hide()
	_stop_automatic_combat()

	if _defender != null and _defender.get("_is_paused") != null:
		_defender.set("_is_paused", false)

func _on_attack_pressed() -> void:
	if _attacker == null or _defender == null:
		return

	# Execute first combat round immediately
	_execute_combat_round()

	# Start automatic combat cycle
	_start_automatic_combat()

	# Transform button to Retreat
	if attack_button != null:
		attack_button.text = "Retreat"
		attack_button.pressed.disconnect(_on_attack_pressed)
		attack_button.pressed.connect(_on_retreat_pressed)

func _execute_combat_round() -> void:
	if _attacker == null or _defender == null:
		return

	# Resolve one combat round
	var combat_manager: Node = get_node_or_null("/root/CombatManager")
	if combat_manager != null and combat_manager.has_method("resolve_combat_round"):
		combat_manager.resolve_combat_round(_attacker, _defender)

	# Check if combat is over
	var attacker_sheet: CharacterSheet = _attacker.get("charactersheet")
	var defender_sheet: CharacterSheet = _defender.get("charactersheet")

	if attacker_sheet == null or defender_sheet == null:
		return

	# Update combat feedback
	combat_label.text = "Combat! HP: You %d/%d | Enemy %d/%d" % [
		attacker_sheet.current_health,
		attacker_sheet.get_effective_health(),
		defender_sheet.current_health,
		defender_sheet.get_effective_health()
	]

	if attacker_sheet.current_health <= 0:
		combat_ended.emit(_attacker, _defender, _defender)
		close_ui()
	elif defender_sheet.current_health <= 0:
		combat_ended.emit(_attacker, _defender, _attacker)
		close_ui()

func _start_automatic_combat() -> void:
	_combat_active = true
	_tick_counter = 0

	var timekeeper: Node = get_node_or_null("/root/Timekeeper")
	if timekeeper != null and timekeeper.has_signal("tick"):
		if not timekeeper.tick.is_connected(_on_timekeeper_tick):
			timekeeper.tick.connect(_on_timekeeper_tick)

func _stop_automatic_combat() -> void:
	_combat_active = false
	_tick_counter = 0

	var timekeeper: Node = get_node_or_null("/root/Timekeeper")
	if timekeeper != null and timekeeper.has_signal("tick"):
		if timekeeper.tick.is_connected(_on_timekeeper_tick):
			timekeeper.tick.disconnect(_on_timekeeper_tick)

func _on_timekeeper_tick(_step: float) -> void:
	if not _combat_active:
		return

	_tick_counter += 1

	if _tick_counter >= TICKS_PER_COMBAT_ROUND:
		_tick_counter = 0
		_execute_combat_round()

func _on_retreat_pressed() -> void:
	combat_ended.emit(_attacker, _defender, null)
	close_ui()

func _on_exit_pressed() -> void:
	exit_pressed.emit()
	close_ui()
